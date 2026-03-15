import Foundation

/// Partial dyld enumeration hiding backed by a C bridge.
/// This build only attempts to rebind `_dyld_get_image_name`.
struct ModernDyldHooks {
    private static var didHook = false

    struct Status {
        let attempted: Bool
        let active: Bool
        let hiddenCount: Int
    }
    
    /// Attempt to install the supported dyld hook set.
    static func hookAll() {
        guard !didHook else { return }
        didHook = true

        install_dyld_hooks()

        let status = currentStatus()
        if status.active {
            NSLog("[SJ] Dyld name hook active (hiding \(status.hiddenCount) dylibs)")
        } else if status.attempted {
            NSLog("[SJ] Dyld name hook unavailable in this process; continuing without it")
        }
    }
    
    /// Get count of hidden dylibs
    static func getHiddenCount() -> Int {
        return Int(stealth_dyld_get_hidden_count())
    }

    static func currentStatus() -> Status {
        Status(
            attempted: stealth_dyld_was_attempted() != 0,
            active: stealth_dyld_name_hook_is_active() != 0,
            hiddenCount: Int(stealth_dyld_get_hidden_count())
        )
    }
    
    /// Add custom pattern to hide
    static func addHiddenPattern(_ pattern: String, at index: Int) {
        guard index >= 0 && index < 10 else { return }
        pattern.withCString { patternCString in
            stealth_dyld_set_hidden_pattern(Int32(index), patternCString)
        }
    }
    
    /// Default patterns that are hidden
    static let defaultPatterns = [
        "SatellaJailed",
        "libcrane",
        "frida",
        "cynject",
        "inject",
        "tweak",
        "llb",
        "substrate",
        "substitute",
        "ellekit"
    ]
}

// MARK: - C Bridge Imports

@_silgen_name("install_dyld_hooks")
func install_dyld_hooks()

@_silgen_name("stealth_dyld_get_hidden_count")
func stealth_dyld_get_hidden_count() -> Int32

@_silgen_name("stealth_dyld_set_hidden_pattern")
func stealth_dyld_set_hidden_pattern(_ index: Int32, _ pattern: UnsafePointer<CChar>)

@_silgen_name("stealth_dyld_was_attempted")
func stealth_dyld_was_attempted() -> Int32

@_silgen_name("stealth_dyld_name_hook_is_active")
func stealth_dyld_name_hook_is_active() -> Int32
