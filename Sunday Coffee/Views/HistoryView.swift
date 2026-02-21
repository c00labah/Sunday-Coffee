import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: CoffeeStore
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F5E6D3").ignoresSafeArea()
                
                if store.coffeeRounds.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.coffeeRounds) { round in
                                roundCard(round)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Text("☕️")
                .font(.system(size: 80))
            
            Text("No coffees yet")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Color(hex: "4A2C2A"))
            
            Text("Record your first coffee payment!")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "8B7355"))
        }
    }
    
    private func roundCard(_ round: CoffeeRound) -> some View {
        let payer = store.participants.first { $0.id == round.payerID }
        let attendeeCount = round.attendeeIDs.count
        
        return HStack(spacing: 16) {
            Text(payer?.avatarEmoji ?? "☕️")
                .font(.system(size: 44))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(payer?.name ?? "Unknown")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "2C1810"))
                
                Text("\(attendeeCount) people")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "8B7355"))
            }
            
            Spacer()
            
            Text(round.formattedDate)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "8B7355"))
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
    }
}

#Preview {
    HistoryView()
        .environmentObject(CoffeeStore())
}
