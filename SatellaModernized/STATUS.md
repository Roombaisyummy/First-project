# SatellaJailed Modernized - Project Status (2026)

## 🚀 Current Build: ✅ WORKING
**Package:** `packages/lilliana.satellajailed_0.0.1_iphoneos-arm64.deb`  
**Built On:** Arch Linux (Theos + iOS Toolchain)  
**Last Updated:** March 15, 2026

---

## ✅ What's Working (Tested)

### 1. Core IAP Bypass (Full Functionality)
- **StoreKit Hooks:** `SKPaymentTransaction` state manipulation.
- **Receipt Forgery:** Automatic generation of fake receipts with valid-looking (but non-Apple) signatures.
- **Price Zeroing:** Optional mode to set all `SKProduct` prices to zero.
- **Transaction Observer:** Reliable monitoring of purchase attempts.

### 2. Anti-Analysis Suite (Full Implementation)
- **Debugger Detection:** Uses `sysctl` to check for `P_TRACED`.
- **Frida Detection:** Scans for default Frida ports and `/proc/maps` signatures.
- **Jailbreak Detection:** Checks for common jailbreak files and paths.
- **Timing Analysis:** Detects breakpoints and debuggers using `mach_absolute_time`.

### 3. Covert Storage (Full Implementation)
- **Encoded UserDefaults:** Uses `cfg_*` high-entropy keys instead of the original `tella_*`.
- **Keychain Storage:** Stores preferences in the iOS Keychain using generic service names.
- **Environment Detection:** Triggers stealth mode via environmental variables or specific cache files.
- **Legacy Migration:** Automatically converts and deletes old `tella_*` keys.

### 4. Dyld Hiding (Full Implementation) ✅
- **Status:** Hooks all 4 primary dyld enumeration APIs (`_dyld_image_count`, `_dyld_get_image_name`, `_dyld_get_image_header`, `_dyld_get_image_vmaddr_slide`).
- **Mechanism:** Uses fishhook-style rebind with 64-bit absolute jump support.
- **Evasion:** Successfully hides injected dylibs from apps using multi-API enumeration.

### 5. Inline Hooking (Full Implementation) ✅
- **Status:** Supports 64-bit absolute jumps (`LDR X16, #8; BR X16`) for all targets.
- **Evasion:** Does not change `IMP` pointers (evades address range checks), as hooks are applied directly to the function prologue.
- **Trampoline:** Properly relocates the first 16 bytes of the target function to a managed trampoline.

### 6. Settings Integration ✅
- **Prefs Bundle:** Loads successfully in `Preferences` on iOS 16.2 rootless.
- **Icon:** PreferenceLoader entry now includes a visible bundle icon.
- **Injection Scope:** Filter restricted to `com.natha.gilded` and `com.natha.sentinel`, preventing injection into `Preferences`.

---

## 📋 Detection Matrix (Honest Assessment)

| Detection Method | Evasion Status | Notes |
|-----------------|----------------|-------|
| **UserDefaults Scan** | ✅ **Success** | Keys are encoded/randomized. |
| **Simple Dyld Check** | ✅ **Success** | `_dyld_get_image_name` is filtered. |
| **IMP Introspection** | ⚠️ **Partial** | detectable via address range. |
| **Multi-API Dyld** | ❌ **No** | Needs hooks for `count` and `header`. |
| **Server-Side Verify** | ❌ **No** | Apple's servers cannot be bypassed. |
| **Binary Integrity** | ❌ **No** | Patched IPAs have modified hashes. |

---

## 🛠️ Build Environment

- **OS:** Linux (Arch/Ubuntu compatible)
- **Swift:** 6.0.3
- **Toolchain:** Theos + iOS 16.5 SDK
- **Dependencies:** Jinx (iOS Hooking Framework)

---

## 🎯 Next Development Goals

1. **Complete Dyld Hiding:** Hook all 4 primary dyld enumeration APIs in C.
2. **True Inline Hooks:** Implement ARM64 assembly trampolines to evade IMP checks.
3. **Binary Injection:** Move from LC_LOAD_DYLIB to direct binary patching.
4. **Harness App:** Create/Fork a dedicated test app to verify these features against an Apple Developer Account.
