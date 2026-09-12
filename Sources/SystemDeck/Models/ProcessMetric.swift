import Foundation

struct ProcessMetric: Identifiable, Sendable, Hashable {
    let pid: Int
    let name: String
    let cpuTotalPercent: Double
    let coreUsagePercent: Double
    let memoryBytes: UInt64
    let elapsedTime: String
    let commandPath: String
    let workqueueThreads: Int?

    var id: Int { pid }
}

struct ProcessDetail: Sendable, Hashable {
    let pid: Int
    let elapsedTime: String
    let command: String
    let threadCount: Int?
}

enum ProcessSort: String, CaseIterable, Identifiable, Hashable {
    case cpu = "CPU Total"
    case core = "Core Usage"
    case memory = "Memory"
    case name = "Name"
    case pid = "PID"

    var id: String { rawValue }
}
