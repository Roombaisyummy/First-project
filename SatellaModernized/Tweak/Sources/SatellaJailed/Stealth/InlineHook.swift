import Foundation

/// Limited ARM64 inline hooking.
/// The current implementation uses a direct branch and a simple trampoline.
struct InlineHook {
    private static var initialized = false
    
    /// Initialize hook system
    private static func initialize() {
        guard !initialized else { return }
        initialized = true
        stealth_hook_remove_all()
    }
    
    /// Install inline hook at function address
    /// - Parameters:
    ///   - function: Pointer to function to hook
    ///   - replacement: Pointer to replacement function
    ///   - name: Optional name for tracking
    /// - Returns: Trampoline pointer for calling original function, or nil on failure
    static func install(
        at function: UnsafeMutableRawPointer,
        replacement: UnsafeMutableRawPointer,
        name: String? = nil
    ) -> UnsafeMutableRawPointer? {
        initialize()
        
        let hookName = name ?? String(format: "hook_%p", UInt(bitPattern: function))
        let trampoline = stealth_hook_install(hookName, function, replacement)
        
        if trampoline != nil {
            NSLog("[InlineHook] Installed: \(hookName) (trampoline: \(trampoline.map { String(format: "%p", UInt(bitPattern: $0)) } ?? "nil"))")
        } else {
            NSLog("[InlineHook] Failed: \(hookName)")
        }
        
        return trampoline
    }
    
    /// Install inline hook by symbol name
    /// - Parameters:
    ///   - symbol: Function symbol name (e.g., "_dyld_get_image_name")
    ///   - replacement: Pointer to replacement function
    /// - Returns: Trampoline pointer or nil
    static func install(
        symbol: String,
        replacement: UnsafeMutableRawPointer
    ) -> UnsafeMutableRawPointer? {
        // RTLD_DEFAULT = (void *)-2
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)!
        guard let function = dlsym(rtldDefault, symbol) else {
            NSLog("[InlineHook] Symbol not found: \(symbol)")
            return nil
        }
        
        return install(at: function, replacement: replacement, name: symbol)
    }
    
    /// Remove hook by name
    @discardableResult
    static func remove(name: String) -> Bool {
        return stealth_hook_remove(name) != 0
    }
    
    /// Get trampoline for calling original function
    static func getTrampoline(for name: String) -> UnsafeMutableRawPointer? {
        return stealth_hook_trampoline(name)
    }
    
    /// Remove all installed hooks
    static func removeAll() {
        stealth_hook_remove_all()
        NSLog("[InlineHook] Removed all hooks")
    }
    
    /// Check if function is hooked
    static func isHooked(name: String) -> Bool {
        return stealth_hook_is_installed(name) != 0
    }
    
    /// Get count of installed hooks
    static func getHookCount() -> Int {
        return Int(stealth_hook_get_count())
    }
    
    /// Get list of hooked function names.
    ///
    /// The C bridge currently exposes hook count but not name enumeration.
    static func getHookedFunctions() -> [String] {
        return []
    }
}

// MARK: - C Function Hook Helper

/// Generic C function hook wrapper.
struct CHook<T> {
    private var original: T?
    private var name: String?
    
    /// Hook a C function by symbol.
    /// - Parameters:
    ///   - symbol: Function name
    ///   - replacement: Replacement function
    /// - Returns: Original function pointer (for calling original via trampoline)
    mutating func hook(symbol: String, replacement: T) -> T? {
        guard let function = dlsym(UnsafeMutableRawPointer(bitPattern: -2)!, symbol) else {
            return nil
        }
        
        let trampoline = InlineHook.install(
            at: function,
            replacement: unsafeBitCast(replacement as Any, to: UnsafeMutableRawPointer.self),
            name: symbol
        )
        
        guard let tramp = trampoline else { return nil }
        
        self.name = symbol
        // Store trampoline as the "original" function to call
        self.original = unsafeBitCast(tramp, to: T.self)
        return self.original
    }
    
    /// Call the original function via the stored trampoline.
    func callOriginal() -> T? {
        return original
    }
}

// MARK: - C Bridge Imports

@_silgen_name("stealth_hook_install")
func stealth_hook_install(_ name: UnsafePointer<CChar>, _ target: UnsafeMutableRawPointer, _ replacement: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?

@_silgen_name("stealth_hook_remove")
func stealth_hook_remove(_ name: UnsafePointer<CChar>) -> Int32

@_silgen_name("stealth_hook_trampoline")
func stealth_hook_trampoline(_ name: UnsafePointer<CChar>) -> UnsafeMutableRawPointer?

@_silgen_name("stealth_hook_remove_all")
func stealth_hook_remove_all()

@_silgen_name("stealth_hook_is_installed")
func stealth_hook_is_installed(_ name: UnsafePointer<CChar>) -> Int32

@_silgen_name("stealth_hook_get_count")
func stealth_hook_get_count() -> Int32
