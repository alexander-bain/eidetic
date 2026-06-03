import SwiftUI

struct MagazineSpreadView: View {
    let photos: [AnalyzedPhoto]
    @State private var currentIndex = 0
    @State private var kenBurnsScale: CGFloat = 1.0
    @State private var kenBurnsOffset: CGSize = .zero
    @State private var opacity: Double = 1.0

    private let cycleDuration: TimeInterval = 15

    var body: some View {
        GeometryReader { geo in
            if let photo = photos[safe: currentIndex] {
                HStack(spacing: 0) {
                    metadataPanel(photo: photo, width: geo.size.width * 0.33)
                    heroPanel(photo: photo, size: CGSize(
                        width: geo.size.width * 0.67,
                        height: geo.size.height
                    ))
                }
                .opacity(opacity)
            } else {
                emptyState
            }
        }
        .background(Color(white: 0.04))
        .onAppear { startCycle() }
    }

    private func metadataPanel(photo: AnalyzedPhoto, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            if let date = photo.monthDay {
                Text(date.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(5)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 8)
            }

            if let year = photo.yearString {
                Text(year)
                    .font(.system(size: 80, weight: .ultraLight, design: .serif))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 32)
            }

            if let img = photo.image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: min(width * 0.55, 220), height: min(width * 0.55, 220))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                    .padding(.bottom, 24)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(Color(nsColor: photo.dominantColor))
                    .frame(width: 8, height: 8)
                Text("\(currentIndex + 1) / \(photos.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
            }

            Spacer()
                .frame(height: 60)
        }
        .frame(width: width)
        .padding(.leading, 60)
    }

    private func heroPanel(photo: AnalyzedPhoto, size: CGSize) -> some View {
        Group {
            if let img = photo.image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .scaleEffect(kenBurnsScale)
                    .offset(kenBurnsOffset)
            }
        }
    }

    private var emptyState: some View {
        Text("No photos available")
            .font(.system(size: 18, weight: .light))
            .foregroundColor(.white.opacity(0.3))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startCycle() {
        guard photos.isNotEmpty else { return }
        startKenBurns()
        scheduleAdvance()
    }

    private func startKenBurns() {
        kenBurnsScale = 1.0
        kenBurnsOffset = .zero

        let directions: [(CGFloat, CGSize)] = [
            (1.08, CGSize(width: -30, height: -15)),
            (1.06, CGSize(width: 20, height: -20)),
            (1.07, CGSize(width: -15, height: 25)),
            (1.05, CGSize(width: 25, height: 10)),
        ]
        let pick = directions[currentIndex % directions.count]

        withAnimation(.easeInOut(duration: cycleDuration)) {
            kenBurnsScale = pick.0
            kenBurnsOffset = pick.1
        }
    }

    private func scheduleAdvance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + cycleDuration) {
            withAnimation(.easeInOut(duration: 1.5)) {
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                currentIndex = (currentIndex + 1) % max(photos.count, 1)
                opacity = 0
                startKenBurns()
                withAnimation(.easeInOut(duration: 1.5)) {
                    opacity = 1
                }
                scheduleAdvance()
            }
        }
    }
}
