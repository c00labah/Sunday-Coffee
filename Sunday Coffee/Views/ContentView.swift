import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: CoffeeStore
    
    var body: some View {
        if store.currentUserID == nil {
            OnboardingView()
        } else {
            TabView {
                PaymentView()
                    .tabItem {
                        Label("Pay", systemImage: "dollarsign.circle.fill")
                    }
                
                PerformanceView()
                    .tabItem {
                        Label("Performance", systemImage: "person.3.sequence.fill")
                    }
                
                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "clock.fill")
                    }
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .tint(Color(hex: "8B4513"))
        }
    }
}

// MARK: - Onboarding
struct OnboardingView: View {
    @EnvironmentObject var store: CoffeeStore
    @State private var selected: String?
    
    var body: some View {
        ZStack {
            Color(hex: "F5E6D3").ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)
                    
                    Text("☕️")
                        .font(.system(size: 80))
                    
                    Text("Sunday Coffee")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "4A2C2A"))
                    
                    Text("Who are you?")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Color(hex: "8B7355"))
                    
                    VStack(spacing: 14) {
                        ForEach(Participant.defaultParticipants) { p in
                            Button {
                                selected = p.id
                            } label: {
                                HStack(spacing: 16) {
                                    Text(p.avatarEmoji)
                                        .font(.system(size: 40))
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(p.name)
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundColor(Color(hex: "2C1810"))
                                        Text(p.nickname)
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(hex: "8B7355"))
                                    }
                                    
                                    Spacer()
                                    
                                    if selected == p.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(Color(hex: "8B4513"))
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(selected == p.id ? Color(hex: "8B4513").opacity(0.1) : Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selected == p.id ? Color(hex: "8B4513") : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Button {
                        if let id = selected {
                            store.registerUser(as: id)
                        }
                    } label: {
                        Text("Continue")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(18)
                            .background(selected != nil ? Color(hex: "8B4513") : Color.gray)
                            .cornerRadius(14)
                    }
                    .disabled(selected == nil)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

#Preview {
    ContentView()
        .environmentObject(CoffeeStore())
}
