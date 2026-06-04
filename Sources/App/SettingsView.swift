import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var photoProvider: PhotoProvider
    @EnvironmentObject var coordinator: ModeCoordinator

    var body: some View {
        Form {
            Section("Display Modes") {
                ForEach(DisplayModeType.allCases) { mode in
                    Toggle(isOn: binding(for: mode)) {
                        Label(mode.rawValue, systemImage: mode.systemImage)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Keep display awake", isOn: $coordinator.stayAwake)
                Toggle("Show favorites only", isOn: $photoProvider.favoritesOnly)
            }

            Section("Library") {
                LabeledContent("Photos loaded", value: "\(photoProvider.photos.count)")
                LabeledContent("Favorites", value: "\(photoProvider.favoritesCount)")
                LabeledContent("Now showing", value: "\(photoProvider.curatedPhotos.count)")
                LabeledContent("On this day", value: "\(photoProvider.photosForToday().count)")
            }

            Section("Keyboard Shortcuts") {
                LabeledContent("Next mode", value: "\u{2192}")
                LabeledContent("Toggle awake", value: "Space")
                LabeledContent("Full screen", value: "F")
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 440)
    }

    private func binding(for mode: DisplayModeType) -> Binding<Bool> {
        Binding(
            get: { coordinator.enabledModes.contains(mode) },
            set: { enabled in
                if enabled {
                    coordinator.enabledModes.insert(mode)
                } else if coordinator.enabledModes.count > 1 {
                    coordinator.enabledModes.remove(mode)
                }
            }
        )
    }
}
