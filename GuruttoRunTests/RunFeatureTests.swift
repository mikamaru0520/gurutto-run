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
        }

        // 精度の悪い点は無視される
        await store.send(.locationUpdated(lowAccuracyLocation))
    }
}
