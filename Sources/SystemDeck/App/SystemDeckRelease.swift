import Foundation

enum SystemDeckRelease {
    static var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.1.0"
    }

    static var build: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "110"
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "dev.raj.systemdeck"
    }
}
