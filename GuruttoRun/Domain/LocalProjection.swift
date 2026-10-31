import Foundation

/// 緯度経度をメートル単位の平面座標に変換する簡易投影
struct LocalProjection: Equatable, Sendable {
    /// 基準点（原点）
    let origin: Coordinate

    /// 緯度1度あたりのメートル数（およそ111km）
    private let metersPerLatitude: Double = 111_319.9

    /// 経度1度あたりのメートル数（緯度により変化）
    private let metersPerLongitude: Double

    /// 指定した基準点で投影を初期化
    init(origin: Coordinate) {
        self.origin = origin
        // 経度1度あたりのメートル数 = 緯度1度あたりのメートル数 × cos(緯度)
        let latitudeRadians = origin.latitude * .pi / 180.0
        self.metersPerLongitude = metersPerLatitude * cos(latitudeRadians)
    }

    /// 緯度経度をメートル平面座標に変換
    func project(_ coordinate: Coordinate) -> Point2D {
        let dx = (coordinate.longitude - origin.longitude) * metersPerLongitude
        let dy = (coordinate.latitude - origin.latitude) * metersPerLatitude
        return Point2D(x: dx, y: dy)
    }

    /// 2点間の距離（メートル）
    func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let pa = project(a)
        let pb = project(b)
        let dx = pb.x - pa.x
        let dy = pb.y - pa.y
        return sqrt(dx * dx + dy * dy)
    }
}
