import Foundation

// MARK: - Launch At Login Helper (via ~/Library/LaunchAgents)
struct LaunchAtLoginHelper {
    static let plistUrl: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("com.nino.switchrpc.plist")
    }()
    
    static func setLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            let appPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/SwitchRPC.app/Contents/MacOS/SwitchRPC").path
            let plistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.nino.switchrpc</string>
                <key>ProgramArguments</key>
                <array>
                    <string>\(appPath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
                <key>ProcessType</key>
                <string>Interactive</string>
            </dict>
            </plist>
            """
            try? plistContent.write(to: plistUrl, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(at: plistUrl)
        }
    }
}
