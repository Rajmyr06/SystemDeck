import XCTest
@testable import SystemDeck

final class DeckFormatTests: XCTestCase {
    func testRateFormatting() {
        XCTAssertEqual(DeckFormat.rate(999), "999 B/s")
        XCTAssertEqual(DeckFormat.rate(1_500), "1.5 KB/s")
        XCTAssertEqual(DeckFormat.rate(2_500_000), "2.5 MB/s")
        XCTAssertEqual(DeckFormat.rate(2_500_000_000), "2.50 GB/s")
    }

    func testRateRejectsInvalidValues() {
        XCTAssertEqual(DeckFormat.rate(-1), "0 B/s")
        XCTAssertEqual(DeckFormat.rate(.infinity), "0 B/s")
    }

    func testPercentClampsRange() {
        XCTAssertEqual(DeckFormat.percent(-10), "0%")
        XCTAssertEqual(DeckFormat.percent(42.4), "42%")
        XCTAssertEqual(DeckFormat.percent(110), "100%")
    }

    func testHistoryRangeFormatting() {
        XCTAssertEqual(DeckFormat.historyRange(45), "Last 45 sec")
        XCTAssertEqual(DeckFormat.historyRange(120), "Last 2 min")
        XCTAssertEqual(DeckFormat.historyRange(240), "Last 4 min")
    }

    func testPowerFormatting() {
        XCTAssertEqual(DeckFormat.voltage(12.418), "12.42 V")
        XCTAssertEqual(DeckFormat.current(-1.82), "1.82 A")
        XCTAssertEqual(DeckFormat.power(22.64), "22.6 W")
    }

    func testDurationCompact() {
        XCTAssertEqual(DeckFormat.durationCompact(9), "9s")
        XCTAssertEqual(DeckFormat.durationCompact(125), "2m 5s")
    }
}
