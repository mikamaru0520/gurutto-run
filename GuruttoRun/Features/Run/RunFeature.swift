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
        #if DEBUG
        case createDummyRecord
        #endif
    }

    @Dependency(\.locationClient) var locationClient
    @Dependency(\.healthKitClient) var healthKitClient
    @Dependency(\.continuousClock) var clock

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

                // HealthKit の認可をリクエスト + 現在地取得で皇居付近かチェック
                return .run { send in
                    try? await healthKitClient.requestAuthorization()

                    // 現在地を1回だけ取得
                    for await location in locationClient.updates() {
                        await send(.locationUpdated(location))
                        break  // 1回だけ
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
                        try? await healthKitClient.startWorkout()

                        for await location in locationClient.updates() {
                            await send(.locationUpdated(location))
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
                        try? await healthKitClient.finishWorkout(
                            route: route,
                            distanceMeters: distanceMeters,
                            startDate: startDate,
                            endDate: endDate
                        )
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

                // 精度が悪い点は無視
                guard location.horizontalAccuracy <= 30 else { return .none }

                // 距離を加算
                if let lastCoord = state.route.last {
                    let projection = LocalProjection(origin: lastCoord)
                    let distance = projection.distance(lastCoord, coordinate)
                    state.distanceMeters += distance
                }

                // ルートに追加
                state.route.append(coordinate)

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
                return .none

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
                return .none

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
