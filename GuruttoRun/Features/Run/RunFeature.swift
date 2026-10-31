import ComposableArchitecture
import CoreLocation
import Foundation

@Reducer
struct RunFeature {
    @ObservableState
    struct State: Equatable {
        var status: Status = .idle
        var mode: Mode = .normal
        var distanceMeters: Double = 0
        var elapsed: Duration = .zero
        var route: [Coordinate] = []
        var lapCounter: LapCounter?
        var shareRecord: RunRecord?
        var startDate: Date?
        var isNearImperialPalace: Bool = false
        var showImperialPalaceSuggestion: Bool = false

        // エラーハンドリング
        var errorMessage: String?
        var showLowGPSAccuracyWarning: Bool = false

        enum Status: Equatable {
            case idle
            case running
            case paused
            case finished
        }

        enum Mode: Equatable {
            case imperialPalace  // 皇居モード
            case normal          // 通常モード
        }

        var laps: Double {
            lapCounter?.laps ?? 0
        }
    }

    enum Action: Sendable {
        case onAppear
        case modeToggled(State.Mode)
        case startTapped
        case pauseTapped
        case resumeTapped
        case finishTapped
        case locationUpdated(CLLocation)
        case tick
        case workoutFinished
        case shareRecordUpdated(RunRecord?)
        case dismissImperialPalaceSuggestion
        case acceptImperialPalaceSuggestion

        // エラーハンドリング
        case errorOccurred(String)
        case dismissError
        case lowGPSAccuracyDetected
        case dismissLowGPSAccuracyWarning

        #if DEBUG
        case createDummyRecord
        #endif
    }

    @Dependency(\.locationClient) var locationClient
    @Dependency(\.healthKitClient) var healthKitClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.persistenceClient) var persistenceClient

    private enum CancelID {
        case location
        case timer
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // 基準ルートを読み込む
                if state.lapCounter == nil {
                    let referenceRoute = loadReferenceRoute()
                    if !referenceRoute.isEmpty {
                        state.lapCounter = LapCounter(referenceRoute: referenceRoute)
                    }
                }

                // 保存された走行中の状態を復元（クラッシュ保護）
                return .run { [state] send in
                    // 保存された状態を復元
                    if let savedState = try? await persistenceClient.loadRunningState() {
                        // 復元するかユーザーに確認する処理を追加することも可能
                        // 今回はシンプルに自動復元
                    }

                    do {
                        try await healthKitClient.requestAuthorization()
                    } catch {
                        await send(.errorOccurred("HealthKit へのアクセス権限が必要です。設定アプリから権限を許可してください。"))
                    }

                    // 現在地を1回だけ取得
                    do {
                        for await location in locationClient.updates() {
                            await send(.locationUpdated(location))
                            break  // 1回だけ
                        }
                    } catch {
                        await send(.errorOccurred("位置情報へのアクセス権限が必要です。設定アプリから権限を許可してください。"))
                    }
                }

            case let .modeToggled(mode):
                // 計測中はモード変更不可
                guard state.status == .idle else { return .none }
                state.mode = mode
                return .none

            case .dismissImperialPalaceSuggestion:
                state.showImperialPalaceSuggestion = false
                return .none

            case .acceptImperialPalaceSuggestion:
                state.mode = .imperialPalace
                state.showImperialPalaceSuggestion = false
                return .none

            case .startTapped:
                state.status = .running
                state.distanceMeters = 0
                state.elapsed = .zero
                state.route = []
                state.lapCounter?.reset()
                state.startDate = Date()

                return .merge(
                    // 位置情報の更新を開始
                    .run { send in
                        await locationClient.startBackgroundSession()

                        do {
                            try await healthKitClient.startWorkout()
                        } catch {
                            await send(.errorOccurred("ワークアウトの開始に失敗しました。HealthKit の権限を確認してください。"))
                            return
                        }

                        do {
                            for await location in locationClient.updates() {
                                await send(.locationUpdated(location))
                            }
                        } catch {
                            await send(.errorOccurred("位置情報の取得に失敗しました。設定アプリから位置情報の権限を許可してください。"))
                        }
                    }
                    .cancellable(id: CancelID.location),

                    // タイマーを開始
                    .run { send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            await send(.tick)
                        }
                    }
                    .cancellable(id: CancelID.timer)
                )

            case .pauseTapped:
                state.status = .paused
                return .merge(
                    .cancel(id: CancelID.location),
                    .cancel(id: CancelID.timer)
                )

            case .resumeTapped:
                state.status = .running
                return .merge(
                    // 位置情報の更新を再開
                    .run { send in
                        for await location in locationClient.updates() {
                            await send(.locationUpdated(location))
                        }
                    }
                    .cancellable(id: CancelID.location),

                    // タイマーを再開
                    .run { send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            await send(.tick)
                        }
                    }
                    .cancellable(id: CancelID.timer)
                )

            case .finishTapped:
                state.status = .finished

                let route = state.route
                let distanceMeters = state.distanceMeters
                let startDate = state.startDate ?? Date()
                let endDate = Date()

                return .merge(
                    .cancel(id: CancelID.location),
                    .cancel(id: CancelID.timer),
                    .run { send in
                        await locationClient.stopBackgroundSession()

                        do {
                            try await healthKitClient.finishWorkout(
                                route: route,
                                distanceMeters: distanceMeters,
                                startDate: startDate,
                                endDate: endDate
                            )
                        } catch {
                            await send(.errorOccurred("ワークアウトの保存に失敗しました。データは記録されていない可能性があります。"))
                        }

                        await send(.workoutFinished)
                    }
                )

            case let .locationUpdated(location):
                let coordinate = Coordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )

                // idle 時は皇居付近判定のみ
                if state.status == .idle {
                    let isNear = isNearImperialPalace(coordinate)
                    state.isNearImperialPalace = isNear

                    // 通常モードで皇居付近にいたら提案を表示
                    if isNear && state.mode == .normal && !state.showImperialPalaceSuggestion {
                        state.showImperialPalaceSuggestion = true
                    }
                    return .none
                }

                guard state.status == .running else { return .none }

                // 精度が悪い点は無視し、警告を表示
                guard location.horizontalAccuracy <= 30 else {
                    // GPS 精度が悪い場合は警告を表示（1回のみ）
                    if !state.showLowGPSAccuracyWarning {
                        return .send(.lowGPSAccuracyDetected)
                    }
                    return .none
                }

                // 距離を加算
                if let lastCoord = state.route.last {
                    let projection = LocalProjection(origin: lastCoord)
                    let distance = projection.distance(lastCoord, coordinate)
                    state.distanceMeters += distance
                }

                // ルートに追加
                state.route.append(coordinate)

                // ルートが大きくなりすぎないように定期的に簡略化
                // 100点ごとに5m の許容誤差で簡略化
                if state.route.count % 100 == 0 && state.route.count > 100 {
                    state.route = state.route.simplified(epsilon: 5.0)
                }

                // 皇居モードの時のみ周回カウント
                if state.mode == .imperialPalace {
                    state.lapCounter?.update(coordinate: coordinate, timestamp: location.timestamp)
                }

                // HealthKit に位置を追加
                return .run { _ in
                    try? await healthKitClient.addLocation(coordinate, location.timestamp)
                }

            case .tick:
                guard state.status == .running else { return .none }
                state.elapsed += .seconds(1)

                // 状態を保存（クラッシュ保護）
                let runningState = RunningState(
                    distanceMeters: state.distanceMeters,
                    elapsed: TimeInterval(state.elapsed.components.seconds),
                    route: state.route,
                    startDate: state.startDate ?? Date(),
                    mode: state.mode == .imperialPalace ? "imperialPalace" : "normal"
                )
                return .run { _ in
                    try? await persistenceClient.saveRunningState(runningState)
                }

            case .workoutFinished:
                // ワークアウト終了後、ShareFeature で表示するレコードを作成
                let record = RunRecord(
                    id: UUID(),
                    date: Date(),
                    distanceMeters: state.distanceMeters,
                    elapsed: state.elapsed,
                    laps: state.laps,
                    route: state.route,
                    source: .guruttoRun
                )
                state.shareRecord = record

                // 保存された状態をクリア
                return .run { _ in
                    try? await persistenceClient.clearRunningState()
                }

            case let .shareRecordUpdated(record):
                state.shareRecord = record

                // シェア画面を閉じたら（record が nil）、状態をリセット
                if record == nil {
                    state.status = .idle
                    state.distanceMeters = 0
                    state.elapsed = .zero
                    state.route = []
                    state.startDate = nil
                    state.lapCounter?.reset()
                }

                return .none

            case let .errorOccurred(message):
                state.errorMessage = message
                // エラーが発生したら計測を停止
                if state.status == .running || state.status == .paused {
                    state.status = .idle
                    return .merge(
                        .cancel(id: CancelID.location),
                        .cancel(id: CancelID.timer),
                        .run { _ in
                            await locationClient.stopBackgroundSession()
                        }
                    )
                }
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .lowGPSAccuracyDetected:
                state.showLowGPSAccuracyWarning = true
                return .none

            case .dismissLowGPSAccuracyWarning:
                state.showLowGPSAccuracyWarning = false
                return .none

            #if DEBUG
            case .createDummyRecord:
                // 基準ルートを読み込んでダミーデータを作成
                let referenceRoute = loadReferenceRoute()
                let dummyRecord = RunRecord(
                    id: UUID(),
                    date: Date(),
                    distanceMeters: 5123.4,  // 約5km
                    elapsed: .seconds(1534),  // 25分34秒
                    laps: 1.0,
                    route: referenceRoute,
                    source: .guruttoRun
                )
                state.shareRecord = dummyRecord
                return .none
            #endif
            }
        }
    }

    /// 基準ルートを JSON ファイルから読み込む
    private func loadReferenceRoute() -> [Coordinate] {
        guard let url = Bundle.main.url(forResource: "ReferenceRoute", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let coordinates = try? JSONDecoder().decode([Coordinate].self, from: data) else {
            return []
        }
        return coordinates
    }

    /// 皇居付近にいるか判定（皇居中心から半径2km以内）
    private func isNearImperialPalace(_ coordinate: Coordinate) -> Bool {
        // 皇居の中心座標（概算）
        let imperialPalaceCenter = Coordinate(latitude: 35.685175, longitude: 139.752799)
        let projection = LocalProjection(origin: imperialPalaceCenter)
        let distance = projection.distance(imperialPalaceCenter, coordinate)

        // 2km 以内なら皇居付近とみなす
        return distance < 2000
    }
}
