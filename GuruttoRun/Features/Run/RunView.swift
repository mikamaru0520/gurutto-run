import SwiftUI
import ComposableArchitecture

struct RunView: View {
    let store: StoreOf<RunFeature>

    var body: some View {
        WithPerceptionTracking {
            ZStack {
                // 背景
                Color(hex: "F5F5F5").ignoresSafeArea()

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
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                            Text("計測中はモードを切り替えできません")
                                .font(.caption)
                        }
                        .foregroundStyle(.gray)
                        .padding(.top, 8)
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
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
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
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
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
        HStack(spacing: 8) {
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
                .foregroundStyle(selectedMode == .imperialPalace ? .white : Color(hex: "3D9B7E"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedMode == .imperialPalace ? Color(hex: "3D9B7E") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
                .foregroundStyle(selectedMode == .normal ? .white : Color(hex: "FF9F5A"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedMode == .normal ? Color(hex: "FF9F5A") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            .disabled(isRunning)
        }
        .frame(height: 48)
    }
}

// MARK: - Idle View

struct IdleView: View {
    let mode: RunFeature.State.Mode

    var body: some View {
        VStack(spacing: 32) {
            // アイコン
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 200, height: 200)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)

                Image(systemName: mode == .imperialPalace ? "arrow.triangle.2.circlepath" : "figure.run")
                    .font(.system(size: 72))
                    .foregroundStyle(mode == .imperialPalace ? Color(hex: "3D9B7E") : Color(hex: "FF9F5A"))
            }

            // モード名と説明
            VStack(spacing: 8) {
                Text(mode == .imperialPalace ? "皇居モード" : "通常モード")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.black)

                Text(mode == .imperialPalace ? "皇居を走るとき用" : "近所のコースや旅先で")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }

            // 特徴
            VStack(alignment: .leading, spacing: 12) {
                if mode == .imperialPalace {
                    FeatureRow(text: "周回を自動でカウント", color: Color(hex: "3D9B7E"))
                    FeatureRow(text: "どこから走り始めても1周で1カウント", color: Color(hex: "3D9B7E"))
                    FeatureRow(text: "「2.5周」のような実測の周回数を表示", color: Color(hex: "3D9B7E"))
                } else {
                    FeatureRow(text: "周回カウントなし（距離のみ計測）", color: Color(hex: "FF9F5A"))
                    FeatureRow(text: "距離を「皇居○周分」に換算して表示", color: Color(hex: "FF9F5A"))
                    FeatureRow(text: "GPS が弱い場所でも使いやすく、電池にもやさしい", color: Color(hex: "FF9F5A"))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 32)
        }
    }
}

struct FeatureRow: View {
    let text: String
    var color: Color = Color(hex: "3D9B7E")

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .padding(.top, 7)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.black.opacity(0.8))
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
        VStack(spacing: 24) {
            // 距離
            VStack(spacing: 4) {
                Text("距離")
                    .font(.caption)
                    .foregroundStyle(.gray)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", distanceMeters / 1000.0))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                    Text("km")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }
            }

            // 周回（円形プログレス）
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: laps.truncatingRemainder(dividingBy: 1))
                    .stroke(
                        Color(hex: "3D9B7E"),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text(String(format: "%.1f", laps))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                    Text("周")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text("実測カウント")
                        .font(.caption2)
                        .foregroundStyle(.gray.opacity(0.7))
                }
            }

            // 現在の周の進捗
            if laps >= 1 {
                Text("\(Int(laps) + 1)周目・リングは今の周の進み具合")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - 通常モード計測中

struct NormalModeRunningView: View {
    let distanceMeters: Double
    let elapsed: Duration

    var body: some View {
        VStack(spacing: 32) {
            // 距離
            VStack(spacing: 4) {
                Text("距離")
                    .font(.caption)
                    .foregroundStyle(.gray)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", distanceMeters / 1000.0))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                    Text("km")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }
            }

            // 皇居換算カード
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("皇居")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.gray)

                    Spacer()

                    Text("換算")
                        .font(.caption2)
                        .foregroundStyle(.gray.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Capsule())
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", distanceMeters / 5000.0))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                    Text("周分")
                        .font(.title3)
                        .foregroundStyle(.gray)
                }

                // プログレスバー
                let progress = (distanceMeters / 5000.0).truncatingRemainder(dividingBy: 1)
                HStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "FF9F5A"))
                                .frame(width: geometry.size.width * progress, height: 8)
                        }
                    }
                    .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 8)
                }

                Text("皇居1周の実測距離で換算しています")
                    .font(.caption2)
                    .foregroundStyle(.gray.opacity(0.6))
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - タイム・ペース

struct TimeAndPaceView: View {
    let elapsed: Duration
    let pace: String

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("タイム")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(formatDuration(elapsed))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Text("ペース")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(pace)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                + Text("/km")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 130, height: 130)
                        .background(mode == .imperialPalace ? Color(hex: "3D9B7E") : Color(hex: "FF9F5A"))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                }

            case .running:
                HStack(spacing: 32) {
                    Button(action: onPauseTapped) {
                        Image(systemName: "pause.fill")
                            .font(.title)
                            .foregroundStyle(.black)
                            .frame(width: 80, height: 80)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(Circle())
                    }

                    Button(action: onFinishTapped) {
                        Image(systemName: "stop.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 80)
                            .background(Color.black)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                }

            case .paused:
                HStack(spacing: 32) {
                    Button(action: onResumeTapped) {
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 80)
                            .background(mode == .imperialPalace ? Color(hex: "3D9B7E") : Color(hex: "FF9F5A"))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }

                    Button(action: onFinishTapped) {
                        Image(systemName: "stop.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 80)
                            .background(Color.black)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                }

            case .finished:
                EmptyView()
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
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
