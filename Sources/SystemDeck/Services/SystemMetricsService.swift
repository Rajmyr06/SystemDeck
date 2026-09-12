import Darwin
import Foundation
import IOKit
import SystemConfiguration

actor SystemMetricsService {
    private var cachedTotalMemory: UInt64?
    private var previousCPULoad: host_cpu_load_info_data_t?
    private var previousRX: UInt64?
    private var previousTX: UInt64?
    private var previousNetworkDate: Date?

    // Reset delta baselines after sleep or long sampling gaps.
    func resetSamplingBaselines() {
        previousCPULoad = nil
        resetNetworkBaseline()
    }

    // MARK: - CPU

    // CPU utilization from Mach host statistics.
    func cpuUsage() -> Double {
        var load = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &load) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(
                    mach_host_self(),
                    HOST_CPU_LOAD_INFO,
                    rebound,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        guard let previous = previousCPULoad else {
            previousCPULoad = load
            return 0
        }

        let user = UInt64(load.cpu_ticks.0 &- previous.cpu_ticks.0)
        let system = UInt64(load.cpu_ticks.1 &- previous.cpu_ticks.1)
        let idle = UInt64(load.cpu_ticks.2 &- previous.cpu_ticks.2)
        let nice = UInt64(load.cpu_ticks.3 &- previous.cpu_ticks.3)

        previousCPULoad = load

        let busy = user + system + nice
        let total = busy + idle
        guard total > 0 else { return 0 }

        return min(100, max(0, Double(busy) / Double(total) * 100))
    }

    // MARK: - Memory

    // Memory counters from Mach VM statistics.
    func memory() async -> MemoryMetric {
        let total = await totalMemory()

        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    rebound,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryMetric(usedBytes: 0, totalBytes: total)
        }

        var hostPageSize: vm_size_t = 0
        let pageSizeResult = host_page_size(mach_host_self(), &hostPageSize)

        guard pageSizeResult == KERN_SUCCESS, hostPageSize > 0 else {
            return MemoryMetric(usedBytes: 0, totalBytes: total)
        }

        let pageSize = UInt64(hostPageSize)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize
        let purgeable = UInt64(stats.purgeable_count) * pageSize

        // Treat active, wired, and compressed pages as committed usage.
        let rawUsed = active + wired + compressed
        let used = rawUsed > purgeable ? rawUsed - purgeable : rawUsed

        return MemoryMetric(
            usedBytes: min(used, total),
            totalBytes: total,
            activeBytes: min(active, total),
            wiredBytes: min(wired, total),
            compressedBytes: min(compressed, total),
            inactiveBytes: min(inactive, total),
            freeBytes: min(free, total),
            purgeableBytes: min(purgeable, total)
        )
    }

    // MARK: - Memory pressure

    // System memory headroom reported by memory_pressure.
    func memoryPressure() async -> MemoryPressureMetric {
        guard let output = await CommandRunner.run(
            "/usr/bin/memory_pressure",
            arguments: ["-Q"]
        ),
        let raw = firstMatch(#"free percentage:\s*([0-9]+)%"#, in: output),
        let headroom = Double(raw) else {
            return MemoryPressureMetric()
        }

        let clamped = min(100, max(0, headroom))
        let level: MemoryPressureLevel

        // Headroom bands used by the UI status model.
        if clamped >= 60 {
            level = .normal
        } else if clamped >= 30 {
            level = .elevated
        } else {
            level = .critical
        }

        return MemoryPressureMetric(
            available: true,
            level: level,
            headroomPercent: clamped
        )
    }

    // MARK: - GPU

    // GPU metrics from IORegistry performance statistics.
    func gpu() -> GPUMetric {
        if let metric = gpuMetric(serviceClass: "AGXAccelerator") {
            return metric
        }

        if let metric = gpuMetric(serviceClass: "IOAccelerator") {
            return metric
        }

        return GPUMetric()
    }

    private func gpuMetric(serviceClass: String) -> GPUMetric? {
        guard let matching = IOServiceMatching(serviceClass) else { return nil }

        var iterator: io_iterator_t = 0
        let status = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            matching,
            &iterator
        )

        guard status == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var bestMetric: GPUMetric?

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }

            var unmanagedProperties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(
                service,
                &unmanagedProperties,
                kCFAllocatorDefault,
                0
            ) == KERN_SUCCESS,
            let properties = unmanagedProperties?.takeRetainedValue() as? [String: Any],
            let statistics = findDictionary(named: "PerformanceStatistics", in: properties)
            else {
                continue
            }

            let utilization = percentage(
                keys: [
                    "Device Utilization %",
                    "Device Utilization",
                    "GPU Activity(%)",
                    "GPU Activity %",
                    "GPU Utilization %",
                    "GPU Core Utilization",
                    "GPU Busy %"
                ],
                in: statistics
            )

            let renderer = percentage(
                keys: [
                    "Renderer Utilization %",
                    "Renderer Utilization"
                ],
                in: statistics
            )

            let tiler = percentage(
                keys: [
                    "Tiler Utilization %",
                    "Tiler Utilization"
                ],
                in: statistics
            )

            let inUseMemory = uint64(
                keys: [
                    "In use system memory",
                    "In Use System Memory",
                    "In use system memory bytes"
                ],
                in: statistics
            ) ?? 0

            let allocatedMemory = uint64(
                keys: [
                    "Alloc system memory",
                    "Allocated system memory",
                    "Alloc System Memory"
                ],
                in: statistics
            ) ?? 0

            let model = stringValue(
                properties["model"] ?? properties["Model"]
            ) ?? "Apple GPU"

            let coreCount = Int(
                uint64(
                    keys: ["gpu-core-count", "GPU Core Count"],
                    in: properties
                ) ?? 0
            )

            let available = utilization != nil
                || renderer != nil
                || tiler != nil
                || inUseMemory > 0
                || allocatedMemory > 0

            guard available else { continue }

            let metric = GPUMetric(
                available: true,
                utilizationPercent: utilization ?? renderer ?? 0,
                rendererPercent: renderer ?? 0,
                tilerPercent: tiler ?? 0,
                rendererAvailable: renderer != nil,
                tilerAvailable: tiler != nil,
                inUseMemoryBytes: inUseMemory,
                allocatedMemoryBytes: allocatedMemory,
                coreCount: coreCount,
                model: model
            )

            // Prefer entries with a device-utilization counter.
            if utilization != nil {
                return metric
            }

            bestMetric = metric
        }

        return bestMetric
    }

    // MARK: - Disk

    func disk() -> DiskMetric {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let total = (attrs[.systemSize] as? NSNumber)?.uint64Value ?? 0
            let free = (attrs[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
            return DiskMetric(
                usedBytes: total > free ? total - free : 0,
                totalBytes: total,
                freeBytes: free
            )
        } catch {
            return DiskMetric()
        }
    }

    // MARK: - Network

    // Network rates from BSD counters on the primary interface.
    func network() -> NetworkMetric {
        let interface = primaryInterface()
        guard interface != "—",
              let counters = interfaceCounters(named: interface) else {
            resetNetworkBaseline()
            return NetworkMetric(interface: interface)
        }

        let now = Date()
        var down = 0.0
        var up = 0.0

        if let previousRX, let previousTX, let previousNetworkDate {
            let elapsed = max(0.001, now.timeIntervalSince(previousNetworkDate))
            if counters.rx >= previousRX {
                down = Double(counters.rx - previousRX) / elapsed
            }
            if counters.tx >= previousTX {
                up = Double(counters.tx - previousTX) / elapsed
            }
        }

        previousRX = counters.rx
        previousTX = counters.tx
        previousNetworkDate = now

        return NetworkMetric(
            interface: interface,
            downloadBytesPerSecond: down,
            uploadBytesPerSecond: up,
            receivedBytes: counters.rx,
            sentBytes: counters.tx
        )
    }

    private func primaryInterface() -> String {
        guard let value = SCDynamicStoreCopyValue(
            nil,
            "State:/Network/Global/IPv4" as CFString
        ) as? [String: Any],
        let name = value["PrimaryInterface"] as? String,
        !name.isEmpty else {
            return "—"
        }

        return name
    }

    private func interfaceCounters(named interface: String) -> (rx: UInt64, tx: UInt64)? {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return nil }
        defer { freeifaddrs(addresses) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first

        while let pointer = cursor {
            let entry = pointer.pointee
            cursor = entry.ifa_next

            guard String(cString: entry.ifa_name) == interface,
                  let address = entry.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK),
                  let rawData = entry.ifa_data else {
                continue
            }

            let data = rawData.assumingMemoryBound(to: if_data.self).pointee
            return (
                rx: UInt64(data.ifi_ibytes),
                tx: UInt64(data.ifi_obytes)
            )
        }

        return nil
    }

    private func resetNetworkBaseline() {
        previousRX = nil
        previousTX = nil
        previousNetworkDate = nil
    }

    // MARK: - Thermal state

    // System thermal pressure from ProcessInfo.
    func thermalState() -> ThermalMetric {
        let state = ProcessInfo.processInfo.thermalState
        let level: SystemThermalLevel

        switch state {
        case .nominal:
            level = .nominal
        case .fair:
            level = .fair
        case .serious:
            level = .serious
        case .critical:
            level = .critical
        @unknown default:
            level = .unavailable
        }

        return ThermalMetric(
            available: level != .unavailable,
            level: level
        )
    }

    // Battery temperature when AppleSmartBattery exposes it.
    private func batteryTemperatureCelsius() -> Double? {
        guard let matching = IOServiceMatching("AppleSmartBattery") else {
            return nil
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let unmanaged = IORegistryEntryCreateCFProperty(
            service,
            "Temperature" as CFString,
            kCFAllocatorDefault,
            0
        ) else {
            return nil
        }

        let value = unmanaged.takeRetainedValue()
        guard let number = value as? NSNumber else { return nil }

        return MetricMath.batteryTemperatureCelsius(rawValue: number.doubleValue)
    }

    // MARK: - Battery / Hardware / Processes

    func battery() async -> BatteryMetric {
        guard let output = await CommandRunner.run("/usr/bin/pmset", arguments: ["-g", "batt"]) else {
            return BatteryMetric()
        }

        guard let percentMatch = firstMatch(#"([0-9]+)%"#, in: output),
              let percentage = Double(percentMatch) else {
            return BatteryMetric()
        }

        let onAC = output.contains("AC Power")
        let lowered = output.lowercased()
        let state: String
        if lowered.contains("discharging") {
            state = "Discharging"
        } else if lowered.contains("charging") && !lowered.contains("not charging") {
            state = "Charging"
        } else if lowered.contains("charged") {
            state = "Charged"
        } else {
            state = onAC ? "AC Power" : "Battery"
        }

        var remaining = "—"
        if let time = firstMatch(#"([0-9]+:[0-9]+) remaining"#, in: output) {
            remaining = time
        }

        let batteryTemperature = batteryTemperatureCelsius()

        return BatteryMetric(
            available: true,
            percentage: percentage,
            state: state,
            timeRemaining: remaining,
            onACPower: onAC,
            temperatureAvailable: batteryTemperature != nil,
            temperatureCelsius: batteryTemperature ?? 0
        )
    }

    func hardwareInfo() async -> HardwareInfo {
        async let model = CommandRunner.run("/usr/sbin/sysctl", arguments: ["-n", "hw.model"])
        async let cpu = CommandRunner.run("/usr/sbin/sysctl", arguments: ["-n", "machdep.cpu.brand_string"])
        async let version = CommandRunner.run("/usr/bin/sw_vers", arguments: ["-productVersion"])
        async let arch = CommandRunner.run("/usr/bin/uname", arguments: ["-m"])

        return HardwareInfo(
            computerName: Host.current().localizedName ?? "Mac",
            modelIdentifier: clean(await model) ?? "Unknown Mac",
            processor: clean(await cpu) ?? "Apple Silicon",
            architecture: clean(await arch) ?? "arm64",
            macOSVersion: clean(await version) ?? "Unknown",
            physicalMemoryBytes: await totalMemory(),
            logicalCPUCount: max(1, ProcessInfo.processInfo.activeProcessorCount)
        )
    }

    func processes(limit: Int = 200) async -> [ProcessMetric] {
        guard let output = await CommandRunner.run(
            "/bin/ps",
            arguments: ["-axo", "pid=,pcpu=,rss=,etime=,wq=,comm="]
        ) else {
            return []
        }

        let logicalCPUCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
        var result: [ProcessMetric] = []
        result.reserveCapacity(min(limit, 250))

        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let parts = line.split(
                maxSplits: 5,
                omittingEmptySubsequences: true,
                whereSeparator: { $0.isWhitespace }
            )

            guard parts.count == 6,
                  let pid = Int(parts[0]),
                  let rawCPU = Double(parts[1]),
                  let rssKB = UInt64(parts[2]) else {
                continue
            }

            let elapsed = String(parts[3])
            let workqueueThreads = Int(parts[4])
            let command = String(parts[5])
            let name = URL(fileURLWithPath: command).lastPathComponent.isEmpty
                ? command
                : URL(fileURLWithPath: command).lastPathComponent

            let coreUsage = max(0, rawCPU)
            let totalCPU = MetricMath.normalizedProcessCPU(
                coreUsagePercent: coreUsage,
                logicalCPUCount: logicalCPUCount
            )

            result.append(
                ProcessMetric(
                    pid: pid,
                    name: name,
                    cpuTotalPercent: totalCPU,
                    coreUsagePercent: coreUsage,
                    memoryBytes: rssKB * 1024,
                    elapsedTime: elapsed,
                    commandPath: command,
                    workqueueThreads: workqueueThreads
                )
            )
        }

        return Array(
            result
                .sorted { $0.cpuTotalPercent > $1.cpuTotalPercent }
                .prefix(limit)
        )
    }

    // Process detail is loaded on demand.
    func processDetail(pid: Int) async -> ProcessDetail? {
        guard pid > 0 else { return nil }

        async let infoOutput = CommandRunner.run(
            "/bin/ps",
            arguments: ["-p", String(pid), "-o", "etime=,command="]
        )

        async let threadOutput = CommandRunner.run(
            "/bin/ps",
            arguments: ["-M", "-p", String(pid), "-o", "pid="]
        )

        let infoResult = await infoOutput
        guard let info = infoResult?.trimmingCharacters(in: .whitespacesAndNewlines),
              !info.isEmpty else {
            return nil
        }

        let pieces = info.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: { $0.isWhitespace }
        )

        let elapsed = pieces.first.map(String.init) ?? "—"
        let command = pieces.count > 1 ? String(pieces[1]) : "—"

        let threadCount: Int?
        if let threadText = await threadOutput {
            let count = threadText
                .split(separator: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .count
            threadCount = count > 0 ? count : nil
        } else {
            threadCount = nil
        }

        return ProcessDetail(
            pid: pid,
            elapsedTime: elapsed,
            command: command,
            threadCount: threadCount
        )
    }

    // MARK: - Helpers

    private func totalMemory() async -> UInt64 {
        if let cachedTotalMemory { return cachedTotalMemory }
        guard let output = await CommandRunner.run("/usr/sbin/sysctl", arguments: ["-n", "hw.memsize"]),
              let value = UInt64(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return ProcessInfo.processInfo.physicalMemory
        }
        cachedTotalMemory = value
        return value
    }

    private func findDictionary(named key: String, in value: Any) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            if let match = dictionary[key] as? [String: Any] {
                return match
            }

            for child in dictionary.values {
                if let match = findDictionary(named: key, in: child) {
                    return match
                }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let match = findDictionary(named: key, in: child) {
                    return match
                }
            }
        }

        return nil
    }

    private func percentage(keys: [String], in dictionary: [String: Any]) -> Double? {
        for key in keys {
            guard let raw = doubleValue(dictionary[key]) else { continue }

            let normalized: Double
            if key.contains("%") {
                normalized = raw
            } else if raw >= 0, raw <= 1 {
                normalized = raw * 100
            } else {
                normalized = raw
            }

            guard normalized.isFinite else { continue }
            return min(100, max(0, normalized))
        }

        return nil
    }

    private func uint64(keys: [String], in dictionary: [String: Any]) -> UInt64? {
        for key in keys {
            guard let value = dictionary[key] else { continue }

            if let number = value as? NSNumber {
                return number.uint64Value
            }
            if let number = value as? UInt64 {
                return number
            }
            if let number = value as? Int, number >= 0 {
                return UInt64(number)
            }
            if let string = value as? String,
               let number = UInt64(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return number
            }
        }

        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let string = value as? String {
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let data = value as? Data,
           let string = String(data: data, encoding: .utf8) {
            return string
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespacesAndNewlines))
        }

        return nil
    }

    private func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func clean(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
