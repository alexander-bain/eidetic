import Foundation
import Combine
import CoreLocation
import AppKit
import SwiftUI

final class AnalyzedPhoto: ObservableObject, Identifiable {
    let id: String
    let assetIdentifier: String
    let creationDate: Date?
    let location: CLLocation?
    let dominantColor: NSColor
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat

    // On-device Vision analysis (see PhotoProvider).
    let isUtility: Bool          // screenshot / receipt / document — hidden from display
    let aestheticsScore: Float   // Vision overall score, -1...1 (0 = unknown)
    let saliencyRect: CGRect?    // subject region, normalized, Vision (bottom-left) origin

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
        isUtility: Bool = false,
        aestheticsScore: Float = 0,
        saliencyRect: CGRect? = nil,
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
        self.isUtility = isUtility
        self.aestheticsScore = aestheticsScore
        self.saliencyRect = saliencyRect
        self.image = image
    }

    /// The subject's location as a SwiftUI `UnitPoint` (top-left origin), for
    /// focusing Ken Burns motion. Falls back to center when no subject is found.
    var subjectAnchor: UnitPoint {
        guard let rect = saliencyRect else { return .center }
        let x = min(max(rect.midX, 0), 1)
        let y = min(max(1 - rect.midY, 0), 1) // flip Vision's bottom-left origin
        return UnitPoint(x: x, y: y)
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
