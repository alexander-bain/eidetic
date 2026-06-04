import SwiftUI
import CoreLocation

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
    @State private var timeMachineChapters: [TimeMachineChapter] = []
    @State private var mapStops: [MapStop] = []
    @State private var sameSpotSelection: [AnalyzedPhoto] = []
    @State private var postcardTrip: PostcardTrip?

    // The curator writes a gallery placard for each segment.
    private let curator = Curator()
    @State private var placard: CuratedPlacard?
    @State private var placardReady = false
    @State private var showPlacard = false
    @State private var placardTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if photoProvider.isLoading {
                loadingView
            } else if photoProvider.photos.isEmpty && hasStarted {
                onboardingView
            } else if photoProvider.photos.isNotEmpty {
                cyclerView
                placardOverlay
                controlsOverlay
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear { startIfNeeded() }
        .onDisappear {
            controlsTimer?.invalidate()
            controlsTimer = nil
            placardTask?.cancel()
        }
        .onChange(of: coordinator.currentMode) { _, _ in
            refreshSelections()
        }
        .onChange(of: photoProvider.favoritesOnly) { _, _ in
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
            case .timeMachineRadio:
                TimeMachineRadioView(chapters: timeMachineChapters)
                    .transition(.opacity)
            case .mapRoom:
                MapRoomView(stops: mapStops)
                    .transition(.opacity)
            case .sameSpot:
                SameSpotView(photos: sameSpotSelection)
                    .transition(.opacity)
            case .reversePostcard:
                ReversePostcardView(trip: postcardTrip)
                    .transition(.opacity)
            }
        }
        .opacity(coordinator.isTransitioning ? 0 : 1)
        .animation(.easeInOut(duration: 1.5), value: coordinator.currentMode)
    }

    @ViewBuilder
    private var placardOverlay: some View {
        VStack(spacing: 10) {
            if placardReady, let placard {
                Text(placard.title)
                    .font(.system(size: 36, weight: .ultraLight, design: .serif))
                    .foregroundColor(.white.opacity(0.95))
                if !placard.subtitle.isEmpty {
                    Text(placard.subtitle.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(4)
                        .foregroundColor(.white.opacity(0.55))
                }
            } else {
                // Don't show copy we know isn't ready — show progress instead.
                ProgressView()
                    .controlSize(.small)
                    .tint(.white.opacity(0.5))
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 12, y: 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 64)
        .opacity(showPlacard ? 1 : 0)
        .animation(.easeInOut(duration: 1.2), value: showPlacard)
        .allowsHitTesting(false)
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

    private static let mapDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private func refreshSelections() {
        magazineSelection = photoProvider.randomPhotos(24)
        colorSelection = photoProvider.photosSortedByHue()
        timelineSelection = photoProvider.splitTimelinePhotos()
        refreshTimeMachine()
        mapStops = photoProvider.locatedPhotos().compactMap { photo in
            guard let location = photo.location else { return nil }
            let dateString = photo.creationDate.map(Self.mapDateFormatter.string) ?? ""
            return MapStop(photo: photo, coordinate: location.coordinate, dateString: dateString)
        }
        sameSpotSelection = photoProvider.sameSpotPhotos()
        postcardTrip = photoProvider.reversePostcardTrip()
        refreshPlacard()
    }

    /// Builds the Time Machine chapters (instant templated narration), then lets
    /// the on-device curator rewrite the per-year lines in the background.
    private func refreshTimeMachine() {
        let entries = photoProvider.thisWeekAcrossYears()
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"

        let memoirYears: [MemoirYear] = entries.map { entry in
            let month = entry.photos.first?.creationDate.map(monthFormatter.string) ?? "that week"
            return MemoirYear(year: entry.year, count: entry.photos.count, monthName: month)
        }
        let lines = Curator.memoirFactual(for: memoirYears)

        timeMachineChapters = entries.map { entry in
            let representative = entry.photos
                .sorted { lhs, rhs in
                    if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
                    if lhs.isUtility != rhs.isUtility { return !lhs.isUtility }
                    return lhs.aestheticsScore > rhs.aestheticsScore
                }
                .first ?? entry.photos[0]
            return TimeMachineChapter(year: entry.year, photo: representative, line: lines[entry.year] ?? "")
        }
    }

    /// Shows a progress indicator until the curator's (grounded) copy is ready,
    /// then reveals it — never flashing copy we know isn't good — and fades out.
    private func refreshPlacard() {
        let context = currentContext()
        placardReady = false
        withAnimation(.easeInOut(duration: 0.5)) { showPlacard = true }

        placardTask?.cancel()
        placardTask = Task {
            let copy = await curator.placard(for: context)
            if Task.isCancelled { return }
            placard = copy
            withAnimation(.easeInOut(duration: 0.8)) { placardReady = true }
            try? await Task.sleep(for: .seconds(8))
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 1.2)) { showPlacard = false }
            }
        }
    }

    private func currentContext() -> SegmentContext {
        let photos: [AnalyzedPhoto]
        switch coordinator.currentMode {
        case .magazineSpread: photos = magazineSelection
        case .colorSort: photos = colorSelection
        case .splitTimeline: photos = timelineSelection.map(\.1)
        case .timeMachineRadio: photos = timeMachineChapters.map(\.photo)
        case .mapRoom: photos = mapStops.map(\.photo)
        case .sameSpot: photos = sameSpotSelection
        case .reversePostcard: photos = postcardTrip?.photos ?? []
        }

        let years = Array(Set(photos.compactMap(\.year))).sorted()
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        let currentYear = calendar.component(.year, from: now)
        let onThisDay = photos.contains { photo in
            guard let date = photo.creationDate else { return false }
            return calendar.component(.month, from: date) == month
                && abs(calendar.component(.day, from: date) - day) <= 3
                && calendar.component(.year, from: date) != currentYear
        }
        let allFavorites = !photos.isEmpty && photos.allSatisfy(\.isFavorite)

        return SegmentContext(
            mode: coordinator.currentMode,
            photoCount: photos.count,
            years: years,
            onThisDay: onThisDay,
            allFavorites: allFavorites
        )
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
