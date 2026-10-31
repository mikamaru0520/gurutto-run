import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .run
        var run = RunFeature.State()
        var history = HistoryFeature.State()

        enum Tab: Equatable {
            case run
            case history
        }
    }

    enum Action: Sendable {
        case tabSelected(State.Tab)
        case run(RunFeature.Action)
        case history(HistoryFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.run, action: \.run) {
            RunFeature()
        }

        Scope(state: \.history, action: \.history) {
            HistoryFeature()
        }

        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case .run:
                return .none

            case .history:
                return .none
            }
        }
    }
}

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        WithPerceptionTracking {
            TabView(selection: Binding(
                get: { store.selectedTab },
                set: { store.send(.tabSelected($0)) }
            )) {
                RunView(store: store.scope(state: \.run, action: \.run))
                    .tabItem {
                        Label("計測", systemImage: "figure.run")
                    }
                    .tag(AppFeature.State.Tab.run)

                NavigationStack {
                    HistoryView(store: store.scope(state: \.history, action: \.history))
                }
                .tabItem {
                    Label("記録", systemImage: "list.bullet")
                }
                .tag(AppFeature.State.Tab.history)
            }
            .preferredColorScheme(.light)
        }
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
