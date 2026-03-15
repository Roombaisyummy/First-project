import SwiftUI
import StoreKit

// MARK: - Real StoreKit Observer
class IAPManager: NSObject, SKPaymentTransactionObserver {
    static let shared = IAPManager()
    var onResult: ((String) -> Void)?

    func startPurchase(productID: String) {
        let payment = SKMutablePayment()
        payment.productIdentifier = productID
        SKPaymentQueue.default().add(self)
        SKPaymentQueue.default().add(payment)
    }

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                let receiptURL = Bundle.main.appStoreReceiptURL
                let receiptData = try? Data(contentsOf: receiptURL!)
                let receiptBase64 = receiptData?.base64EncodedString() ?? "SATELLA_MODERN_V1_FALLBACK"
                onResult?("SUCCESS:\(receiptBase64)")
                SKPaymentQueue.default().finishTransaction(transaction)
            case .failed:
                onResult?("FAILED:\(transaction.error?.localizedDescription ?? "Access Denied")")
                SKPaymentQueue.default().finishTransaction(transaction)
            default: break
            }
        }
    }
}

// MARK: - Dynamic UI
struct StoreConfig: Codable {
    var buttonText: String
    var productID: String
    var gemReward: Int
    var alertMessage: String
}

struct ContentView: View {
    @State private var logs: [String] = []
    @State private var gems: Int = 0
    @State private var status: String = "Status: Ready"
    @State private var config: StoreConfig = StoreConfig(buttonText: "Purchase Gems", productID: "com.natha.gems.100", gemReward: 100, alertMessage: "Success!")
    @State private var serverIP: String = "192.168.0.102"
    @State private var isPurchasing: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("💎 Gilded Harness 💎").font(.largeTitle).bold()
            
            VStack {
                Text("\(gems)").font(.system(size: 60, weight: .black, design: .rounded)).foregroundColor(.blue)
                Text("GEMS").font(.headline)
            }
            
            Section(header: Text("Server Config")) {
                TextField("Arch Linux IP", text: $serverIP)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .multilineTextAlignment(.center)
            }

            if isPurchasing {
                ProgressView("Intercepting...")
            } else {
                Button(action: { buyGems() }) {
                    Text(config.buttonText)
                        .bold().frame(width: 280, height: 50)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(15)
                }
            }
            
            HStack {
                Button("Reload Logic") { fetchConfig() }.font(.caption)
                Button("Clear Logs") { logs.removeAll() }.font(.caption)
            }

            Text(status).font(.caption).foregroundColor(.gray)

            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(logs, id: \.self) { log in
                        Text(log).font(.system(size: 10, design: .monospaced))
                    }
                }
            }.frame(maxHeight: 150).background(Color.black.opacity(0.05)).cornerRadius(10)
        }
        .padding()
        .onAppear {
            // Delay network calls to ensure app finishes launching first
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                fetchConfig()
                fetchStats()
            }
        }
    }

    func fetchConfig() {
        guard let url = URL(string: "http://\(serverIP):5000/config") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2 // Short timeout
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let decoded = try? JSONDecoder().decode(StoreConfig.self, from: data) {
                DispatchQueue.main.async { 
                    self.config = decoded
                    appendLog("Config updated")
                }
            }
        }.resume()
    }

    func buyGems() {
        isPurchasing = true
        status = "StoreKit Requesting..."
        appendLog("Buying \(config.productID)")
        
        IAPManager.shared.onResult = { result in
            DispatchQueue.main.async {
                self.isPurchasing = false
                if result.hasPrefix("SUCCESS:") {
                    let receipt = String(result.dropFirst(8))
                    verifyWithServer(receipt: receipt)
                } else {
                    self.status = "Failed: \(result.dropFirst(7))"
                }
            }
        }
        IAPManager.shared.startPurchase(productID: config.productID)
    }

    func verifyWithServer(receipt: String) {
        guard let url = URL(string: "http://\(serverIP):5000/verify_receipt") else { return }
        var request = URLRequest(url: url); request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5
        let body: [String: Any] = ["product_id": config.productID, "receipt": receipt]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.gems = json["balance"] as? Int ?? self.gems
                    self.status = "Server: \(json["status"] ?? "Error")"
                    appendLog("Verified: \(self.status)")
                }
            }
        }.resume()
    }
    
    func fetchStats() {
        guard let url = URL(string: "http://\(serverIP):5000/stats") else { return }
        var request = URLRequest(url: url); request.timeoutInterval = 2
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                DispatchQueue.main.async { 
                    self.gems = json["gems"] as? Int ?? 0 
                    appendLog("Stats loaded")
                }
            }
        }.resume()
    }

    func appendLog(_ msg: String) {
        logs.insert("\(Date().formatted(date: .omitted, time: .shortened)): \(msg)", at: 0)
    }
}
