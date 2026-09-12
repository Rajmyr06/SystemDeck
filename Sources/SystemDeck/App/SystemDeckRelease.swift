import Foundation

enum SystemDeckRelease {
    static var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0.0-dev"
    }

    static var build: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "dev"
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "dev.raj.systemdeck"
    }
}
