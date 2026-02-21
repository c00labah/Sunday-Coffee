import SwiftUI

struct PaymentView: View {
    @EnvironmentObject var store: CoffeeStore
    @State private var attendees: Set<String> = []
    @State private var showConfirmation = false
    @State private var confirmedPayer: Participant?
    
    var attendeeList: [Participant] {
        store.participants.filter { attendees.contains($0.id) }
    }
    
    var todaysPayer: Participant? {
        store.getTodaysPayer(attendees: attendeeList)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F5E6D3").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Who's paying - single card at top
                        payerCard
                        
                        // Attendance checkboxes
                        attendanceSection
                        
                        // Confirm button
                        confirmButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Sunday Coffee")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                attendees = Set(store.participants.map { $0.id })
            }
            .alert("Payment Recorded! ☕️", isPresented: $showConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                if let payer = confirmedPayer {
                    Text("\(payer.name) got this round!")
                }
            }
        }
    }
    
    // MARK: - Payer Card
    private var payerCard: some View {
        VStack(spacing: 0) {
            if let payer = todaysPayer {
                VStack(spacing: 8) {
                    Text(payer.avatarEmoji)
                        .font(.system(size: 70))
                    
                    Text(payer.name)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(hex: "4A2C2A"))
                    
                    Text(payer.nickname)
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "8B7355"))
                        .italic()
                    
                    Text("is paying")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: "8B4513"))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "8B4513"), lineWidth: 2)
                        )
                )
            } else {
                // No one selected yet
                VStack(spacing: 8) {
                    Text("☕️")
                        .font(.system(size: 70))
                    
                    Text("Select who's here")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "8B7355"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                )
            }
        }
    }
    
    // MARK: - Attendance Section
    private var attendanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WHO'S HERE?")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "8B7355"))
                    .tracking(1)
                
                Spacer()
                
                Button(attendees.count == store.participants.count ? "None" : "All") {
                    if attendees.count == store.participants.count {
                        attendees.removeAll()
                    } else {
                        attendees = Set(store.participants.map { $0.id })
                    }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "8B4513"))
            }
            
            VStack(spacing: 8) {
                ForEach(store.participants) { p in
                    Button {
                        if attendees.contains(p.id) {
                            attendees.remove(p.id)
                        } else {
                            attendees.insert(p.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(p.avatarEmoji)
                                .font(.system(size: 32))
                            
                            Text(p.name)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(hex: "2C1810"))
                            
                            Spacer()
                            
                            Image(systemName: attendees.contains(p.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 28))
                                .foregroundColor(attendees.contains(p.id) ? Color(hex: "8B4513") : Color(hex: "CCCCCC"))
                        }
                        .padding(14)
                        .background(attendees.contains(p.id) ? Color(hex: "8B4513").opacity(0.1) : Color.white)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - Confirm Button
    private var confirmButton: some View {
        Button {
            recordPayment()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                Text("Confirm Payment")
            }
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(attendeeList.count >= 2 ? Color(hex: "8B4513") : Color.gray)
            .cornerRadius(14)
        }
        .disabled(attendeeList.count < 2)
    }
    
    // MARK: - Actions
    private func recordPayment() {
        guard let payer = todaysPayer else { return }
        
        store.recordPayment(
            payerID: payer.id,
            attendeeIDs: Array(attendees)
        )
        
        confirmedPayer = payer
        showConfirmation = true
        
        // Reset to everyone here for next time
        attendees = Set(store.participants.map { $0.id })
    }
}

#Preview {
    PaymentView()
        .environmentObject(CoffeeStore())
}
