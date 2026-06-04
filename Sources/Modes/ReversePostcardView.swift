import SwiftUI
import CoreLocation

/// Reverse Postcard — the postcard you never sent from a past trip. The prose is
/// grounded strictly in facts (place, dates, length, photo count); it never
/// describes the photos themselves. The card text appears only once it's ready
/// (a spinner until then) — we never flash copy we know isn't good.
struct ReversePostcardView: View {
    let trip: PostcardTrip?

    @State private var index = 0
    @State private var opacity: Double = 1.0
    @State private var postcard: String?      // nil = still preparing

    private let geocoder = Geocoder()
    private let curator = Curator()
    private let stepDuration: TimeInterval = 6

    private var photos: [AnalyzedPhoto] { trip?.photos ?? [] }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if trip == nil || photos.isEmpty {
                    emptyState
                } else {
                    if let photo = photos[safe: index] {
                        AsyncPhotoImage(photo: photo)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .overlay(Color.black.opacity(0.45))
                            .opacity(opacity)
                    }
                    postcardCard
                        .frame(maxWidth: min(geo.size.width * 0.5, 520))
                        .padding(48)
                }
            }
        }
        .background(.black)
        .onAppear { scheduleNext() }
        .task { await composePostcard() }
    }

    private var postcardCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let postcard {
                Text(postcard)
                    .font(.system(size: 22, weight: .light, design: .serif))
                    .foregroundColor(Color(white: 0.12))
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            } else {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small).tint(Color(white: 0.4))
                    Text("Composing\u{2026}")
                        .font(.system(size: 14, weight: .light, design: .serif))
                        .foregroundColor(Color(white: 0.4))
                }
            }
        }
        .padding(34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.97, green: 0.96, blue: 0.93)) // warm paper
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 30, y: 16)
        .rotationEffect(.degrees(-1.5))
        .animation(.easeInOut(duration: 0.8), value: postcard)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.2))
            Text("No trips to write home about yet")
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

    private func composePostcard() async {
        guard let trip else { return }
        let location = CLLocation(latitude: trip.coordinate.latitude, longitude: trip.coordinate.longitude)
        let place = await geocoder.placeName(for: location) ?? "somewhere far from home"

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let monthYear = formatter.string(from: trip.startDate)

        let days = max(1, (Calendar.current.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 0) + 1)

        let facts = PostcardFacts(place: place, monthYear: monthYear, days: days, photoCount: trip.photos.count)
        let text = await curator.postcard(for: facts)
        if !Task.isCancelled {
            withAnimation(.easeInOut(duration: 0.8)) { postcard = text }
        }
    }
}
