import Foundation

struct CoreCPUMetric: Identifiable, Sendable, Equatable {
    let index: Int
    let usagePercent: Double

    var id: Int { index }
    var displayName: String { "CPU \(index + 1)" }
}
