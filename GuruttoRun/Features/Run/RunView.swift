import SwiftUI
import ComposableArchitecture

struct RunView: View {
    let store: StoreOf<RunFeature>

    var body: some View {
        WithPerceptionTracking {
            ZStack {
                // 背景地図
                BackgroundMapView(
                    mode: store.mode,
                    isRunning: store.status != .idle,
                    route: store.route
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // モード切替 / ステータスバッジ
                    if store.status == .idle {
                        ModeSwitcher(
                            selectedMode: store.mode,
                            isRunning: false,
                            onModeChanged: { mode in
                                store.send(.modeToggled(mode))
                            }
                        )
                        .padding(.horizontal)
                        .padding(.top)
                    } else if store.status == .finished {
                        // 保存中のバッジ
                        HStack(spacing: Spacing.xs) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("保存中...")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: Shadow.light.color, radius: Shadow.light.radius, x: Shadow.light.x, y: Shadow.light.y)
                        .padding(.top)
                    } else {
                        // 計測中のバッジ
                        HStack(spacing: Spacing.xs) {
                            Circle()
                                .fill(store.mode == .imperialPalace ? AppColors.imperialPalace : AppColors.normal)
                                .frame(width: 8, height: 8)
                            Text("\(store.mode == .imperialPalace ? "皇居モード" : "通常モード")・計測中")
                                .font(.caption.weight(.semibold))
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                        }
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: Shadow.light.color, radius: Shadow.light.radius, x: Shadow.light.x, y: Shadow.light.y)
                        .padding(.top)
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
            // エラーアラート
            .alert("エラー", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.send(.dismissError) } }
            )) {
                Button("OK") {
                    store.send(.dismissError)
                }
            } message: {
                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                }
            }
            // GPS 精度警告
            .alert("GPS 精度が低下しています", isPresented: Binding(
                get: { store.showLowGPSAccuracyWarning },
                set: { if !$0 { store.send(.dismissLowGPSAccuracyWarning) } }
            )) {
                Button("OK") {
                    store.send(.dismissLowGPSAccuracyWarning)
                }
            } message: {
                Text("屋外の開けた場所に移動すると、GPS の精度が向上します。")
            }
        }
    }
}

// MARK: - 背景地図

struct BackgroundMapView: View {
    let mode: RunFeature.State.Mode
    let isRunning: Bool
    let route: [Coordinate]

    var body: some View {
        ZStack {
            // 地図の色オーバーレイ
            (mode == .imperialPalace ?
                LinearGradient(colors: [AppColors.imperialPalace.opacity(0.3), AppColors.imperialPalace.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                LinearGradient(colors: [AppColors.normal.opacity(0.3), AppColors.normal.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))

            // ルート線の描画（常に表示、デザイン風）
            GeometryReader { geometry in
                let points = generateDesignRoute(mode: mode, size: geometry.size)

                // ルート線
                Path { path in
                    if let first = points.first {
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(mode == .imperialPalace ? AppColors.imperialPalace : AppColors.normal, lineWidth: 6)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                // スタート地点のマーカー（白い円）
                if let first = points.first {
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(mode == .imperialPalace ? AppColors.imperialPalace : AppColors.normal, lineWidth: 4)
                        )
                        .position(first)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }

                // 計測中の場合、現在地マーカー（ドット）
                if isRunning, mode == .imperialPalace, !route.isEmpty {
                    // ルート上の進行位置を計算（例として30%の位置）
                    let progress = 0.3  // 実際にはroute.countなどから計算
                    let index = Int(Double(points.count - 1) * progress)
                    if index < points.count {
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                            .position(points[index])
                            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    }
                }
            }
        }
    }

    // デザイン用のルート生成
    private func generateDesignRoute(mode: RunFeature.State.Mode, size: CGSize) -> [CGPoint] {
        if mode == .imperialPalace {
            // 皇居の角丸四角形ルート
            let margin: CGFloat = 80
            let width = size.width - margin * 2
            let height = size.height - margin * 2
            let cornerRadius: CGFloat = 100

            var points: [CGPoint] = []
            let steps = 60

            for i in 0...steps {
                let progress = CGFloat(i) / CGFloat(steps)
                var point: CGPoint

                if progress < 0.25 {
                    // 上辺
                    let t = progress / 0.25
                    point = CGPoint(x: margin + cornerRadius + t * (width - 2 * cornerRadius), y: margin)
                } else if progress < 0.5 {
                    // 右辺
                    let t = (progress - 0.25) / 0.25
                    point = CGPoint(x: margin + width, y: margin + cornerRadius + t * (height - 2 * cornerRadius))
                } else if progress < 0.75 {
                    // 下辺
                    let t = (progress - 0.5) / 0.25
                    point = CGPoint(x: margin + width - cornerRadius - t * (width - 2 * cornerRadius), y: margin + height)
                } else {
                    // 左辺
                    let t = (progress - 0.75) / 0.25
                    point = CGPoint(x: margin, y: margin + height - cornerRadius - t * (height - 2 * cornerRadius))
                }
                points.append(point)
            }
            return points
        } else {
            // 通常モードの曲線ルート
            let startX = size.width * 0.2
            let startY = size.height * 0.8
            let endX = size.width * 0.9
            let endY = size.height * 0.2

            var points: [CGPoint] = []
            let steps = 40

            for i in 0...steps {
                let progress = CGFloat(i) / CGFloat(steps)
                let x = startX + (endX - startX) * progress
                let y = startY + (endY - startY) * progress + sin(progress * .pi * 2) * 60
                points.append(CGPoint(x: x, y: y))
            }
            return points
        }
    }
}

// MARK: - モード切替

struct ModeSwitcher: View {
    let selectedMode: RunFeature.State.Mode
    let isRunning: Bool
    let onModeChanged: (RunFeature.State.Mode) -> Void

    var body: some View {
        HStack(spacing: Spacing.xxs) {
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
                .foregroundStyle(selectedMode == .imperialPalace ? AppColors.textPrimary : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(selectedMode == .imperialPalace ? .white : .clear)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
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
                .foregroundStyle(selectedMode == .normal ? AppColors.textPrimary : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(selectedMode == .normal ? .white : .clear)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .disabled(isRunning)
        }
        .padding(Spacing.xxs)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .shadow(color: Shadow.light.color, radius: Shadow.light.radius, x: Shadow.light.x, y: Shadow.light.y)
    }
}

// MARK: - Idle View

struct IdleView: View {
    let mode: RunFeature.State.Mode

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // 皇居モードの場合、「どこから走っても1周で1カウント」メッセージ
            if mode == .imperialPalace {
                Text("どこから走っても1周で1カウント")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: Shadow.light.color, radius: Shadow.light.radius, x: Shadow.light.x, y: Shadow.light.y)
            }

            // モード名と説明カード
            VStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.xs) {
                    Text(mode == .imperialPalace ? "皇居モード" : "通常モード")
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(mode == .imperialPalace ? "皇居を走るとき用" : "近所のコースや旅先で")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                // 特徴を3列グリッドで表示
                if mode == .imperialPalace {
                    HStack(spacing: Spacing.md) {
                        FeatureIcon(icon: "arrow.triangle.2.circlepath", title: "周回を\n自動カウント", color: AppColors.imperialPalace)
                        FeatureIcon(icon: "location", title: "好きな地点\nからスタート", color: AppColors.imperialPalace)
                        FeatureIcon(icon: "chart.bar", title: "実測の\n周回数を表示", color: AppColors.imperialPalace)
                    }
                } else {
                    HStack(spacing: Spacing.md) {
                        FeatureIcon(icon: "arrow.up.forward", title: "距離だけを\n計測", color: AppColors.normal)
                        FeatureIcon(icon: "arrow.triangle.2.circlepath", title: "皇居○周分に\n換算", color: AppColors.normal)
                        FeatureIcon(icon: "battery.100", title: "GPSが弱くて\nも省電力", color: AppColors.normal)
                    }
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            .shadow(color: Shadow.medium.color, radius: Shadow.medium.radius, x: Shadow.medium.x, y: Shadow.medium.y)
            .padding(.horizontal, Spacing.lg)
        }
    }
}

struct FeatureIcon: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: FontSize.xl))
                .foregroundStyle(color)
                .frame(height: 40)

            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 皇居モード計測中

struct ImperialPalaceModeRunningView: View {
    let distanceMeters: Double
    let laps: Double
    let elapsed: Duration

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            // 周回（円形プログレス）
            ZStack {
                // 背景の円
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 12)
                    .frame(width: 240, height: 240)

                // プログレスの円
                Circle()
                    .trim(from: 0, to: laps.truncatingRemainder(dividingBy: 1))
                    .stroke(
                        AppColors.imperialPalace,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))

                // 進行位置のドット
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .offset(y: -120)
                    .rotationEffect(.degrees(360 * laps.truncatingRemainder(dividingBy: 1)))
            }

            Spacer()

            // 情報カード（ガラスモーフィズム）
            VStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.lg) {
                    // 距離
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("距離")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", distanceMeters / 1000.0))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                            Text("km")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }

                    Spacer()

                    // 周回（実測）
                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                        Text("周回（実測）")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", laps))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.imperialPalace)
                            Text("周")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }

                // タイムとペース
                HStack(spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("タイム")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Text(formatDuration(elapsed))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                        Text("ペース")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Text(calculatePace(distance: distanceMeters, elapsed: elapsed))
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                        + Text("/km")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .padding(Spacing.lg)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            .shadow(color: Shadow.medium.color, radius: Shadow.medium.radius, x: Shadow.medium.x, y: Shadow.medium.y)
            .padding(.horizontal, Spacing.lg)
        }
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

// MARK: - 通常モード計測中

struct NormalModeRunningView: View {
    let distanceMeters: Double
    let elapsed: Duration

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            // 距離の大きな表示
            VStack(spacing: Spacing.xs) {
                Text("距離")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))

                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Text(String(format: "%.1f", distanceMeters / 1000.0))
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("km")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            Spacer()

            // 情報カード（ガラスモーフィズム）
            VStack(spacing: Spacing.md) {
                // 皇居換算
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("皇居換算")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", distanceMeters / 5000.0))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.normal)
                        Text("周分")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Divider()

                // タイムとペース
                HStack(spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("タイム")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Text(formatDuration(elapsed))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                        Text("ペース")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Text(calculatePace(distance: distanceMeters, elapsed: elapsed))
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                        + Text("/km")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .padding(Spacing.lg)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            .shadow(color: Shadow.medium.color, radius: Shadow.medium.radius, x: Shadow.medium.x, y: Shadow.medium.y)
            .padding(.horizontal, Spacing.lg)
        }
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
                // 大きな角丸長方形のスタートボタン
                Button(action: onStartTapped) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "play.fill")
                            .font(.title3)
                        Text("スタート")
                            .font(.title3.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(mode == .imperialPalace ? AppColors.imperialPalace : AppColors.normal)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                    .shadow(color: Shadow.heavy.color, radius: Shadow.heavy.radius, x: Shadow.heavy.x, y: Shadow.heavy.y)
                }
                .padding(.horizontal, Spacing.lg)

            case .running:
                HStack(spacing: Spacing.lg) {
                    // 白い円形のポーズボタン
                    Button(action: onPauseTapped) {
                        Image(systemName: "pause.fill")
                            .font(.title2)
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(width: ButtonSize.lg, height: ButtonSize.lg)
                            .background(.white)
                            .clipShape(Circle())
                            .shadow(color: Shadow.medium.color, radius: Shadow.medium.radius, x: Shadow.medium.x, y: Shadow.medium.y)
                    }

                    // 黒い円形のストップボタン
                    Button(action: onFinishTapped) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: ButtonSize.lg, height: ButtonSize.lg)
                            .background(AppColors.textPrimary)
                            .clipShape(Circle())
                            .shadow(color: Shadow.medium.color, radius: Shadow.medium.radius, x: Shadow.medium.x, y: Shadow.medium.y)
                    }
                }

            case .paused:
                HStack(spacing: Spacing.lg) {
                    // プレイボタン（カラー）
                    Button(action: onResumeTapped) {
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: ButtonSize.lg, height: ButtonSize.lg)
                            .background(mode == .imperialPalace ? AppColors.imperialPalace : AppColors.normal)
                            .clipShape(Circle())
                            .shadow(color: Shadow.heavy.color, radius: Shadow.heavy.radius, x: Shadow.heavy.x, y: Shadow.heavy.y)
                    }

                    // ストップボタン（黒）
                    Button(action: onFinishTapped) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: ButtonSize.lg, height: ButtonSize.lg)
                            .background(AppColors.textPrimary)
                            .clipShape(Circle())
                            .shadow(color: Shadow.medium.color, radius: Shadow.medium.radius, x: Shadow.medium.x, y: Shadow.medium.y)
                    }
                }

            case .finished:
                // 保存中インジケーター
                VStack(spacing: Spacing.md) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("記録を保存中...")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(height: ButtonSize.lg)
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
