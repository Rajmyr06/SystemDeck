import Combine
import Foundation

@MainActor
final class SystemMonitorStore: ObservableObject {
    @Published var cpuUsage: Double = 0
    @Published var cpuCores: [CoreCPUMetric] = []
    @Published var gpu = GPUMetric()
    @Published var memory = MemoryMetric()
    @Published var memoryPressure = MemoryPressureMetric()
    @Published var disk = DiskMetric()
    @Published var network = NetworkMetric()
    @Published var battery = BatteryMetric()
    @Published var thermal = ThermalMetric()
    @Published var hardware = HardwareInfo()
    @Published var processes: [ProcessMetric] = []
    @Published var selectedProcessDetail: ProcessDetail?
    @Published var selectedProcessDetailPID: Int?

    @Published var cpuHistory: [MetricSample] = []
    @Published var gpuHistory: [MetricSample] = []
    @Published var memoryHistory: [MetricSample] = []
    @Published var downloadHistory: [MetricSample] = []
    @Published var uploadHistory: [MetricSample] = []
    @Published var batteryHistory: [MetricSample] = []
    @Published var batteryPowerHistory: [MetricSample] = []

    @Published var refreshInterval: Double {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
        }
    }

    @Published var isMonitoring = false
    @Published var lastRefresh: Date?
    @Published var lastError: String?

    private let service = SystemMetricsService()
    private let thresholdAlerts = ThresholdAlertEngine()
    private var fastTask: Task<Void, Never>?
    private var processTask: Task<Void, Never>?
    private var batteryTask: Task<Void, Never>?
    private var slowTask: Task<Void, Never>?
    private var processDetailTask: Task<Void, Never>?
    private var didLoadHardware = false
    private var resumeMonitoringAfterWake = false
    private var activeIssues: [String: String] = [:]
    private var collectorLastAttempt: [String: Date] = [:]
    private var collectorLastSuccess: [String: Date] = [:]
    private var collectorFailures: [String: Int] = [:]

    private let historyLimit = 120

    init() {
        let saved = UserDefaults.standard.double(forKey: "refreshInterval")
        self.refreshInterval = [1.0, 2.0, 5.0].contains(saved) ? saved : 1.0
    }

    deinit {
        fastTask?.cancel()
        processTask?.cancel()
        batteryTask?.cancel()
        slowTask?.cancel()
        processDetailTask?.cancel()
    }

    var diagnostics: [TelemetryDiagnostic] {
        let fastStaleAfter = max(5.0, refreshInterval * 3.0)
        let processStaleAfter = max(15.0, refreshInterval * 10.0)
        let batteryStaleAfter = 15.0
        let slowStaleAfter = 75.0

        return [
            TelemetryDiagnostic(
                id: "cpu",
                name: "CPU",
                state: diagnosticState(
                    key: "cpu",
                    currentlyAvailable: lastRefresh != nil,
                    staleAfter: fastStaleAfter
                ),
                detail: lastRefresh == nil
                    ? "Waiting for the first CPU sample"
                    : "\(DeckFormat.percent(cpuUsage)) utilization · \(cpuCores.count) logical CPUs · \(sampleAgeText(for: "cpu"))",
                lastSuccess: collectorLastSuccess["cpu"]
            ),
            TelemetryDiagnostic(
                id: "memory",
                name: "Memory",
                state: diagnosticState(
                    key: "memory",
                    currentlyAvailable: memory.totalBytes > 0,
                    staleAfter: fastStaleAfter
                ),
                detail: memory.totalBytes > 0
                    ? "\(DeckFormat.bytes(memory.usedBytes)) of \(DeckFormat.bytes(memory.totalBytes)) used · \(DeckFormat.bytes(memory.compressedBytes)) compressed · \(sampleAgeText(for: "memory"))"
                    : "No valid memory sample",
                lastSuccess: collectorLastSuccess["memory"]
            ),
            TelemetryDiagnostic(
                id: "storage",
                name: "Storage",
                state: storageDiagnosticState(staleAfter: fastStaleAfter),
                detail: disk.totalBytes > 0
                    ? "\(DeckFormat.percent(disk.usagePercent)) used · \(DeckFormat.bytes(disk.freeBytes)) free · \(sampleAgeText(for: "storage"))"
                    : "Capacity data unavailable",
                lastSuccess: collectorLastSuccess["storage"]
            ),
            TelemetryDiagnostic(
                id: "gpu",
                name: "GPU",
                state: gpuDiagnosticState(staleAfter: fastStaleAfter),
                detail: gpuDiagnosticDetail(),
                lastSuccess: collectorLastSuccess["gpu"]
            ),
            TelemetryDiagnostic(
                id: "network",
                name: "Network",
                state: diagnosticState(
                    key: "network",
                    currentlyAvailable: network.available,
                    staleAfter: fastStaleAfter
                ),
                detail: network.available
                    ? "\(network.interface) active · ↓ \(DeckFormat.rate(network.downloadBytesPerSecond)) · ↑ \(DeckFormat.rate(network.uploadBytesPerSecond)) · \(sampleAgeText(for: "network"))"
                    : "No active primary network interface",
                lastSuccess: collectorLastSuccess["network"]
            ),
            TelemetryDiagnostic(
                id: "processes",
                name: "Processes",
                state: diagnosticState(
                    key: "processes",
                    currentlyAvailable: !processes.isEmpty,
                    staleAfter: processStaleAfter
                ),
                detail: !processes.isEmpty
                    ? "\(processes.count) processes sampled · \(sampleAgeText(for: "processes"))"
                    : "Process snapshot unavailable",
                lastSuccess: collectorLastSuccess["processes"]
            ),
            TelemetryDiagnostic(
                id: "battery",
                name: "Battery",
                state: batteryDiagnosticState(staleAfter: batteryStaleAfter),
                detail: batteryDiagnosticDetail(),
                lastSuccess: collectorLastSuccess["battery"]
            ),
            TelemetryDiagnostic(
                id: "thermal",
                name: "Thermal state",
                state: thermalDiagnosticState(staleAfter: fastStaleAfter),
                detail: thermal.available
                    ? "\(thermal.displayName) · \(thermal.shortDetail) · \(sampleAgeText(for: "thermal"))"
                    : "System thermal state unavailable",
                lastSuccess: collectorLastSuccess["thermal"]
            ),
            TelemetryDiagnostic(
                id: "pressure",
                name: "Memory pressure",
                state: memoryPressureDiagnosticState(staleAfter: slowStaleAfter),
                detail: memoryPressure.available
                    ? "\(DeckFormat.percent(memoryPressure.headroomPercent)) headroom · \(DeckFormat.bytes(memory.compressedBytes)) compressed · \(sampleAgeText(for: "pressure"))"
                    : "Memory headroom signal unavailable",
                lastSuccess: collectorLastSuccess["pressure"]
            )
        ]
    }

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        activeIssues.removeAll()
        lastError = nil
        SystemDeckLog.lifecycle.info("Monitoring started")

        fastTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshFastMetrics()
                let interval = max(1.0, self.refreshInterval)
                try? await Task.sleep(for: .seconds(interval))
            }
        }

        processTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshProcesses()
                let interval = max(5.0, self.refreshInterval * 5)
                try? await Task.sleep(for: .seconds(interval))
            }
        }

        batteryTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshBatteryMetrics()
                try? await Task.sleep(for: .seconds(5))
            }
        }

        slowTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshSlowMetrics()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await self.refreshSlowMetrics()
            }
        }
    }

    func stop() {
        fastTask?.cancel()
        processTask?.cancel()
        batteryTask?.cancel()
        slowTask?.cancel()
        processDetailTask?.cancel()
        fastTask = nil
        processTask = nil
        batteryTask = nil
        slowTask = nil
        processDetailTask = nil
        isMonitoring = false
        SystemDeckLog.lifecycle.info("Monitoring stopped")
    }

    func refreshNow() {
        SystemDeckLog.telemetry.debug("Manual refresh requested")
        Task {
            await refreshFastMetrics()
            await refreshProcesses()
            await refreshBatteryMetrics()
            await refreshSlowMetrics()
        }
    }

    // MARK: - Sleep / Wake

    func prepareForSystemSleep() {
        resumeMonitoringAfterWake = isMonitoring
        SystemDeckLog.lifecycle.info("System sleep detected; monitoringActive=\(self.isMonitoring)")
        if isMonitoring {
            stop()
        }
    }

    func resumeAfterSystemWake() {
        let shouldResume = resumeMonitoringAfterWake
        resumeMonitoringAfterWake = false
        SystemDeckLog.lifecycle.info("System wake detected; shouldResume=\(shouldResume)")

        Task { [weak self] in
            guard let self else { return }
            await self.service.resetSamplingBaselines()
            if shouldResume {
                self.start()
            }
        }
    }

    func loadProcessDetail(pid: Int) {
        processDetailTask?.cancel()
        selectedProcessDetailPID = pid
        selectedProcessDetail = nil

        processDetailTask = Task { [weak self] in
            guard let self else { return }
            let detail = await self.service.processDetail(pid: pid)
            guard !Task.isCancelled, self.selectedProcessDetailPID == pid else { return }
            self.selectedProcessDetail = detail
        }
    }

    func clearProcessDetail() {
        processDetailTask?.cancel()
        processDetailTask = nil
        selectedProcessDetailPID = nil
        selectedProcessDetail = nil
    }

    private func refreshFastMetrics() async {
        let fastKeys = ["cpu", "gpu", "memory", "storage", "network", "thermal"]
        fastKeys.forEach { markCollectorAttempt($0) }

        async let cpuTask = service.cpuUsage()
        async let coreTask = service.perCoreCPUUsage()
        async let gpuTask = service.gpu()
        async let memoryTask = service.memory()
        async let diskTask = service.disk()
        async let networkTask = service.network()
        async let thermalTask = service.thermalState()

        let cpu = await cpuTask
        let coreValues = await coreTask
        let gpuValue = await gpuTask
        let mem = await memoryTask
        let diskValue = await diskTask
        let networkValue = await networkTask
        let thermalValue = await thermalTask

        if cpu.isFinite && cpu >= 0 && cpu <= 100 {
            cpuUsage = cpu
            cpuCores = coreValues
            markCollectorSuccess("cpu")
        } else {
            markCollectorFailure("cpu")
        }

        gpu = gpuValue
        updateCollectorAvailability("gpu", available: gpuValue.available)

        thermal = thermalValue
        updateCollectorAvailability("thermal", available: thermalValue.available)

        if mem.totalBytes > 0 {
            memory = mem
            markCollectorSuccess("memory")
            clearIssue(key: "memory")
        } else {
            markCollectorFailure("memory")
            recordIssue(key: "memory", message: "Memory telemetry returned an invalid sample.")
        }

        if diskValue.totalBytes > 0 {
            disk = diskValue
            markCollectorSuccess("storage")
            clearIssue(key: "storage")
        } else {
            markCollectorFailure("storage")
            recordIssue(key: "storage", message: "Storage telemetry is temporarily unavailable.")
        }

        network = networkValue
        updateCollectorAvailability("network", available: networkValue.available)
        lastRefresh = Date()

        MetricMath.appendBounded(value: cpu, to: &cpuHistory, limit: historyLimit)
        if gpuValue.available {
            MetricMath.appendBounded(value: gpuValue.utilizationPercent, to: &gpuHistory, limit: historyLimit)
        }
        if mem.totalBytes > 0 {
            MetricMath.appendBounded(value: mem.usagePercent, to: &memoryHistory, limit: historyLimit)
        }
        if networkValue.available {
            MetricMath.appendBounded(value: networkValue.downloadBytesPerSecond, to: &downloadHistory, limit: historyLimit)
            MetricMath.appendBounded(value: networkValue.uploadBytesPerSecond, to: &uploadHistory, limit: historyLimit)
        }

        thresholdAlerts.evaluate(
            cpuUsage: cpuUsage,
            memoryPressure: memoryPressure,
            disk: disk,
            thermal: thermal,
            battery: battery
        )
    }

    private func refreshProcesses() async {
        markCollectorAttempt("processes")
        let snapshot = await service.processes(limit: 250)
        guard !snapshot.isEmpty else {
            markCollectorFailure("processes")
            recordIssue(
                key: "processes",
                message: "Process telemetry is temporarily unavailable. The previous snapshot is retained."
            )
            SystemDeckLog.process.warning("Process snapshot returned no rows")
            return
        }

        processes = snapshot
        markCollectorSuccess("processes")
        clearIssue(key: "processes")
    }

    private func refreshBatteryMetrics() async {
        markCollectorAttempt("battery")

        let batteryValue = await service.battery()
        battery = batteryValue
        updateCollectorAvailability("battery", available: batteryValue.available)

        if batteryValue.available {
            MetricMath.appendBounded(value: batteryValue.percentage, to: &batteryHistory, limit: historyLimit)
            if let power = batteryValue.powerWatts {
                MetricMath.appendBounded(value: power, to: &batteryPowerHistory, limit: historyLimit)
            }
        }

        thresholdAlerts.evaluate(
            cpuUsage: cpuUsage,
            memoryPressure: memoryPressure,
            disk: disk,
            thermal: thermal,
            battery: battery
        )
    }

    private func refreshSlowMetrics() async {
        markCollectorAttempt("pressure")

        let pressureValue = await service.memoryPressure()
        memoryPressure = pressureValue
        updateCollectorAvailability("pressure", available: pressureValue.available)

        if !didLoadHardware {
            hardware = await service.hardwareInfo()
            didLoadHardware = true
            SystemDeckLog.telemetry.info("Hardware identity cached")
        }

        thresholdAlerts.evaluate(
            cpuUsage: cpuUsage,
            memoryPressure: memoryPressure,
            disk: disk,
            thermal: thermal,
            battery: battery
        )
    }

    // MARK: - Collector health metadata

    private func markCollectorAttempt(_ key: String) {
        collectorLastAttempt[key] = Date()
    }

    private func markCollectorSuccess(_ key: String) {
        collectorLastSuccess[key] = Date()
        collectorFailures[key] = 0
    }

    private func markCollectorFailure(_ key: String) {
        collectorFailures[key, default: 0] += 1
    }

    private func updateCollectorAvailability(_ key: String, available: Bool) {
        if available {
            markCollectorSuccess(key)
        } else if collectorLastSuccess[key] != nil {
            markCollectorFailure(key)
        }
    }

    private func diagnosticState(
        key: String,
        currentlyAvailable: Bool,
        staleAfter: TimeInterval
    ) -> DiagnosticState {
        let failures = collectorFailures[key, default: 0]
        if failures >= 3 { return .failed }

        if let lastSuccess = collectorLastSuccess[key] {
            let age = Date().timeIntervalSince(lastSuccess)
            if age > staleAfter { return .stale }
            if !currentlyAvailable { return .limited }
            return .healthy
        }

        if collectorLastAttempt[key] == nil { return .limited }
        return currentlyAvailable ? .healthy : .unavailable
    }

    private func storageDiagnosticState(staleAfter: TimeInterval) -> DiagnosticState {
        let sourceState = diagnosticState(
            key: "storage",
            currentlyAvailable: disk.totalBytes > 0,
            staleAfter: staleAfter
        )
        guard sourceState == .healthy else { return sourceState }
        return disk.usagePercent >= 80 ? .limited : .healthy
    }

    private func gpuDiagnosticDetail() -> String {
        guard gpu.available else { return "GPU telemetry is not exposed on this Mac" }
        let utilization = DeckFormat.percent(gpu.utilizationPercent)
        let memoryText = gpu.inUseMemoryBytes > 0
            ? "\(DeckFormat.bytes(gpu.inUseMemoryBytes)) in use"
            : "memory use unavailable"
        let scopeText = (!gpu.hasDistinctRendererMetric && !gpu.hasDistinctTilerMetric)
            ? "renderer and tiler metrics not exposed"
            : "device and sub-metrics updating"
        return "\(utilization) utilization · \(memoryText) · \(scopeText) · \(sampleAgeText(for: "gpu"))"
    }

    private func gpuDiagnosticState(staleAfter: TimeInterval) -> DiagnosticState {
        let sourceState = diagnosticState(
            key: "gpu",
            currentlyAvailable: gpu.available,
            staleAfter: staleAfter
        )
        guard sourceState == .healthy else { return sourceState }
        if !gpu.hasDistinctRendererMetric && !gpu.hasDistinctTilerMetric {
            return .limited
        }
        return .healthy
    }

    private func batteryDiagnosticState(staleAfter: TimeInterval) -> DiagnosticState {
        let sourceState = diagnosticState(
            key: "battery",
            currentlyAvailable: battery.available,
            staleAfter: staleAfter
        )
        guard sourceState == .healthy else { return sourceState }
        return (battery.hasElectricalTelemetry || battery.hasHealthTelemetry) ? .healthy : .limited
    }

    private func batteryDiagnosticDetail() -> String {
        guard battery.available else { return "No battery telemetry on this Mac" }

        var parts = [DeckFormat.percent(battery.percentage), battery.state]
        if let voltage = battery.voltageVolts { parts.append(DeckFormat.voltage(voltage)) }
        if let power = battery.powerWatts { parts.append(DeckFormat.power(power)) }
        if let cycles = battery.cycleCount { parts.append("\(cycles) cycles") }
        parts.append(sampleAgeText(for: "battery"))
        return parts.joined(separator: " · ")
    }

    private func thermalDiagnosticState(staleAfter: TimeInterval) -> DiagnosticState {
        let sourceState = diagnosticState(
            key: "thermal",
            currentlyAvailable: thermal.available,
            staleAfter: staleAfter
        )
        guard sourceState == .healthy else { return sourceState }
        switch thermal.level {
        case .nominal: return .healthy
        case .fair, .serious, .critical: return .limited
        case .unavailable: return .unavailable
        }
    }

    private func memoryPressureDiagnosticState(staleAfter: TimeInterval) -> DiagnosticState {
        let sourceState = diagnosticState(
            key: "pressure",
            currentlyAvailable: memoryPressure.available,
            staleAfter: staleAfter
        )
        guard sourceState == .healthy else { return sourceState }
        switch memoryPressure.level {
        case .normal: return .healthy
        case .elevated, .critical: return .limited
        case .unavailable: return .unavailable
        }
    }

    private func sampleAgeText(for key: String) -> String {
        let failures = collectorFailures[key, default: 0]
        guard let date = collectorLastSuccess[key] else {
            if failures > 0 {
                return failures == 1 ? "1 failed refresh" : "\(failures) failed refreshes"
            }
            return "no successful sample yet"
        }

        let seconds = max(0, Int(Date().timeIntervalSince(date).rounded()))
        let ageText: String
        if seconds < 2 {
            ageText = "updated now"
        } else if seconds < 60 {
            ageText = "updated \(seconds)s ago"
        } else {
            ageText = "updated \(seconds / 60)m ago"
        }

        guard failures > 0 else { return ageText }
        let failureText = failures == 1 ? "1 failed refresh" : "\(failures) failed refreshes"
        return "\(ageText) · \(failureText)"
    }

    private func recordIssue(key: String, message: String) {
        activeIssues[key] = message
        syncLastError()
        SystemDeckLog.telemetry.warning("\(message, privacy: .public)")
    }

    private func clearIssue(key: String) {
        activeIssues.removeValue(forKey: key)
        syncLastError()
    }

    private func syncLastError() {
        lastError = activeIssues.keys.sorted().compactMap { activeIssues[$0] }.first
    }

    // MARK: - History helpers

    func average(of history: [MetricSample], fallback: Double = 0) -> Double {
        MetricMath.average(of: history, fallback: fallback)
    }

    func peak(of history: [MetricSample], fallback: Double = 0) -> Double {
        MetricMath.peak(of: history, fallback: fallback)
    }

    func historyWindow(of history: [MetricSample]) -> TimeInterval {
        MetricMath.historyWindow(of: history)
    }
}
