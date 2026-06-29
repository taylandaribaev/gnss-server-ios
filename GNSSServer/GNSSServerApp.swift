import SwiftUI

@main
struct GNSSServerApp: App {
    @StateObject private var coordinator = ServerCoordinator()

    init() {
        AppLogger.shared.info(.app, "GNSS Server app launched")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
        }
    }
}
