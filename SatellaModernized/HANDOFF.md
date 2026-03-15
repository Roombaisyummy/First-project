# Project Handoff: Satella Modernized (Pen-Test Edition)

**Target Environment:** iOS 16.2 (Dopamine Rootless)  
**Development Host:** Arch Linux  
**iPhone IP:** `192.168.0.166` (Password: `alpine`)  
**Arch IP:** `192.168.0.102` (Port: `5000`)

---

## 🧠 Core Philosophy

1.  **Stealth as a Priority:** Modern apps check for injected dylibs and tampered function pointers. This tool isn't just about bypassing StoreKit; it’s about **instrumentation invisibility**.
2.  **Offensive Research:** Structured as a research platform to test how apps detect hooks and how servers validate receipts.
3.  **Developer Velocity (The "Mini-Virt"):** Minimize the "iPhone-to-Linux" friction. The Harness app is a "Shell"—logic changes are made on Arch and updated live without re-installing the IPA.

---

## ⚔️ The Pen-Test Loop: Harness vs. Tweak

To understand this project, you must distinguish between the **Target** and the **Attacker**.

### 1. The Gilded App (The Target / "The Victim")
*   **What it is:** A standalone SwiftUI game application installed on the iPhone.
*   **Its Role:** It acts as the "Victim." It represents a real-world app that a security researcher wants to test.
*   **Its Behavior:**
    *   It implements **StoreKit 2** to "sell" gems.
    *   It contains **Defensive Code** that scans for jailbreaks and suspicious dylibs.
    *   It is a **Shell**: It fetches its logic (prices, button text) live from the Arch server so we can change the "test scenario" without reinstalling the app.
*   **The Goal:** Gilded's job is to **detect** the tweak and **reject** fake receipts.

### 2. The Satella Tweak (The Attacker / "The Instrumentor")
*   **What it is:** A jailbreak tweak (`.dylib`) that is **injected** into Gilded's process at runtime.
*   **Its Role:** It acts as the "Attacker." It is the surgical tool used to manipulate the target.
*   **Its Behavior:**
    *   **Offensive:** It intercepts Gilded's calls to Apple and provides fake "Purchase Successful" responses.
    *   **Stealth:** It uses **Inline Hooks** and **Dyld Hiding** to ensure that when Gilded runs its "Security Scan," the tweak appears invisible.
*   **The Goal:** The tweak's job is to **bypass** the IAP and **evade** Gilded's detection.

### 🔄 How They Interact
1.  **Gilded** asks the system: "Is there a tweak here?"
2.  **The Tweak** intercepts that question and makes the system answer: "No, everything is clean."
3.  **Gilded** tells the user: "Click here to buy 100 gems for $99."
4.  **The Tweak** intercepts the payment window, fakes a "Success" signature, and gives it to Gilded.
5.  **Gilded** sends that fake signature to the **Arch Server**.
6.  **The Arch Server** (The remote alarm) logs the attempt and decides if the "Attacker" won.

---

## 🛠️ Project Architecture

### 1. The Tweak (`/home/natha/SatellaJailed-Modernized`)
The core instrumentation engine.
*   **ModernDyldHooks:** C-based hooks for the entire Dyld enumeration surface. It manipulates the count and index so the dylib effectively "doesn't exist" to the app.
*   **InlineHook Engine:** Uses ARM64 absolute jumps (16-byte trampolines). It **does not change the IMP pointer**, making it invisible to standard address-range checks.
*   **Anti-Analysis Suite:** Built-in detection for debuggers (`sysctl`), Frida (`/proc/maps`), and breakpoint timing checks.
*   **Logging:** Persistent architectural logs at `/var/jb/var/mobile/Library/Logs/SatellaJailed.log`.

### 2. The Gilded Harness (`/home/natha/GildedClient` & `GildedHarness`)
A two-part system to test the tweak against "Industry Standard" security.
*   **Client (`GildedClient`):** A SwiftUI app (No storyboards for Arch compatibility). Implements **Real StoreKit 2** logic. It is a "Shell" that fetches its configuration (rewards, product IDs) live from the Arch server.
*   **Backend (`GildedHarness`):** A Python/Flask server on Arch. It receives receipts from the iPhone and is ready for "Hardened Validation" (Anti-replay, signature checks).

---

## 📡 Automation & Tools

Located in `/home/natha/`:
*   **`deploy_all.sh`**: Rebuilds the Tweak and Harness, pushes `.deb` and `.ipa` to iPhone, installs, and resprings.
*   **`live_dev.sh`**: Starts the Python backend and automatically streams the iPhone's tweak logs to your Arch terminal.
*   **`stealth_test`**: A CLI tool on the iPhone (`/var/jb/usr/bin/stealth_test`) to verify Dyld hiding and IMP integrity.

---

## 📍 Current Status

### ✅ Working
*   **Tweak Injection:** `lilliana.satellajailed` is installed and injecting properly.
*   **Settings Pane:** The preference bundle now loads correctly on iOS 16.2 rootless.
*   **Settings Icon:** The PreferenceLoader entry now has a visible icon.
*   **Injection Filter:** The tweak filter is narrowed to the harness apps (`com.natha.gilded`, `com.natha.sentinel`) so it no longer crashes `Preferences`.
*   **Network Pipe:** The iPhone app can successfully talk to the Arch Python server.

### ⚠️ Remaining Focus
1.  **Gilded Validation Loop:** Re-run a full purchase flow and confirm the server-side behavior is still what you expect.
2.  **Docs Drift:** Several markdown files still reference the obsolete `iphoneos-arm` package and the pre-fix prefs/icon failures.
3.  **Workspace Hygiene:** Generated build artifacts and duplicate extracted payloads can be removed safely after preserving the latest `.deb`/`.ipa`.

---

## 📝 Roadmap for Successor AI

1.  **Verify the Offensive Loop:** 
    *   With Settings working, have the user turn on "Inline Hooks."
    *   Run a purchase in **Gilded**.
    *   Verify that Satella intercepts the StoreKit transaction.
2.  **Harden Validation:** 
    *   Move `game_server.py` from "Lazy Mode" to "Signature Verification" mode.
3.  **Logging Integration:** 
    *   Make the tweak logs appear directly inside the Gilded app for a better UI experience.
4.  **Doc Cleanup:**
    *   Update `STATUS.md`, `docs/STEALTH.md`, and `docs/BUILD.md` to match the current `iphoneos-arm64` rootless package and fixed Settings state.

---

**Original Reference:** [Paisseon/Satella GitHub](https://github.com/Paisseon/Satella)
