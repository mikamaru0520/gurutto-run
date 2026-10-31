import SwiftUI

/// シェアカード（写真背景）
struct ShareCardPhotoView: View {
    let record: RunRecord
    let photoData: Data

    // カラーパレット
    private let textColor = Color.white
    private let overlayColor = Color(red: 10/255, green: 16/255, blue: 26/255).opacity(0.72)
    private let accentColor = Color(red: 127/255, green: 224/255, blue: 196/255)

    var body: some View {
        ZStack {
            // 背景写真
            if let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 360, height: 640)
                    .clipped()
            }

            // コンテンツ
            VStack(spacing: 0) {
                // 上部: アプリ名 + 日付
                HStack {
                    Text("ぐるっとらん")
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .tracking(2)
                        .foregroundStyle(textColor)

                    Spacer()

                    Text(formatDate(record.date))
                        .font(.system(size: 13, design: .default))
                        .foregroundStyle(textColor)
                }
                .padding(.top, 40)
                .padding(.horizontal, 28)

                Spacer()

                // 下部の帯
                HStack(spacing: 16) {
                    // ルート図（小）
                    if !record.route.isEmpty {
                        ZStack {
                            // ルートの線
                            RouteShape(coordinates: record.route)
                                .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                            // スタート地点のマーカー
                            GeometryReader { geometry in
                                if let startCoord = record.route.first {
                                    let position = RouteShape(coordinates: record.route)
                                        .startPointPosition(in: geometry.size, coordinate: startCoord, allCoordinates: record.route)
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 8, height: 8)
                                        .overlay(
                                            Circle()
                                                .stroke(accentColor, lineWidth: 1.5)
                                        )
                                        .position(position)
                                }
                            }
                        }
                        .frame(width: 72, height: 86)
                    }

                    // 距離と詳細
                    VStack(alignment: .leading, spacing: 8) {
                        // 距離
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.2f", record.distanceMeters / 1000.0))
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundStyle(textColor)

                            Text("km")
                                .font(.system(size: 18, design: .rounded))
                                .foregroundStyle(accentColor)
                        }

                        // 皇居換算
                        Text(record.imperialPalaceFormatted)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(textColor.opacity(0.7))

                        // タイム / ペース / 周回
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("タイム")
                                    .font(.system(size: 10))
                                    .foregroundStyle(textColor.opacity(0.7))
                                Text(formatDuration(record.elapsed))
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .foregroundStyle(textColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("ペース")
                                    .font(.system(size: 10))
                                    .foregroundStyle(textColor.opacity(0.7))
                                Text(record.paceFormatted)
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .foregroundStyle(textColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("周回")
                                    .font(.system(size: 10))
                                    .foregroundStyle(textColor.opacity(0.7))
                                Text(record.lapsFormatted)
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .foregroundStyle(textColor)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.top, 24)
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
                .background(overlayColor)
            }
        }
        .frame(width: 360, height: 640)
        .clipped()
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
    ShareCardPhotoView(
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
        ),
        photoData: Data()  // ダミー
    )
}
