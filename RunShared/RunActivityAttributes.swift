import ActivityKit
import Foundation

/// ランニング中の Live Activity の属性定義
public struct RunActivityAttributes: ActivityAttributes {
    /// 固定コンテンツ（開始時に設定、変更不可）
    public struct ContentState: Codable, Hashable, Sendable {
        /// 走行距離（メートル）
        public var distanceMeters: Double

        /// 経過時間（秒）
        public var elapsedSeconds: Int

        /// ペース（秒/km）- 0 の場合は "--'--\"" 表示
        public var paceSecondsPerKm: Double

        /// 周回数（皇居モードの場合のみ有効）
        public var laps: Double?

        /// 状態（running / paused）
        public var status: Status

        public enum Status: String, Codable, Sendable {
            case running
            case paused
        }

        public init(
            distanceMeters: Double,
            elapsedSeconds: Int,
            paceSecondsPerKm: Double,
            laps: Double?,
            status: Status
        ) {
            self.distanceMeters = distanceMeters
            self.elapsedSeconds = elapsedSeconds
            self.paceSecondsPerKm = paceSecondsPerKm
            self.laps = laps
            self.status = status
        }
    }

    /// モード（開始時に設定、変更不可）
    public var mode: Mode

    public enum Mode: String, Codable, Sendable {
        case imperialPalace  // 皇居モード
        case normal          // 通常モード

        public var displayName: String {
            switch self {
            case .imperialPalace:
                return "皇居モード"
            case .normal:
                return "通常モード"
            }
        }

        public var iconName: String {
            switch self {
            case .imperialPalace:
                return "arrow.triangle.2.circlepath"
            case .normal:
                return "figure.run"
            }
        }
    }

    public init(mode: Mode) {
        self.mode = mode
    }
}

// MARK: - Helper Extensions

public extension RunActivityAttributes.ContentState {
    /// 距離のフォーマット済み文字列（例: "5.2"）
    var distanceKm: String {
        String(format: "%.1f", distanceMeters / 1000.0)
    }

    /// タイムのフォーマット済み文字列（例: "25:34"）
    var timeFormatted: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let secs = elapsedSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    /// ペースのフォーマット済み文字列（例: "4'58\""）
    var paceFormatted: String {
        guard paceSecondsPerKm > 0 else { return "--'--\"" }
        let seconds = Int(paceSecondsPerKm)
        let minutes = seconds / 60
        let secs = seconds % 60
        return "\(minutes)'\(String(format: "%02d", secs))\""
    }

    /// 周回数のフォーマット済み文字列（例: "1.2"）
    var lapsFormatted: String? {
        guard let laps = laps else { return nil }
        return String(format: "%.1f", laps)
    }
}
