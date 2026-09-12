import Foundation

struct MetricSample: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let value: Double

    init(timestamp: Date = Date(), value: Double) {
        self.id = UUID()
        self.timestamp = timestamp
        self.value = value
    }
}
