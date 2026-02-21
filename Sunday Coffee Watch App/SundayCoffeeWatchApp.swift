import SwiftUI

@main
struct SundayCoffeeWatchApp: App {
    @StateObject private var store = CoffeeStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchContentView()
            }
            .environmentObject(store)
        }
    }
}
