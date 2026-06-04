import Foundation

enum DisplayModeType: String, CaseIterable, Identifiable {
    case magazineSpread = "Magazine Spread"
    case splitTimeline = "Split Timeline"
    case colorSort = "Color Sort"
    case timeMachineRadio = "Time Machine Radio"

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .magazineSpread: return 60
        case .splitTimeline: return 48
        case .colorSort: return 50
        case .timeMachineRadio: return 66
        }
    }

    var systemImage: String {
        switch self {
        case .magazineSpread: return "book.pages"
        case .splitTimeline: return "calendar.day.timeline.left"
        case .colorSort: return "paintpalette"
        case .timeMachineRadio: return "antenna.radiowaves.left.and.right"
        }
    }
}
