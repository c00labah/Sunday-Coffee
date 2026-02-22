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
    private var pendingRefreshTask: Task<Void, Never>?
    private let cloudKitContainerIdentifier = "iCloud.com.sundaycoffee.app"
    
    // Record types
    private let participantRecordType = "Participant"
    private let roundRecordType = "CoffeeRound"
    private let rosterRecordType = "RosterState"
    private let roundIndexRecordType = "RoundIndex"
    private let roundIndexRecordName = "coffee-round-index"
    
    init() {
        loadLocalData()
        checkCloudKitAvailability()
    }
    
    private func isMissingRecordTypeError(_ error: Error) -> Bool {
        error.localizedDescription.contains("Did not find record type")
    }
    
    private func isNotQueryableFieldError(_ error: Error) -> Bool {
        error.localizedDescription.contains("not marked queryable")
    }
    
    private func isUnknownItemError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        if ckError.code == .unknownItem {
            return true
        }
        if ckError.code == .partialFailure,
           let partial = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            return partial.values.allSatisfy { ($0 as? CKError)?.code == .unknownItem }
        }
        return false
    }
    
    private func fetchParticipantFromCloud(id: String) async throws -> Participant? {
        guard let database else { return nil }
        let recordID = CKRecord.ID(recordName: id)
        do {
            let record = try await database.record(for: recordID)
            return Participant(from: record)
        } catch {
            if isUnknownItemError(error) {
                return nil
            }
            throw error
        }
    }
    
    private func fetchRosterStateFromCloud() async throws -> RosterState? {
        guard let database else { return nil }
        let recordID = CKRecord.ID(recordName: "roster-state")
        do {
            let record = try await database.record(for: recordID)
            return RosterState(from: record)
        } catch {
            if isUnknownItemError(error) {
                return nil
            }
            throw error
        }
    }
    
    private func fetchCoffeeRoundFromCloud(id: String) async throws -> CoffeeRound? {
        guard let database else { return nil }
        let recordID = CKRecord.ID(recordName: id)
        do {
            let record = try await database.record(for: recordID)
            return CoffeeRound(from: record)
        } catch {
            if isUnknownItemError(error) {
                return nil
            }
            throw error
        }
    }
    
    private func fetchRoundIndexFromCloud() async throws -> [String]? {
        guard let database else { return nil }
        let recordID = CKRecord.ID(recordName: roundIndexRecordName)
        do {
            let record = try await database.record(for: recordID)
            return record["roundIDs"] as? [String] ?? []
        } catch {
            if isUnknownItemError(error) {
                return nil
            }
            throw error
        }
    }
    
    private func saveRoundIndexToCloud(_ roundIDs: [String]) async {
        guard let database else { return }
        let recordID = CKRecord.ID(recordName: roundIndexRecordName)
        let record = CKRecord(recordType: roundIndexRecordType, recordID: recordID)
        record["roundIDs"] = roundIDs
        record["lastUpdated"] = Date()
        
        do {
            _ = try await database.save(record)
        } catch {
            print("Error saving round index: \(error)")
        }
    }
    
    private func appendRoundIDToCloudIndex(_ roundID: String) async {
        let existing = (try? await fetchRoundIndexFromCloud()) ?? []
        if existing.contains(roundID) { return }
        await saveRoundIndexToCloud(existing + [roundID])
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
        guard database != nil else {
            syncError = "CloudKit not configured"
            return
        }
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Fetch participants by known IDs (avoids CloudKit query/index requirements on recordName).
            var fetchedParticipants: [Participant] = []
            for participantID in Participant.rosterOrder {
                if let participant = try await fetchParticipantFromCloud(id: participantID) {
                    fetchedParticipants.append(participant)
                }
            }
            
            if fetchedParticipants.count == Participant.defaultParticipants.count {
                participants = fetchedParticipants.sorted { $0.rosterPosition < $1.rosterPosition }
            } else {
                let fetchedByID = Dictionary(uniqueKeysWithValues: fetchedParticipants.map { ($0.id, $0) })
                let mergedParticipants = Participant.defaultParticipants.map { fetchedByID[$0.id] ?? $0 }
                
                participants = mergedParticipants.sorted { $0.rosterPosition < $1.rosterPosition }
                
                // If CloudKit is fresh or partially seeded, push the full roster to bootstrap/repair it.
                if fetchedParticipants.count < Participant.defaultParticipants.count {
                    await uploadParticipants()
                }
            }
            
            // Fetch roster state by fixed ID (avoids query/index requirements).
            do {
                if let state = try await fetchRosterStateFromCloud() {
                    rosterState = state
                } else {
                    rosterState = .initial
                    await saveRosterToCloud()
                }
            }
            
            // Fetch coffee rounds via index record (avoids CloudKit query-index requirements).
            do {
                let roundIDsFromIndex = try await fetchRoundIndexFromCloud()
                let roundIDs: [String]
                
                if let indexedIDs = roundIDsFromIndex {
                    roundIDs = indexedIDs
                } else {
                    // Migrate to index-based syncing using local history if available.
                    let localRoundIDs = coffeeRounds.map(\.id)
                    roundIDs = localRoundIDs
                    if !localRoundIDs.isEmpty {
                        await saveRoundIndexToCloud(localRoundIDs)
                    }
                }
                
                var fetchedRounds: [CoffeeRound] = []
                var validRoundIDs: [String] = []
                for roundID in roundIDs {
                    if let round = try await fetchCoffeeRoundFromCloud(id: roundID) {
                        fetchedRounds.append(round)
                        validRoundIDs.append(roundID)
                    }
                }
                
                if validRoundIDs.count != roundIDs.count {
                    // Prune stale IDs if records were removed or failed to save previously.
                    await saveRoundIndexToCloud(validRoundIDs)
                }
                
                coffeeRounds = fetchedRounds.sorted { $0.date > $1.date }
            } catch {
                if isMissingRecordTypeError(error) {
                    coffeeRounds = []
                } else {
                    throw error
                }
            }
            
            lastSyncDate = Date()
            
            saveLocal()
            isSyncing = false
            
        } catch {
            print("CloudKit fetch error: \(error)")
            syncError = error.localizedDescription
            isSyncing = false
        }
    }
    
    func scheduleCloudRefresh(after delaySeconds: Double = 1.5) {
        guard cloudKitAvailable else { return }
        
        pendingRefreshTask?.cancel()
        pendingRefreshTask = Task { @MainActor in
            let nanos = UInt64(max(0, delaySeconds) * 1_000_000_000)
            if nanos > 0 {
                try? await Task.sleep(nanoseconds: nanos)
            }
            guard !Task.isCancelled else { return }
            
            // If a sync is already running, wait briefly and try once more.
            if isSyncing {
                try? await Task.sleep(nanoseconds: 750_000_000)
                guard !Task.isCancelled else { return }
            }
            await fetchFromCloud()
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
    
    private func saveRoundToCloud(_ round: CoffeeRound) async -> Bool {
        guard let database = database else { return false }
        let record = round.toRecord()
        do {
            _ = try await database.save(record)
            return true
        } catch {
            print("Error saving round: \(error)")
            return false
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
        let n = order.count
        let cursor = ((rosterState.cursor % max(n, 1)) + max(n, 1)) % max(n, 1)
        let attendeeIDs = Set(attendees.map(\.id))
        let attendeesByID = Dictionary(uniqueKeysWithValues: attendees.map { ($0.id, $0) })
        
        // Pure round-robin: choose the first attendee encountered when scanning
        // forward through roster order from the current cursor.
        for offset in 0..<n {
            let candidateID = order[(cursor + offset) % n]
            if attendeeIDs.contains(candidateID), let participant = attendeesByID[candidateID] {
                return participant
            }
        }
        
        // Fallback for any unexpected ID mismatch.
        return attendees.sorted { $0.rosterPosition < $1.rosterPosition }.first
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
        
        // Advance cursor to the person after the payer for the next round-robin choice.
        let order = Participant.rosterOrder
        if let payerIndex = order.firstIndex(of: payerID) {
            rosterState.cursor = (payerIndex + 1) % order.count
            rosterState.lastUpdated = Date()
            Task { await saveRosterToCloud() }
        }
        
        saveLocal()
        Task {
            if await saveRoundToCloud(round) {
                await appendRoundIDToCloudIndex(round.id)
            }
        }
        scheduleCloudRefresh()
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
