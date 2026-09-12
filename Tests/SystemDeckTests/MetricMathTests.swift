import XCTest
@testable import SystemDeck

final class MetricMathTests: XCTestCase {
    func testProcessCPUNormalizesAcrossLogicalCPUs() {
        XCTAssertEqual(
            MetricMath.normalizedProcessCPU(coreUsagePercent: 192.0, logicalCPUCount: 8),
            24.0,
            accuracy: 0.0001
        )
    }

    func testProcessCPUIsClampedToTotalCapacity() {
        XCTAssertEqual(
            MetricMath.normalizedProcessCPU(coreUsagePercent: 900.0, logicalCPUCount: 8),
            100.0,
            accuracy: 0.0001
        )
    }

    func testProcessCPUProtectsInvalidCPUCount() {
        XCTAssertEqual(
            MetricMath.normalizedProcessCPU(coreUsagePercent: 50.0, logicalCPUCount: 0),
            50.0,
            accuracy: 0.0001
        )
    }

    func testBatteryTemperatureConversionSupportsCommonEncodings() throws {
        let deciKelvin = try XCTUnwrap(MetricMath.batteryTemperatureCelsius(rawValue: 3031))
        let kelvin = try XCTUnwrap(MetricMath.batteryTemperatureCelsius(rawValue: 303.15))
        let centiKelvin = try XCTUnwrap(MetricMath.batteryTemperatureCelsius(rawValue: 30315))
        let celsius = try XCTUnwrap(MetricMath.batteryTemperatureCelsius(rawValue: 32))

        XCTAssertEqual(deciKelvin, 29.95, accuracy: 0.05)
        XCTAssertEqual(kelvin, 30.0, accuracy: 0.05)
        XCTAssertEqual(centiKelvin, 30.0, accuracy: 0.05)
        XCTAssertEqual(celsius, 32.0, accuracy: 0.05)
    }

    func testBatteryTemperatureRejectsImplausibleValues() {
        XCTAssertNil(MetricMath.batteryTemperatureCelsius(rawValue: 1_000_000))
        XCTAssertNil(MetricMath.batteryTemperatureCelsius(rawValue: -200))
    }

    func testBoundedHistoryRetainsNewestSamples() {
        var history: [MetricSample] = []
        for value in 0..<6 {
            MetricMath.appendBounded(value: Double(value), to: &history, limit: 3)
        }

        XCTAssertEqual(history.map(\.value), [3, 4, 5])
    }

    func testBoundedHistoryRejectsNonFiniteValues() {
        var history: [MetricSample] = []
        MetricMath.appendBounded(value: .infinity, to: &history, limit: 3)
        MetricMath.appendBounded(value: .nan, to: &history, limit: 3)
        XCTAssertTrue(history.isEmpty)
    }

    func testAveragePeakAndWindow() {
        let start = Date(timeIntervalSince1970: 100)
        let history = [
            MetricSample(timestamp: start, value: 10),
            MetricSample(timestamp: start.addingTimeInterval(2), value: 20),
            MetricSample(timestamp: start.addingTimeInterval(5), value: 30)
        ]

        XCTAssertEqual(MetricMath.average(of: history), 20, accuracy: 0.0001)
        XCTAssertEqual(MetricMath.peak(of: history), 30, accuracy: 0.0001)
        XCTAssertEqual(MetricMath.historyWindow(of: history), 5, accuracy: 0.0001)
    }
}
