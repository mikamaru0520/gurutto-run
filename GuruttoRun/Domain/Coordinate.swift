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
