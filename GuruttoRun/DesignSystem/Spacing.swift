import SwiftUI

/// 8pt グリッドシステムに基づくスペーシング定義
enum Spacing {
    /// 4pt - 最小のスペース
    static let xxs: CGFloat = 4

    /// 8pt - 小さいスペース
    static let xs: CGFloat = 8

    /// 12pt - やや小さいスペース
    static let sm: CGFloat = 12

    /// 16pt - 標準的なスペース
    static let md: CGFloat = 16

    /// 20pt - やや大きいスペース
    static let lg: CGFloat = 20

    /// 24pt - 大きいスペース
    static let xl: CGFloat = 24

    /// 32pt - とても大きいスペース
    static let xxl: CGFloat = 32

    /// 40pt - 非常に大きいスペース
    static let xxxl: CGFloat = 40

    /// 48pt - セクション間の余白
    static let section: CGFloat = 48
}

// MARK: - Radius (角丸)

enum Radius {
    /// 4pt - 小さな角丸
    static let xs: CGFloat = 4

    /// 8pt - 標準的な角丸
    static let sm: CGFloat = 8

    /// 12pt - やや大きい角丸
    static let md: CGFloat = 12

    /// 16pt - 大きい角丸
    static let lg: CGFloat = 16

    /// 20pt - とても大きい角丸（ボタンなど）
    static let xl: CGFloat = 20

    /// 完全な円形
    static let circle: CGFloat = .infinity
}

// MARK: - Shadow

enum Shadow {
    /// 軽いシャドウ
    static let light = (color: AppColors.shadow, radius: 2.0, x: 0.0, y: 1.0)

    /// 標準的なシャドウ
    static let medium = (color: AppColors.shadowMedium, radius: 4.0, x: 0.0, y: 2.0)

    /// 強いシャドウ
    static let heavy = (color: AppColors.shadowHeavy, radius: 8.0, x: 0.0, y: 4.0)
}

// MARK: - Icon Sizes

enum IconSize {
    /// 小さいアイコン
    static let sm: CGFloat = 16

    /// 標準的なアイコン
    static let md: CGFloat = 24

    /// 大きいアイコン
    static let lg: CGFloat = 32

    /// とても大きいアイコン
    static let xl: CGFloat = 48

    /// 巨大なアイコン
    static let xxl: CGFloat = 72
}

// MARK: - Button Sizes

enum ButtonSize {
    /// 小さいボタン
    static let sm: CGFloat = 40

    /// 標準的なボタン
    static let md: CGFloat = 48

    /// 大きいボタン
    static let lg: CGFloat = 80

    /// スタートボタンなど
    static let xl: CGFloat = 130

    /// プログレスリング
    static let progress: CGFloat = 160

    /// アイコンサークル
    static let iconCircle: CGFloat = 200
}
