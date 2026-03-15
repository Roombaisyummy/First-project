#!/bin/bash
# SatellaJailed Modernized - Arch Linux Setup & Build Script
# Run this script as a normal user. It uses sudo only for package installs.

set -euo pipefail

echo "=============================================="
echo "SatellaJailed Modernized - Linux Setup"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "Missing required command: $1"
        exit 1
    fi
}

if [ "${EUID}" -eq 0 ]; then
    log_error "Run this script as your normal user, not with sudo."
    exit 1
fi

require_command sudo
require_command git
require_command curl
require_command bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEOS_DIR="${THEOS:-$HOME/theos}"

echo ""
log_info "Step 1: Installing system dependencies..."
echo ""

sudo pacman -S --needed --noconfirm \
    git \
    make \
    clang \
    lld \
    llvm \
    perl \
    fakeroot \
    dpkg \
    binutils \
    coreutils \
    sed \
    tar \
    gzip \
    openssl \
    libxml2 \
    ncurses \
    curl \
    wget \
    libimobiledevice \
    usbmuxd

if ! pacman -Qi ldid >/dev/null 2>&1; then
    if command -v yay >/dev/null 2>&1; then
        log_info "Installing ldid from AUR with yay..."
        yay -S --noconfirm ldid
    else
        log_error "ldid is not installed and no AUR helper was found."
        log_error "Install ldid manually, then rerun this script."
        exit 1
    fi
else
    log_warn "ldid already installed"
fi

echo ""
log_info "Step 2: Installing Theos and the Linux iPhone toolchain..."
echo ""

if [ -d "$THEOS_DIR/.git" ]; then
    log_warn "Theos already exists at $THEOS_DIR"
else
    git clone --recursive https://github.com/theos/theos.git "$THEOS_DIR"
fi

echo ""
log_info "Running the official Theos installer..."
echo ""

chmod +x "$THEOS_DIR/bin/install-theos"
THEOS="$THEOS_DIR" bash "$THEOS_DIR/bin/install-theos" <<'EOF'
y
EOF

echo ""
log_info "Step 3: Setting up environment..."
echo ""

if ! grep -q "export THEOS=" ~/.bashrc 2>/dev/null; then
    echo "" >> ~/.bashrc
    echo "# Theos environment" >> ~/.bashrc
    echo "export THEOS=$THEOS_DIR" >> ~/.bashrc
    echo "export PATH=\$PATH:\$THEOS/bin" >> ~/.bashrc
    log_info "Environment variables added to ~/.bashrc"
else
    log_warn "Theos environment already in ~/.bashrc"
fi

export THEOS="$THEOS_DIR"
export PATH="$PATH:$THEOS/bin"

echo ""
log_info "Step 4: Fetching Jinx dependency..."
echo ""

cd "$SCRIPT_DIR/Tweak"

if [ ! -d ".build/checkouts/Jinx" ]; then
    mkdir -p .build/checkouts
    cd .build/checkouts
    git clone https://github.com/Paisseon/Jinx.git
    log_info "Jinx cloned successfully!"
else
    log_warn "Jinx already present"
fi

cd "$SCRIPT_DIR"

echo ""
echo "=============================================="
echo "Setup Complete!"
echo "=============================================="
echo ""
echo "To build the tweak, run:"
echo "  cd $SCRIPT_DIR"
echo "  make package FINALPACKAGE=1"
echo ""
echo "Or use the build script:"
echo "  ./build.sh"
echo ""
echo "Build artifacts will be in: packages/"
echo ""

log_info "Remember to run: source ~/.bashrc (or restart your terminal)"
