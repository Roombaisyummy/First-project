import Foundation

private struct _Preferences {
    private let bundleID = "lilliana.satellajailed"
    private let path = "/var/jb/var/mobile/Library/Preferences/lilliana.satellajailed.plist"

    func get<T>(for key: String, default val: T) -> T {
        if let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let value = dict[key] as? T {
            return value
        }
        return val
    }
}

private let prefs = _Preferences()

struct Preferences {
    static let isEnabled: Bool   = prefs.get(for: "tella_isEnabled",   default: true)
    static let isGesture: Bool   = prefs.get(for: "tella_isGesture",   default: true)
    static let isHidden: Bool    = prefs.get(for: "tella_isHidden",    default: false)
    static let isObserver: Bool  = prefs.get(for: "tella_isObserver",  default: false)
    static let isPriceZero: Bool = prefs.get(for: "tella_isPriceZero", default: false)
    static let isReceipt: Bool   = prefs.get(for: "tella_isReceipt",   default: false)
    
    // Modernized / Stealth Toggles
    static let isStealth: Bool       = prefs.get(for: "tella_isStealth",       default: false)
    static let isDyldHook: Bool      = prefs.get(for: "tella_isDyldHook",      default: false)
    static let isInlineHook: Bool    = prefs.get(for: "tella_isInlineHook",    default: false)
    static let isAntiAnalysis: Bool  = prefs.get(for: "tella_isAntiAnalysis",  default: false)
    
    // Logging
    static let showLogs: Bool = prefs.get(for: "tella_showLogs", default: false)
}
