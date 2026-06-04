import Foundation
import CoreLocation

/// Turns photo coordinates into real, human place names ("Lisbon, Portugal").
/// This is grounding, not generation — the names are facts, never invented.
/// Serialized via an actor (CLGeocoder wants one request at a time) and cached
/// by coarse coordinate (persisted to disk) so we stay well under the rate limit
/// and re-launches are instant.
actor Geocoder {
    private let geocoder = CLGeocoder()
    private var cache: [String: String]   // coarse coord -> place name ("" = none)

    init() {
        cache = Self.loadCache()
    }

    func placeName(for location: CLLocation) async -> String? {
        let key = String(format: "%.2f,%.2f", location.coordinate.latitude, location.coordinate.longitude)
        if let cached = cache[key] { return cached.isEmpty ? nil : cached }

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let name = Self.shortName(from: placemarks.first)
            cache[key] = name ?? ""
            persist()
            return name
        } catch {
            return nil
        }
    }

    // MARK: - Disk cache

    private static var cacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Eidetic", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("place-cache.json")
    }

    private static func loadCache() -> [String: String] {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return decoded
    }

    private func persist() {
        let snapshot = cache
        let url = Self.cacheURL
        Task.detached {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private static func shortName(from placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }
        let primary = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.name
        let region = placemark.administrativeArea ?? placemark.country
        switch (primary, region) {
        case let (place?, area?) where place != area: return "\(place), \(area)"
        case let (place?, _): return place
        case let (nil, area?): return area
        default: return nil
        }
    }
}
