import SwiftUI
import ComposableArchitecture

struct HistoryView: View {
    let store: StoreOf<HistoryFeature>

    var body: some View {
        WithPerceptionTracking {
            VStack {
                if store.isLoading {
                    ProgressView()
                } else if store.records.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)

                        Text("記録がありません")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(store.records) { record in
                        Button {
                            store.send(.recordTapped(record))
                        } label: {
                            RecordRow(record: record)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("記録")
            .onAppear {
                store.send(.onAppear)
            }
            .sheet(item: Binding(
                get: { store.selectedRecord },
                set: { store.send(.shareRecordUpdated($0)) }
            )) { record in
                ShareView(
                    store: Store(initialState: ShareFeature.State(record: record)) {
                        ShareFeature()
                    }
                )
            }
        }
    }
}

struct RecordRow: View {
    let record: RunRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 日付
            Text(formatDate(record.date))
                .font(.caption)
                .foregroundStyle(.secondary)

            // 距離
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.2f", record.distanceMeters / 1000.0))
                    .font(.title.bold())

                Text("km")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // 詳細
            HStack(spacing: 16) {
                Label(formatDuration(record.elapsed), systemImage: "clock")
                    .font(.caption)

                Label(record.paceFormatted, systemImage: "speedometer")
                    .font(.caption)

                Label(record.lapsFormatted, systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            // ソース
            if case let .otherApp(name) = record.source {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
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
}

#Preview {
    NavigationStack {
        HistoryView(
            store: Store(initialState: HistoryFeature.State(
                records: [
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
            )) {
                HistoryFeature()
            }
        )
    }
}
