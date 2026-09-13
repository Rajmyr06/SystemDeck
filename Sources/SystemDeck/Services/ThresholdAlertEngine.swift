import Foundation

@MainActor
final class ThresholdAlertEngine {
    enum Kind: String, CaseIterable, Hashable {
        case cpu
        case memory
        case storage
        case thermal
        case battery

        var enabledKey: String { "thresholdAlert.\(rawValue).enabled" }
        var lastSentKey: String { "thresholdAlert.\(rawValue).lastSent" }
    }

    private let cooldown: TimeInterval = 10 * 60
    private var conditionStartedAt: [Kind: Date] = [:]
    private var active: Set<Kind> = []

    func evaluate(
        cpuUsage: Double,
        memoryPressure: MemoryPressureMetric,
        disk: DiskMetric,
        thermal: ThermalMetric,
        battery: BatteryMetric
    ) {
        guard UserDefaults.standard.bool(forKey: "thresholdAlerts.enabled") else {
            conditionStartedAt.removeAll()
            active.removeAll()
            return
        }

        guard NotificationAuthorizationManager.shared.isPackagedApp, NotificationAuthorizationManager.shared.canDeliver else {
            conditionStartedAt.removeAll()
            active.removeAll()
            return
        }

        evaluate(
            .cpu,
            condition: cpuUsage > 90,
            duration: 30,
            title: "High CPU usage",
            body: "CPU has stayed above 90% for 30 seconds. Current usage is \(DeckFormat.percent(cpuUsage))."
        )

        let memoryAlertTitle = memoryPressure.headroomPercent < 15
            ? "Memory pressure is critical"
            : "Memory pressure is high"
        evaluate(
            .memory,
            condition: memoryPressure.available && memoryPressure.headroomPercent < 30,
            duration: 0,
            title: memoryAlertTitle,
            body: "Memory headroom is \(DeckFormat.percent(memoryPressure.headroomPercent))."
        )

        evaluate(
            .storage,
            condition: disk.totalBytes > 0 && disk.usagePercent > 90,
            duration: 0,
            title: "Storage is almost full",
            body: "Storage usage is \(DeckFormat.percent(disk.usagePercent)) with \(DeckFormat.bytes(disk.freeBytes)) free."
        )

        evaluate(
            .thermal,
            condition: thermal.available && (thermal.level == .serious || thermal.level == .critical),
            duration: 0,
            title: "Thermal pressure is \(thermal.displayName.lowercased())",
            body: thermal.shortDetail
        )

        evaluate(
            .battery,
            condition: battery.available && !battery.onACPower && battery.percentage < 20,
            duration: 0,
            title: "Battery is low",
            body: "Battery level is \(DeckFormat.percent(battery.percentage))."
        )
    }

    private func evaluate(
        _ kind: Kind,
        condition: Bool,
        duration: TimeInterval,
        title: String,
        body: String
    ) {
        guard isEnabled(kind) else {
            conditionStartedAt.removeValue(forKey: kind)
            active.remove(kind)
            return
        }

        guard condition else {
            conditionStartedAt.removeValue(forKey: kind)
            active.remove(kind)
            return
        }

        if active.contains(kind) { return }

        let now = Date()
        if duration > 0 {
            if conditionStartedAt[kind] == nil {
                conditionStartedAt[kind] = now
                return
            }
            guard let started = conditionStartedAt[kind], now.timeIntervalSince(started) >= duration else {
                return
            }
        }

        guard cooldownElapsed(for: kind, now: now) else { return }

        NotificationAuthorizationManager.shared.post(
            identifier: "systemdeck.threshold.\(kind.rawValue).\(Int(now.timeIntervalSince1970))",
            title: title,
            body: body
        )
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: kind.lastSentKey)
        active.insert(kind)
    }

    private func isEnabled(_ kind: Kind) -> Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: kind.enabledKey) == nil { return true }
        return defaults.bool(forKey: kind.enabledKey)
    }

    private func cooldownElapsed(for kind: Kind, now: Date) -> Bool {
        let raw = UserDefaults.standard.double(forKey: kind.lastSentKey)
        guard raw > 0 else { return true }
        return now.timeIntervalSince1970 - raw >= cooldown
    }
}
