import Foundation
import OSLog

/// アプリ全体で使用するLogger
extension Logger {
    /// HealthKit関連のログ
    static let healthKit = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.marotech.GuruttoRun", category: "HealthKit")

    /// Live Activity関連のログ
    static let liveActivity = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.marotech.GuruttoRun", category: "LiveActivity")

    /// Run機能関連のログ
    static let run = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.marotech.GuruttoRun", category: "Run")

    /// テスト環境のログ
    static let test = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.marotech.GuruttoRun", category: "Test")

    /// プレビュー環境のログ
    static let preview = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.marotech.GuruttoRun", category: "Preview")
}
