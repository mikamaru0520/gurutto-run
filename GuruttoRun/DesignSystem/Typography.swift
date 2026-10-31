import SwiftUI

// MARK: - Font Sizes

/// フォントサイズの定義（8pt グリッドベース）
enum FontSize {
    /// 12pt - キャプション
    static let xs: CGFloat = 12

    /// 14pt - 小さいテキスト
    static let sm: CGFloat = 14

    /// 16pt - 標準的なテキスト
    static let md: CGFloat = 16

    /// 20pt - やや大きいテキスト
    static let lg: CGFloat = 20

    /// 24pt - 大きいテキスト
    static let xl: CGFloat = 24

    /// 32pt - 見出し
    static let xxl: CGFloat = 32

    /// 48pt - 大きな見出し
    static let xxxl: CGFloat = 48

    /// 60pt - メインディスプレイ（距離など）
    static let display: CGFloat = 60

    /// 72pt - 超大型ディスプレイ
    static let giant: CGFloat = 72
}

// MARK: - Text Styles

extension Font {
    /// キャプションテキスト（12pt）
    static let caption = Font.system(size: FontSize.xs, design: .rounded)

    /// 小さいテキスト（14pt）
    static let bodySmall = Font.system(size: FontSize.sm, design: .rounded)

    /// 標準的なボディテキスト（16pt）
    static let bodyMedium = Font.system(size: FontSize.md, design: .rounded)

    /// 大きいボディテキスト（20pt）
    static let bodyLarge = Font.system(size: FontSize.lg, weight: .medium, design: .rounded)

    /// 小さい見出し（24pt）
    static let headingSmall = Font.system(size: FontSize.xl, weight: .bold, design: .rounded)

    /// 標準的な見出し（32pt）
    static let headingMedium = Font.system(size: FontSize.xxl, weight: .bold, design: .rounded)

    /// 大きい見出し（48pt）
    static let headingLarge = Font.system(size: FontSize.xxxl, weight: .bold, design: .rounded)

    /// メインディスプレイ（60pt） - 距離表示など
    static let displayMain = Font.system(size: FontSize.display, weight: .bold, design: .rounded)

    /// 超大型ディスプレイ（72pt）
    static let displayGiant = Font.system(size: FontSize.giant, weight: .bold, design: .rounded)
}

// MARK: - Dynamic Type Support

extension Font {
    /// キャプション（Dynamic Type対応）
    static let captionDynamic = Font.caption.weight(.regular)

    /// 小さいボディ（Dynamic Type対応）
    static let bodySmallDynamic = Font.body.weight(.regular)

    /// 標準的なボディ（Dynamic Type対応）
    static let bodyMediumDynamic = Font.body.weight(.regular)

    /// 大きいボディ（Dynamic Type対応）
    static let bodyLargeDynamic = Font.body.weight(.medium)

    /// 小さい見出し（Dynamic Type対応）
    static let headingSmallDynamic = Font.title3.weight(.bold)

    /// 標準的な見出し（Dynamic Type対応）
    static let headingMediumDynamic = Font.title2.weight(.bold)

    /// 大きい見出し（Dynamic Type対応）
    static let headingLargeDynamic = Font.title.weight(.bold)
}

// MARK: - Text Modifiers

extension View {
    /// キャプションスタイルを適用
    func captionStyle() -> some View {
        self
            .font(.caption)
            .foregroundColor(AppColors.textSecondary)
    }

    /// セカンダリテキストスタイルを適用
    func secondaryTextStyle() -> some View {
        self
            .font(.bodySmall)
            .foregroundColor(AppColors.textSecondary)
    }

    /// プライマリテキストスタイルを適用
    func primaryTextStyle() -> some View {
        self
            .font(.bodyMedium)
            .foregroundColor(AppColors.textPrimary)
    }

    /// 見出しスタイルを適用
    func headingStyle() -> some View {
        self
            .font(.headingMedium)
            .foregroundColor(AppColors.textPrimary)
    }

    /// メインディスプレイスタイルを適用
    func displayStyle() -> some View {
        self
            .font(.displayMain)
            .foregroundColor(AppColors.textPrimary)
    }
}
