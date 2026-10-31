import SwiftUI
import ComposableArchitecture
import PhotosUI
import UniformTypeIdentifiers

/// シェア用の画像とテキストをまとめた型
struct ShareContent: Transferable {
    let image: Data
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { content in
            content.image
        }
        DataRepresentation(exportedContentType: .plainText) { content in
            Data(content.text.utf8)
        }
    }
}

struct ShareView: View {
    let store: StoreOf<ShareFeature>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 24) {
                // ヘッダー（タイトル + 閉じるボタン）
                HStack {
                    Spacer()

                    Text("シェア")
                        .font(.largeTitle.weight(.bold))

                    Spacer()

                    Button {
                        store.send(.dismissTapped)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                // セグメント: 写真なし / 写真あり
                Picker("背景", selection: Binding(
                    get: { store.backgroundMode },
                    set: { store.send(.backgroundModeChanged($0)) }
                )) {
                    Text("写真なし").tag(ShareFeature.State.BackgroundMode.none)
                    Text("写真あり").tag(ShareFeature.State.BackgroundMode.photo)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // プレビュー
                Group {
                    if store.backgroundMode == .none {
                        ShareCardNightView(record: store.record)
                            .scaleEffect(0.5)
                            .frame(width: 180, height: 320)
                    } else {
                        if let photoData = store.photoData {
                            ShareCardPhotoView(record: store.record, photoData: photoData)
                                .scaleEffect(0.5)
                                .frame(width: 180, height: 320)
                        } else {
                            // 写真選択ボタン
                            PhotosPicker(
                                selection: Binding(
                                    get: { store.photoItem },
                                    set: { store.send(.photoItemSelected($0)) }
                                ),
                                matching: .images
                            ) {
                                VStack(spacing: 16) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.secondary)

                                    Text("写真を選択")
                                        .font(.headline)
                                }
                                .frame(width: 180, height: 320)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 8)
                .padding()

                // 写真を選び直すボタン
                if store.backgroundMode == .photo, store.photoData != nil {
                    PhotosPicker(
                        selection: Binding(
                            get: { store.photoItem },
                            set: { store.send(.photoItemSelected($0)) }
                        ),
                        matching: .images
                    ) {
                        Text("写真を選び直す")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }

                Spacer()

                // ボタン
                VStack(spacing: 12) {
                    // Instagram へシェア
                    if store.canShareToInstagram {
                        Button {
                            store.send(.shareToInstagramTapped)
                        } label: {
                            Label("Instagram のストーリーズへ", systemImage: "camera")
                                .font(.title3.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.purple, Color.pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    // その他で共有
                    if let imageData = store.generatedCardImage {
                        ShareLink(
                            item: ShareContent(image: imageData, text: makeShareText()),
                            preview: SharePreview(
                                "ぐるっとらん",
                                image: Image(uiImage: UIImage(data: imageData) ?? UIImage())
                            )
                        ) {
                            Label("その他で共有（X など）", systemImage: "square.and.arrow.up")
                                .font(.title3.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
                        // 画像生成中
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("画像を準備中...")
                        }
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    private func makeShareText() -> String {
        let distance = String(format: "%.2f", store.record.distanceMeters / 1000.0)
        let laps = String(format: "%.1f", store.record.laps)
        return "ぐるっとらんで\(distance)km（\(laps)周）走りました！ #ぐるっとらん"
    }
}

#Preview {
    ShareView(
        store: Store(initialState: ShareFeature.State(
            record: RunRecord(
                id: UUID(),
                date: Date(),
                distanceMeters: 5123.4,
                elapsed: .seconds(1534),
                laps: 1.0,
                route: [],
                source: .guruttoRun
            )
        )) {
            ShareFeature()
        }
    )
}
