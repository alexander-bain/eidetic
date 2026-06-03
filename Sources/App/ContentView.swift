import SwiftUI

struct ContentView: View {
    @EnvironmentObject var photoProvider: PhotoProvider
    @EnvironmentObject var coordinator: ModeCoordinator
    @State private var hasStarted = false
    @State private var showControls = false
    @State private var controlsTimer: Timer?

    // Per-mode photo selections, refreshed when a mode begins rather than on
    // every render — so hovering or background photo loading doesn't reshuffle
    // what's on screen mid-animation.
    @State private var magazineSelection: [AnalyzedPhoto] = []
    @State private var colorSelection: [AnalyzedPhoto] = []
    @State private var timelineSelection: [(Int, AnalyzedPhoto)] = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if photoProvider.isLoading {
                loadingView
            } else if photoProvider.photos.isEmpty && hasStarted {
                onboardingView
            } else if photoProvider.photos.isNotEmpty {
                cyclerView
                controlsOverlay
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear { startIfNeeded() }
        .onDisappear {
            controlsTimer?.invalidate()
            controlsTimer = nil
        }
        .onChange(of: coordinator.currentMode) { _, _ in
            refreshSelections()
        }
        .onHover { hovering in
            if hovering { showControlsBriefly() }
        }
        .onKeyPress(.rightArrow) {
            coordinator.skipToNext()
            return .handled
        }
        .onKeyPress(.space) {
            coordinator.stayAwake.toggle()
            return .handled
        }
        .onKeyPress("f") {
            toggleFullScreen()
            return .handled
        }
    }

    @ViewBuilder
    private var cyclerView: some View {
        ZStack {
            switch coordinator.currentMode {
            case .magazineSpread:
                MagazineSpreadView(photos: magazineSelection)
                    .transition(.opacity)
            case .splitTimeline:
                SplitTimelineView(photosByYear: timelineSelection)
                    .transition(.opacity)
            case .colorSort:
                ColorSortView(photos: colorSelection)
                    .transition(.opacity)
            }
        }
        .opacity(coordinator.isTransitioning ? 0 : 1)
        .animation(.easeInOut(duration: 1.5), value: coordinator.currentMode)
    }

    @ViewBuilder
    private var controlsOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 16) {
                    Image(systemName: coordinator.isPaused ? "pause.fill" : coordinator.currentMode.systemImage)
                        .font(.system(size: 12))
                    Text(coordinator.currentMode.rawValue)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))

                    Divider()
                        .frame(height: 12)

                    Image(systemName: coordinator.stayAwake ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 11))

                    Text("\(photoProvider.photos.count) photos")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(Capsule())
                .padding(20)
            }
        }
        .opacity(showControls ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: showControls)
    }

    private var loadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 3)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: photoProvider.loadingProgress)
                    .stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: photoProvider.loadingProgress)
            }
            Text("Loading photos\u{2026}")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(.white.opacity(0.5))
            Text("\(Int(photoProvider.loadingProgress * 100))%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
        }
    }

    private var onboardingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(.white.opacity(0.3))
                .padding(.bottom, 8)

            Text("Eidetic")
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundColor(.white.opacity(0.8))

            Text("Grant photo access to get started")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))

            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.3))
            .padding(.top, 8)
        }
    }

    private func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        Task {
            await photoProvider.requestAuthorization()
            await photoProvider.loadPhotos()
            if photoProvider.photos.isNotEmpty {
                refreshSelections()
                coordinator.startCycling()
            }
        }
    }

    private func refreshSelections() {
        magazineSelection = photoProvider.randomPhotos(24)
        colorSelection = photoProvider.photosSortedByHue()
        timelineSelection = photoProvider.splitTimelinePhotos()
    }

    private func showControlsBriefly() {
        showControls = true
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            Task { @MainActor in
                showControls = false
            }
        }
    }

    private func toggleFullScreen() {
        guard let window = NSApplication.shared.windows.first else { return }
        window.toggleFullScreen(nil)
    }
}
