import XCTest
@testable import GuruttoRun

final class CoordinateTests: XCTestCase {
    func testDouglasPeuckerSimplification() {
        // 直線上の点列（簡略化で中間点が削除されるべき）
        let straightLine: [Coordinate] = [
            Coordinate(latitude: 35.0, longitude: 139.0),
            Coordinate(latitude: 35.001, longitude: 139.001),
            Coordinate(latitude: 35.002, longitude: 139.002),
            Coordinate(latitude: 35.003, longitude: 139.003),
            Coordinate(latitude: 35.004, longitude: 139.004),
        ]

        // epsilon が大きい場合、始点と終点のみになる
        let simplified = straightLine.simplified(epsilon: 100.0)
        XCTAssertEqual(simplified.count, 2)
        XCTAssertEqual(simplified.first, straightLine.first)
        XCTAssertEqual(simplified.last, straightLine.last)
    }

    func testDouglasPeuckerWithCorner() {
        // コーナーがある点列（重要な点は保持されるべき）
        let routeWithCorner: [Coordinate] = [
            Coordinate(latitude: 35.0, longitude: 139.0),
            Coordinate(latitude: 35.001, longitude: 139.0),  // 直線
            Coordinate(latitude: 35.002, longitude: 139.0),  // 直線
            Coordinate(latitude: 35.002, longitude: 139.002), // コーナー（重要）
            Coordinate(latitude: 35.002, longitude: 139.003), // 直線
            Coordinate(latitude: 35.002, longitude: 139.004), // 直線
        ]

        // epsilon を小さくすると、コーナーが保持される
        let simplified = routeWithCorner.simplified(epsilon: 5.0)

        // 始点、コーナー、終点が保持される
        XCTAssertGreaterThanOrEqual(simplified.count, 3)
        XCTAssertEqual(simplified.first, routeWithCorner.first)
        XCTAssertEqual(simplified.last, routeWithCorner.last)
    }

    func testDouglasPeuckerWithFewPoints() {
        // 2点以下の場合はそのまま返される
        let twoPoints: [Coordinate] = [
            Coordinate(latitude: 35.0, longitude: 139.0),
            Coordinate(latitude: 35.001, longitude: 139.001),
        ]

        let simplified = twoPoints.simplified(epsilon: 10.0)
        XCTAssertEqual(simplified.count, 2)
        XCTAssertEqual(simplified, twoPoints)

        // 1点の場合
        let onePoint = [Coordinate(latitude: 35.0, longitude: 139.0)]
        let simplifiedOne = onePoint.simplified(epsilon: 10.0)
        XCTAssertEqual(simplifiedOne.count, 1)
        XCTAssertEqual(simplifiedOne, onePoint)
    }

    func testDouglasPeuckerPreservesImportantPoints() {
        // 実際のGPSデータに近い点列
        let route: [Coordinate] = [
            Coordinate(latitude: 35.685, longitude: 139.752),
            Coordinate(latitude: 35.6851, longitude: 139.7521),  // 直線上
            Coordinate(latitude: 35.6852, longitude: 139.7522),  // 直線上
            Coordinate(latitude: 35.6855, longitude: 139.7520),  // コーナー
            Coordinate(latitude: 35.6856, longitude: 139.7521),  // 直線上
            Coordinate(latitude: 35.6857, longitude: 139.7522),  // 直線上
            Coordinate(latitude: 35.6858, longitude: 139.7523),  // 終点
        ]

        let simplified = route.simplified(epsilon: 5.0)

        // 簡略化後も始点と終点は保持される
        XCTAssertEqual(simplified.first, route.first)
        XCTAssertEqual(simplified.last, route.last)

        // 元の点列より短くなる
        XCTAssertLessThan(simplified.count, route.count)
    }

    func testDouglasPeuckerWithZigzag() {
        // ジグザグの点列（多くの点が保持されるべき）
        let zigzag: [Coordinate] = [
            Coordinate(latitude: 35.0, longitude: 139.0),
            Coordinate(latitude: 35.001, longitude: 139.001),
            Coordinate(latitude: 35.002, longitude: 139.0),
            Coordinate(latitude: 35.003, longitude: 139.001),
            Coordinate(latitude: 35.004, longitude: 139.0),
            Coordinate(latitude: 35.005, longitude: 139.001),
        ]

        // epsilon を小さくすると、ジグザグが保持される
        let simplified = zigzag.simplified(epsilon: 5.0)

        // ジグザグなので、多くの点が保持される
        XCTAssertGreaterThan(simplified.count, 2)
    }

    func testDouglasPeuckerReducesMemoryUsage() {
        // 大量の点列を生成
        var largeRoute: [Coordinate] = []
        for i in 0..<1000 {
            let lat = 35.0 + Double(i) * 0.0001
            let lon = 139.0 + Double(i) * 0.0001
            largeRoute.append(Coordinate(latitude: lat, longitude: lon))
        }

        let simplified = largeRoute.simplified(epsilon: 10.0)

        // 大幅に点数が削減される
        XCTAssertLessThan(simplified.count, largeRoute.count / 2)

        // 始点と終点は保持される
        XCTAssertEqual(simplified.first, largeRoute.first)
        XCTAssertEqual(simplified.last, largeRoute.last)
    }
}
