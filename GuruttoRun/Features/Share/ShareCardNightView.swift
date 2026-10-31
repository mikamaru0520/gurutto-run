import SwiftUI

/// シェアカード（ナイト - 写真なし）
struct ShareCardNightView: View {
    let record: RunRecord

    // カラーパレット
    private let backgroundColor = Color(red: 15/255, green: 26/255, blue: 43/255)
    private let textColor = Color(red: 242/255, green: 244/255, blue: 247/255)
    private let secondaryTextColor = Color(red: 169/255, green: 180/255, blue: 196/255)
    private let accentColor = Color(red: 127/255, green: 224/255, blue: 196/255)
    private let lineColor = Color(red: 42/255, green: 58/255, blue: 82/255)

    var body: some View {
        ZStack {
            // 背景
            backgroundColor

            VStack(spacing: 0) {
                // 上段: アプリ名 + 日付
                HStack {
                    Text("ぐるっとらん")
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .tracking(2)
                        .foregroundStyle(textColor)

                    Spacer()

                    Text(formatDate(record.date))
                        .font(.system(size: 13, design: .default))
                        .foregroundStyle(secondaryTextColor)
                }
                .padding(.top, 40)
                .padding(.horizontal, 28)

                Spacer()

                // 中段: ルート図
                if !record.route.isEmpty {
                    ZStack {
                        // ルートの線
                        RouteShape(coordinates: record.route)
                            .stroke(accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

                        // スタート地点のマーカー
                        GeometryReader { geometry in
                            if let startCoord = record.route.first {
                                let position = RouteShape(coordinates: record.route)
                                    .startPointPosition(in: geometry.size, coordinate: startCoord, allCoordinates: record.route)
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(accentColor, lineWidth: 2)
                                    )
                                    .position(position)
                            }
                        }
                    }
                    .frame(width: 200, height: 200)
                    .padding()
                }

                Spacer()

                // 下段: 距離（大きく）
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.2f", record.distanceMeters / 1000.0))
                            .font(.system(size: 88, weight: .bold, design: .rounded))
                            .foregroundStyle(textColor)

                        Text("km")
                            .font(.system(size: 28, design: .rounded))
                            .foregroundStyle(accentColor)
                    }

                    Text(record.imperialPalaceFormatted)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                }
                .padding(.bottom, 24)

                // 罫線
                Rectangle()
                    .fill(lineColor)
                    .frame(height: 1)
                    .padding(.horizontal, 28)

                // 最下段: タイム / ペース / 周回
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("タイム")
                            .font(.system(size: 11))
                            .foregroundStyle(secondaryTextColor)
                        Text(formatDuration(record.elapsed))
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                            .foregroundStyle(textColor)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("ペース")
                            .font(.system(size: 11))
                            .foregroundStyle(secondaryTextColor)
                        Text(record.paceFormatted)
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                            .foregroundStyle(textColor)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("周回")
                            .font(.system(size: 11))
                            .foregroundStyle(secondaryTextColor)
                        Text(record.lapsFormatted)
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                            .foregroundStyle(textColor)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
            }
        }
        .frame(width: 360, height: 640)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: Duration) -> String {
        let seconds = duration.components.seconds
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

#Preview {
    ShareCardNightView(
        record: RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5123.4,
            elapsed: .seconds(1534),
            laps: 1.0,
            route: [
                Coordinate(latitude: 35.685, longitude: 139.752),
                Coordinate(latitude: 35.686, longitude: 139.753),
                Coordinate(latitude: 35.687, longitude: 139.752),
                Coordinate(latitude: 35.686, longitude: 139.751),
            ],
            source: .guruttoRun
        )
    )
}
