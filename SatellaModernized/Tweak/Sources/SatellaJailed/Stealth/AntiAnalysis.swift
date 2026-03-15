import Darwin
import Foundation

/// Compile-safe anti-analysis helpers.
///
/// Keep the higher-level interface intact, but limit implementation to checks
/// that are portable across the Linux-hosted Theos toolchain.
struct AntiAnalysis {
    enum ThreatLevel: Int, Comparable {
        case none = 0
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4

        static func < (lhs: ThreatLevel, rhs: ThreatLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private static var baselineTime: UInt64 = 0

    static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    static func isDebuggerAttachedPtrace() -> Bool {
        false
    }

    static func denyDebuggerAttachment() {}

    static func detectFridaImages() -> Bool {
        detectSuspiciousMappings(patterns: ["frida", "gum-", "cynject", "libcycript"])
    }

    static func detectFridaPort() -> Bool {
        // Never block the app launch path on a localhost probe.
        if Thread.isMainThread {
            return false
        }

        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(27042).bigEndian
        addr.sin_addr = in_addr(s_addr: in_addr_t(0x7F000001))

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return result == 0
    }

    static func detectFridaMemory() -> Bool {
        detectSuspiciousMappings(patterns: ["frida-agent", "frida-gadget", "frida_server", "com.frida"])
    }

    static func isFridaRunning() -> Bool {
        detectFridaImages() || detectFridaPort() || detectFridaMemory()
    }

    static func detectJailbreakPaths() -> Bool {
        let paths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/var/jb",
            "/jb",
            "/private/jailbreak"
        ]
        let fm = FileManager.default
        return paths.contains { fm.fileExists(atPath: $0) }
    }

    static func detectFork() -> Bool {
        false
    }

    static func detectSystemLinks() -> Bool {
        let fm = FileManager.default
        if let target = try? fm.destinationOfSymbolicLink(atPath: "/var") {
            return target != "/private/var"
        }
        return false
    }

    static func isJailbroken() -> Bool {
        detectJailbreakPaths() || detectSystemLinks()
    }

    static func initializeTimingBaseline() {
        var sum: UInt64 = 0
        let start = mach_absolute_time()
        for i in 0..<100_000 {
            sum += UInt64(i)
        }
        baselineTime = mach_absolute_time() - start
        if sum == 0 {
            baselineTime = 0
        }
    }

    static func detectBreakpoints() -> Bool {
        guard baselineTime > 0 else { return false }
        var sum: UInt64 = 0
        let start = mach_absolute_time()
        for i in 0..<100_000 {
            sum += UInt64(i)
        }
        if sum == 0 {
            return false
        }
        return mach_absolute_time() - start > baselineTime * 3
    }

    static func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    static func detectEmulatorFiles() -> Bool {
        let paths = [
            "/Applications/iOS Simulator.app",
            "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app"
        ]
        let fm = FileManager.default
        return paths.contains { fm.fileExists(atPath: $0) }
    }

    static func getThreatLevel() -> ThreatLevel {
        var score = 0
        if isDebuggerAttached() { score += 3 }
        if isFridaRunning() { score += 3 }
        if isJailbroken() { score += 2 }
        if detectBreakpoints() { score += 1 }
        if isSimulator() || detectEmulatorFiles() { score += 1 }

        switch score {
        case 0: return .none
        case 1: return .low
        case 2...3: return .medium
        case 4...5: return .high
        default: return .critical
        }
    }

    static func getDetectionReport() -> [String: Bool] {
        [
            "debugger_attached": isDebuggerAttached(),
            "frida_images": detectFridaImages(),
            "frida_port": detectFridaPort(),
            "frida_memory": detectFridaMemory(),
            "jailbreak_paths": detectJailbreakPaths(),
            "jailbreak_links": detectSystemLinks(),
            "breakpoints": detectBreakpoints(),
            "simulator": isSimulator(),
            "emulator_files": detectEmulatorFiles()
        ]
    }

    static func applyCountermeasures() {
        denyDebuggerAttachment()
        initializeTimingBaseline()
    }

    static func reactToThreats() {
        switch getThreatLevel() {
        case .none, .low:
            break
        case .medium:
            NSLog("[Security] Medium threat level detected")
        case .high, .critical:
            NSLog("[Security] High threat level detected")
        }
    }

    private static func detectSuspiciousMappings(patterns: [String]) -> Bool {
        guard let maps = try? String(contentsOfFile: "/proc/self/maps", encoding: .utf8) else {
            return false
        }
        let haystack = maps.lowercased()
        return patterns.contains { haystack.contains($0.lowercased()) }
    }
}
