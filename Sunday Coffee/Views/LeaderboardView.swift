import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var store: CoffeeStore
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F5E6D3").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Podium
                        podiumSection
                        
                        // Full standings
                        standingsSection
                        
                        // Stats
                        statsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Podium
    private var podiumSection: some View {
        let leaderboard = store.getLeaderboard()
        
        return HStack(alignment: .bottom, spacing: 8) {
            // 2nd place
            if leaderboard.count > 1 {
                podiumCard(leaderboard[1], position: 2, extraHeight: 0)
            }
            
            // 1st place
            if !leaderboard.isEmpty {
                podiumCard(leaderboard[0], position: 1, extraHeight: 30)
            }
            
            // 3rd place
            if leaderboard.count > 2 {
                podiumCard(leaderboard[2], position: 3, extraHeight: 0)
            }
        }
        .padding(.top, 20)
    }
    
    private func podiumCard(_ participant: Participant, position: Int, extraHeight: CGFloat) -> some View {
        let colors: [Color] = [Color(hex: "FFD700"), Color(hex: "C0C0C0"), Color(hex: "CD7F32")]
        let color = colors[position - 1]
        let medals = ["🥇", "🥈", "🥉"]
        
        // Base height for all cards ensures numbers align
        let baseHeight: CGFloat = 140
        
        return VStack(spacing: 8) {
            Text(medals[position - 1])
                .font(.system(size: 26))
            
            Text(participant.avatarEmoji)
                .font(.system(size: position == 1 ? 44 : 36))
            
            Text(participant.name)
                .font(.system(size: position == 1 ? 18 : 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 4)
            
            Text("\(participant.roundsPaid)")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white.opacity(0.95))
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .frame(height: baseHeight + extraHeight)
        .background(
            LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        )
        .cornerRadius(16)
    }
    
    // MARK: - Standings
    private var standingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FULL STANDINGS")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: "8B7355"))
                .tracking(1)
            
            VStack(spacing: 10) {
                ForEach(Array(store.getLeaderboard().enumerated()), id: \.element.id) { index, p in
                    HStack(spacing: 14) {
                        Text("\(index + 1)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "8B7355"))
                            .frame(width: 28)
                        
                        Text(p.avatarEmoji)
                            .font(.system(size: 36))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(hex: "2C1810"))
                            Text(p.nickname)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "8B7355"))
                                .italic()
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(p.roundsPaid)")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color(hex: "8B4513"))
                            
                            Text(p.roundsPaid == 1 ? "round" : "rounds")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "8B7355"))
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(14)
                }
            }
        }
    }
    
    // MARK: - Stats
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STATS")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: "8B7355"))
                .tracking(1)
            
            HStack(spacing: 12) {
                statCard(value: "\(store.totalRounds)", label: "Rounds", icon: "cup.and.saucer.fill")
                statCard(value: "\(store.participants.count)", label: "Members", icon: "person.3.fill")
            }
        }
    }
    
    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(Color(hex: "8B4513"))
            
            Text(value)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Color(hex: "2C1810"))
            
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "8B7355"))
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color.white)
        .cornerRadius(14)
    }
}

#Preview {
    LeaderboardView()
        .environmentObject(CoffeeStore())
}
