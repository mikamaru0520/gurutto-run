import ComposableArchitecture
import UIKit
import Foundation

@DependencyClient
struct ShareClient: Sendable {
    /// Instagram が利用可能かチェック
    var canShareToInstagram: @Sendable () -> Bool = { false }

    /// Instagram Stories にシェア
    var shareToInstagramStories: @Sendable (_ backgroundPNG: Data) async -> Bool = { _ in false }
}

extension ShareClient: DependencyKey {
    static let liveValue: ShareClient = {
        ShareClient(
            canShareToInstagram: {
                // Facebook App ID を取得（開発中はプレースホルダーでも OK）
                let facebookAppID = Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String ?? "dev"

                guard let url = URL(string: "instagram-stories://share?source_application=\(facebookAppID)") else {
                    return false
                }

                return UIApplication.shared.canOpenURL(url)
            },
            shareToInstagramStories: { backgroundPNG in
                // Facebook App ID を取得（開発中はプレースホルダーでも OK）
                let facebookAppID = Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String ?? "dev"

                guard let url = URL(string: "instagram-stories://share?source_application=\(facebookAppID)") else {
                    return false
                }

                await MainActor.run {
                    // Pasteboard に画像を設定
                    let pasteboard = UIPasteboard.general
                    let pasteboardItems: [[String: Any]] = [
                        [
                            "com.instagram.sharedSticker.backgroundImage": backgroundPNG
                        ]
                    ]
                    pasteboard.items = pasteboardItems
                }

                // Instagram を開く
                // Swift 6 strict concurrency: UIApplication.open の options パラメータは非 Sendable
                // 実行時は MainActor で動作するため安全
                await Task { @MainActor in
                    UIApplication.shared.open(url)
                }.value

                return true
            }
        )
    }()

    static let testValue = ShareClient()

    static let previewValue = ShareClient(
        canShareToInstagram: { false },
        shareToInstagramStories: { _ in false }
    )
}

extension DependencyValues {
    var shareClient: ShareClient {
        get { self[ShareClient.self] }
        set { self[ShareClient.self] = newValue }
    }
}
