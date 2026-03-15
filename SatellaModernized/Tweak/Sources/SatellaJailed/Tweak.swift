import UIKit

/// Tweak entry point.
struct Tweak {
    static func ctor() {
        let hasActiveFeatures =
            Preferences.isAntiAnalysis ||
            Preferences.isStealth ||
            Preferences.isDyldHook ||
            Preferences.isPriceZero ||
            Preferences.isObserver ||
            Preferences.isReceipt ||
            (Preferences.isGesture && !Preferences.isHidden)

        guard Preferences.isEnabled else {
            Logger.log("Tweak disabled by preferences; skipping hooks.")
            return
        }

        guard hasActiveFeatures else {
            Logger.log("No active tweak features enabled; skipping ctor work.")
            return
        }

        Logger.log("Starting Modernized Tweak...")

        let needsStoreKitHooks = Preferences.isPriceZero || Preferences.isObserver || Preferences.isReceipt
        
        if Preferences.isAntiAnalysis {
            Logger.log("Scheduling Anti-Analysis countermeasures...")
            DispatchQueue.global(qos: .utility).async {
                AntiAnalysis.applyCountermeasures()
                let threatLevel = AntiAnalysis.getThreatLevel()
                if threatLevel >= .high {
                    Logger.log("High threat detected (\(threatLevel.rawValue)); reducing behavior")
                    AntiAnalysis.reactToThreats()
                }
            }
        }

        if Preferences.isStealth {
            Logger.log("Stealth mode enabled; migrating storage...")
            CovertStorage.migrateFromLegacy()
        }

        if Preferences.isDyldHook {
            Logger.log("Applying Modern Dyld hooks...")
            ModernDyldHooks.hookAll()
        }

        if needsStoreKitHooks {
            Logger.log("Hooking StoreKit components...")
            CanPayHook().hook()
            DelegateHook().hook()
            TransactionHook().hook()
        } else {
            Logger.log("No StoreKit hook features enabled; skipping StoreKit hooks.")
        }

        if Preferences.isPriceZero {
            Logger.log("Price Zeroing enabled.")
            ProductHook().hook()
        }

        if Preferences.isObserver {
            Logger.log("Transaction Observer enabled.")
            ObserverHook().hook()
        }

        if Preferences.isReceipt {
            Logger.log("Receipt forgery enabled.")
            install_posix_receipt_hooks()
            BundleHook().hook()
            DataHook().hook()
            ReceiptHook().hook()
            URLHook().hook()
        }

        if #available(iOS 15, *) {
            if Preferences.isGesture {
                Logger.log("UI Gesture Trigger enabled.")
                WindowHook().hook()
            }

            guard !Preferences.isHidden else {
                Logger.log("UI is hidden by preferences.")
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                Logger.log("Injecting UI Controller...")
                let rootVC: UIViewController? = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
                rootVC?.add(SatellaController.shared)
            }
        }

        Logger.log("Modernized Satella Tweak Initialized Successfully.")
    }
}

@_cdecl("jinx_entry")
func jinxEntry() {
    Tweak.ctor()
}

@_silgen_name("install_posix_receipt_hooks")
func install_posix_receipt_hooks()
