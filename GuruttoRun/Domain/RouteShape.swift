import SwiftUI

/// ルート（座標列）を描画する Shape
struct RouteShape: Shape {
    let coordinates: [Coordinate]

    func path(in rect: CGRect) -> Path {
        guard coordinates.count >= 2 else { return Path() }

        // 座標の範囲を取得
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)

        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max() else {
            return Path()
        }

        // 緯度の補正（経度を cos(平均緯度) で補正）
        let avgLat = (minLat + maxLat) / 2
        let latRadians = avgLat * .pi / 180
        let lonScale = cos(latRadians)

        // スケールと範囲
        let latRange = maxLat - minLat
        let lonRange = (maxLon - minLon) * lonScale

        guard latRange > 0 || lonRange > 0 else { return Path() }

        // アスペクト比を保ちながら rect に収める
        let aspectRatio = lonRange / latRange
        let rectAspect = rect.width / rect.height

        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat

        if aspectRatio > rectAspect {
            // 横が長い
            scale = rect.width / lonRange
            offsetX = rect.minX
            offsetY = rect.minY + (rect.height - latRange * scale) / 2
        } else {
            // 縦が長い
            scale = rect.height / latRange
            offsetX = rect.minX + (rect.width - lonRange * scale) / 2
            offsetY = rect.minY
        }

        // パスを構築
        var path = Path()
        for (index, coord) in coordinates.enumerated() {
            let x = offsetX + (coord.longitude - minLon) * lonScale * scale
            let y = offsetY + (maxLat - coord.latitude) * scale  // Y軸は反転

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }

    /// スタート地点の座標を計算
    func startPointPosition(in size: CGSize, coordinate: Coordinate, allCoordinates: [Coordinate]) -> CGPoint {
        guard allCoordinates.count >= 2 else { return CGPoint(x: size.width / 2, y: size.height / 2) }

        let rect = CGRect(origin: .zero, size: size)

        // 座標の範囲を取得
        let latitudes = allCoordinates.map(\.latitude)
        let longitudes = allCoordinates.map(\.longitude)

        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max() else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }

        // 緯度の補正
        let avgLat = (minLat + maxLat) / 2
        let latRadians = avgLat * .pi / 180
        let lonScale = cos(latRadians)

        // スケールと範囲
        let latRange = maxLat - minLat
        let lonRange = (maxLon - minLon) * lonScale

        guard latRange > 0 || lonRange > 0 else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }

        // アスペクト比を保ちながら rect に収める
        let aspectRatio = lonRange / latRange
        let rectAspect = rect.width / rect.height

        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat

        if aspectRatio > rectAspect {
            scale = rect.width / lonRange
            offsetX = rect.minX
            offsetY = rect.minY + (rect.height - latRange * scale) / 2
        } else {
            scale = rect.height / latRange
            offsetX = rect.minX + (rect.width - lonRange * scale) / 2
            offsetY = rect.minY
        }

        // スタート地点の位置
        let x = offsetX + (coordinate.longitude - minLon) * lonScale * scale
        let y = offsetY + (maxLat - coordinate.latitude) * scale

        return CGPoint(x: x, y: y)
    }
}
