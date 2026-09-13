import Foundation

enum DeckFormat {
    static func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .memory)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond >= 0 else { return "0 B/s" }
        if bytesPerSecond >= 1_000_000_000 {
            return String(format: "%.2f GB/s", bytesPerSecond / 1_000_000_000)
        }
        if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
        }
        if bytesPerSecond >= 1_000 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1_000)
        }
        return String(format: "%.0f B/s", bytesPerSecond)
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", min(100, max(0, value)))
    }


    static func voltage(_ volts: Double) -> String {
        guard volts.isFinite else { return "N/A" }
        return String(format: "%.2f V", volts)
    }

    static func current(_ amps: Double) -> String {
        guard amps.isFinite else { return "N/A" }
        return String(format: "%.2f A", abs(amps))
    }

    static func power(_ watts: Double) -> String {
        guard watts.isFinite, watts >= 0 else { return "N/A" }
        return watts >= 100 ? String(format: "%.0f W", watts) : String(format: "%.1f W", watts)
    }

    static func capacityMah(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "\(formatter.string(from: NSNumber(value: value)) ?? String(value)) mAh"
    }

    static func historyRange(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        if seconds >= 3_600 {
            let hours = seconds / 3_600
            let minutes = (seconds % 3_600) / 60
            return minutes > 0 ? "Last \(hours)h \(minutes)m" : "Last \(hours)h"
        }
        if seconds >= 60 {
            let minutes = max(1, Int((Double(seconds) / 60).rounded()))
            return "Last \(minutes) min"
        }
        return "Last \(seconds) sec"
    }

    static func durationCompact(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        if seconds >= 60 {
            return "\(seconds / 60)m \(seconds % 60)s"
        }
        return "\(seconds)s"
    }

    static func uptime(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
