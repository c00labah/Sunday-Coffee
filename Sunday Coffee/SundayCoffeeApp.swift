import SwiftUI

@main
struct SundayCoffeeApp: App {
    @StateObject private var store = CoffeeStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
