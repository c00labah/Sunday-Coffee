import Foundation
import SwiftUI
import Combine
import CloudKit

@MainActor
class CoffeeStore: ObservableObject {
    
    @Published var participants: [Participant] = []
    @Published var coffeeRounds: [CoffeeRound] = []
    @Published var currentUserID: String?
    @Published var rosterState: RosterState = .initial
    @Published var isSyncing = false
    @Published var syncError: String?
    @Published var cloudKitAvailable = false
    @Published var lastSyncDate: Date?
    
    private var container: CKContainer?
    private var database: CKDatabase?
    private let cloudKitContainerIdentifier = "iCloud.com.sundaycoffee.app"
    
    // Record types
    private let participantRecordType = "Participant"
    private let roundRecordType = "CoffeeRound"
    private let rosterRecordType = "RosterState"
    
    init() {
        loadLocalData()
        checkCloudKitAvailability()
    }
    
    private func checkCloudKitAvailability() {
        let cloudContainer = CKContainer(identifier: cloudKitContainerIdentifier)
        
        cloudContainer.accountStatus { [weak self] status, error in
            Task { @MainActor in
                if status == .available {
                    self?.container = cloudContainer
                    self?.database = self?.container?.publicCloudDatabase
                    self?.cloudKitAvailable = true
                    await self?.fetchFromCloud()
                } else {
                    print("iCloud not available: \(status.rawValue)")
                    self?.syncError = "iCloud not available. Data is local only."
                    self?.cloudKitAvailable = false
                }
            }
        }
    }
    
    // MARK: - Local Data
    private func loadLocalData() {
        if let id = UserDefaults.standard.string(forKey: "currentUserID") {
            currentUserID = id
        }
        
        if let data = UserDefaults.standard.data(forKey: "participants"),
           let saved = try? JSONDecoder().decode([Participant].self, from: data) {
            participants = saved.sorted { $0.rosterPosition < $1.rosterPosition }
        } else {
            participants = Participant.defaultParticipants
        }
        
        if let data = UserDefaults.standard.data(forKey: "rosterState"),
           let saved = try? JSONDecoder().decode(RosterState.self, from: data) {
            rosterState = saved
        }
        
        if let data = UserDefaults.standard.data(forKey: "coffeeRounds"),
           let saved = try? JSONDecoder().decode([CoffeeRound].self, from: data) {
            coffeeRounds = saved
        }
        
        if let savedDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            lastSyncDate = savedDate
        }
    }
    
    private func saveLocal() {
        if let data = try? JSONEncoder().encode(participants) {
            UserDefaults.standard.set(data, forKey: "participants")
        }
        if let data = try? JSONEncoder().encode(rosterState) {
            UserDefaults.standard.set(data, forKey: "rosterState")
        }
        if let data = try? JSONEncoder().encode(coffeeRounds) {
            UserDefaults.standard.set(data, forKey: "coffeeRounds")
        }
        if let lastSyncDate {
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
        }
    }
    
    // MARK: - CloudKit Fetch
    func fetchFromCloud() async {
        guard let database = database else {
            syncError = "CloudKit not configured"
            return
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Fetch participants
            let participantQuery = CKQuery(recordType: participantRecordType, predicate: NSPredicate(value: true))
            let participantResults = try await database.records(matching: participantQuery)
            
            var fetchedParticipants: [Participant] = []
            for (_, result) in participantResults.matchResults {
                if let record = try? result.get() {
                    if let participant = Participant(from: record) {
                        fetchedParticipants.append(participant)
                    }
                }
            }
            
            if !fetchedParticipants.isEmpty {
                participants = fetchedParticipants.sorted { $0.rosterPosition < $1.rosterPosition }
            } else if participants.isEmpty {
                // First time - seed defaults and upload
                participants = Participant.defaultParticipants
                await uploadParticipants()
            }
            
            // Fetch roster state
            let rosterQuery = CKQuery(recordType: rosterRecordType, predicate: NSPredicate(value: true))
            let rosterResults = try await database.records(matching: rosterQuery)
            
            for (_, result) in rosterResults.matchResults {
                if let record = try? result.get(),
                   let state = RosterState(from: record) {
                    rosterState = state
                    break
                }
            }
            
            // Fetch coffee rounds
            let roundQuery = CKQuery(recordType: roundRecordType, predicate: NSPredicate(value: true))
            roundQuery.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            let roundResults = try await database.records(matching: roundQuery)
            
            var fetchedRounds: [CoffeeRound] = []
            for (_, result) in roundResults.matchResults {
                if let record = try? result.get(),
                   let round = CoffeeRound(from: record) {
                    fetchedRounds.append(round)
                }
            }
            coffeeRounds = fetchedRounds.sorted { $0.date > $1.date }
            lastSyncDate = Date()
            
            saveLocal()
            isSyncing = false
            
        } catch {
            print("CloudKit fetch error: \(error)")
            syncError = error.localizedDescription
            isSyncing = false
        }
    }
    
    // MARK: - CloudKit Save
    private func uploadParticipants() async {
        guard let database = database else { return }
        for participant in participants {
            let record = participant.toRecord()
            do {
                _ = try await database.save(record)
            } catch {
                print("Error saving participant: \(error)")
            }
        }
    }
    
    private func saveParticipantToCloud(_ participant: Participant) async {
        guard let database = database else { return }
        let record = participant.toRecord()
        do {
            _ = try await database.save(record)
        } catch {
            print("Error saving participant: \(error)")
        }
    }
    
    private func saveRosterToCloud() async {
        guard let database = database else { return }
        let record = rosterState.toRecord()
        do {
            _ = try await database.save(record)
        } catch {
            print("Error saving roster: \(error)")
        }
    }
    
    private func saveRoundToCloud(_ round: CoffeeRound) async {
        guard let database = database else { return }
        let record = round.toRecord()
        do {
            _ = try await database.save(record)
        } catch {
            print("Error saving round: \(error)")
        }
    }
    
    // MARK: - User Registration
    func registerUser(as participantID: String) {
        currentUserID = participantID
        UserDefaults.standard.set(participantID, forKey: "currentUserID")
    }
    
    // MARK: - Roster Logic
    func getTodaysPayer(attendees: [Participant]) -> Participant? {
        guard !attendees.isEmpty else { return nil }
        
        let order = Participant.rosterOrder
        let cursor = rosterState.cursor
        let n = order.count
        
        // Calculate cursor distance for tie-breaking
        func cursorDistance(for participant: Participant) -> Int {
            guard let idx = order.firstIndex(of: participant.id) else { return n }
            return (idx - cursor + n) % n
        }
        
        // Sort attendees by:
        // 1. Oldest lastPaidDate (nil = oldest, so comes first)
        // 2. Lowest roundsPaid (least frequent payer)
        // 3. Closest to cursor in cyclic order (rotating tie-break)
        let sorted = attendees.sorted { a, b in
            // Primary: oldest last_paid (nil counts as oldest)
            let aDate = a.lastPaidDate ?? Date.distantPast
            let bDate = b.lastPaidDate ?? Date.distantPast
            if aDate != bDate {
                return aDate < bDate
            }
            
            // Secondary: lowest pay_count
            if a.roundsPaid != b.roundsPaid {
                return a.roundsPaid < b.roundsPaid
            }
            
            // Tertiary: rotating cursor tie-break
            return cursorDistance(for: a) < cursorDistance(for: b)
        }
        
        return sorted.first
    }
    
    // MARK: - Record Payment
    func recordPayment(payerID: String, attendeeIDs: [String]) {
        let round = CoffeeRound(
            id: UUID().uuidString,
            date: Date(),
            payerID: payerID,
            attendeeIDs: attendeeIDs
        )
        
        coffeeRounds.insert(round, at: 0)
        
        // Update payer - they paid for one round
        if let index = participants.firstIndex(where: { $0.id == payerID }) {
            participants[index].roundsPaid += 1
            participants[index].lastPaidDate = Date()
            let updated = participants[index]
            Task { await saveParticipantToCloud(updated) }
        }
        
        // Update all attendees (including payer) - they attended one round
        for id in attendeeIDs {
            if let index = participants.firstIndex(where: { $0.id == id }) {
                participants[index].roundsAttended += 1
                let updated = participants[index]
                Task { await saveParticipantToCloud(updated) }
            }
        }
        
        // Advance cursor to the person after the payer (for tie-breaking)
        let order = Participant.rosterOrder
        if let payerIndex = order.firstIndex(of: payerID) {
            rosterState.cursor = (payerIndex + 1) % order.count
            rosterState.lastUpdated = Date()
            Task { await saveRosterToCloud() }
        }
        
        saveLocal()
        Task { await saveRoundToCloud(round) }
    }
    
    // MARK: - Performance Tracking
    func updateFiredOrPIPs(for participantID: String, count: Int) {
        guard let index = participants.firstIndex(where: { $0.id == participantID }) else { return }
        
        participants[index].firedOrPIPsLastWeek = max(0, count)
        let updated = participants[index]
        
        saveLocal()
        Task { await saveParticipantToCloud(updated) }
    }
    
    func getPerformanceLeaderboard() -> [Participant] {
        participants.sorted { a, b in
            if a.firedOrPIPsLastWeek != b.firedOrPIPsLastWeek {
                return a.firedOrPIPsLastWeek > b.firedOrPIPsLastWeek
            }
            return a.name < b.name
        }
    }
    
    func getLeaderboard() -> [Participant] {
        participants.sorted { $0.paymentBalance > $1.paymentBalance }
    }
    
    // MARK: - Stats
    var totalRounds: Int { coffeeRounds.count }
    
    // MARK: - Reset
    func resetAllData() async {
        // Delete from CloudKit if available
        if let database = database {
            do {
                let participantQuery = CKQuery(recordType: participantRecordType, predicate: NSPredicate(value: true))
                let results = try await database.records(matching: participantQuery)
                for (recordID, _) in results.matchResults {
                    _ = try? await database.deleteRecord(withID: recordID)
                }
                
                let roundQuery = CKQuery(recordType: roundRecordType, predicate: NSPredicate(value: true))
                let roundResults = try await database.records(matching: roundQuery)
                for (recordID, _) in roundResults.matchResults {
                    _ = try? await database.deleteRecord(withID: recordID)
                }
                
                let rosterQuery = CKQuery(recordType: rosterRecordType, predicate: NSPredicate(value: true))
                let rosterResults = try await database.records(matching: rosterQuery)
                for (recordID, _) in rosterResults.matchResults {
                    _ = try? await database.deleteRecord(withID: recordID)
                }
            } catch {
                print("Error deleting from CloudKit: \(error)")
            }
        }
        
        // Reset local
        UserDefaults.standard.removeObject(forKey: "coffeeRounds")
        UserDefaults.standard.removeObject(forKey: "participants")
        UserDefaults.standard.removeObject(forKey: "rosterState")
        UserDefaults.standard.removeObject(forKey: "lastSyncDate")
        
        coffeeRounds = []
        participants = Participant.defaultParticipants
        rosterState = .initial
        lastSyncDate = nil
        
        await uploadParticipants()
        await saveRosterToCloud()
    }
}
