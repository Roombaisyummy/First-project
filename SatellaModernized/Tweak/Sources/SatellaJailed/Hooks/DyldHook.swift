/// DEPRECATED: This is the legacy dyld hook - only hooks _dyld_get_image_name
/// Use ModernDyldHooks.hookAll() instead for comprehensive enumeration hiding
///
/// This legacy hook is easily detected because:
/// - Only hooks _dyld_get_image_name
/// - _dyld_image_count() still returns inflated count
/// - _dyld_get_image_header(i) still exposes injected image
/// - Other dyld APIs remain unhooked
struct DyldHook: HookFunc {
    typealias T = @convention(c) (UInt32) -> UnsafePointer<Int8>?

    let name: String = "_dyld_get_image_name"
    let replace: T = { index in
        let crane: UnsafePointer<Int8> = "/usr/lib/libcrane.dylib".withCString { $0 }
        let origVal: UnsafePointer<Int8>? = orig(index)

        if let origVal, !String(cString: origVal).hasSuffix("SatellaJailed.dylib") {
            return origVal
        }

        return crane
    }
}
