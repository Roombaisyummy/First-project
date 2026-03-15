# SatellaJailed Modernized (2026)

> **Educational/Penetration Testing Tool** - For authorized security research only.

**Quick Links:**
- [📊 Project Status (What Works/Doesn't)](./STATUS.md)
- [🛠️ Build & Setup Guide](./docs/BUILD.md)
- [🏗️ Internal Architecture](./docs/ARCHITECTURE.md)
- [🕵️ Stealth Technical Specs](./docs/STEALTH.md)
- [🆚 Comparison with Original](./docs/COMPARISON.md)

---

## Overview

This is a modernized version of SatellaJailed with enhanced stealth capabilities for testing iOS app IAP security. It features improved storage encoding, anti-analysis detection, and early-stage inline hooking.

### Key Features (Modernized)

- **Covert Storage:** Moves away from identifiable `tella_*` UserDefaults keys to high-entropy encoded keys and Keychain storage.
- **Anti-Analysis:** Built-in detection for debuggers (sysctl), Frida (ports/maps), and common jailbreak indicators.
- **Improved Hooks:** Transitioning from simple swizzling to inline hooking to evade IMP-based detection.
- **Linux Compatibility:** Full support for building on Arch Linux and other Linux distributions via Theos.

---

## Quick Build (Linux)

```bash
# Setup environment (Arch Linux)
./setup-linux.sh

# Build the package
./build.sh
```

---

## Installation

### Sideload (Patched IPA)
```bash
# macOS
sh patch-mac.sh -i target.ipa

# Linux/WSL
sh patch-linux.sh -i target.ipa
```

### On-Device (.deb)
Install the package from the `packages/` directory using `dpkg -i`.

---

## For Defenders: Detection Guide

See [COMPARISON.md](./docs/COMPARISON.md) and [STEALTH.md](./docs/STEALTH.md) for the current modernization and detection notes.

---

## Disclaimer

**Authorized penetration testing and educational use only.** The authors are not responsible for any misuse.
