import Foundation

struct BundleHook: Hook {
    typealias T = @convention(c) (Bundle, Selector) -> URL?

    let cls: AnyClass? = Bundle.self
    let sel: Selector = #selector(getter: Bundle.appStoreReceiptURL)
    let replace: T = { obj, _sel in
        Logger.log("Intercepted appStoreReceiptURL request")
        return URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/SATELLA_GHOST_RECEIPT")
    }
}

struct DataHook: Hook {
    typealias T = @convention(c) (AnyClass, Selector, URL) -> NSData?

    let cls: AnyClass? = NSData.self
    let sel: Selector = sel_registerName("dataWithContentsOfURL:")
    let replace: T = { obj, _sel, url in
        if url.path.contains("SATELLA_GHOST_RECEIPT") || url.lastPathComponent == "receipt" {
            Logger.log("Intercepted NSData read for: \(url.lastPathComponent)")
            let productID = SatellaDelegate.shared.products.last?.productIdentifier ?? "com.natha.gems.100"
            let binary = ReceiptGenerator.binary(for: productID)
            return binary as NSData
        }
        return orig(obj, _sel, url)
    }
}
