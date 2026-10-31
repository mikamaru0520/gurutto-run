import ActivityKit
import ComposableArchitecture
import Foundation
import RunShared

@DependencyClient
struct LiveActivityClient: Sendable {
    /// Live Activity を開始
    var start: @Sendable (RunActivityAttributes.Mode) async throws -> Void

    /// Live Activity を更新
    var update: @Sendable (
        _ distanceMeters: Double,
        _ elapsedSeconds: Int,
        _ paceSecondsPerKm: Double,
        _ laps: Double?,
        _ status: RunActivityAttributes.ContentState.Status
    ) async throws -> Void

    /// Live Activity を終了
    var end: @Sendable () async throws -> Void
}

extension LiveActivityClient: DependencyKey {
    static let liveValue = LiveActivityClient(
        start: { mode in
            // 既存の Activity があれば終了
            for activity in Activity<RunActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            // ActivityKit が利用可能かチェック
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                throw LiveActivityError.notAuthorized
            }

            // 初期状態
            let initialState = RunActivityAttributes.ContentState(
                distanceMeters: 0,
                elapsedSeconds: 0,
                paceSecondsPerKm: 0,
                laps: mode == .imperialPalace ? 0 : nil,
                status: .running
            )

            // Activity を開始
            let attributes = RunActivityAttributes(mode: mode)
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
        },
        update: { distanceMeters, elapsedSeconds, paceSecondsPerKm, laps, status in
            guard let activity = Activity<RunActivityAttributes>.activities.first else {
                return
            }

            let newState = RunActivityAttributes.ContentState(
                distanceMeters: distanceMeters,
                elapsedSeconds: elapsedSeconds,
                paceSecondsPerKm: paceSecondsPerKm,
                laps: laps,
                status: status
            )

            await activity.update(
                ActivityContent(state: newState, staleDate: nil)
            )
        },
        end: {
            guard let activity = Activity<RunActivityAttributes>.activities.first else {
                return
            }

            // 最終状態を設定してから終了
            let finalState = RunActivityAttributes.ContentState(
                distanceMeters: activity.content.state.distanceMeters,
                elapsedSeconds: activity.content.state.elapsedSeconds,
                paceSecondsPerKm: activity.content.state.paceSecondsPerKm,
                laps: activity.content.state.laps,
                status: .paused
            )

            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .default
            )
        }
    )

    static let testValue = LiveActivityClient()

    static let previewValue = LiveActivityClient(
        start: { _ in },
        update: { _, _, _, _, _ in },
        end: { }
    )
}

extension DependencyValues {
    var liveActivityClient: LiveActivityClient {
        get { self[LiveActivityClient.self] }
        set { self[LiveActivityClient.self] = newValue }
    }
}

enum LiveActivityError: Error {
    case notAuthorized
}
