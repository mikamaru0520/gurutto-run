import ComposableArchitecture
import CoreLocation
import Foundation

@DependencyClient
struct LocationClient: Sendable {
    /// 位置情報の更新ストリーム
    var updates: @Sendable () -> AsyncStream<CLLocation> = { .finished }

    /// バックグラウンドセッションの開始
    var startBackgroundSession: @Sendable () async -> Void

    /// バックグラウンドセッションの終了
    var stopBackgroundSession: @Sendable () async -> Void
}

extension LocationClient: DependencyKey {
    static let liveValue: LocationClient = {
        let session = BackgroundSessionManager()

        return LocationClient(
            updates: {
                AsyncStream { continuation in
                    let task = Task {
                        let updates = CLLocationUpdate.liveUpdates()
                        for try await update in updates {
                            guard let location = update.location else { continue }
                            continuation.yield(location)
                        }
                        continuation.finish()
                    }

                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                }
            },
            startBackgroundSession: {
                await session.start()
            },
            stopBackgroundSession: {
                await session.stop()
            }
        )
    }()

    static let testValue = LocationClient()

    static let previewValue = LocationClient(
        updates: {
            // プレビュー用のダミーデータ
            AsyncStream { continuation in
                Task {
                    for i in 0..<100 {
                        let location = CLLocation(
                            latitude: 35.685 + Double(i) * 0.0001,
                            longitude: 139.752 + Double(i) * 0.0001
                        )
                        continuation.yield(location)
                        try? await Task.sleep(for: .seconds(1))
                    }
                    continuation.finish()
                }
            }
        },
        startBackgroundSession: {},
        stopBackgroundSession: {}
    )
}

extension DependencyValues {
    var locationClient: LocationClient {
        get { self[LocationClient.self] }
        set { self[LocationClient.self] = newValue }
    }
}

/// バックグラウンドセッション管理
private actor BackgroundSessionManager {
    private var session: CLBackgroundActivitySession?

    func start() {
        guard session == nil else { return }
        session = CLBackgroundActivitySession()
    }

    func stop() {
        session?.invalidate()
        session = nil
    }
}
