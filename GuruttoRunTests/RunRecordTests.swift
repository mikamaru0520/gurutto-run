import XCTest
@testable import GuruttoRun

final class RunRecordTests: XCTestCase {
    func testPaceCalculation() {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5000,  // 5km
            elapsed: .seconds(1500),  // 25分（1500秒）
            laps: 1.0,
            route: [],
            source: .guruttoRun
        )

        // 1500秒 / 5km = 300秒/km = 5分00秒/km
        XCTAssertEqual(record.paceSecondsPerKm, 300.0, accuracy: 0.1)
        XCTAssertEqual(record.paceFormatted, "5'00\"/km")
    }

    func testPaceFormattedWithShortDistance() {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 50,  // 50m（100m未満）
            elapsed: .seconds(30),
            laps: 0,
            route: [],
            source: .guruttoRun
        )

        // 100m未満の場合は "--'--\"" を返す
        XCTAssertEqual(record.paceFormatted, "--'--\"")
    }

    func testPaceFormattedWithZeroDistance() {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 0,
            elapsed: .seconds(100),
            laps: 0,
            route: [],
            source: .guruttoRun
        )

        XCTAssertEqual(record.paceFormatted, "--'--\"")
    }

    func testImperialPalaceEquivalent() {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 8000,  // 8km
            elapsed: .seconds(2400),
            laps: 0,
            route: [],
            source: .guruttoRun
        )

        // 8km = 皇居1.6周分
        XCTAssertEqual(record.imperialPalaceEquivalent, 1.6, accuracy: 0.01)
        XCTAssertEqual(record.imperialPalaceFormatted, "皇居1.6周分")
    }

    func testLapsFormatted() {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5000,
            elapsed: .seconds(1500),
            laps: 2.5,  // 2.5周
            route: [],
            source: .guruttoRun
        )

        XCTAssertEqual(record.lapsFormatted, "2.5周")
    }

    func testSourceEquality() {
        let record1 = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5000,
            elapsed: .seconds(1500),
            laps: 1.0,
            route: [],
            source: .guruttoRun
        )

        let record2 = RunRecord(
            id: record1.id,
            date: record1.date,
            distanceMeters: 5000,
            elapsed: .seconds(1500),
            laps: 1.0,
            route: [],
            source: .otherApp("Nike Run Club")
        )

        // source が異なるので等しくない
        XCTAssertNotEqual(record1, record2)
    }

    func testPaceFormattedWithFastPace() {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5000,  // 5km
            elapsed: .seconds(900),  // 15分（900秒）
            laps: 1.0,
            route: [],
            source: .guruttoRun
        )

        // 900秒 / 5km = 180秒/km = 3分00秒/km
        XCTAssertEqual(record.paceSecondsPerKm, 180.0, accuracy: 0.1)
        XCTAssertEqual(record.paceFormatted, "3'00\"/km")
    }

    func testPaceFormattedWithSlowPace() {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5000,  // 5km
            elapsed: .seconds(3000),  // 50分（3000秒）
            laps: 1.0,
            route: [],
            source: .guruttoRun
        )

        // 3000秒 / 5km = 600秒/km = 10分00秒/km
        XCTAssertEqual(record.paceSecondsPerKm, 600.0, accuracy: 0.1)
        XCTAssertEqual(record.paceFormatted, "10'00\"/km")
    }
}
