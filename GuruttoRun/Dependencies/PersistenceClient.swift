import ComposableArchitecture
import Foundation

/// 走行中の状態を永続化するクライアント（クラッシュ保護）
@DependencyClient
struct PersistenceClient: Sendable {
    var saveRunningState: @Sendable (RunningState) async throws -> Void
    var loadRunningState: @Sendable () async throws -> RunningState?
    var clearRunningState: @Sendable () async throws -> Void
}

/// 走行中の状態を保存するための構造体
struct RunningState: Codable, Equatable, Sendable {
    let distanceMeters: Double
    let elapsed: TimeInterval  // Duration は Codable でないため TimeInterval で保存
    let route: [Coordinate]
    let startDate: Date
    let mode: String  // "imperialPalace" or "normal"
}

extension PersistenceClient: DependencyKey {
    static let liveValue = PersistenceClient(
        saveRunningState: { state in
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: "running_state")
        },
        loadRunningState: {
            guard let data = UserDefaults.standard.data(forKey: "running_state") else {
                return nil
            }
            return try JSONDecoder().decode(RunningState.self, from: data)
        },
        clearRunningState: {
            UserDefaults.standard.removeObject(forKey: "running_state")
        }
    )

    static let testValue = PersistenceClient()
}

extension DependencyValues {
    var persistenceClient: PersistenceClient {
        get { self[PersistenceClient.self] }
        set { self[PersistenceClient.self] = newValue }
    }
}
