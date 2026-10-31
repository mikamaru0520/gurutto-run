import XCTest
@testable import GuruttoRun

final class LocalProjectionTests: XCTestCase {
    func testProjectionAtOrigin() {
        let origin = Coordinate(latitude: 35.0, longitude: 139.0)
        let projection = LocalProjection(origin: origin)

        let point = projection.project(origin)

        // 原点は (0, 0) にマップされる
        XCTAssertEqual(point.x, 0, accuracy: 0.001)
        XCTAssertEqual(point.y, 0, accuracy: 0.001)
    }

    func testProjectionNorthSouth() {
        let origin = Coordinate(latitude: 35.0, longitude: 139.0)
        let projection = LocalProjection(origin: origin)

        // 北へ0.01度（約1.1km）
        let north = Coordinate(latitude: 35.01, longitude: 139.0)
        let pointNorth = projection.project(north)

        // y座標が正で、約1113メートル
        XCTAssertGreaterThan(pointNorth.y, 1100)
        XCTAssertLessThan(pointNorth.y, 1120)
        XCTAssertEqual(pointNorth.x, 0, accuracy: 0.001)

        // 南へ0.01度
        let south = Coordinate(latitude: 34.99, longitude: 139.0)
        let pointSouth = projection.project(south)

        // y座標が負で、約-1113メートル
        XCTAssertLessThan(pointSouth.y, -1100)
        XCTAssertGreaterThan(pointSouth.y, -1120)
        XCTAssertEqual(pointSouth.x, 0, accuracy: 0.001)
    }

    func testProjectionEastWest() {
        let origin = Coordinate(latitude: 35.0, longitude: 139.0)
        let projection = LocalProjection(origin: origin)

        // 東へ0.01度
        let east = Coordinate(latitude: 35.0, longitude: 139.01)
        let pointEast = projection.project(east)

        // x座標が正
        XCTAssertGreaterThan(pointEast.x, 900)
        XCTAssertLessThan(pointEast.x, 920)
        XCTAssertEqual(pointEast.y, 0, accuracy: 0.001)

        // 西へ0.01度
        let west = Coordinate(latitude: 35.0, longitude: 138.99)
        let pointWest = projection.project(west)

        // x座標が負
        XCTAssertLessThan(pointWest.x, -900)
        XCTAssertGreaterThan(pointWest.x, -920)
        XCTAssertEqual(pointWest.y, 0, accuracy: 0.001)
    }

    func testDistanceCalculation() {
        let origin = Coordinate(latitude: 35.685, longitude: 139.752)
        let projection = LocalProjection(origin: origin)

        // 同じ点の距離は0
        let distance1 = projection.distance(origin, origin)
        XCTAssertEqual(distance1, 0, accuracy: 0.001)

        // 北へ約100m移動
        let point1 = Coordinate(latitude: 35.686, longitude: 139.752)
        let distance2 = projection.distance(origin, point1)
        XCTAssertGreaterThan(distance2, 100)
        XCTAssertLessThan(distance2, 120)

        // 東へ約100m移動
        let point2 = Coordinate(latitude: 35.685, longitude: 139.753)
        let distance3 = projection.distance(origin, point2)
        XCTAssertGreaterThan(distance3, 90)
        XCTAssertLessThan(distance3, 110)
    }

    func testDistanceSymmetry() {
        let origin = Coordinate(latitude: 35.685, longitude: 139.752)
        let projection = LocalProjection(origin: origin)

        let pointA = Coordinate(latitude: 35.686, longitude: 139.753)
        let pointB = Coordinate(latitude: 35.687, longitude: 139.754)

        // 距離は対称的（A→B と B→A は同じ）
        let distanceAB = projection.distance(pointA, pointB)
        let distanceBA = projection.distance(pointB, pointA)

        XCTAssertEqual(distanceAB, distanceBA, accuracy: 0.001)
    }

    func testDistancePythagorean() {
        let origin = Coordinate(latitude: 35.0, longitude: 139.0)
        let projection = LocalProjection(origin: origin)

        // 北へ300m、東へ400m移動 → 距離は500m（三平方の定理）
        let north300 = Coordinate(latitude: 35.0 + 300.0 / 111_319.9, longitude: 139.0)
        let distanceNorth = projection.distance(origin, north300)
        XCTAssertEqual(distanceNorth, 300, accuracy: 1.0)

        let latNorth = 35.0 + 300.0 / 111_319.9
        let lonEast = 139.0 + 400.0 / (111_319.9 * cos(35.0 * .pi / 180.0))
        let northeast = Coordinate(latitude: latNorth, longitude: lonEast)

        let distanceDiagonal = projection.distance(origin, northeast)
        // √(300² + 400²) = 500
        XCTAssertEqual(distanceDiagonal, 500, accuracy: 5.0)
    }

    func testProjectionConsistency() {
        let origin = Coordinate(latitude: 35.685, longitude: 139.752)
        let projection1 = LocalProjection(origin: origin)
        let projection2 = LocalProjection(origin: origin)

        // 同じ原点なら同じ投影結果
        let point = Coordinate(latitude: 35.686, longitude: 139.753)
        let projected1 = projection1.project(point)
        let projected2 = projection2.project(point)

        XCTAssertEqual(projected1.x, projected2.x, accuracy: 0.001)
        XCTAssertEqual(projected1.y, projected2.y, accuracy: 0.001)
    }
}
