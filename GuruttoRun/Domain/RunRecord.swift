import Foundation

/// ランニング記録
struct RunRecord: Equatable, Sendable, Identifiable {
    var id: UUID
    var date: Date
    var distanceMeters: Double   // 実測距離
    var elapsed: Duration        // 経過時間
    var laps: Double             // 周回数（2.5周などの端数あり）
    var route: [Coordinate]      // ルート（ない場合は空配列）
    var source: Source           // 記録元

    /// 記録の出典
    enum Source: Equatable, Sendable {
        case guruttoRun          // このアプリで計測
        case otherApp(String)    // 他のアプリ（アプリ名）
    }

    /// ペース（秒/km）
    var paceSecondsPerKm: Double {
        guard distanceMeters > 0 else { return 0 }
        let distanceKm = distanceMeters / 1000.0
        let elapsedSeconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        return elapsedSeconds / distanceKm
    }

    /// ペースの文字列表現（例: "5'14\"/km"）
    var paceFormatted: String {
        // 距離が100m未満の場合はペースを表示しない
        guard distanceMeters >= 100 else { return "--'--\"" }

        let seconds = Int(paceSecondsPerKm)
        let minutes = seconds / 60
        let secs = seconds % 60
        return "\(minutes)'\(String(format: "%02d", secs))\"/km"
    }

    /// 周回数の文字列表現（例: "2.5周"）
    var lapsFormatted: String {
        String(format: "%.1f周", laps)
    }

    /// 皇居換算の周回数（皇居1周 = 5km として計算）
    var imperialPalaceEquivalent: Double {
        distanceMeters / 5000.0
    }

    /// 皇居換算の文字列表現（例: "皇居1.6周分"）
    var imperialPalaceFormatted: String {
        String(format: "皇居%.1f周分", imperialPalaceEquivalent)
    }
}
