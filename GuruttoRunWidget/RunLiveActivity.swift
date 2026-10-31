import ActivityKit
import SwiftUI
import WidgetKit
import RunShared

/// ランニング中の Live Activity
struct RunLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { context in
            // ロック画面の表示
            LockScreenView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island の表示
            DynamicIsland {
                // Expanded（長押し時の展開表示）
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                // Compact Leading（左側の常時表示）
                CompactLeadingView(context: context)
            } compactTrailing: {
                // Compact Trailing（右側の常時表示）
                CompactTrailingView(context: context)
            } minimal: {
                // Minimal（端に追いやられた時の表示）
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<RunActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // ヘッダー（モード表示）
            HStack {
                Image(systemName: context.attributes.mode.iconName)
                    .font(.caption.weight(.semibold))
                Text(context.attributes.mode.displayName)
                    .font(.caption.weight(.semibold))
                Spacer()
                if context.state.status == .paused {
                    Text("一時停止中")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }

            // メイン情報
            HStack(spacing: 20) {
                // 距離
                VStack(alignment: .leading, spacing: 4) {
                    Text("距離")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(context.state.distanceKm)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("km")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // タイム
                VStack(alignment: .trailing, spacing: 4) {
                    Text("タイム")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(context.state.timeFormatted)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                }

                // ペース
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ペース")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(context.state.paceFormatted)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                    + Text("/km")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // 周回数（皇居モードのみ）
            if let lapsFormatted = context.state.lapsFormatted {
                HStack {
                    Text("周回")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(lapsFormatted)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    + Text("周")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .activityBackgroundTint(Color(red: 0.24, green: 0.61, blue: 0.49).opacity(0.15))
        .activitySystemActionForegroundColor(Color(red: 0.24, green: 0.61, blue: 0.49))
    }
}

// MARK: - Dynamic Island - Expanded Views

struct ExpandedLeadingView: View {
    let context: ActivityViewContext<RunActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("距離")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(context.state.distanceKm)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("km")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ExpandedTrailingView: View {
    let context: ActivityViewContext<RunActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("タイム")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(context.state.timeFormatted)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
        }
    }
}

struct ExpandedBottomView: View {
    let context: ActivityViewContext<RunActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // ペース
            VStack(spacing: 2) {
                Text("ペース")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(context.state.paceFormatted)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                + Text("/km")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // 周回（皇居モードのみ）
            if let lapsFormatted = context.state.lapsFormatted {
                Divider()
                    .frame(height: 20)
                VStack(spacing: 2) {
                    Text("周回")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(lapsFormatted)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    + Text("周")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // 状態表示
            if context.state.status == .paused {
                Text("一時停止")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Dynamic Island - Compact Views

struct CompactLeadingView: View {
    let context: ActivityViewContext<RunActivityAttributes>

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: context.attributes.mode.iconName)
                .font(.caption2)
            Text(context.state.distanceKm)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Text("km")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

struct CompactTrailingView: View {
    let context: ActivityViewContext<RunActivityAttributes>

    var body: some View {
        Text(context.state.timeFormatted)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .monospacedDigit()
    }
}

// MARK: - Dynamic Island - Minimal View

struct MinimalView: View {
    let context: ActivityViewContext<RunActivityAttributes>

    var body: some View {
        Image(systemName: context.attributes.mode.iconName)
            .font(.caption2)
    }
}

// MARK: - Widget Bundle

@main
struct GuruttoRunWidgetBundle: WidgetBundle {
    var body: some Widget {
        RunLiveActivity()
    }
}
