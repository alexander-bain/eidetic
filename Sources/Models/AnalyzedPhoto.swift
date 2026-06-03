import Foundation
import Combine
import CoreLocation
import AppKit

final class AnalyzedPhoto: ObservableObject, Identifiable {
    let id: String
    let assetIdentifier: String
    let creationDate: Date?
    let location: CLLocation?
    let dominantColor: NSColor
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat

    // Display image is loaded on demand (see PhotoProvider.requestImage) so the
    // full library can be tracked without holding every decoded image in memory.
    @Published var image: NSImage?

    init(
        id: String,
        assetIdentifier: String,
        creationDate: Date?,
        location: CLLocation?,
        dominantColor: NSColor,
        hue: CGFloat,
        saturation: CGFloat,
        brightness: CGFloat,
        image: NSImage? = nil
    ) {
        self.id = id
        self.assetIdentifier = assetIdentifier
        self.creationDate = creationDate
        self.location = location
        self.dominantColor = dominantColor
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.image = image
    }

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
