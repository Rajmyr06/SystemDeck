import XCTest
@testable import SystemDeck

final class MetricStatusTests: XCTestCase {
    func testCPUThresholds() {
        XCTAssertEqual(MetricStatusEvaluator.cpu(rollingAverage: 20, hasSamples: true).severity, .normal)
        XCTAssertEqual(MetricStatusEvaluator.cpu(rollingAverage: 55, hasSamples: true).severity, .elevated)
        XCTAssertEqual(MetricStatusEvaluator.cpu(rollingAverage: 80, hasSamples: true).severity, .high)
        XCTAssertEqual(MetricStatusEvaluator.cpu(rollingAverage: 80, hasSamples: false).severity, .unavailable)
    }

    func testDiskThresholds() {
        XCTAssertEqual(MetricStatusEvaluator.disk(usagePercent: 70, totalBytes: 100).severity, .normal)
        XCTAssertEqual(MetricStatusEvaluator.disk(usagePercent: 85, totalBytes: 100).severity, .elevated)
        XCTAssertEqual(MetricStatusEvaluator.disk(usagePercent: 95, totalBytes: 100).severity, .high)
        XCTAssertEqual(MetricStatusEvaluator.disk(usagePercent: 0, totalBytes: 0).severity, .unavailable)
    }
}
