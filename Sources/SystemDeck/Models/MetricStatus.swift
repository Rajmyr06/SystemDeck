import Foundation

enum MetricSeverity: String, Sendable, Equatable {
    case normal = "Normal"
    case elevated = "Elevated"
    case high = "High"
    case critical = "Critical"
    case unavailable = "N/A"
}

struct MetricStatus: Sendable {
    let severity: MetricSeverity
    let label: String
    let explanation: String
}

enum MetricStatusEvaluator {
    static func cpu(rollingAverage: Double, hasSamples: Bool) -> MetricStatus {
        guard hasSamples else {
            return MetricStatus(
                severity: .unavailable,
                label: "Collecting",
                explanation: "Waiting for enough CPU history to classify sustained load."
            )
        }

        if rollingAverage < 40 {
            return MetricStatus(
                severity: .normal,
                label: "Low load",
                explanation: "Rolling CPU average is below 40% of total system CPU capacity."
            )
        }
        if rollingAverage < 75 {
            return MetricStatus(
                severity: .elevated,
                label: "Moderate load",
                explanation: "Rolling CPU average is between 40% and 75%. Short bursts are usually normal."
            )
        }
        return MetricStatus(
            severity: .high,
            label: "High load",
            explanation: "Rolling CPU average is above 75% of total system capacity."
        )
    }

    static func disk(usagePercent: Double, totalBytes: UInt64) -> MetricStatus {
        guard totalBytes > 0 else {
            return MetricStatus(
                severity: .unavailable,
                label: "Unavailable",
                explanation: "Storage capacity could not be read."
            )
        }

        if usagePercent < 80 {
            return MetricStatus(
                severity: .normal,
                label: "Normal",
                explanation: "Less than 80% of the monitored filesystem capacity is used."
            )
        }
        if usagePercent < 90 {
            return MetricStatus(
                severity: .elevated,
                label: "Elevated",
                explanation: "Filesystem usage is between 80% and 90%. Consider watching free capacity."
            )
        }
        return MetricStatus(
            severity: .high,
            label: "High usage",
            explanation: "Filesystem usage is above 90%. Low free space can affect updates, caches, and application workflows."
        )
    }

    static func memoryPressure(_ pressure: MemoryPressureMetric) -> MetricStatus {
        guard pressure.available else {
            return MetricStatus(
                severity: .unavailable,
                label: "Unavailable",
                explanation: "The macOS memory-pressure headroom signal is not currently available."
            )
        }

        switch pressure.level {
        case .normal:
            return MetricStatus(
                severity: .normal,
                label: "Normal",
                explanation: "Memory headroom is within the normal range."
            )
        case .elevated:
            return MetricStatus(
                severity: .elevated,
                label: "Elevated",
                explanation: "Memory headroom is reduced. Heavier workloads may increase compression and affect responsiveness."
            )
        case .critical:
            return MetricStatus(
                severity: .critical,
                label: "Critical",
                explanation: "Memory headroom is low. Sustained memory pressure may affect responsiveness."
            )
        case .unavailable:
            return MetricStatus(
                severity: .unavailable,
                label: "Unavailable",
                explanation: "Memory pressure could not be classified."
            )
        }
    }
}
