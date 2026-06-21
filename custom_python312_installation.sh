#!/usr/bin/env bash -e

  # Reusable Bash Script String with dynamic repository checks
    echo "* Checking system Python status..."
    
    # 1. Check if ANY modern Python 3.12+ is already installed
    if command -v python3 >/dev/null 2>&1; then
        INSTALLED_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
        # Using awk to handle version comparisons safely
        IS_SUFFICIENT=$(echo "$INSTALLED_VER" | awk '{print ($1 >= 12.0) ? "yes" : "no"}')
        
        if [ "$IS_SUFFICIENT" = "yes" ]; then
            echo "* A sufficient Python version ($INSTALLED_VER) is already installed. Skipping setup."
            exit 0
        fi
    fi

    # 2. Query repositories for the highest available python3.X package
    echo "* Checking distribution repositories for available Python packages..."
    REPO_MAX_VER=$(dnf list available "python3.*" 2>/dev/null | grep -E '^python3\.[0-9]+' | awk '{print $1}' | sed 's/python3\.//' | sort -n | tail -n 1)

    # 3. Decision Logic: Install from Repo if version > 12, otherwise use local RPMs
    if [ -n "$REPO_MAX_VER" ] && [ "$REPO_MAX_VER" -gt 12 ]; then
        TARGET_REPO_PACKAGE="python3.${REPO_MAX_VER}"
        echo "* Found a higher version in the repo: ${TARGET_REPO_PACKAGE}. Installing from repository..."
        
        yum clean all
        yum update -y
        yum install -y "$TARGET_REPO_PACKAGE"
    else
        echo "* No higher Python version found in repos (Max repo sub-version: ${REPO_MAX_VER:-none}). Falling back to local RPM fallback..."
        
        yum clean all
        yum update -y
        systemctl daemon-reload
        
        echo "* Installing compilation building blocks and tools..."
        yum install -y wget openssl-devel bzip2-devel libffi-devel gcc make
        yum groupinstall -y "Development Tools"
        
        mkdir -p /tmp/rpms
        if [ -d "/vagrant" ] && ls /vagrant/*.rpm >/dev/null 2>&1; then
            cp /vagrant/*.rpm /tmp/rpms/
            echo "* Installing local RPM files (including Python 3.12)..."
            dnf localinstall -y /tmp/rpms/*.rpm
        else
            echo "[WARNING] No RPM files found in /vagrant folder to install!"
        fi
    fi

    # Print final tool states
    gcc --version
    if command -v python3 >/dev/null 2>&1; then python3 --version; fi