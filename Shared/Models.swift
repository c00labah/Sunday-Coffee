import Foundation
import SwiftUI
import CloudKit

// MARK: - Participant Model
struct Participant: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var nickname: String
    var roundsPaid: Int
    var roundsAttended: Int
    var lastPaidDate: Date?
    var avatarEmoji: String
    var isCurrentUser: Bool
    var rosterPosition: Int
    
    var paymentBalance: Int {
        // Positive = paid more than attended, Negative = attended more than paid
        // But for leaderboard purposes, we show rounds paid
        roundsPaid
    }
    
    var balanceDescription: String {
        if roundsPaid > roundsAttended {
            return "+\(roundsPaid - roundsAttended) ahead"
        } else if roundsPaid < roundsAttended {
            return "\(roundsPaid - roundsAttended) behind"
        } else {
            return "Square"
        }
    }
    
    static let rosterOrder = ["paul", "justin", "johnny", "jonny", "cliff", "barry", "tim"]
    
    static let defaultParticipants: [Participant] = [
        Participant(id: "paul", name: "Paul", nickname: "The Billable Hour",
                    roundsPaid: 0, roundsAttended: 0, lastPaidDate: nil,
                    avatarEmoji: "⚖️", isCurrentUser: false, rosterPosition: 0),
        Participant(id: "justin", name: "Justin", nickname: "The Cardio King",
                    roundsPaid: 0, roundsAttended: 0, lastPaidDate: nil,
                    avatarEmoji: "🏃", isCurrentUser: false, rosterPosition: 1),
        Participant(id: "johnny", name: "Johnny", nickname: "The Waitress Whisperer",
                    roundsPaid: 0, roundsAttended: 0, lastPaidDate: nil,
                    avatarEmoji: "🎭", isCurrentUser: false, rosterPosition: 2),
        Participant(id: "jonny", name: "Jonny", nickname: "Diamond Ring Maybe",
                    roundsPaid: 0, roundsAttended: 0, lastPaidDate: nil,
                    avatarEmoji: "⚾️", isCurrentUser: false, rosterPosition: 3),
        Participant(id: "cliff", name: "Cliff", nickname: "Cardiac Cliff",
                    roundsPaid: 0, roundsAttended: 0, lastPaidDate: nil,
                    avatarEmoji: "❤️‍🩹", isCurrentUser: false, rosterPosition: 4),
        Participant(id: "barry", name: "Barry", nickname: "The Silverback",
                    roundsPaid: 0, roundsAttended: 0, lastPaidDate: nil,
                    avatarEmoji: "🦁", isCurrentUser: false, rosterPosition: 5),
        Participant(id: "tim", name: "Tim", nickname: "The Mystery Man",
                    roundsPaid: 0, roundsAttended: 0, lastPaidDate: nil,
                    avatarEmoji: "🎯", isCurrentUser: false, rosterPosition: 6)
    ]
    
    // MARK: - CloudKit
    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "Participant", recordID: recordID)
        record["name"] = name
        record["nickname"] = nickname
        record["roundsPaid"] = roundsPaid
        record["roundsAttended"] = roundsAttended
        record["lastPaidDate"] = lastPaidDate
        record["avatarEmoji"] = avatarEmoji
        record["rosterPosition"] = rosterPosition
        return record
    }
    
    init?(from record: CKRecord) {
        guard let name = record["name"] as? String,
              let nickname = record["nickname"] as? String,
              let roundsPaid = record["roundsPaid"] as? Int,
              let roundsAttended = record["roundsAttended"] as? Int,
              let avatarEmoji = record["avatarEmoji"] as? String,
              let rosterPosition = record["rosterPosition"] as? Int else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.name = name
        self.nickname = nickname
        self.roundsPaid = roundsPaid
        self.roundsAttended = roundsAttended
        self.lastPaidDate = record["lastPaidDate"] as? Date
        self.avatarEmoji = avatarEmoji
        self.isCurrentUser = false
        self.rosterPosition = rosterPosition
    }
    
    init(id: String, name: String, nickname: String, roundsPaid: Int, roundsAttended: Int, lastPaidDate: Date?, avatarEmoji: String, isCurrentUser: Bool, rosterPosition: Int) {
        self.id = id
        self.name = name
        self.nickname = nickname
        self.roundsPaid = roundsPaid
        self.roundsAttended = roundsAttended
        self.lastPaidDate = lastPaidDate
        self.avatarEmoji = avatarEmoji
        self.isCurrentUser = isCurrentUser
        self.rosterPosition = rosterPosition
    }
}

// MARK: - Coffee Round
struct CoffeeRound: Identifiable, Codable {
    let id: String
    var date: Date
    var payerID: String
    var attendeeIDs: [String]
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: date)
    }
    
    // MARK: - CloudKit
    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "CoffeeRound", recordID: recordID)
        record["date"] = date
        record["payerID"] = payerID
        record["attendeeIDs"] = attendeeIDs
        return record
    }
    
    init?(from record: CKRecord) {
        guard let date = record["date"] as? Date,
              let payerID = record["payerID"] as? String,
              let attendeeIDs = record["attendeeIDs"] as? [String] else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.date = date
        self.payerID = payerID
        self.attendeeIDs = attendeeIDs
    }
    
    init(id: String, date: Date, payerID: String, attendeeIDs: [String]) {
        self.id = id
        self.date = date
        self.payerID = payerID
        self.attendeeIDs = attendeeIDs
    }
}

// MARK: - Roster State
struct RosterState: Codable {
    var cursor: Int  // Index into rosterOrder for tie-breaking
    var lastUpdated: Date
    
    static let initial = RosterState(cursor: 0, lastUpdated: Date())
    
    // MARK: - CloudKit
    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: "roster-state")
        let record = CKRecord(recordType: "RosterState", recordID: recordID)
        record["cursor"] = cursor
        record["lastUpdated"] = lastUpdated
        return record
    }
    
    init?(from record: CKRecord) {
        guard let cursor = record["cursor"] as? Int,
              let lastUpdated = record["lastUpdated"] as? Date else {
            return nil
        }
        
        self.cursor = cursor
        self.lastUpdated = lastUpdated
    }
    
    init(cursor: Int, lastUpdated: Date) {
        self.cursor = cursor
        self.lastUpdated = lastUpdated
    }
}
