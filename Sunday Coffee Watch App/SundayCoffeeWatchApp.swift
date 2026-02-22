import SwiftUI

@main
struct SundayCoffeeWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = CoffeeStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchContentView()
            }
            .environmentObject(store)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await store.fetchFromCloud() }
                }
            }
        }
    }
}
