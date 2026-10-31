import Foundation

/// 平面座標上の点
struct Point2D: Equatable, Sendable {
    var x: Double
    var y: Double
}

/// 周回カウンター
/// 基準ルートに対して、現在位置から周回数を計算する
struct LapCounter: Equatable, Sendable {
    /// 基準ルート上の点（メートル平面座標）
    private let routePoints: [Point2D]

    /// 各点までの累積距離
    private let cumulativeDistances: [Double]

    /// ルート全長（メートル）
    let totalLength: Double

    /// ルートから許容する最大距離（メートル）
    let maxOffRoute: Double

    /// タイムアウト時間（秒）- この時間以上空いたら前回位置をリセット
    let timeoutSeconds: Double

    /// 投影用オブジェクト
    private let projection: LocalProjection

    /// 現在の進行度（メートル）
    private(set) var progress: Double = 0

    /// 前回の有効な位置（ルート上の位置、メートル）
    private var lastPosition: Double? = nil

    /// 前回の有効な更新時刻
    private var lastUpdateTime: Date? = nil

    /// 周回数
    var laps: Double {
        guard totalLength > 0 else { return 0 }
        return progress / totalLength
    }

    /// 基準ルートから初期化
    init(
        referenceRoute: [Coordinate],
        maxOffRoute: Double = 40.0,
        timeoutSeconds: Double = 180.0
    ) {
        precondition(!referenceRoute.isEmpty, "Reference route must not be empty")

        self.maxOffRoute = maxOffRoute
        self.timeoutSeconds = timeoutSeconds

        // ルートの中心を原点とする投影を作成
        let avgLat = referenceRoute.map(\.latitude).reduce(0, +) / Double(referenceRoute.count)
        let avgLon = referenceRoute.map(\.longitude).reduce(0, +) / Double(referenceRoute.count)
        let projection = LocalProjection(origin: Coordinate(latitude: avgLat, longitude: avgLon))

        // ルートをメートル平面座標に変換
        let routePoints = referenceRoute.map { projection.project($0) }

        // 累積距離を計算
        var cumDist: [Double] = [0]
        var total: Double = 0
        for i in 1..<routePoints.count {
            let p0 = routePoints[i - 1]
            let p1 = routePoints[i]
            let dx = p1.x - p0.x
            let dy = p1.y - p0.y
            let dist = sqrt(dx * dx + dy * dy)
            total += dist
            cumDist.append(total)
        }
        // 最後の点から最初の点への距離も加える（閉じたループ）
        let pLast = routePoints[routePoints.count - 1]
        let pFirst = routePoints[0]
        let dxClose = pFirst.x - pLast.x
        let dyClose = pFirst.y - pLast.y
        let distClose = sqrt(dxClose * dxClose + dyClose * dyClose)
        total += distClose

        // プロパティに代入
        self.projection = projection
        self.routePoints = routePoints
        self.cumulativeDistances = cumDist
        self.totalLength = total
    }

    /// 新しい位置を更新（mutating）
    mutating func update(coordinate: Coordinate, timestamp: Date) {
        // タイムアウトチェック
        if let lastTime = lastUpdateTime, timestamp.timeIntervalSince(lastTime) > timeoutSeconds {
            // 前回位置をリセット
            lastPosition = nil
            lastUpdateTime = nil
        }

        // ルート上への投影
        let point = projection.project(coordinate)
        guard let (position, distance) = projectOntoRoute(point: point) else {
            // 投影できない場合（ルートが空など）
            return
        }

        // ルートから離れすぎている場合は無視（ただし前回位置はリセットしない）
        guard distance <= maxOffRoute else {
            return
        }

        // 前回位置がない場合は初期化
        guard let prevPosition = lastPosition else {
            lastPosition = position
            lastUpdateTime = timestamp
            return
        }

        // 差分を計算
        var delta = position - prevPosition

        // スタート地点またぎの補正
        if delta > totalLength / 2 {
            delta -= totalLength
        } else if delta < -totalLength / 2 {
            delta += totalLength
        }

        // 進行度を更新
        progress += delta
        lastPosition = position
        lastUpdateTime = timestamp
    }

    /// 点をルート上に投影し、ルート上の位置（0..<totalLength）とルートからの距離を返す
    private func projectOntoRoute(point: Point2D) -> (position: Double, distance: Double)? {
        guard !routePoints.isEmpty else { return nil }

        var minDistance = Double.infinity
        var bestPosition: Double = 0

        // 各セグメントに対して投影を試みる
        for i in 0..<routePoints.count {
            let p0 = routePoints[i]
            let p1 = routePoints[(i + 1) % routePoints.count]
            let segmentStart = cumulativeDistances[i]
            let segmentEnd: Double
            if i == routePoints.count - 1 {
                // 最後のセグメント（閉じる）
                segmentEnd = totalLength
            } else {
                segmentEnd = cumulativeDistances[i + 1]
            }
            let segmentLength = segmentEnd - segmentStart

            // セグメント上への投影
            let (projectedPosition, distance) = projectOntoSegment(
                point: point,
                segmentStart: p0,
                segmentEnd: p1,
                segmentLength: segmentLength
            )

            if distance < minDistance {
                minDistance = distance
                bestPosition = segmentStart + projectedPosition
            }
        }

        return (position: bestPosition, distance: minDistance)
    }

    /// 点を線分上に投影し、線分の開始点からの位置（0..<segmentLength）と距離を返す
    private func projectOntoSegment(
        point: Point2D,
        segmentStart: Point2D,
        segmentEnd: Point2D,
        segmentLength: Double
    ) -> (position: Double, distance: Double) {
        guard segmentLength > 0 else {
            // セグメントの長さが0の場合は始点との距離
            let dx = point.x - segmentStart.x
            let dy = point.y - segmentStart.y
            return (position: 0, distance: sqrt(dx * dx + dy * dy))
        }

        // ベクトル計算
        let vx = segmentEnd.x - segmentStart.x
        let vy = segmentEnd.y - segmentStart.y
        let wx = point.x - segmentStart.x
        let wy = point.y - segmentStart.y

        // 内積
        let dot = vx * wx + vy * wy
        let t = max(0, min(1, dot / (segmentLength * segmentLength)))

        // 投影点
        let projX = segmentStart.x + t * vx
        let projY = segmentStart.y + t * vy

        // 距離
        let dx = point.x - projX
        let dy = point.y - projY
        let distance = sqrt(dx * dx + dy * dy)

        return (position: t * segmentLength, distance: distance)
    }

    /// リセット
    mutating func reset() {
        progress = 0
        lastPosition = nil
        lastUpdateTime = nil
    }
}
