import Foundation
import OSLog

enum SystemDeckLog {
    static let subsystem = "dev.systemdeck.app"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let telemetry = Logger(subsystem: subsystem, category: "telemetry")
    static let process = Logger(subsystem: subsystem, category: "process")
    static let command = Logger(subsystem: subsystem, category: "command")
}
