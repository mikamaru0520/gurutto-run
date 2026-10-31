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
            // タブのコンテンツ
            Group {
                switch store.selectedTab {
                case .run:
                    RunView(store: store.scope(state: \.run, action: \.run))
                case .history:
                    NavigationStack {
                        HistoryView(store: store.scope(state: \.history, action: \.history))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // カスタムタブバー（ガラスモーフィズム）
                GlassTabBar(
                    selectedTab: store.selectedTab,
                    onTabSelected: { tab in
                        store.send(.tabSelected(tab))
                    }
                )
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.md)
            }
            .preferredColorScheme(.light)
        }
    }
}

// MARK: - Glass Tab Bar

struct GlassTabBar: View {
    let selectedTab: AppFeature.State.Tab
    let onTabSelected: (AppFeature.State.Tab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 計測タブ
            TabBarItem(
                icon: "figure.run",
                title: "計測",
                isSelected: selectedTab == .run
            ) {
                onTabSelected(.run)
            }

            Spacer()

            // 記録タブ
            TabBarItem(
                icon: "list.bullet",
                title: "記録",
                isSelected: selectedTab == .history
            ) {
                onTabSelected(.history)
            }
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(.ultraThinMaterial)
                .shadow(
                    color: Shadow.medium.color,
                    radius: Shadow.medium.radius,
                    x: Shadow.medium.x,
                    y: Shadow.medium.y
                )
        )
    }
}

struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: FontSize.lg, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)

                Text(title)
                    .font(.system(size: FontSize.xs, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
