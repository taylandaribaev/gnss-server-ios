import SwiftUI

@main
struct GNSSServerApp: App {
    init() {
        AppLogger.shared.info(.app, "GPS Server app launched")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ServerCoordinator.shared)
        }
    }
}
