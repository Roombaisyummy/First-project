# SatellaJailed Modernized - Build & Setup Guide

This guide covers the environment setup and compilation process for both Linux (Arch/Ubuntu) and macOS.

---

## 🚀 Quick Setup (Linux/Arch)

If you are on Arch Linux, use the provided setup script:

```bash
# Install dependencies, Theos, and iOS SDK
./setup-linux.sh

# Build the package
./build.sh
```

---

## 🛠️ Manual Environment Setup

### 1. Requirements
- **Swift 6.0+**
- **Theos** (Mobile development environment)
- **iOS SDK 15.0+**
- **ldid** (Link Identity Editor)
- **dpkg** (Debian package manager)

### 2. macOS Setup
```bash
# Install Theos
brew install ldid dpkg make
git clone --recursive https://github.com/theos/theos.git $THEOS

# Install iOS SDK to $THEOS/sdks/
```

### 3. Linux Setup
Follow the [LINUX_GUIDE.md](./LINUX_GUIDE.md) for detailed steps on installing the cross-compilation toolchain and Swift on Linux.

---

## 📦 Compilation

### Build with Theos (Recommended)
```bash
export THEOS=/opt/theos
cd /home/natha/SatellaJailed-Modernized
make package FINALPACKAGE=1
```

The output will be located in the `packages/` directory as a `.deb` file.

### Build with SwiftPM (Syntax Check)
If you only want to verify the Swift code on Linux:
```bash
cd Tweak
swift build
```

---

## 📋 Common Issues

- **Missing Toolchain:** Ensure `/opt/theos/toolchain/linux/iphone/bin/clang` exists on Linux.
- **SDK Path:** Verify your SDK is located in `$THEOS/sdks/`.
- **Permission Denied:** Use `chmod +x` on the shell scripts before running.
