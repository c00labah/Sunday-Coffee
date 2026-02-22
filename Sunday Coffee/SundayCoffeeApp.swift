import SwiftUI

@main
struct SundayCoffeeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = CoffeeStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await store.fetchFromCloud() }
                    }
                }
        }
    }
}
