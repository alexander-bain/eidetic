import CoreLocation

/// Turns photo coordinates into real, human place names ("Lisbon, Portugal").
/// This is grounding, not generation — the names are facts, never invented.
/// Serialized via an actor (CLGeocoder wants one request at a time) and cached
/// by coarse coordinate so we stay well under the rate limit.
actor Geocoder {
    private let geocoder = CLGeocoder()
    private var cache: [String: String] = [:]   // coarse coord -> place name ("" = none)

    func placeName(for location: CLLocation) async -> String? {
        let key = String(format: "%.2f,%.2f", location.coordinate.latitude, location.coordinate.longitude)
        if let cached = cache[key] { return cached.isEmpty ? nil : cached }

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let name = Self.shortName(from: placemarks.first)
            cache[key] = name ?? ""
            return name
        } catch {
            return nil
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
