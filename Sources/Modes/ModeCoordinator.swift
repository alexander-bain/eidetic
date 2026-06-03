import Foundation
import SwiftUI

@MainActor
class ModeCoordinator: ObservableObject {
    @Published var currentMode: DisplayModeType = .magazineSpread
    @Published var isTransitioning = false
    @Published var stayAwake = true {
        didSet { updateSleepPrevention() }
    }
    @Published var enabledModes: Set<DisplayModeType> = Set(DisplayModeType.allCases)

    private var cycleTimer: Timer?
    private var modeQueue: [DisplayModeType] = []
    private var activityToken: NSObjectProtocol?

    func startCycling() {
        resetQueue()
        scheduleNext()
        updateSleepPrevention()
    }

    func stopCycling() {
        cycleTimer?.invalidate()
        cycleTimer = nil
        endSleepPrevention()
    }

    func skipToNext() {
        cycleTimer?.invalidate()
        advanceMode()
    }

    private func resetQueue() {
        modeQueue = Array(enabledModes).shuffled()
        modeQueue.removeAll { $0 == currentMode }
    }

    private func scheduleNext() {
        cycleTimer?.invalidate()
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

    private func updateSleepPrevention() {
        endSleepPrevention()
        if stayAwake {
            activityToken = ProcessInfo.processInfo.beginActivity(
                options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled],
                reason: "Photo Cycler keeping display active"
            )
        }
    }

    private func endSleepPrevention() {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }

    deinit {
        cycleTimer?.invalidate()
    }
}
