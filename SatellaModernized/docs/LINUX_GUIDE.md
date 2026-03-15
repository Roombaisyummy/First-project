# SatellaJailed Modernized - Arch Linux Build Guide

## Overview

This tweak **can be built on Linux** (including Arch) with the right setup. The patches applied remove macOS-specific dependencies.

## Prerequisites

### System Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| **OS** | Arch Linux (or any x86_64 Linux) | Tested on Arch |
| **Architecture** | x86_64 | For cross-compilation to arm64 |
| **Disk Space** | ~5 GB | For SDKs and toolchain |
| **RAM** | 4 GB minimum | 8 GB recommended |

## Step 1: Install Base Dependencies

```bash
# Essential build tools
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
    wget
```

## Step 2: Install Swift Toolchain

### Option A: Official Swift.org Toolchain (Recommended)

```bash
# Download Swift 6.0.3 for Ubuntu 22.04 (works on Arch)
cd /tmp
wget https://download.swift.org/swift-6.0.3-release/ubuntu2204/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE-ubuntu22.04.tar.gz

# Extract
sudo tar xzf swift-6.0.3-RELEASE-ubuntu22.04.tar.gz -C /opt/

# Create symlinks
sudo ln -sf /opt/swift-6.0.3-RELEASE-ubuntu22.04/usr/bin/swift /usr/local/bin/swift
sudo ln -sf /opt/swift-6.0.3-RELEASE-ubuntu22.04/usr/bin/swiftc /usr/local/bin/swiftc

# Fix library symlinks (Arch uses newer ncurses)
sudo ln -sf /usr/lib/libncursesw.so.6 /usr/lib/libncurses.so.6
sudo ln -sf /usr/lib/libxml2.so.16 /usr/lib/libxml2.so.2

# Verify
swift --version
```

### Option B: AUR Swift Package

```bash
# Install from AUR (may be outdated)
yay -S swift-lang
```

## Step 3: Install Theos

```bash
# Clone Theos
export THEOS=/opt/theos
sudo git clone --recursive https://github.com/theos/theos.git $THEOS

# Install additional Theos dependencies
sudo pacman -S --needed --noconfirm \
    libimobiledevice \
    usbmuxd \
    ldid
```

### Install iOS SDK

```bash
# Download iPhoneOS SDK (required for cross-compilation)
cd $THEOS/sdks

# Option 1: Clone from Theos SDKs repo
sudo git clone https://github.com/theos/sdks.git
sudo mv sdks/iPhoneOS16.0.sdk .
sudo rm -rf sdks

# Option 2: Extract from Xcode (if you have Mac access)
# Copy iPhoneOS16.0.sdk from /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/
```

### Set Environment Variables

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
export THEOS=/opt/theos
export PATH=$PATH:$THEOS/bin
```

Then reload:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

## Step 4: Clone SatellaJailed Modernized

```bash
# Clone your repo
cd ~
git clone <your-repo-url> SatellaJailed-Modernized
cd SatellaJailed-Modernized
```

## Step 5: Fetch Jinx Dependency

### Option A: Using Swift Package Manager

```bash
cd Tweak
swift package resolve
cd ..
```

### Option B: Manual Clone (if SPM fails)

```bash
mkdir -p Tweak/.build/checkouts
cd Tweak/.build/checkouts
git clone https://github.com/Paisseon/Jinx.git
cd ../../../
```

## Step 6: Build the Tweak

```bash
cd ~/SatellaJailed-Modernized

# Clean previous builds
make clean

# Build package
make package FINALPACKAGE=1
```

### Expected Output

```
> Making SatellaJailed for iphone:clang:latest:12.2...
> Compiling Swift source...
> Linking SatellaJailed.dylib...
> Signing SatellaJailed.dylib...
> Packaging SatellaJailed...
```

### Build Artifacts

```
packages/
├── com.yourrepo.satellajailed-modernized_1.0_iphoneos-arm.deb
└── SatellaJailed.dylib
```

## Step 7: Deploy to Device

### Method 1: Sideload with AltStore/SideStore

```bash
# The .deb contains the dylib - extract it
cd packages
ar x *.deb
tar -xzf data.tar.*

# Copy SatellaJailed.dylib to your IPA's Frameworks/
# Then sign and install with AltStore
```

### Method 2: Use Patch Scripts

```bash
# Move your target IPA to the repo folder
cp /path/to/target.ipa ~/SatellaJailed-Modernized/

# Run patch script
sh patch-linux.sh -i target.ipa

# Install patched IPA with your preferred sideloading method
```

### Method 3: Direct Install (Jailbroken Device)

```bash
# Copy .deb to device
scp packages/*.deb root@your-device:/var/root/

# SSH to device and install
ssh root@your-device
dpkg -i /var/root/*.deb
uicache -a
```

## Troubleshooting

### Error: "Could not locate Jinx sources"

```bash
# Set JINX_PATH manually
export JINX_PATH=/path/to/SatellaJailed-Modernized/Tweak/.build/checkouts/Jinx/Sources/Jinx

# Or clone manually
git clone https://github.com/Paisseon/Jinx.git Tweak/.build/checkouts/Jinx
```

### Error: "Cannot find iPhoneOS16.0.sdk"

```bash
# Verify SDK location
ls $THEOS/sdks/iPhoneOS16.0.sdk

# If missing, download:
cd $THEOS/sdks
git clone https://github.com/theos/sdks.git
mv sdks/iPhoneOS16.0.sdk .
rm -rf sdks
```

### Error: "swift: not found" or library errors

```bash
# Create required symlinks
sudo ln -sf /usr/lib/libncursesw.so.6 /usr/lib/libncurses.so.6
sudo ln -sf /usr/lib/libxml2.so.16 /usr/lib/libxml2.so.2

# Add Swift to PATH
export PATH=/opt/swift-6.0.3-RELEASE-ubuntu22.04/usr/bin:$PATH
```

### Error: "install_name_tool: command not found"

This only affects ROOTLESS=1 builds. For non-rootless (default):

```bash
# Ensure ROOTLESS=0 in Makefile
export ROOTLESS=0
make package FINALPACKAGE=1
```

### Build succeeds but dylib crashes

```bash
# Re-sign with ldid
ldid -S packages/SatellaJailed.dylib

# Or use theos signing
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=ios-appstore
```

### Swift package resolve fails

Use manual clone instead:

```bash
mkdir -p Tweak/.build/checkouts
cd Tweak/.build/checkouts
git clone https://github.com/Paisseon/Jinx.git
cd ../../../
make package FINALPACKAGE=1
```

## Rootless Build (Optional)

If targeting rootless jailbreaks (Dopamine, etc.):

```bash
# Edit Makefile - change ROOTLESS = 0 to ROOTLESS = 1
sed -i 's/ROOTLESS = 0/ROOTLESS = 1/' Makefile

# Build
make package FINALPACKAGE=1
```

Note: Rootless builds require `install_name_tool` which is macOS-only. You may need to:
- Use a macOS VM for final packaging
- Replace with a custom script using `vtool` or similar

## Architecture Notes

### Current Target: arm64 (Standard)

- Works on: A7-A11 devices, non-checkra1n devices
- Jailbreaks: Dopamine, XinaA15, etc.

### Not Targeted: arm64e

- A12+ devices only
- Requires additional entitlements
- More complex build process

## Post-Build Testing

### Verify Dylib Structure

```bash
# Check architecture
file packages/SatellaJailed.dylib
# Should show: Mach-O 64-bit dynamically linked shared library arm64

# Check load commands
otool -l packages/SatellaJailed.dylib | grep -A 5 LC_LOAD_DYLIB

# Check symbols
nm packages/SatellaJailed.dylib | grep -i "tella"
```

### Test on Device

1. Install patched IPA or .deb
2. Open target app
3. Attempt IAP purchase
4. Verify stealth mode works (if enabled)

## Performance Tips

### Faster Builds

```bash
# Use ccache
sudo pacman -S ccache
export CCACHE_SLOPPINESS=clang_index_store,file_stat_matches,include_file_ctime,include_file_mtime,ivfsoverlay,pch_defines,modules,system_headers,time_macros
export CC=/usr/bin/clang
export CXX=/usr/bin/clang++

# Build with more jobs
make -j$(nproc) package FINALPACKAGE=1
```

### Clean Builds

```bash
# Full clean
make clean
rm -rf Tweak/.build
rm -rf .theos

# Rebuild
make package FINALPACKAGE=1
```

## Complete Build Script

Save as `build.sh`:

```bash
#!/bin/bash
set -e

echo "=== SatellaJailed Modernized - Linux Build Script ==="

# Environment
export THEOS=/opt/theos
export PATH=$PATH:$THEOS/bin:/opt/swift-6.0.3-RELEASE-ubuntu22.04/usr/bin

# Check dependencies
command -v swift >/dev/null 2>&1 || { echo "Swift not found"; exit 1; }
command -v make >/dev/null 2>&1 || { echo "Make not found"; exit 1; }
[ -d "$THEOS" ] || { echo "Theos not found at $THEOS"; exit 1; }
[ -d "$THEOS/sdks/iPhoneOS16.0.sdk" ] || { echo "iOS SDK not found"; exit 1; }

# Fetch Jinx if missing
if [ ! -d "Tweak/.build/checkouts/Jinx" ]; then
    echo "Fetching Jinx dependency..."
    cd Tweak
    mkdir -p .build/checkouts
    cd .build/checkouts
    git clone https://github.com/Paisseon/Jinx.git
    cd ../../..
fi

# Build
echo "Building..."
make clean
make package FINALPACKAGE=1

echo "Build complete! Output in packages/"
ls -lh packages/
```

Make executable and run:
```bash
chmod +x build.sh
./build.sh
```

## Summary

✅ **Linux-buildable**: Yes, with Theos + iOS SDK + Swift toolchain
✅ **macOS required**: No (only for ROOTLESS=1 with install_name_tool)
✅ **Patches applied**: Jinx path, sed compatibility, Darwin.POSIX removal
✅ **Arch-specific**: Use official Swift toolchain + symlinks for libraries

---

**For issues, check MODERNIZATION_2026.md for detection troubleshooting.**
