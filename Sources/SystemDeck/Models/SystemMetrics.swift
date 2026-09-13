import Foundation

enum MemoryPressureLevel: String, Sendable {
    case normal = "Normal"
    case elevated = "Elevated"
    case critical = "Critical"
    case unavailable = "Unavailable"
}

struct MemoryPressureMetric: Sendable {
    var available = false
    var level: MemoryPressureLevel = .unavailable
    var headroomPercent: Double = 0
}

struct MemoryMetric: Sendable {
    var usedBytes: UInt64 = 0
    var totalBytes: UInt64 = 0
    var activeBytes: UInt64 = 0
    var wiredBytes: UInt64 = 0
    var compressedBytes: UInt64 = 0
    var inactiveBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    var purgeableBytes: UInt64 = 0

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return min(100, max(0, Double(usedBytes) / Double(totalBytes) * 100))
    }
}

struct DiskMetric: Sendable {
    var usedBytes: UInt64 = 0
    var totalBytes: UInt64 = 0
    var freeBytes: UInt64 = 0

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return min(100, max(0, Double(usedBytes) / Double(totalBytes) * 100))
    }
}

struct NetworkMetric: Sendable {
    var interface: String = "—"
    var downloadBytesPerSecond: Double = 0
    var uploadBytesPerSecond: Double = 0
    var receivedBytes: UInt64 = 0
    var sentBytes: UInt64 = 0

    var available: Bool { interface != "—" }
}

struct GPUMetric: Sendable {
    var available = false
    var utilizationPercent: Double = 0
    var rendererPercent: Double = 0
    var tilerPercent: Double = 0
    var rendererAvailable = false
    var tilerAvailable = false
    var inUseMemoryBytes: UInt64 = 0
    var allocatedMemoryBytes: UInt64 = 0
    var coreCount: Int = 0
    var model: String = "Apple GPU"

    // Ignore renderer/tiler counters that mirror total device utilization.
    var hasDistinctRendererMetric: Bool {
        rendererAvailable && abs(rendererPercent - utilizationPercent) > 0.25
    }

    var hasDistinctTilerMetric: Bool {
        tilerAvailable && abs(tilerPercent - utilizationPercent) > 0.25
    }
}

enum SystemThermalLevel: String, Sendable, Equatable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"
    case unavailable = "Unavailable"

    var displayName: String {
        switch self {
        case .nominal: "Normal"
        case .fair: "Elevated"
        case .serious: "High"
        case .critical: "Critical"
        case .unavailable: "Unavailable"
        }
    }

    var shortDetail: String {
        switch self {
        case .nominal: "No thermal constraint"
        case .fair: "Thermal pressure increased"
        case .serious: "Performance may be reduced"
        case .critical: "Strong thermal constraint"
        case .unavailable: "No thermal signal"
        }
    }

    var explanation: String {
        switch self {
        case .nominal:
            "Thermal conditions are normal. macOS is not indicating a thermal performance constraint."
        case .fair:
            "Thermal pressure is elevated. The Mac is managing heat more actively, but major performance limits are not indicated."
        case .serious:
            "Thermal pressure is high. macOS may reduce sustained CPU or GPU performance to control heat."
        case .critical:
            "Thermal pressure is critical. Significant performance reduction may occur until thermal conditions improve."
        case .unavailable:
            "macOS did not provide a system thermal-pressure signal."
        }
    }
}

struct ThermalMetric: Sendable {
    var available = false
    var level: SystemThermalLevel = .unavailable

    var displayName: String { level.displayName }
    var shortDetail: String { level.shortDetail }
    var explanation: String { level.explanation }

    var compactSummary: String {
        guard available else { return "N/A" }
        return "\(displayName) · \(shortDetail)"
    }
}

struct BatteryMetric: Sendable {
    var available = false
    var percentage: Double = 0
    var state: String = "Unavailable"
    var timeRemaining: String = "—"
    var onACPower = false
    var voltageVolts: Double?
    var currentAmps: Double?
    var powerWatts: Double?
    var adapterWatts: Double?
    var cycleCount: Int?
    var fullChargeCapacityMah: Int?
    var designCapacityMah: Int?
    var healthText: String?
    var healthPercent: Double?

    var hasElectricalTelemetry: Bool {
        voltageVolts != nil || currentAmps != nil || powerWatts != nil || adapterWatts != nil
    }

    var hasHealthTelemetry: Bool {
        cycleCount != nil || fullChargeCapacityMah != nil || designCapacityMah != nil || healthText != nil || healthPercent != nil
    }
}

struct HardwareInfo: Sendable {
    var computerName: String = "Mac"
    var modelIdentifier: String = "Unknown Mac"
    var processor: String = "Apple Silicon"
    var architecture: String = "arm64"
    var macOSVersion: String = "Unknown"
    var physicalMemoryBytes: UInt64 = 0
    var logicalCPUCount: Int = ProcessInfo.processInfo.activeProcessorCount
}
