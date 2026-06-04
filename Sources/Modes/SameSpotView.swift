import SwiftUI
import CoreLocation

/// Same Spot, Different Time — one place you've returned to, across the years.
/// The place name (reverse-geocoded, a fact) holds steady at the top while the
/// photos cross-fade in chronological order, the year changing beneath them.
struct SameSpotView: View {
    let photos: [AnalyzedPhoto]

    @State private var index = 0
    @State private var opacity: Double = 1.0
    @State private var placeName: String?

    private let geocoder = Geocoder()
    private let stepDuration: TimeInterval = 6

    private var coordinate: CLLocationCoordinate2D? {
        photos.first?.location?.coordinate
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let photo = photos[safe: index] {
                    AsyncPhotoImage(photo: photo)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(alignment: .topLeading) { placeHeader }
                        .overlay(alignment: .bottomTrailing) { yearLabel(photo) }
                        .opacity(opacity)
                } else {
                    emptyState
                }
            }
        }
        .background(.black)
        .onAppear { scheduleNext() }
        .task { await resolvePlace() }
    }

    private var placeHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Same Spot, Different Time".uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(4)
                .foregroundColor(.white.opacity(0.5))
            if let placeName {
                Text(placeName)
                    .font(.system(size: 34, weight: .ultraLight, design: .serif))
                    .foregroundColor(.white)
            } else {
                // Never guess the place — wait for the real name.
                ProgressView()
                    .controlSize(.small)
                    .tint(.white.opacity(0.5))
            }
        }
        .shadow(color: .black.opacity(0.6), radius: 12)
        .padding(48)
    }

    private func yearLabel(_ photo: AnalyzedPhoto) -> some View {
        Group {
            if let year = photo.year {
                Text(String(year))
                    .font(.system(size: 80, weight: .ultraLight, design: .serif))
                    .foregroundColor(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.6), radius: 14, y: 2)
            }
        }
        .padding(48)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.2))
            Text("No revisited places yet")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scheduleNext() {
        guard photos.count > 1 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration) {
            withAnimation(.easeInOut(duration: 1.2)) { opacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                index = (index + 1) % photos.count
                withAnimation(.easeInOut(duration: 1.2)) { opacity = 1 }
                scheduleNext()
            }
        }
    }

    private func resolvePlace() async {
        guard let coordinate else { return }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        placeName = await geocoder.placeName(for: location)
    }
}
