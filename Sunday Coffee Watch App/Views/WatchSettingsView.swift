import SwiftUI
import WatchKit

struct WatchSettingsView: View {
    @EnvironmentObject private var store: CoffeeStore

    var body: some View {
        List {
            Section("iCloud") {
                if store.isSyncing {
                    HStack {
                        ProgressView()
                        Text("Syncing")
                    }
                } else if store.cloudKitAvailable {
                    Label("Connected", systemImage: "checkmark.icloud")
                        .foregroundStyle(.green)
                } else {
                    Label("Unavailable", systemImage: "icloud.slash")
                        .foregroundStyle(.orange)
                }

                if let lastSyncDate = store.lastSyncDate {
                    LabeledContent("Last Sync") {
                        Text(lastSyncDate, format: .dateTime.month().day().hour().minute())
                    }
                } else {
                    Text("Last sync: Never")
                        .foregroundStyle(.secondary)
                }

                Button("Refresh Now") {
                    Task { await refreshFromCloud(playHaptic: true) }
                }
                .disabled(store.isSyncing || !store.cloudKitAvailable)

                if let syncError = store.syncError, !syncError.isEmpty {
                    Text(syncError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Settings")
        .refreshable {
            await refreshFromCloud(playHaptic: true)
        }
    }

    private func refreshFromCloud(playHaptic: Bool) async {
        let previousSyncDate = store.lastSyncDate
        await store.fetchFromCloud()
        guard playHaptic else { return }

        if store.syncError == nil, store.lastSyncDate != previousSyncDate {
            WKInterfaceDevice.current().play(.success)
        } else if store.syncError != nil {
            WKInterfaceDevice.current().play(.failure)
        }
    }
}

#Preview {
    NavigationStack {
        WatchSettingsView()
            .environmentObject(CoffeeStore())
    }
}
