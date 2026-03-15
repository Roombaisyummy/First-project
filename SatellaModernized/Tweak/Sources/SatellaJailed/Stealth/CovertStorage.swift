import CommonCrypto
import Foundation
import Security

/// Compile-safe covert preference storage.
///
/// The original version mixed several low-level storage backends that are not
/// stable under this toolchain. Keep a conservative implementation that still
/// avoids the old obvious `tella_*` keys and uses Keychain when available.
struct CovertStorage {
    private enum EncodedKeys {
        static let isEnabled = "cfg_a7f3e9d2c1b8f4e6a5d0c9b8a7f6e5d4"
        static let isGesture = "cfg_b8e4f0d3c2a9f5e7b6d1c0b9a8f7e6d5"
        static let isHidden = "cfg_c9f5e1d4c3b0f6e8c7d2c1b0a9f8e7d6"
        static let isObserver = "cfg_d0f6e2d5c4b1f7e9d8d3c2b1a0f9e8d7"
        static let isPriceZero = "cfg_e1f7e3d6c5b2f8e0d9d4c3b2a1f0e9d8"
        static let isReceipt = "cfg_f2f8e4d7c6b3f9e1d0d5c4b3a2f1e0d9"
        static let isStealth = "cfg_03f9e5d8c7b4f0e2d1d6c5b4a3f2e1d0"
    }

    static func getBool(_ key: String, default value: Bool = false) -> Bool {
        let encodedKey = encodedKey(for: key)
        return UserDefaults.standard.object(forKey: encodedKey) as? Bool ?? value
    }

    static func setBool(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: encodedKey(for: key))
    }

    static func storeInKeychain(key: String, value: Bool) -> OSStatus {
        let query = keychainQuery(for: key, data: Data([value ? 1 : 0]))
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil)
    }

    static func readFromKeychain(key: String) -> Bool? {
        var query = keychainQuery(for: key, data: nil)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data.first == 1
    }

    static func detectFromEnvironment() -> [String: Bool] {
        var config: [String: Bool] = [:]
        let fm = FileManager.default
        config["isStealth"] = fm.fileExists(atPath: "/var/tmp/.cache/com.apple.fonts")

        let environment = ProcessInfo.processInfo.environment
        let configString = environment["SATELLA_CFG"] ?? environment["SATLLA_CFG"]
        if let envValue = configString,
           let data = envValue.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Bool] {
            config.merge(parsed) { _, new in new }
        }

        return config
    }

    static func migrateFromLegacy() {
        let legacyMapping: [String: String] = [
            "tella_isEnabled": "isEnabled",
            "tella_isGesture": "isGesture",
            "tella_isHidden": "isHidden",
            "tella_isObserver": "isObserver",
            "tella_isPriceZero": "isPriceZero",
            "tella_isReceipt": "isReceipt",
            "tella_isStealth": "isStealth"
        ]

        for (legacyKey, newKey) in legacyMapping {
            guard let value = UserDefaults.standard.object(forKey: legacyKey) as? Bool else {
                continue
            }
            if readFromKeychain(key: newKey) == nil {
                _ = storeInKeychain(key: newKey, value: value)
            }
            setBool(newKey, value)
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }
    }

    private static func encodedKey(for key: String) -> String {
        switch key {
        case "isEnabled": return EncodedKeys.isEnabled
        case "isGesture": return EncodedKeys.isGesture
        case "isHidden": return EncodedKeys.isHidden
        case "isObserver": return EncodedKeys.isObserver
        case "isPriceZero": return EncodedKeys.isPriceZero
        case "isReceipt": return EncodedKeys.isReceipt
        case "isStealth": return EncodedKeys.isStealth
        default: return "cfg_\(sha256Hex(key).prefix(32))"
        }
    }

    private static func keychainQuery(for key: String, data: Data?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.apple.security.identity.token",
            kSecAttrAccount as String: sha256Base64(key)
        ]
        if let data {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
        return query
    }

    private static func sha256Hex(_ string: String) -> String {
        let digest = sha256(string)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256Base64(_ string: String) -> String {
        Data(sha256(string)).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
    }

    private static func sha256(_ string: String) -> [UInt8] {
        let data = Array(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest
    }
}

struct ModernPreferences {
    static var isEnabled: Bool {
        CovertStorage.readFromKeychain(key: "isEnabled") ?? CovertStorage.getBool("isEnabled", default: true)
    }

    static var isGesture: Bool {
        CovertStorage.readFromKeychain(key: "isGesture") ?? CovertStorage.getBool("isGesture", default: true)
    }

    static var isHidden: Bool {
        CovertStorage.readFromKeychain(key: "isHidden") ?? CovertStorage.getBool("isHidden", default: false)
    }

    static var isObserver: Bool {
        CovertStorage.readFromKeychain(key: "isObserver") ?? CovertStorage.getBool("isObserver", default: false)
    }

    static var isPriceZero: Bool {
        CovertStorage.readFromKeychain(key: "isPriceZero") ?? CovertStorage.getBool("isPriceZero", default: false)
    }

    static var isReceipt: Bool {
        CovertStorage.readFromKeychain(key: "isReceipt") ?? CovertStorage.getBool("isReceipt", default: false)
    }

    static var isStealth: Bool {
        if CovertStorage.detectFromEnvironment()["isStealth"] == true {
            return true
        }
        return CovertStorage.readFromKeychain(key: "isStealth") ?? CovertStorage.getBool("isStealth", default: false)
    }
}
