import XCTest
@testable import GuruttoRun

final class LapCounterTests: XCTestCase {
    /// テスト用の円形ルートを生成
    private func makeCircularRoute(center: Coordinate, radiusMeters: Double, points: Int) -> [Coordinate] {
        // radiusMeters を緯度経度の差分に変換（簡易計算）
        let metersPerDegree = 111_319.9
        let radiusDegrees = radiusMeters / metersPerDegree

        return (0..<points).map { i in
            let angle = 2 * Double.pi * Double(i) / Double(points)
            let latOffset = radiusDegrees * cos(angle)
            let lonOffset = radiusDegrees * sin(angle) / cos(center.latitude * .pi / 180)
            return Coordinate(
                latitude: center.latitude + latOffset,
                longitude: center.longitude + lonOffset
            )
        }
    }

    func testOneLap() throws {
        // 中心が皇居付近、半径400m、36点の円形ルート
        let center = Coordinate(latitude: 35.685, longitude: 139.752)
        let route = makeCircularRoute(center: center, radiusMeters: 400, points: 36)

        var counter = LapCounter(referenceRoute: route)
        let totalLength = counter.totalLength

        // ルート上の各点を順番に更新
        var timestamp = Date()
        for coord in route {
            counter.update(coordinate: coord, timestamp: timestamp)
            timestamp = timestamp.addingTimeInterval(10) // 10秒ごと
        }

        // 1周したので laps はおよそ 1
        XCTAssertEqual(counter.laps, 1.0, accuracy: 0.1)
    }

    func testTwoAndHalfLaps() throws {
        let center = Coordinate(latitude: 35.685, longitude: 139.752)
        let route = makeCircularRoute(center: center, radiusMeters: 400, points: 36)

        var counter = LapCounter(referenceRoute: route)

        // 2.5周分進む
        var timestamp = Date()
        for _ in 0..<2 {
            for coord in route {
                counter.update(coordinate: coord, timestamp: timestamp)
                timestamp = timestamp.addingTimeInterval(10)
            }
        }
        // さらに半周
        for i in 0..<(route.count / 2) {
            counter.update(coordinate: route[i], timestamp: timestamp)
            timestamp = timestamp.addingTimeInterval(10)
        }

        // 2.5周
        XCTAssertEqual(counter.laps, 2.5, accuracy: 0.15)
    }

    func testCrossStartPoint() throws {
        let center = Coordinate(latitude: 35.685, longitude: 139.752)
        let route = makeCircularRoute(center: center, radiusMeters: 400, points: 36)

        var counter = LapCounter(referenceRoute: route)

        var timestamp = Date()

        // 最後の点から開始
        let lastIndex = route.count - 1
        counter.update(coordinate: route[lastIndex], timestamp: timestamp)
        timestamp = timestamp.addingTimeInterval(10)

        // 最初の点に移動（スタート地点をまたぐ）
        counter.update(coordinate: route[0], timestamp: timestamp)
        timestamp = timestamp.addingTimeInterval(10)

        // 進行が巻き戻らず、前進している
        XCTAssertGreaterThan(counter.progress, 0)
    }

    func testIgnoreFarOffRoute() throws {
        let center = Coordinate(latitude: 35.685, longitude: 139.752)
        let route = makeCircularRoute(center: center, radiusMeters: 400, points: 36)

        var counter = LapCounter(referenceRoute: route, maxOffRoute: 40)

        var timestamp = Date()

        // ルート上の点で初期化
        counter.update(coordinate: route[0], timestamp: timestamp)
        timestamp = timestamp.addingTimeInterval(10)

        let progressBefore = counter.progress

        // ルートから遠く離れた点（無視されるべき）
        let farAway = Coordinate(latitude: 35.7, longitude: 139.8)
        counter.update(coordinate: farAway, timestamp: timestamp)
        timestamp = timestamp.addingTimeInterval(10)

        // 進行が変わっていない
        XCTAssertEqual(counter.progress, progressBefore, accuracy: 0.01)

        // 次の有効な点を更新すると、進みが失われていない
        counter.update(coordinate: route[1], timestamp: timestamp)
        XCTAssertGreaterThan(counter.progress, progressBefore)
    }

    func testTimeoutResetsPosition() throws {
        let center = Coordinate(latitude: 35.685, longitude: 139.752)
        let route = makeCircularRoute(center: center, radiusMeters: 400, points: 36)

        var counter = LapCounter(referenceRoute: route, timeoutSeconds: 10)

        var timestamp = Date()

        // 最初の点
        counter.update(coordinate: route[0], timestamp: timestamp)
        let progress1 = counter.progress

        // 10秒を超えて経過（タイムアウト）
        timestamp = timestamp.addingTimeInterval(15)

        // 次の点を更新
        counter.update(coordinate: route[10], timestamp: timestamp)

        // タイムアウト後は前回位置がリセットされるので、進行は更新されない
        // （2回目の更新で初期化される）
        XCTAssertEqual(counter.progress, progress1, accuracy: 0.01)
    }

    func testReverseDirection() throws {
        let center = Coordinate(latitude: 35.685, longitude: 139.752)
        let route = makeCircularRoute(center: center, radiusMeters: 400, points: 36)

        var counter = LapCounter(referenceRoute: route)

        var timestamp = Date()

        // 順方向に進む
        counter.update(coordinate: route[0], timestamp: timestamp)
        timestamp = timestamp.addingTimeInterval(10)
        counter.update(coordinate: route[10], timestamp: timestamp)
        timestamp = timestamp.addingTimeInterval(10)

        let progressForward = counter.progress

        // 逆方向に進む
        counter.update(coordinate: route[5], timestamp: timestamp)

        // 進行が減っている
        XCTAssertLessThan(counter.progress, progressForward)
    }
}
