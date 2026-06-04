import Foundation

enum DisplayModeType: String, CaseIterable, Identifiable {
    case magazineSpread = "Magazine Spread"
    case splitTimeline = "Split Timeline"
    case colorSort = "Color Sort"
    case timeMachineRadio = "Time Machine Radio"
    case mapRoom = "The Map Room"
    case sameSpot = "Same Spot, Different Time"
    case reversePostcard = "Reverse Postcard"

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .magazineSpread: return 60
        case .splitTimeline: return 48
        case .colorSort: return 50
        case .timeMachineRadio: return 66
        case .mapRoom: return 64
        case .sameSpot: return 54
        case .reversePostcard: return 58
        }
    }

    var systemImage: String {
        switch self {
        case .magazineSpread: return "book.pages"
        case .splitTimeline: return "calendar.day.timeline.left"
        case .colorSort: return "paintpalette"
        case .timeMachineRadio: return "antenna.radiowaves.left.and.right"
        case .mapRoom: return "map"
        case .sameSpot: return "mappin.and.ellipse"
        case .reversePostcard: return "envelope"
        }
    }
}
