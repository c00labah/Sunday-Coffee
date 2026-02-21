import SwiftUI

struct PerformanceView: View {
    @EnvironmentObject var store: CoffeeStore
    @State private var draftCounts: [String: Int] = [:]
    
    private var roster: [Participant] {
        store.participants.sorted { $0.rosterPosition < $1.rosterPosition }
    }
    
    private var leaderboard: [Participant] {
        store.getPerformanceLeaderboard()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F5E6D3").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        inputSection
                        leaderboardSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        for participant in roster {
                            draftCounts[participant.id] = 0
                            store.updateFiredOrPIPs(for: participant.id, count: 0)
                        }
                    }
                    .foregroundColor(Color(hex: "8B4513"))
                }
            }
            .onAppear {
                syncDraftFromStore()
            }
        }
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAST WEEK CHECK-IN")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: "8B7355"))
                .tracking(1)
            
            Text("Fired or put on PIPs")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "8B7355"))
            
            VStack(spacing: 10) {
                ForEach(roster) { participant in
                    HStack(spacing: 12) {
                        Text(participant.avatarEmoji)
                            .font(.system(size: 34))
                        
                        Text(participant.name)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hex: "2C1810"))
                        
                        Spacer()
                        
                        HStack(spacing: 10) {
                            Button {
                                updateCount(for: participant.id, delta: -1)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: "8B7355"))
                            }
                            
                            Text("\(count(for: participant.id))")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "4A2C2A"))
                                .frame(width: 42)
                            
                            Button {
                                updateCount(for: participant.id, delta: 1)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: "8B4513"))
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LEADERBOARD")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: "8B7355"))
                .tracking(1)
            
            VStack(spacing: 10) {
                ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, participant in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "8B7355"))
                            .frame(width: 24)
                        
                        Text(participant.avatarEmoji)
                            .font(.system(size: 34))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(participant.name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(hex: "2C1810"))
                            Text(participant.nickname)
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "8B7355"))
                                .italic()
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(participant.firedOrPIPsLastWeek)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(hex: "8B4513"))
                            Text("fired/PIP")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "8B7355"))
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func syncDraftFromStore() {
        var values: [String: Int] = [:]
        for participant in roster {
            values[participant.id] = participant.firedOrPIPsLastWeek
        }
        draftCounts = values
    }
    
    private func count(for participantID: String) -> Int {
        draftCounts[participantID] ?? 0
    }
    
    private func updateCount(for participantID: String, delta: Int) {
        let current = count(for: participantID)
        let next = max(0, min(999, current + delta))
        draftCounts[participantID] = next
        store.updateFiredOrPIPs(for: participantID, count: next)
    }
}

#Preview {
    PerformanceView()
        .environmentObject(CoffeeStore())
}
