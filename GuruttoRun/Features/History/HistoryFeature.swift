import ComposableArchitecture
import Foundation

@Reducer
struct HistoryFeature {
    @ObservableState
    struct State: Equatable {
        var records: [RunRecord] = []
        var isLoading: Bool = false
        var selectedRecord: RunRecord?
    }

    enum Action: Sendable {
        case onAppear
        case recordsLoaded([RunRecord])
        case recordTapped(RunRecord)
        case shareRecordUpdated(RunRecord?)
    }

    @Dependency(\.healthKitClient) var healthKitClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true

                return .run { send in
                    let records = try await healthKitClient.fetchWorkouts(50)
                    await send(.recordsLoaded(records))
                }

            case let .recordsLoaded(records):
                state.records = records
                state.isLoading = false
                return .none

            case let .recordTapped(record):
                state.selectedRecord = record
                return .none

            case let .shareRecordUpdated(record):
                state.selectedRecord = record
                return .none
            }
        }
    }
}
