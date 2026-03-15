# iOS Penetration Testing & Instrumentation Lab (2026)

> **⚠️ DISCLAIMER:** This project is for authorized security research, CTF (Capture The Flag) practice, and educational purposes ONLY. Use only on devices and applications you own or have explicit permission to test.

## ⚠️ A Note from the Architect
Look, I'll be honest—this repo is a total **clusterfuck**. I've been chaining different AI models and manual hacks for hours to get the stealth hooks and receipt forgery working against a hardened backend. **PLZ FIX** whatever I've inevitably broken in this mess. Also, I have to say, I'm a **really big fan of Paisseon and Lilliana**—their original work is the only reason any of this exists.

---

## 🧠 Philosophy: The Offensive vs. Defensive Loop

This repository is a complete, self-contained laboratory designed to study modern iOS instrumentation, stealth, and server-side IAP validation. It is structured as a **red-team/blue-team exercise**.

### The Core Components
1. **The Attacker (Satella Modernized):** A highly sophisticated jailbreak tweak designed for stealth. It implements C-level POSIX hooks, binary forgery, and anti-analysis modules to remain invisible to security scanners.
2. **The Victim (Gilded Harness):** A SwiftUI-based game app that implements "Industry Standard" security. It doesn't just check local states; it sends cryptographically structured receipts to a hardened backend.
3. **The Watcher (Python Backend):** A Flask-based validation server that performs deep inspection of incoming traffic, checking for signature validity, anti-replay, and data integrity.

---

## 📦 Installation Instructions

### 🦓 Installing .deb files (Tweak / Sentinel) with Zebra
1. Download the desired `.deb` from the `Binaries/` folder in this repo to your iPhone.
2. Open **Zebra**.
3. Go to the **Downloads** or use **Filza** to "Open In" Zebra.
4. Tap **Install** and confirm.
5. Respring your device.

### 👹 Installing .ipa files (Gilded) with TrollStore
1. Download the `Gilded.ipa` from the `Binaries/` folder to your iPhone.
2. Share the file and select **TrollStore**.
3. Tap **Install**. The app will now appear on your home screen with permanent signing.

---

## 🛠️ Lab Structure

### 🟥 Offensive: Satella Modernized
Located in `/SatellaModernized`. This is the core "Instrumentor."
- **Deep Dyld Hiding:** Manipulates the system image count and indices to effectively erase its own existence from the process.
- **Inline Hooking:** Uses 16-byte ARM64 trampolines to replace logic without changing the `IMP` pointer, evading address-range checks.
- **Advanced Forgery:** Generates generic, binary-perfect receipts based on the app's metadata.

### 🟦 Defensive: Gilded Harness Lab
Located in `/GildedHarnessLab`.
- **Client:** A SwiftUI app that serves as the "Shell." It fetches logic live from the server to simulate a production environment.
- **Hardened Backend:** Implements strict validation. It currently "beats" basic bypasses by requiring valid binary structures and matching IDs.

### 🧪 Development & AI Tooling
Located in `/DevTools`.
- **`live_dev.sh`**: The "Mini-Virt" orchestrator. Starts the backend and follows tweak logs in real-time.
- **`watcher.sh`**: Auto-rebuilds and deploys to the iPhone every time you save a file.
- **`stealth_test`**: CLI tool to verify Dyld/IMP integrity on-device.

---

## 🤖 Working with AI Models

This lab is optimized for iteration using different AI models. Here is the recommended "Swap" strategy:

*   **Gemini (The Architect):** Best for cross-component reasoning (e.g., "Why is the backend rejecting the tweak's receipt?") due to its massive context window.
*   **Claude (The Surgeon):** Exceptional for writing the high-level Swift/Objective-C hooks and UI logic.
*   **Aider (The Engineer):** Use for low-level ARM64 assembly, assembly-to-C bridges, and complex Makefiles.

---

## 📡 Setup & Deployment

1. **Prerequisites:**
   - Dev Host: Arch Linux with Theos installed (`/opt/theos`).
   - Device: iOS 16.2 (Dopamine Rootless).
2. **Installation:**
   ```bash
   # Run the master deployment script
   bash DevTools/deploy_all.sh
   ```
3. **The Test Loop:**
   - Edit `GildedHarnessLab/GildedHarness/game_server.py` to change security difficulty.
   - Edit `SatellaModernized/Tweak/Sources/...` to improve stealth.
   - Run `live_dev.sh` to see the battle in real-time.

---

**Developed for the next generation of iOS security researchers.**
