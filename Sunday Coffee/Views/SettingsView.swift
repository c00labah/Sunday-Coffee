import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: CoffeeStore
    @State private var showResetAlert = false
    
    var currentUser: Participant? {
        store.participants.first { $0.id == store.currentUserID }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F5E6D3").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Sync status
                        syncStatusSection
                        
                        // Profile
                        profileSection
                        
                        // Danger zone
                        dangerSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Reset All Data?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    Task { await store.resetAllData() }
                }
            } message: {
                Text("This will clear all payment history and balances for everyone. This cannot be undone.")
            }
        }
    }
    
    // MARK: - Sync Status
    private var syncStatusSection: some View {
        HStack(spacing: 12) {
            if store.isSyncing {
                ProgressView()
                    .scaleEffect(1.0)
                Text("Syncing...")
                    .font(.system(size: 17))
                    .foregroundColor(Color(hex: "8B7355"))
            } else if store.cloudKitAvailable {
                Image(systemName: "checkmark.icloud")
                    .font(.system(size: 22))
                    .foregroundColor(Color(hex: "2E7D32"))
                Text("Synced with iCloud")
                    .font(.system(size: 17))
                    .foregroundColor(Color(hex: "2E7D32"))
            } else {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 22))
                    .foregroundColor(.orange)
                Text("Local only")
                    .font(.system(size: 17))
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            if store.cloudKitAvailable {
                Button {
                    Task { await store.fetchFromCloud() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "8B4513"))
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
    }
    
    // MARK: - Profile
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROFILE")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: "8B7355"))
                .tracking(1)
            
            if let user = currentUser {
                HStack(spacing: 16) {
                    Text(user.avatarEmoji)
                        .font(.system(size: 60))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "2C1810"))
                        Text(user.nickname)
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "8B7355"))
                            .italic()
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
                
                HStack(spacing: 12) {
                    statBox(value: "\(user.roundsPaid)", label: "Paid")
                    statBox(value: "\(user.roundsAttended)", label: "Attended")
                    let balance = user.roundsPaid - user.roundsAttended
                    statBox(value: "\(balance >= 0 ? "+" : "")\(balance)", label: "Balance")
                }
            }
        }
    }
    
    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Color(hex: "4A2C2A"))
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "8B7355"))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
    
    // MARK: - Danger Zone
    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DANGER ZONE")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: "C62828"))
                .tracking(1)
            
            Button {
                showResetAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                    Text("Reset All Data")
                        .font(.system(size: 18))
                    Spacer()
                }
                .foregroundColor(Color(hex: "C62828"))
                .padding(16)
                .background(Color(hex: "C62828").opacity(0.1))
                .cornerRadius(14)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(CoffeeStore())
}
