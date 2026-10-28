#!/bin/sh
# Script to install BATS (Bash Automated Testing System)

set -e

# Detect OS
if [ "$(uname)" = "Darwin" ]; then
    # macOS
    echo "Detected macOS, using Homebrew to install BATS..."
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew not found. Please install Homebrew first:"
        echo "  /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi

    if ! brew list bats-core >/dev/null 2>&1; then
        brew install bats-core
    else
        echo "BATS already installed"
    fi

elif [ -f /etc/debian_version ]; then
    # Debian/Ubuntu
    echo "Detected Debian/Ubuntu, using apt to install BATS..."
    if ! command -v bats >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y bats
    else
        echo "BATS already installed"
    fi

elif [ -f /etc/redhat-release ]; then
    # RHEL/CentOS
    echo "Detected RHEL/CentOS, installing BATS from GitHub..."
    if ! command -v bats >/dev/null 2>&1; then
        # Create temporary directory for installation
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"

        # Clone and install BATS
        git clone https://github.com/bats-core/bats-core.git
        cd bats-core
        sudo ./install.sh /usr/local

        # Clean up
        cd /
        rm -rf "$TEMP_DIR"
    else
        echo "BATS already installed"
    fi

else
    # Other Linux or Unix
    echo "Installing BATS from GitHub..."
    if ! command -v bats >/dev/null 2>&1; then
        # Create temporary directory for installation
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"

        # Clone and install BATS
        git clone https://github.com/bats-core/bats-core.git
        cd bats-core
        sudo ./install.sh /usr/local

        # Clean up
        cd /
        rm -rf "$TEMP_DIR"
    else
        echo "BATS already installed"
    fi
fi

# Verify installation
if command -v bats >/dev/null 2>&1; then
    echo "BATS installed successfully!"
    echo "Version information:"
    bats --version
    echo ""
    echo "To run phpvm tests, use: bats tests/"
else
    echo "BATS installation failed."
    exit 1
fi
