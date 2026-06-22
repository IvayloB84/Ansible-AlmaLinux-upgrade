#!/usr/bin/env bash -e

# =================================================================
# 1. VERIFY RUNTIME STATUS (Sufficient Python 3.12+)
# =================================================================
echo "* Checking system Python status..."

if command -v python3 >/dev/null 2>&1; then
    INSTALLED_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    # Use awk to evaluate numerical values cleanly (e.g., 3.12 >= 3.12)
    IS_SUFFICIENT=$(echo "$INSTALLED_VER" | awk '{print ($1 >= 3.12) ? "yes" : "no"}')
    
    if [ "$IS_SUFFICIENT" = "yes" ]; then
        echo "* Complete. A sufficient Python version ($INSTALLED_VER) is active. Skipping setup."
        exit 0
    fi
fi

# =================================================================
# 2. DYNAMIC REPOSITORY MAXIMUM VERSION EXTRACTION
# =================================================================
echo "* Auditing distribution repositories for available Python streams..."

# Cleanly query repo for package roots matching python3.<digit><digit> without architecture noise
REPO_MAX_VER=$(dnf repoquery --available --qf "%{name}" "python3.*" 2>/dev/null | \
               grep -E '^python3\.[0-9]+$' | \
               sed 's/python3\.//' | \
               sort -nu | \
               tail -n 1)

echo "* Highest available Python sub-version found in repositories: 3.${REPO_MAX_VER:-none}"

# =================================================================
# 3. DECISION & INSTALLATION PATHWAYS
# =================================================================
# If a repository stream exists and matches 3.12 or newer
if [ -n "$REPO_MAX_VER" ] && [ "$REPO_MAX_VER" -ge 12 ]; then
    TARGET_PACKAGE="python3.${REPO_MAX_VER}"
    echo "* Installing native package [${TARGET_PACKAGE}] from distribution streams..."
    
    dnf clean all
    dnf install -y "$TARGET_PACKAGE"
    DYNAMIC_BINARY="/usr/bin/python3.${REPO_MAX_VER}"
else
    # Fallback path if upgrading early lifecycle machines or offline hosts
    echo "* No optimal version found in repositories. Launching local RPM fallback routine..."
    
    dnf clean all
    systemctl daemon-reload
    
    echo "* Provisioning compilation prerequisites..."
    dnf groupinstall -y "Development Tools"
    dnf install -y wget openssl-devel bzip2-devel libffi-devel gcc make yum-utils
    
    mkdir -p /tmp/rpms
    if [ -d "/vagrant" ] && compgen -G "/vagrant/*.rpm" >/dev/null; then
        echo "* Deploying local RPM files..."
        cp /vagrant/*.rpm /tmp/rpms/
        dnf localinstall -y /tmp/rpms/*.rpm
    else
        echo "[ERROR] No fallback RPM assets surfaced inside the synced /vagrant channel!"
        exit 1
    fi
    
    # Safely identify whichever version got dropped by your custom local RPM folder
    DYNAMIC_BINARY=$(ls /usr/bin/python3.[1-9][0-9] | sort -V | tail -n 1)
fi

# =================================================================
# 4. CONFIGURATION MAPPING & VERIFICATION
# =================================================================
if [ -f "$DYNAMIC_BINARY" ]; then
    VERSION_SUFFIX=$(basename "$DYNAMIC_BINARY" | sed 's/python//') # e.g. "3.12", "3.13"
    CLEAN_ALIAS="python$(echo "$VERSION_SUFFIX" | tr -d '.')"       # e.g. "python312", "python313"
    
    echo "* Configuration: Linking $DYNAMIC_BINARY to /usr/bin/$CLEAN_ALIAS"
    ln -sf "$DYNAMIC_BINARY" "/usr/bin/$CLEAN_ALIAS"
else
    echo "[WARNING] Target executable binary could not be resolved at path: $DYNAMIC_BINARY"
fi

# Summary tool prints
echo "================================================="
gcc --version | head -n 1
if command -v python3 >/dev/null 2>&1; then python3 --version; fi
echo "Custom alias test: $(command -v python312 || command -v python313 || echo 'No alias mapped')"