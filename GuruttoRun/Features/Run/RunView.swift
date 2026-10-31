import SwiftUI
import ComposableArchitecture

struct RunView: View {
    let store: StoreOf<RunFeature>

    var body: some View {
        WithPerceptionTracking {
            ZStack {
                // 背景
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // モード切替
                    ModeSwitcher(
                        selectedMode: store.mode,
                        isRunning: store.status != .idle,
                        onModeChanged: { mode in
                            store.send(.modeToggled(mode))
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top)

                    // 計測中は切替不可メッセージ
                    if store.status != .idle {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                            Text("計測中はモードを切り替えできません")
                                .font(.caption)
                        }
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.top, Spacing.xs)
                    }

                    Spacer()

                    // メイン表示（モードと状態によって切り替え）
                    Group {
                        if store.status == .idle {
                            IdleView(mode: store.mode)
                        } else if store.mode == .imperialPalace {
                            ImperialPalaceModeRunningView(
                                distanceMeters: store.distanceMeters,
                                laps: store.laps,
                                elapsed: store.elapsed
                            )
                        } else {
                            NormalModeRunningView(
                                distanceMeters: store.distanceMeters,
                                elapsed: store.elapsed
                            )
                        }
                    }

                    Spacer()

                    // タイム・ペース（計測中のみ）
                    if store.status != .idle {
                        TimeAndPaceView(
                            elapsed: store.elapsed,
                            pace: calculatePace(distance: store.distanceMeters, elapsed: store.elapsed)
                        )
                        .padding(.horizontal, Spacing.xxl)
                        .padding(.bottom, Spacing.xl)
                    }

                    // ボタン
                    ActionButtons(
                        status: store.status,
                        mode: store.mode,
                        onStartTapped: { store.send(.startTapped) },
                        onPauseTapped: { store.send(.pauseTapped) },
                        onResumeTapped: { store.send(.resumeTapped) },
                        onFinishTapped: { store.send(.finishTapped) }
                    )
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .sheet(item: Binding(
                get: { store.shareRecord },
                set: { store.send(.shareRecordUpdated($0)) }
            )) { record in
                ShareView(
                    store: Store(initialState: ShareFeature.State(record: record)) {
                        ShareFeature()
                    }
                )
            }
            // 皇居付近提案
            .alert("皇居の近くにいるようです", isPresented: Binding(
                get: { store.showImperialPalaceSuggestion },
                set: { if !$0 { store.send(.dismissImperialPalaceSuggestion) } }
            )) {
                Button("皇居モードにする") {
                    store.send(.acceptImperialPalaceSuggestion)
                }
                Button("このまま", role: .cancel) {
                    store.send(.dismissImperialPalaceSuggestion)
                }
            } message: {
                Text("皇居モードにすると、周回を自動でカウントします。")
            }
        }
    }

    private func calculatePace(distance: Double, elapsed: Duration) -> String {
        guard distance >= 100 else { return "--'--\"" }
        let distanceKm = distance / 1000.0
        let elapsedSeconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let paceSecondsPerKm = elapsedSeconds / distanceKm
        let seconds = Int(paceSecondsPerKm)
        let minutes = seconds / 60
        let secs = seconds % 60
        return "\(minutes)'\(String(format: "%02d", secs))\""
    }
}

// MARK: - モード切替

struct ModeSwitcher: View {
    let selectedMode: RunFeature.State.Mode
    let isRunning: Bool
    let onModeChanged: (RunFeature.State.Mode) -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            // 皇居モード
            Button {
                guard !isRunning else { return }
                onModeChanged(.imperialPalace)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold))
                    Text("皇居")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(selectedMode == .imperialPalace ? AppColors.cardBackground : AppColors.imperialPalace)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(selectedMode == .imperialPalace ? AppColors.imperialPalace : AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                .shadow(color: Shadow.light.color, radius: Shadow.light.radius, x: Shadow.light.x, y: Shadow.light.y)
            }
            .disabled(isRunning)

            // 通常モード
            Button {
                guard !isRunning else { return }
                onModeChanged(.normal)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.caption.weight(.semibold))
                    Text("通常")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(selectedMode == .normal ? AppColors.cardBackground : AppColors.normal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(selectedMode == .normal ? AppColors.normal : AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                .shadow(color: Shadow.light.color, radius: Shadow.light.radius, x: Shadow.light.x, y: Shadow.light.y)
            }
            .disabled(isRunning)
        }
        .frame(height: ButtonSize.md)
    }
}

// MARK: - Idle View

struct IdleView: View {
    let mode: RunFeature.State.Mode

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            // アイコン
            ZStack {
                Circle()
                    .fill(AppColors.cardBackground)
                    .frame(width: ButtonSize.iconCircle, height: ButtonSize.iconCircle)
                    .shadow(color: Shadow.medium.color, radius: Shadow.medium.radius, x: Shadow.medium.x, y: Shadow.medium.y)

                Image(systemName: mode == .imperialPalace ? "arrow.triangle.2.circlepath" : "figure.run")
                    .font(.system(size: IconSize.xxl))
                    .foregroundStyle(mode == .imperialPalace ? AppColors.imperialPalace : AppColors.normal)
            }

            // モード名と説明
            VStack(spacing: Spacing.xs) {
                Text(mode == .imperialPalace ? "皇居モード" : "通常モード")
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)

                Text(mode == .imperialPalace ? "皇居を走るとき用" : "近所のコースや旅先で")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            // 特徴
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if mode == .imperialPalace {
                    FeatureRow(text: "周回を自動でカウント", color: AppColors.imperialPalace)
                    FeatureRow(text: "どこから走り始めても1周で1カウント", color: AppColors.imperialPalace)
                    FeatureRow(text: "「2.5周」のような実測の周回数を表示", color: AppColors.imperialPalace)
                } else {
                    FeatureRow(text: "周回カウントなし（距離のみ計測）", color: AppColors.normal)
                    FeatureRow(text: "距離を「皇居○周分」に換算して表示", color: AppColors.normal)
                    FeatureRow(text: "GPS が弱い場所でも使いやすく、電池にもやさしい", color: AppColors.normal)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .shadow(color: Shadow.medium.color, radius: Shadow.medium.radius, x: Shadow.medium.x, y: Shadow.medium.y)
            .padding(.horizontal, Spacing.xxl)
        }
    }
}

struct FeatureRow: View {
    let text: String
    var color: Color = AppColors.imperialPalace

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .padding(.top, 7)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 皇居モード計測中

struct ImperialPalaceModeRunningView: View {
    let distanceMeters: Double
    let laps: Double
    let elapsed: Duration

    var body: some View {
        VStack(spacing: Spacing.xl) {
            // 距離
            VStack(spacing: Spacing.xxs) {
                Text("距離")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Text(String(format: "%.1f", distanceMeters / 1000.0))
                        .font(.system(size: FontSize.display, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("km")
                        .font(.title2)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            // 周回（円形プログレス）
            ZStack {
                Circle()
                    .stroke(AppColors.border, lineWidth: Spacing.sm)
                    .frame(width: ButtonSize.progress, height: ButtonSize.progress)

                Circle()
                    .trim(from: 0, to: laps.truncatingRemainder(dividingBy: 1))
                    .stroke(
                        AppColors.imperialPalace,
                        style: StrokeStyle(lineWidth: Spacing.sm, lineCap: .round)
                    )
                    .frame(width: ButtonSize.progress, height: ButtonSize.progress)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: Spacing.xxs) {
                    Text(String(format: "%.1f", laps))
                        .font(.system(size: FontSize.xxxl, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("周")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("実測カウント")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                }
            }

            // 現在の周の進捗
            if laps >= 1 {
                Text("\(Int(laps) + 1)周目・リングは今の周の進み具合")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.xxl)
    }
}

// MARK: - 通常モード計測中

struct NormalModeRunningView: View {
    let distanceMeters: Double
    let elapsed: Duration

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            // 距離
            VStack(spacing: Spacing.xxs) {
                Text("距離")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Text(String(format: "%.1f", distanceMeters / 1000.0))
                        .font(.system(size: FontSize.display, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("km")
                        .font(.title2)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            // 皇居換算カード
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("皇居")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer()

                    Text("換算")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                        .background(AppColors.textSecondary.opacity(0.1))
                        .clipShape(Capsule())
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", distanceMeters / 5000.0))
                        .font(.system(size: FontSize.xl, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("周分")
                        .font(.title3)
                        .foregroundStyle(AppColors.textSecondary)
                }

                // プログレスバー
                let progress = (distanceMeters / 5000.0).truncatingRemainder(dividingBy: 1)
                HStack(spacing: Spacing.xs) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: Radius.xs)
                                .fill(AppColors.border)
                                .frame(height: Spacing.xs)

                            RoundedRectangle(cornerRadius: Radius.xs)
                                .fill(AppColors.normal)
                                .frame(width: geometry.size.width * progress, height: Spacing.xs)
                        }
                    }
                    .frame(height: Spacing.xs)

                    RoundedRectangle(cornerRadius: Radius.xs)
                        .fill(AppColors.textSecondary.opacity(0.2))
                        .frame(width: 60, height: Spacing.xs)
                }

                Text("皇居1周の実測距離で換算しています")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(Spacing.lg)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .shadow(color: Shadow.medium.color, radius: Shadow.medium.radius, x: Shadow.medium.x, y: Shadow.medium.y)
            .padding(.horizontal, Spacing.xxl)
        }
    }
}

// MARK: - タイム・ペース

struct TimeAndPaceView: View {
    let elapsed: Duration
    let pace: String

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: Spacing.xxs) {
                Text("タイム")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text(formatDuration(elapsed))
                    .font(.system(size: FontSize.lg + 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: Spacing.xxs) {
                Text("ペース")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text(pace)
                    .font(.system(size: FontSize.lg + 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                + Text("/km")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Spacing.md)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .shadow(color: Shadow.medium.color, radius: Shadow.medium.radius, x: Shadow.medium.x, y: Shadow.medium.y)
    }

    private func formatDuration(_ duration: Duration) -> String {
        let seconds = duration.components.seconds
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - アクションボタン

struct ActionButtons: View {
    let status: RunFeature.State.Status
    let mode: RunFeature.State.Mode
    let onStartTapped: () -> Void
    let onPauseTapped: () -> Void
    let onResumeTapped: () -> Void
    let onFinishTapped: () -> Void

    var body: some View {
        Group {
            switch status {
            case .idle:
                Button(action: onStartTapped) {
                    Text("スタート")
                        .font(.system(size: FontSize.md + 2, weight: .bold))
                        .foregroundStyle(AppColors.cardBackground)
                        .frame(width: ButtonSize.xl, height: ButtonSize.xl)
                        .background(mode == .imperialPalace ? AppColors.imperialPalace : AppColors.normal)
                        .clipShape(Circle())
                        .shadow(color: Shadow.heavy.color, radius: Shadow.heavy.radius, x: Shadow.heavy.x, y: Shadow.heavy.y)
                }

            case .running:
                HStack(spacing: Spacing.xxl) {
                    Button(action: onPauseTapped) {
                        Image(systemName: "pause.fill")
                            .font(.title)
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(width: ButtonSize.lg, height: ButtonSize.lg)
                            .background(AppColors.border)
                            .clipShape(Circle())
                    }

                    Button(action: onFinishTapped) {
                        Image(systemName: "stop.fill")
                            .font(.title)
                            .foregroundStyle(AppColors.cardBackground)
                            .frame(width: ButtonSize.lg, height: ButtonSize.lg)
                            .background(AppColors.textPrimary)
                            .clipShape(Circle())
                            .shadow(color: AppColors.textPrimary.opacity(0.2), radius: Spacing.xs, x: 0, y: Spacing.xxs)
                    }
                }

            case .paused:
                HStack(spacing: Spacing.xxl) {
                    Button(action: onResumeTapped) {
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundStyle(AppColors.cardBackground)
                            .frame(width: ButtonSize.lg, height: ButtonSize.lg)
                            .background(mode == .imperialPalace ? AppColors.imperialPalace : AppColors.normal)
                            .clipShape(Circle())
                            .shadow(color: Shadow.heavy.color, radius: Shadow.heavy.radius, x: Shadow.heavy.x, y: Shadow.heavy.y)
                    }

                    Button(action: onFinishTapped) {
                        Image(systemName: "stop.fill")
                            .font(.title)
                            .foregroundStyle(AppColors.cardBackground)
                            .frame(width: ButtonSize.lg, height: ButtonSize.lg)
                            .background(AppColors.textPrimary)
                            .clipShape(Circle())
                            .shadow(color: AppColors.textPrimary.opacity(0.2), radius: Spacing.xs, x: 0, y: Spacing.xxs)
                    }
                }

            case .finished:
                EmptyView()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RunView(
        store: Store(initialState: RunFeature.State()) {
            RunFeature()
        }
    )
}
