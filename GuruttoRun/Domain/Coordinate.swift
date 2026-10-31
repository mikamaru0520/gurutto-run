import Foundation

/// 緯度経度を表す座標
struct Coordinate: Equatable, Sendable, Codable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - Route Simplification

extension Array where Element == Coordinate {
    /// Douglas-Peucker アルゴリズムでルートを簡略化
    /// - Parameter epsilon: 許容誤差（メートル）。この値より小さい誤差の点は削除される
    /// - Returns: 簡略化されたルート
    func simplified(epsilon: Double) -> [Coordinate] {
        guard count > 2 else { return self }

        let first = self[0]
        let last = self[count - 1]

        // 投影を使って距離計算
        let projection = LocalProjection(origin: first)

        // Douglas-Peucker アルゴリズム
        return douglasPeucker(
            points: self,
            start: 0,
            end: count - 1,
            epsilon: epsilon,
            projection: projection
        )
    }

    private func douglasPeucker(
        points: [Coordinate],
        start: Int,
        end: Int,
        epsilon: Double,
        projection: LocalProjection
    ) -> [Coordinate] {
        // 始点と終点のみの場合
        if end - start <= 1 {
            return [points[start], points[end]]
        }

        // 始点と終点を結ぶ線分から最も離れた点を見つける
        var maxDistance = 0.0
        var maxIndex = start

        let startPoint = points[start]
        let endPoint = points[end]

        for i in (start + 1)..<end {
            let distance = perpendicularDistance(
                point: points[i],
                lineStart: startPoint,
                lineEnd: endPoint,
                projection: projection
            )

            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        // 最大距離が許容値より大きい場合、その点を保持して再帰
        if maxDistance > epsilon {
            // 左側を再帰的に簡略化
            let leftSegment = douglasPeucker(
                points: points,
                start: start,
                end: maxIndex,
                epsilon: epsilon,
                projection: projection
            )

            // 右側を再帰的に簡略化
            let rightSegment = douglasPeucker(
                points: points,
                start: maxIndex,
                end: end,
                epsilon: epsilon,
                projection: projection
            )

            // 結合（maxIndex の点が重複するので1つ削除）
            return leftSegment.dropLast() + rightSegment
        } else {
            // 許容値以下なら、始点と終点のみを返す
            return [points[start], points[end]]
        }
    }

    /// 点から線分への垂直距離を計算
    private func perpendicularDistance(
        point: Coordinate,
        lineStart: Coordinate,
        lineEnd: Coordinate,
        projection: LocalProjection
    ) -> Double {
        // ローカル座標系に変換
        let p = projection.project(point)
        let a = projection.project(lineStart)
        let b = projection.project(lineEnd)

        // ベクトル AB
        let abX = b.x - a.x
        let abY = b.y - a.y

        // ベクトル AB の長さの2乗
        let abLengthSquared = abX * abX + abY * abY

        // 線分が点の場合（始点と終点が同じ）
        if abLengthSquared == 0 {
            let dx = p.x - a.x
            let dy = p.y - a.y
            return sqrt(dx * dx + dy * dy)
        }

        // ベクトル AP
        let apX = p.x - a.x
        let apY = p.y - a.y

        // t = AP·AB / |AB|^2 (線分上の最近点のパラメータ)
        let t = max(0, min(1, (apX * abX + apY * abY) / abLengthSquared))

        // 線分上の最近点
        let nearestX = a.x + t * abX
        let nearestY = a.y + t * abY

        // 点から最近点への距離
        let dx = p.x - nearestX
        let dy = p.y - nearestY

        return sqrt(dx * dx + dy * dy)
    }
}
