import SwiftUI

@main
struct EideticApp: App {
    @StateObject private var photoProvider = PhotoProvider()
    @StateObject private var coordinator = ModeCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoProvider)
                .environmentObject(coordinator)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)

        Settings {
            SettingsView()
                .environmentObject(photoProvider)
                .environmentObject(coordinator)
        }
    }
}
