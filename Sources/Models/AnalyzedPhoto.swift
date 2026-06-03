import Foundation
import CoreLocation
import AppKit

struct AnalyzedPhoto: Identifiable {
    let id: String
    let assetIdentifier: String
    let creationDate: Date?
    let location: CLLocation?
    let dominantColor: NSColor
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat
    var image: NSImage?

    var year: Int? {
        guard let date = creationDate else { return nil }
        return Calendar.current.component(.year, from: date)
    }

    var monthDay: String? {
        guard let date = creationDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date)
    }

    var yearString: String? {
        guard let y = year else { return nil }
        return String(y)
    }

    var fullDateString: String? {
        guard let date = creationDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}
