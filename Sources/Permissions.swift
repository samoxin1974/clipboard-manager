import Foundation
import AppKit
import ApplicationServices
import ServiceManagement

enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestPrompt() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}

enum LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusText: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "Enabled"
        case .requiresApproval: return "Waiting for approval in System Settings"
        case .notRegistered: return "Disabled"
        case .notFound: return "Move the app to Applications to enable"
        @unknown default: return "Unknown"
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}
