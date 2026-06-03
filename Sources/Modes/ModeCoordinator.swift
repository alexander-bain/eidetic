import Foundation
import SwiftUI

@MainActor
class ModeCoordinator: ObservableObject {
    @Published var currentMode: DisplayModeType = .magazineSpread
    @Published var isTransitioning = false
    @Published var isPaused = false
    @Published var stayAwake = true {
        didSet {
            updateSleepPrevention()
            saveSettings()
        }
    }
    @Published var enabledModes: Set<DisplayModeType> = Set(DisplayModeType.allCases) {
        didSet { enabledModesDidChange() }
    }

    private var cycleTimer: Timer?
    private var modeQueue: [DisplayModeType] = []
    private var activityToken: NSObjectProtocol?
    private var isCycling = false

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let stayAwake = "eidetic.stayAwake"
        static let enabledModes = "eidetic.enabledModes"
    }

    init() {
        loadSettings()
    }

    // MARK: - Cycling

    func startCycling() {
        isCycling = true
        resetQueue()
        scheduleNext()
        updateSleepPrevention()
    }

    func stopCycling() {
        isCycling = false
        cycleTimer?.invalidate()
        cycleTimer = nil
        endSleepPrevention()
    }

    func skipToNext() {
        cycleTimer?.invalidate()
        advanceMode()
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            cycleTimer?.invalidate()
            cycleTimer = nil
        } else if isCycling {
            scheduleNext()
        }
    }

    /// Jumps directly to a specific mode (from the menu's mode picker).
    func jumpTo(_ mode: DisplayModeType) {
        cycleTimer?.invalidate()
        guard mode != currentMode else { return }

        withAnimation(.easeOut(duration: 1.5)) {
            isTransitioning = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.currentMode = mode
            self.modeQueue.removeAll { $0 == mode }
            withAnimation(.easeIn(duration: 1.5)) {
                self.isTransitioning = false
            }
            if self.isCycling && !self.isPaused {
                self.scheduleNext()
            }
        }
    }

    private func resetQueue() {
        modeQueue = Array(enabledModes).shuffled()
        modeQueue.removeAll { $0 == currentMode }
    }

    private func scheduleNext() {
        cycleTimer?.invalidate()
        guard !isPaused else { return }
        cycleTimer = Timer.scheduledTimer(
            withTimeInterval: currentMode.duration,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.advanceMode()
            }
        }
    }

    private func advanceMode() {
        if modeQueue.isEmpty { resetQueue() }
        guard let next = modeQueue.first else { return }
        modeQueue.removeFirst()

        withAnimation(.easeOut(duration: 1.5)) {
            isTransitioning = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.currentMode = next
            withAnimation(.easeIn(duration: 1.5)) {
                self.isTransitioning = false
            }
            self.scheduleNext()
        }
    }

    /// Keeps the cycle in sync when the user changes which modes are enabled.
    private func enabledModesDidChange() {
        saveSettings()
        guard isCycling else { return }
        resetQueue()
        if !enabledModes.contains(currentMode) {
            skipToNext()
        }
    }

    // MARK: - Sleep prevention

    private func updateSleepPrevention() {
        endSleepPrevention()
        if stayAwake {
            activityToken = ProcessInfo.processInfo.beginActivity(
                options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled],
                reason: "Eidetic keeping display active"
            )
        }
    }

    private func endSleepPrevention() {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }

    // MARK: - Persistence

    private func loadSettings() {
        if defaults.object(forKey: Keys.stayAwake) != nil {
            stayAwake = defaults.bool(forKey: Keys.stayAwake)
        }
        if let raw = defaults.array(forKey: Keys.enabledModes) as? [String] {
            let modes = raw.compactMap { DisplayModeType(rawValue: $0) }
            if !modes.isEmpty { enabledModes = Set(modes) }
        }
    }

    private func saveSettings() {
        defaults.set(stayAwake, forKey: Keys.stayAwake)
        defaults.set(enabledModes.map(\.rawValue), forKey: Keys.enabledModes)
    }

    deinit {
        cycleTimer?.invalidate()
    }
}
