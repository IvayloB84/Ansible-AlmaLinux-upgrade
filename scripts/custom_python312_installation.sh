#!/bin/bash

set -euo pipefail

# AUTOMATED PATH RESOLUTION: Find the exact folder where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Running Python 3.12 Custom Native Installer ==="
echo "Script location verified at: ${SCRIPT_DIR}"

# =================================================================
# 1. VERIFY RUNTIME STATUS (Sufficient Python 3.12 exactly)
# =================================================================
echo "* Checking system Python status..."

if command -v python3 >/dev/null 2>&1; then
    INSTALLED_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    
    if [ "$INSTALLED_VER" = "3.12" ]; then
        echo "* Complete. Python 3.12 is already the default active version. Skipping setup."
        exit 0
    fi
fi

# =================================================================
# 2. DYNAMIC REPOSITORY MAXIMUM VERSION EXTRACTION (Targeting 3.12)
# =================================================================
echo "* Auditing distribution repositories for Python 3.12..."

# Explicitly check if python3.12 is available in the package manager streams
REPO_HAS_312=$(dnf list available python3.12 >/dev/null 2>&1 && echo "yes" || echo "no")

# =================================================================
# 3. DECISION & INSTALLATION PATHWAYS
# =================================================================
if [ "$REPO_HAS_312" = "yes" ]; then
    TARGET_PACKAGE="python3.12"
    echo "* Installing native package [${TARGET_PACKAGE}] from distribution streams..."
    
    dnf clean all
    dnf install -y python3.12 python3.12-pip
    DYNAMIC_BINARY="/usr/bin/python3.12"
else
    # Fallback path if upgrading early lifecycle machines or offline hosts
    echo "* Python 3.12 not found in repositories. Launching local RPM fallback routine..."
    
    dnf clean all
    
    mkdir -p /tmp/rpms
    if compgen -G "${SCRIPT_DIR}/*python3*12*.rpm" >/dev/null; then
        echo "* Deploying local Python 3.12 RPM files..."
        cp ${SCRIPT_DIR}/*python3*12*.rpm /tmp/rpms/
        dnf localinstall -y /tmp/rpms/*.rpm
    else
        echo "[ERROR] No Python 3.12 RPM assets surfaced inside the script channel: ${SCRIPT_DIR}"
        exit 1
    fi
    
    DYNAMIC_BINARY="/usr/bin/python3.12"
fi

# =================================================================
# 4. CONFIGURATION MAPPING & ALTERNATIVES REGISTRATION
# =================================================================
if [ -f "$DYNAMIC_BINARY" ]; then
    echo "* Registering Python 3.12 with system alternatives..."
    
    # 1. If an alternatives group for python3 doesn't exist yet, seed it with the original python3
    if ! alternatives --display python3 >/dev/null 2>&1; then
        ORIGINAL_PYTHON3=$(readlink -f /usr/bin/python3 2>/dev/null || echo "/usr/bin/python3")
        # Ensure we don't map alternatives to itself if it's already a symlink loop
        if [ "$ORIGINAL_PYTHON3" != "/usr/bin/python3" ] && [ -f "$ORIGINAL_PYTHON3" ]; then
            alternatives --install /usr/bin/python3 python3 "$ORIGINAL_PYTHON3" 1
        fi
    fi

    # 2. Add Python 3.12 to alternatives with high priority (priority 100) to force it as default
    alternatives --install /usr/bin/python3 python3 "$DYNAMIC_BINARY" 100
    alternatives --set python3 "$DYNAMIC_BINARY"
    
    # 3. Handle explicit backward compatibility aliases requested
    ln -sf "$DYNAMIC_BINARY" "/usr/bin/python312"
    echo "* Success: /usr/bin/python3 is now globally managed and points to $DYNAMIC_BINARY"
else
    echo "[ERROR] Target executable binary could not be resolved at path: $DYNAMIC_BINARY"
    exit 1
fi

# Summary tool prints
echo "================================================="
if command -v python3 >/dev/null 2>&1; then 
    echo -n "Global default path: " && which python3
    echo -n "Global default version: " && python3 --version
fi
echo "Custom alias test: $(command -v python312 || echo 'No alias mapped')"