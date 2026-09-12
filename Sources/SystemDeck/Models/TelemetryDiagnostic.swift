import Foundation

enum DiagnosticState: String, Sendable {
    case healthy = "Healthy"
    case limited = "Limited"
    case stale = "Stale"
    case unavailable = "Unavailable"
    case failed = "Failed"
}

struct TelemetryDiagnostic: Identifiable, Sendable {
    let id: String
    let name: String
    let state: DiagnosticState
    let detail: String
    let lastSuccess: Date?

    init(
        id: String,
        name: String,
        state: DiagnosticState,
        detail: String,
        lastSuccess: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.state = state
        self.detail = detail
        self.lastSuccess = lastSuccess
    }
}
