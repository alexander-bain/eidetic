import SwiftUI

@main
struct EideticApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var photoProvider = PhotoProvider()
    @StateObject private var coordinator = ModeCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoProvider)
                .environmentObject(coordinator)
                .onAppear { appDelegate.coordinator = coordinator }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
        .commands {
            EideticCommands(coordinator: coordinator)
        }

        Settings {
            SettingsView()
                .environmentObject(photoProvider)
                .environmentObject(coordinator)
        }
    }
}

// MARK: - Lifecycle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var coordinator: ModeCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // Persist window size/position across launches.
        DispatchQueue.main.async {
            NSApp.windows.first?.setFrameAutosaveName("EideticMainWindow")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Release the sleep-prevention assertion cleanly on quit.
        coordinator?.stopCycling()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - Menu bar

struct EideticCommands: Commands {
    @ObservedObject var coordinator: ModeCoordinator

    var body: some Commands {
        CommandMenu("Playback") {
            Button(coordinator.isPaused ? "Play" : "Pause") {
                coordinator.togglePause()
            }
            .keyboardShortcut("p", modifiers: [.command])

            Button("Next Mode") {
                coordinator.skipToNext()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command])

            Divider()

            Toggle("Stay Awake", isOn: $coordinator.stayAwake)
                .keyboardShortcut("l", modifiers: [.command])

            Divider()

            Menu("Switch To") {
                ForEach(DisplayModeType.allCases) { mode in
                    Button {
                        coordinator.jumpTo(mode)
                    } label: {
                        if coordinator.currentMode == mode {
                            Label(mode.rawValue, systemImage: "checkmark")
                        } else {
                            Text(mode.rawValue)
                        }
                    }
                }
            }
        }
    }
}
