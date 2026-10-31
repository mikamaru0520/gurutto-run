import XCTest
import ComposableArchitecture
@testable import GuruttoRun

@MainActor
final class HistoryFeatureTests: XCTestCase {
    func testOnAppearLoadsRecords() async {
        let testRecords = [
            RunRecord(
                id: UUID(),
                date: Date(),
                distanceMeters: 5000,
                elapsed: .seconds(1500),
                laps: 1.0,
                route: [],
                source: .guruttoRun
            ),
            RunRecord(
                id: UUID(),
                date: Date().addingTimeInterval(-86400),
                distanceMeters: 10000,
                elapsed: .seconds(3000),
                laps: 2.0,
                route: [],
                source: .otherApp("Nike Run Club")
            ),
        ]

        let store = TestStore(initialState: HistoryFeature.State()) {
            HistoryFeature()
        } withDependencies: {
            $0.healthKitClient.fetchWorkouts = { _ in testRecords }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.recordsLoaded) {
            $0.records = testRecords
            $0.isLoading = false
        }
    }

    func testOnAppearWithEmptyRecords() async {
        let store = TestStore(initialState: HistoryFeature.State()) {
            HistoryFeature()
        } withDependencies: {
            $0.healthKitClient.fetchWorkouts = { _ in [] }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.recordsLoaded) {
            $0.records = []
            $0.isLoading = false
        }
    }

    func testRecordTapped() async {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5000,
            elapsed: .seconds(1500),
            laps: 1.0,
            route: [],
            source: .guruttoRun
        )

        let store = TestStore(initialState: HistoryFeature.State()) {
            HistoryFeature()
        }

        await store.send(.recordTapped(record)) {
            $0.selectedRecord = record
        }
    }

    func testShareRecordUpdated() async {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5000,
            elapsed: .seconds(1500),
            laps: 1.0,
            route: [],
            source: .guruttoRun
        )

        let store = TestStore(initialState: HistoryFeature.State(selectedRecord: record)) {
            HistoryFeature()
        }

        // シェア画面を閉じる（nil を設定）
        await store.send(.shareRecordUpdated(nil)) {
            $0.selectedRecord = nil
        }
    }

    func testRecordsLoadedUpdatesState() async {
        let records = [
            RunRecord(
                id: UUID(),
                date: Date(),
                distanceMeters: 3000,
                elapsed: .seconds(900),
                laps: 0.6,
                route: [],
                source: .guruttoRun
            ),
        ]

        let store = TestStore(initialState: HistoryFeature.State(isLoading: true)) {
            HistoryFeature()
        }

        await store.send(.recordsLoaded(records)) {
            $0.records = records
            $0.isLoading = false
        }
    }
}
