import XCTest
import ComposableArchitecture
@testable import GuruttoRun

@MainActor
final class ShareFeatureTests: XCTestCase {
    func testOnAppearGeneratesCardImage() async {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5000,
            elapsed: .seconds(1500),
            laps: 1.0,
            route: [],
            source: .guruttoRun
        )

        let store = TestStore(initialState: ShareFeature.State(record: record)) {
            ShareFeature()
        } withDependencies: {
            $0.shareClient.canShareToInstagram = { false }
            $0.shareClient.shareToInstagram = { _ in }
        }

        await store.send(.onAppear) {
            $0.canShareToInstagram = false
        }

        await store.receive(\.generateCardImage)
        await store.receive(\.cardImageGenerated)
    }

    func testBackgroundModeChanged() async {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5000,
            elapsed: .seconds(1500),
            laps: 1.0,
            route: [],
            source: .guruttoRun
        )

        let store = TestStore(initialState: ShareFeature.State(record: record)) {
            ShareFeature()
        } withDependencies: {
            $0.shareClient.canShareToInstagram = { false }
            $0.shareClient.shareToInstagram = { _ in }
        }

        await store.send(.backgroundModeChanged(.photo)) {
            $0.backgroundMode = .photo
        }

        await store.receive(\.generateCardImage)
        await store.receive(\.cardImageGenerated)
    }

    func testBackgroundModeChangedToNone() async {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5000,
            elapsed: .seconds(1500),
            laps: 1.0,
            route: [],
            source: .guruttoRun
        )

        let photoData = Data([0x01, 0x02, 0x03])

        let store = TestStore(
            initialState: ShareFeature.State(
                record: record,
                backgroundMode: .photo,
                photoData: photoData
            )
        ) {
            ShareFeature()
        } withDependencies: {
            $0.shareClient.canShareToInstagram = { false }
            $0.shareClient.shareToInstagram = { _ in }
        }

        await store.send(.backgroundModeChanged(.none)) {
            $0.backgroundMode = .none
            $0.photoItem = nil
            $0.photoData = nil
        }

        await store.receive(\.generateCardImage)
        await store.receive(\.cardImageGenerated)
    }

    func testPhotoItemSelectedWithNil() async {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5000,
            elapsed: .seconds(1500),
            laps: 1.0,
            route: [],
            source: .guruttoRun
        )

        let store = TestStore(initialState: ShareFeature.State(record: record)) {
            ShareFeature()
        }

        await store.send(.photoItemSelected(nil)) {
            $0.photoItem = nil
            $0.photoData = nil
        }
    }

    func testPhotoDataLoaded() async {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5000,
            elapsed: .seconds(1500),
            laps: 1.0,
            route: [],
            source: .guruttoRun
        )

        let photoData = Data([0x01, 0x02, 0x03])

        let store = TestStore(initialState: ShareFeature.State(record: record)) {
            ShareFeature()
        } withDependencies: {
            $0.shareClient.canShareToInstagram = { false }
            $0.shareClient.shareToInstagram = { _ in }
        }

        await store.send(.photoDataLoaded(photoData)) {
            $0.photoData = photoData
        }

        await store.receive(\.generateCardImage)
        await store.receive(\.cardImageGenerated)
    }

    func testDismissTapped() async {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5000,
            elapsed: .seconds(1500),
            laps: 1.0,
            route: [],
            source: .guruttoRun
        )

        let store = TestStore(initialState: ShareFeature.State(record: record)) {
            ShareFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { }
        }

        await store.send(.dismissTapped)
    }

    func testShareToInstagramTapped() async {
        let record = RunRecord(
            id: UUID(),
            date: Date(),
            distanceMeters: 5000,
            elapsed: .seconds(1500),
            laps: 1.0,
            route: [],
            source: .guruttoRun
        )

        let imageData = Data([0x01, 0x02, 0x03])

        let store = TestStore(
            initialState: ShareFeature.State(
                record: record,
                generatedCardImage: imageData
            )
        ) {
            ShareFeature()
        } withDependencies: {
            $0.shareClient.shareToInstagram = { _ in }
        }

        await store.send(.shareToInstagramTapped)
        await store.receive(\.shareToInstagramCompleted)
    }
}
