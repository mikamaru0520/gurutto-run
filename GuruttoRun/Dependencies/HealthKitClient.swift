import ComposableArchitecture
import HealthKit
import CoreLocation
import Foundation
import OSLog

@DependencyClient
struct HealthKitClient: Sendable {
    /// HealthKit の認可をリクエスト
    var requestAuthorization: @Sendable () async throws -> Void

    /// ワークアウトセッションを開始
    var startWorkout: @Sendable () async throws -> Void

    /// ワークアウトセッションを終了し、ルートを保存
    var finishWorkout: @Sendable (_ route: [Coordinate], _ distanceMeters: Double, _ startDate: Date, _ endDate: Date) async throws -> Void

    /// 位置情報をワークアウトに追加
    var addLocation: @Sendable (_ coordinate: Coordinate, _ timestamp: Date) async throws -> Void

    /// 他アプリを含むランニングワークアウトを取得
    var fetchWorkouts: @Sendable (_ limit: Int) async throws -> [RunRecord]
}

extension HealthKitClient: DependencyKey {
    static let liveValue: HealthKitClient = {
        let manager = HealthKitManager()

        return HealthKitClient(
            requestAuthorization: {
                try await manager.requestAuthorization()
            },
            startWorkout: {
                try await manager.startWorkout()
            },
            finishWorkout: { route, distanceMeters, startDate, endDate in
                try await manager.finishWorkout(
                    route: route,
                    distanceMeters: distanceMeters,
                    startDate: startDate,
                    endDate: endDate
                )
            },
            addLocation: { coordinate, timestamp in
                await manager.addLocation(coordinate: coordinate, timestamp: timestamp)
            },
            fetchWorkouts: { limit in
                try await manager.fetchWorkouts(limit: limit)
            }
        )
    }()

    static let testValue = HealthKitClient(
        requestAuthorization: {
            Logger.test.info("HealthKit authorization requested")
        },
        startWorkout: {
            Logger.test.info("Workout started")
        },
        finishWorkout: { route, distanceMeters, startDate, endDate in
            Logger.test.info("Workout finished: \(distanceMeters, privacy: .public)m, \(route.count) points")
        },
        addLocation: { coordinate, timestamp in
            Logger.test.debug("Location added: \(String(describing: coordinate))")
        },
        fetchWorkouts: { _ in
            Logger.test.info("Fetching workouts")
            return []
        }
    )

    static let previewValue = HealthKitClient(
        requestAuthorization: {
            Logger.preview.info("HealthKit authorization requested")
        },
        startWorkout: {
            Logger.preview.info("Workout started")
        },
        finishWorkout: { route, distanceMeters, startDate, endDate in
            Logger.preview.info("Workout finished: \(distanceMeters, privacy: .public)m, \(route.count) points")
        },
        addLocation: { _, _ in },
        fetchWorkouts: { _ in
            // プレビュー用のダミーデータ
            [
                RunRecord(
                    id: UUID(),
                    date: Date(),
                    distanceMeters: 5123.4,
                    elapsed: .seconds(1534),
                    laps: 1.0,
                    route: [],
                    source: .guruttoRun
                ),
                RunRecord(
                    id: UUID(),
                    date: Date().addingTimeInterval(-86400),
                    distanceMeters: 10234.5,
                    elapsed: .seconds(3045),
                    laps: 2.0,
                    route: [],
                    source: .otherApp("Nike Run Club")
                ),
            ]
        }
    )
}

extension DependencyValues {
    var healthKitClient: HealthKitClient {
        get { self[HealthKitClient.self] }
        set { self[HealthKitClient.self] = newValue }
    }
}

/// HealthKit 管理
private actor HealthKitManager {
    private let healthStore = HKHealthStore()
    private var routeBuilder: HKWorkoutRouteBuilder?
    private var workoutStartDate: Date?

    func requestAuthorization() async throws {
        let workoutType = HKObjectType.workoutType()
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let routeType = HKSeriesType.workoutRoute()

        let typesToShare: Set<HKSampleType> = [workoutType, routeType]
        let typesToRead: Set<HKObjectType> = [workoutType, distanceType, routeType]

        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    func startWorkout() async throws {
        self.workoutStartDate = Date()
        self.routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
    }

    func addLocation(coordinate: Coordinate, timestamp: Date) async {
        guard let routeBuilder = routeBuilder else { return }

        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: timestamp
        )

        try? await routeBuilder.insertRouteData([location])
    }

    func finishWorkout(
        route: [Coordinate],
        distanceMeters: Double,
        startDate: Date,
        endDate: Date
    ) async throws {
        // HealthKit が利用可能かチェック
        guard HKHealthStore.isHealthDataAvailable() else {
            Logger.healthKit.warning("HealthKit is not available on this device/simulator")
            // シミュレーターではHealthKitが利用できないので、エラーを投げずに終了
            return
        }

        guard let routeBuilder = routeBuilder else {
            Logger.healthKit.warning("RouteBuilder is nil, skipping HealthKit save")
            return
        }

        // ルートを保存
        for (index, coord) in route.enumerated() {
            let timestamp = startDate.addingTimeInterval(Double(index))
            await addLocation(coordinate: coord, timestamp: timestamp)
        }

        // 距離サンプルを作成
        let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distanceMeters)
        let distanceSample = HKQuantitySample(
            type: HKQuantityType(.distanceWalkingRunning),
            quantity: distanceQuantity,
            start: startDate,
            end: endDate
        )

        // ワークアウトを作成
        let workout = HKWorkout(
            activityType: .running,
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: nil,
            totalDistance: distanceQuantity,
            metadata: nil
        )

        // HealthKit に保存
        try await healthStore.save(workout)
        try await healthStore.save(distanceSample)

        // ルートをワークアウトに関連付け
        try await routeBuilder.finishRoute(with: workout, metadata: nil)

        // クリーンアップ
        self.routeBuilder = nil
        self.workoutStartDate = nil
    }

    func fetchWorkouts(limit: Int) async throws -> [RunRecord] {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .running)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                Task {
                    var records: [RunRecord] = []

                    for workout in workouts {
                        let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
                        let duration = workout.duration

                        // ルートを取得
                        let route = try? await self.fetchRoute(for: workout)

                        // 周回数を計算（ルートがあれば LapCounter で計算、なければ推定）
                        let laps: Double
                        if let route = route, !route.isEmpty {
                            // TODO: LapCounter で計算（基準ルートが必要）
                            laps = distance / 5000.0  // 仮の推定
                        } else {
                            laps = distance / 5000.0  // 推定
                        }

                        // ソース判定
                        let source: RunRecord.Source
                        let sourceApp = workout.sourceRevision.source.name
                        if sourceApp.contains("GuruttoRun") || sourceApp.contains("ぐるっとらん") {
                            source = .guruttoRun
                        } else {
                            source = .otherApp(sourceApp)
                        }

                        let record = RunRecord(
                            id: UUID(),
                            date: workout.startDate,
                            distanceMeters: distance,
                            elapsed: .seconds(duration),
                            laps: laps,
                            route: route ?? [],
                            source: source
                        )
                        records.append(record)
                    }

                    continuation.resume(returning: records)
                }
            }

            healthStore.execute(query)
        }
    }

    private func fetchRoute(for workout: HKWorkout) async throws -> [Coordinate]? {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let routeSample = samples?.first as? HKWorkoutRoute else {
                    continuation.resume(returning: nil)
                    return
                }

                Task {
                    let coordinates = try await self.fetchRouteData(from: routeSample)
                    continuation.resume(returning: coordinates)
                }
            }

            healthStore.execute(query)
        }
    }

    private func fetchRouteData(from route: HKWorkoutRoute) async throws -> [Coordinate] {
        try await withCheckedThrowingContinuation { continuation in
            var allCoordinates: [Coordinate] = []

            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let locations = locations {
                    let coords = locations.map { loc in
                        Coordinate(
                            latitude: loc.coordinate.latitude,
                            longitude: loc.coordinate.longitude
                        )
                    }
                    allCoordinates.append(contentsOf: coords)
                }

                if done {
                    continuation.resume(returning: allCoordinates)
                }
            }

            healthStore.execute(query)
        }
    }
}
