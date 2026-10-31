import SwiftUI

/// アプリ全体で使用する色の定義
enum AppColors {
    // MARK: - Primary Colors

    /// 皇居モードのメインカラー
    static let imperialPalace = Color(hex: "3D9B7E")

    /// 通常モードのメインカラー
    static let normal = Color(hex: "FF9F5A")

    // MARK: - Background Colors

    /// メイン背景色
    static let background = Color(hex: "F5F5F5")

    /// カード背景色
    static let cardBackground = Color.white

    // MARK: - Text Colors

    /// プライマリテキスト
    static let textPrimary = Color.black

    /// セカンダリテキスト
    static let textSecondary = Color.gray

    /// 薄いテキスト
    static let textTertiary = Color.gray.opacity(0.6)

    // MARK: - UI Elements

    /// ボーダー・区切り線
    static let border = Color.gray.opacity(0.15)

    /// 無効状態
    static let disabled = Color.gray.opacity(0.3)

    /// エラー
    static let error = Color.red

    /// 警告
    static let warning = Color.orange

    /// 成功
    static let success = Color.green

    // MARK: - Shadow

    /// シャドウカラー
    static let shadow = Color.black.opacity(0.05)
    static let shadowMedium = Color.black.opacity(0.08)
    static let shadowHeavy = Color.black.opacity(0.15)
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
