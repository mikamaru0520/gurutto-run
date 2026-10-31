import ComposableArchitecture
import PhotosUI
import SwiftUI
import Foundation

@Reducer
struct ShareFeature {
    @ObservableState
    struct State: Equatable {
        var record: RunRecord
        var backgroundMode: BackgroundMode = .none
        var photoItem: PhotosPickerItem?
        var photoData: Data?
        var canShareToInstagram: Bool = false
        var generatedCardImage: Data?

        enum BackgroundMode: Equatable {
            case none
            case photo
        }
    }

    enum Action: Sendable {
        case onAppear
        case backgroundModeChanged(State.BackgroundMode)
        case photoItemSelected(PhotosPickerItem?)
        case photoDataLoaded(Data?)
        case generateCardImage
        case cardImageGenerated(Data?)
        case shareToInstagramTapped
        case shareToInstagramCompleted
        case dismissTapped
    }

    @Dependency(\.shareClient) var shareClient
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.canShareToInstagram = shareClient.canShareToInstagram()
                return .send(.generateCardImage)

            case let .backgroundModeChanged(mode):
                state.backgroundMode = mode
                if mode == .none {
                    state.photoItem = nil
                    state.photoData = nil
                }
                return .send(.generateCardImage)

            case let .photoItemSelected(item):
                state.photoItem = item
                guard let item = item else {
                    state.photoData = nil
                    return .none
                }

                return .run { send in
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        // 画像を縮小
                        let resizedData = await resizeImage(data, maxDimension: 1920)
                        await send(.photoDataLoaded(resizedData))
                    }
                }

            case let .photoDataLoaded(data):
                state.photoData = data
                return .send(.generateCardImage)

            case .generateCardImage:
                let record = state.record
                let backgroundMode = state.backgroundMode
                let photoData = state.photoData

                return .run { send in
                    let imageData = await generateCardImageData(
                        record: record,
                        backgroundMode: backgroundMode,
                        photoData: photoData
                    )
                    await send(.cardImageGenerated(imageData))
                }

            case let .cardImageGenerated(imageData):
                state.generatedCardImage = imageData
                return .none

            case .shareToInstagramTapped:
                guard let imageData = state.generatedCardImage else {
                    return .none
                }

                return .run { _ in
                    _ = await shareClient.shareToInstagramStories(imageData)
                }

            case .shareToInstagramCompleted:
                return .none

            case .dismissTapped:
                return .run { _ in
                    await dismiss()
                }
            }
        }
    }

    /// 画像を縮小
    private func resizeImage(_ data: Data, maxDimension: CGFloat) async -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height)

        if scale >= 1 {
            // すでに小さい
            return data
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage.pngData()
    }
}

/// シェアカードの画像を生成
@MainActor
private func generateCardImageData(
    record: RunRecord,
    backgroundMode: ShareFeature.State.BackgroundMode,
    photoData: Data?
) -> Data? {
    let renderer: ImageRenderer<AnyView>

    if backgroundMode == .photo, let photoData = photoData {
        renderer = ImageRenderer(
            content: AnyView(ShareCardPhotoView(record: record, photoData: photoData))
        )
    } else {
        renderer = ImageRenderer(
            content: AnyView(ShareCardNightView(record: record))
        )
    }

    // Instagram Stories のサイズに合わせて高解像度で生成
    renderer.scale = 3.0

    guard let uiImage = renderer.uiImage else {
        return nil
    }

    return uiImage.pngData()
}
