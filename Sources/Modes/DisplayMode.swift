import Foundation

enum DisplayModeType: String, CaseIterable, Identifiable {
    case magazineSpread = "Magazine Spread"
    case splitTimeline = "Split Timeline"
    case colorSort = "Color Sort"

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .magazineSpread: return 60
        case .splitTimeline: return 48
        case .colorSort: return 50
        }
    }

    var systemImage: String {
        switch self {
        case .magazineSpread: return "book.pages"
        case .splitTimeline: return "calendar.day.timeline.left"
        case .colorSort: return "paintpalette"
        }
    }
}
