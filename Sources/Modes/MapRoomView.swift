import SwiftUI
import MapKit

/// One stop on the journey: a located photo, its coordinate, and its date.
struct MapStop: Identifiable {
    let photo: AnalyzedPhoto
    let coordinate: CLLocationCoordinate2D
    let dateString: String
    var id: String { photo.id }
}

/// The Map Room — a dark map that flies between the places your photos were
/// taken, blooming each memory at its pin. Hallucination-proof: every label is a
/// fact (a reverse-geocoded place name, a real date), never invented prose.
struct MapRoomView: View {
    let stops: [MapStop]

    @State private var index = 0
    @State private var camera: MapCameraPosition = .automatic
    @State private var placeName: String?

    private let geocoder = Geocoder()
    private let stopDuration: TimeInterval = 8

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black.ignoresSafeArea()

            if stops.isEmpty {
                emptyState
            } else {
                Map(position: $camera, interactionModes: []) {
                    if let stop = stops[safe: index] {
                        Annotation("", coordinate: stop.coordinate) {
                            Circle()
                                .fill(.white)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 1))
                                .shadow(color: .black.opacity(0.5), radius: 6)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
                .ignoresSafeArea()

                if let stop = stops[safe: index] {
                    stopCard(stop)
                        .padding(40)
                }
            }
        }
        .onAppear { begin() }
        .task(id: index) { await updatePlaceName() }
    }

    private func stopCard(_ stop: MapStop) -> some View {
        HStack(alignment: .bottom, spacing: 18) {
            AsyncPhotoImage(photo: stop.photo)
                .frame(width: 240, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.6), radius: 24, y: 12)

            VStack(alignment: .leading, spacing: 6) {
                if let placeName {
                    Text(placeName)
                        .font(.system(size: 30, weight: .ultraLight, design: .serif))
                        .foregroundColor(.white)
                } else {
                    // Don't show a guessed place — show the date until the real
                    // name is geocoded.
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white.opacity(0.5))
                }
                Text(stop.dateString.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.55))
            }
            .shadow(color: .black.opacity(0.7), radius: 10)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.2))
            Text("No located photos")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func begin() {
        guard let first = stops.first else { return }
        camera = cameraPosition(for: first.coordinate)
        scheduleNext()
    }

    private func scheduleNext() {
        guard stops.count > 1 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + stopDuration) {
            index = (index + 1) % stops.count
            if let stop = stops[safe: index] {
                withAnimation(.easeInOut(duration: 2.5)) {
                    camera = cameraPosition(for: stop.coordinate)
                }
            }
            scheduleNext()
        }
    }

    private func cameraPosition(for coordinate: CLLocationCoordinate2D) -> MapCameraPosition {
        .camera(MapCamera(centerCoordinate: coordinate, distance: 6000, heading: 0, pitch: 0))
    }

    private func updatePlaceName() async {
        placeName = nil
        guard let stop = stops[safe: index] else { return }
        let location = CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude)
        let name = await geocoder.placeName(for: location)
        if !Task.isCancelled, stops[safe: index]?.id == stop.id {
            placeName = name
        }
    }
}
