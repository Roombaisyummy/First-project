import Foundation

struct Logger {
    static let logPath = "/var/jb/var/mobile/Library/Logs/SatellaJailed.log"
    
    static func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let fullMessage = "[\(timestamp)] \(message)\n"
        
        NSLog("[SatellaJailed] \(message)")
        
        if Preferences.showLogs {
            appendToFile(fullMessage)
        }
    }
    
    private static func appendToFile(_ text: String) {
        if let data = text.data(using: .utf8) {
            if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try? text.write(toFile: logPath, atomically: true, encoding: .utf8)
            }
        }
    }
}
