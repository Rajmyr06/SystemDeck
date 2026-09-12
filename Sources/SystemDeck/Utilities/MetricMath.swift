import Foundation

enum MetricMath {
    static func normalizedProcessCPU(coreUsagePercent: Double, logicalCPUCount: Int) -> Double {
        guard coreUsagePercent.isFinite else { return 0 }
        let count = max(1, logicalCPUCount)
        return min(100, max(0, coreUsagePercent) / Double(count))
    }

    // AppleSmartBattery has used several temperature encodings across hardware.
    static func batteryTemperatureCelsius(rawValue: Double) -> Double? {
        guard rawValue.isFinite, rawValue > 0 else { return nil }

        let candidates: [Double]
        switch rawValue {
        case 20_000...40_000:
            // centi-Kelvin, e.g. 30315 -> 30 C
            candidates = [rawValue / 100.0 - 273.15]
        case 2_000...4_000:
            // deci-Kelvin, e.g. 3031 -> 30 C
            candidates = [rawValue / 10.0 - 273.15]
        case 250...400:
            // Kelvin, e.g. 303 -> 30 C
            candidates = [rawValue - 273.15]
        case -20...100:
            // Celsius
            candidates = [rawValue]
        default:
            candidates = []
        }

        return candidates.first { (-20...100).contains($0) }
    }

    static func appendBounded(
        value: Double,
        timestamp: Date = Date(),
        to history: inout [MetricSample],
        limit: Int
    ) {
        guard value.isFinite, limit > 0 else { return }
        history.append(MetricSample(timestamp: timestamp, value: value))
        if history.count > limit {
            history.removeFirst(history.count - limit)
        }
    }

    static func average(of history: [MetricSample], fallback: Double = 0) -> Double {
        guard !history.isEmpty else { return fallback }
        return history.map(\.value).reduce(0, +) / Double(history.count)
    }

    static func peak(of history: [MetricSample], fallback: Double = 0) -> Double {
        history.map(\.value).max() ?? fallback
    }

    static func historyWindow(of history: [MetricSample]) -> TimeInterval {
        guard let first = history.first?.timestamp,
              let last = history.last?.timestamp else { return 0 }
        return max(0, last.timeIntervalSince(first))
    }
}
