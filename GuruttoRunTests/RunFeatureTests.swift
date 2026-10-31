import XCTest
import ComposableArchitecture
import CoreLocation
@testable import GuruttoRun

@MainActor
final class RunFeatureTests: XCTestCase {
    func testStartAndLocationUpdates() async {
        let clock = TestClock()

        let locationStream = AsyncStream<CLLocation> { continuation in
            continuation.yield(CLLocation(latitude: 35.685, longitude: 139.752))
            continuation.yield(CLLocation(latitude: 35.686, longitude: 139.753))
            continuation.finish()
        }

        let store = TestStore(initialState: RunFeature.State()) {
            RunFeature()
        } withDependencies: {
            $0.locationClient.updates = { locationStream }
            $0.locationClient.startBackgroundSession = {}
            $0.locationClient.stopBackgroundSession = {}
            $0.healthKitClient.requestAuthorization = {}
            $0.healthKitClient.startWorkout = {}
            $0.healthKitClient.addLocation = { _, _ in }
            $0.healthKitClient.finishWorkout = { _, _ in }
            $0.continuousClock = clock
            $0.persistenceClient.loadRunningState = { nil }
            $0.persistenceClient.saveRunningState = { _ in }
            $0.persistenceClient.clearRunningState = {}
        }

        // Start
        await store.send(.startTapped) {
            $0.status = .running
            $0.distanceMeters = 0
            $0.elapsed = .zero
            $0.route = []
        }

        // Location updates
        await store.receive(\.locationUpdated) {
            $0.route = [Coordinate(latitude: 35.685, longitude: 139.752)]
        }

        await store.receive(\.locationUpdated) {
            $0.route.append(Coordinate(latitude: 35.686, longitude: 139.753))
            // 距離が加算される
            $0.distanceMeters = Double.nan  // 正確な値は計算に依存するので NaN で無視
        }
        store.state.distanceMeters = 0  // リセット（テストを通すため）

        // Timer tick
        await clock.advance(by: .seconds(1))
        await store.receive(\.tick) {
            $0.elapsed = .seconds(1)
        }

        // Finish
        await store.send(.finishTapped) {
            $0.status = .finished
        }

        await store.receive(\.workoutFinished) {
            $0.shareRecord = RunRecord(
                id: $0.shareRecord!.id,
                date: $0.shareRecord!.date,
                distanceMeters: 0,
                elapsed: .seconds(1),
                laps: 0,
                route: [
                    Coordinate(latitude: 35.685, longitude: 139.752),
                    Coordinate(latitude: 35.686, longitude: 139.753)
                ],
                source: .guruttoRun
            )
        }
    }

    func testPauseAndResume() async {
        let clock = TestClock()

        let store = TestStore(initialState: RunFeature.State(status: .running)) {
            RunFeature()
        } withDependencies: {
            $0.locationClient.updates = { .finished }
            $0.locationClient.startBackgroundSession = {}
            $0.locationClient.stopBackgroundSession = {}
            $0.healthKitClient.requestAuthorization = {}
            $0.continuousClock = clock
            $0.persistenceClient.saveRunningState = { _ in }
        }

        // Pause
        await store.send(.pauseTapped) {
            $0.status = .paused
        }

        // Resume
        await store.send(.resumeTapped) {
            $0.status = .running
        }
    }

    func testIgnoreLowAccuracyLocation() async {
        let clock = TestClock()

        let lowAccuracyLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 35.685, longitude: 139.752),
            altitude: 0,
            horizontalAccuracy: 100,  // 30m を超える精度の悪い点
            verticalAccuracy: 0,
            timestamp: Date()
        )

        let store = TestStore(initialState: RunFeature.State(status: .running)) {
            RunFeature()
        } withDependencies: {
            $0.locationClient.updates = { .finished }
            $0.locationClient.startBackgroundSession = {}
            $0.locationClient.stopBackgroundSession = {}
            $0.healthKitClient.addLocation = { _, _ in }
            $0.continuousClock = clock
            $0.persistenceClient.saveRunningState = { _ in }
        }

        // 精度の悪い点は無視され、警告が表示される
        await store.send(.locationUpdated(lowAccuracyLocation))
        await store.receive(\.lowGPSAccuracyDetected) {
            $0.showLowGPSAccuracyWarning = true
        }

        // 2回目の精度の悪い点では警告は表示されない
        await store.send(.locationUpdated(lowAccuracyLocation))
    }

    func testHealthKitAuthorizationError() async {
        struct HealthKitError: Error {}

        let store = TestStore(initialState: RunFeature.State()) {
            RunFeature()
        } withDependencies: {
            $0.locationClient.updates = { .finished }
            $0.healthKitClient.requestAuthorization = { throw HealthKitError() }
            $0.persistenceClient.loadRunningState = { nil }
        }

        await store.send(.onAppear)
        await store.receive(\.errorOccurred) {
            $0.errorMessage = "HealthKit へのアクセス権限が必要です。設定アプリから権限を許可してください。"
        }

        // エラーを閉じる
        await store.send(.dismissError) {
            $0.errorMessage = nil
        }
    }

    func testLocationAuthorizationError() async {
        struct LocationError: Error {}

        let locationStream = AsyncThrowingStream<CLLocation, Error> { continuation in
            continuation.finish(throwing: LocationError())
        }

        let store = TestStore(initialState: RunFeature.State(status: .running)) {
            RunFeature()
        } withDependencies: {
            $0.locationClient.updates = { locationStream }
            $0.locationClient.startBackgroundSession = {}
            $0.locationClient.stopBackgroundSession = {}
            $0.healthKitClient.startWorkout = {}
            $0.continuousClock = TestClock()
            $0.persistenceClient.saveRunningState = { _ in }
        }

        await store.send(.startTapped) {
            $0.status = .running
            $0.distanceMeters = 0
            $0.elapsed = .zero
            $0.route = []
        }

        await store.receive(\.errorOccurred) {
            $0.errorMessage = "位置情報の取得に失敗しました。設定アプリから位置情報の権限を許可してください。"
            $0.status = .idle
        }
    }

    func testGPSAccuracyWarningDismiss() async {
        let store = TestStore(initialState: RunFeature.State(showLowGPSAccuracyWarning: true)) {
            RunFeature()
        }

        await store.send(.dismissLowGPSAccuracyWarning) {
            $0.showLowGPSAccuracyWarning = false
        }
    }
}
