import SwiftUI

@main
struct GNSSServerApp: App {
    @StateObject private var coordinator = ServerCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
        }
    }
}

