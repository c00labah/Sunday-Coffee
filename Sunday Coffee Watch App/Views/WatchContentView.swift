import SwiftUI
import WatchKit

struct WatchContentView: View {
    @EnvironmentObject private var store: CoffeeStore
    @State private var attendees: Set<String> = []
    @State private var showingSavedBanner = false

    private var attendeeList: [Participant] {
        store.participants.filter { attendees.contains($0.id) }
    }

    private var nextPayer: Participant? {
        store.getTodaysPayer(attendees: attendeeList)
    }

    private var lastRoundPayerText: String? {
        guard let lastRound = store.coffeeRounds.first,
              let payer = store.participants.first(where: { $0.id == lastRound.payerID }) else {
            return nil
        }
        return "Last round: \(payer.name)"
    }

    var body: some View {
        List {
            Section {
                if let payer = nextPayer {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next to pay")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(payer.avatarEmoji) \(payer.name)")
                            .font(.headline)
                        if let lastRoundPayerText {
                            Text(lastRoundPayerText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Select at least 2 attendees")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Who's Here") {
                ForEach(store.participants) { participant in
                    Button {
                        toggleAttendance(for: participant.id)
                    } label: {
                        HStack {
                            Text("\(participant.avatarEmoji) \(participant.name)")
                            Spacer()
                            Image(systemName: attendees.contains(participant.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(attendees.contains(participant.id) ? .green : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                Button("Record Round") {
                    saveRound()
                }
                .disabled(attendeeList.count < 2 || nextPayer == nil)

                if showingSavedBanner {
                    Text("Saved to iCloud")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }

                if let syncError = store.syncError {
                    Text(syncError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Sunday Coffee")
        .refreshable {
            await refreshFromCloud(playHaptic: true)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    WatchSettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .task {
            if attendees.isEmpty {
                attendees = Set(store.participants.map(\.id))
            }
            if !store.isSyncing {
                await refreshFromCloud(playHaptic: false)
            }
        }
        .onChange(of: store.participants) { _, updated in
            let validIDs = Set(updated.map(\.id))
            attendees = attendees.intersection(validIDs)
            if attendees.isEmpty {
                attendees = validIDs
            }
        }
    }

    private func toggleAttendance(for participantID: String) {
        if attendees.contains(participantID) {
            attendees.remove(participantID)
        } else {
            attendees.insert(participantID)
        }
    }

    private func saveRound() {
        guard let payer = nextPayer else { return }
        store.recordPayment(payerID: payer.id, attendeeIDs: Array(attendees))

        withAnimation {
            showingSavedBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingSavedBanner = false
            }
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
        WatchContentView()
            .environmentObject(CoffeeStore())
    }
}
