import SwiftUI

struct ColorSortView: View {
    let photos: [AnalyzedPhoto]
    @State private var scrollProgress: CGFloat = 0
    @State private var isAnimating = false

    private let photoWidth: CGFloat = 280
    private let overlap: CGFloat = 40
    private let scrollDuration: TimeInterval = 45

    var body: some View {
        GeometryReader { geo in
            let effectiveWidth = photoWidth - overlap
            let totalContentWidth = CGFloat(photos.count) * effectiveWidth
            let maxScroll = max(totalContentWidth - geo.size.width + 120, 0)

            ZStack {
                backgroundGradient(in: geo)

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geo.size.height * 0.08)

                    colorLabel

                    Spacer()
                        .frame(height: geo.size.height * 0.04)

                    photoStrip(maxScroll: maxScroll, height: geo.size.height * 0.68)

                    Spacer()
                }
            }
        }
        .background(.black)
        .onAppear { startScrolling() }
    }

    private func backgroundGradient(in geo: GeometryProxy) -> some View {
        let progress = min(max(scrollProgress, 0), 1)
        let index = Int(progress * CGFloat(max(photos.count - 1, 0)))
        let photo = photos[safe: index]
        let color = photo?.dominantColor ?? .darkGray

        return ZStack {
            Color.black
            LinearGradient(
                colors: [
                    Color(nsColor: color).opacity(0.35),
                    Color(nsColor: color.blended(withFraction: 0.6, of: .black) ?? color).opacity(0.5),
                    .black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 3), value: index)
    }

    private var colorLabel: some View {
        let progress = min(max(scrollProgress, 0), 1)
        let index = Int(progress * CGFloat(max(photos.count - 1, 0)))
        let hue = photos[safe: index]?.hue ?? 0

        return Text(colorName(for: hue).uppercased())
            .font(.system(size: 13, weight: .semibold))
            .tracking(8)
            .foregroundColor(.white.opacity(0.4))
            .animation(.easeInOut(duration: 1), value: colorName(for: hue))
    }

    private func photoStrip(maxScroll: CGFloat, height: CGFloat) -> some View {
        GeometryReader { stripGeo in
            HStack(spacing: -overlap) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    photoCard(photo: photo, index: index, height: height)
                }
            }
            .padding(.horizontal, 60)
            .offset(x: -scrollProgress * maxScroll)
        }
        .frame(height: height)
        .clipped()
    }

    private func photoCard(photo: AnalyzedPhoto, index: Int, height: CGFloat) -> some View {
        Group {
            if let img = photo.image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: photoWidth, height: height * 0.85)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 12)
                    .rotationEffect(.degrees(tiltAngle(for: index)))
                    .offset(y: verticalOffset(for: index))
                    .zIndex(Double(photos.count - index))
            }
        }
    }

    private func tiltAngle(for index: Int) -> Double {
        let seed = Double(index)
        return sin(seed * 1.3) * 2.5
    }

    private func verticalOffset(for index: Int) -> CGFloat {
        let seed = CGFloat(index)
        return sin(seed * 0.8 + 0.5) * 25
    }

    private func startScrolling() {
        guard photos.isNotEmpty, !isAnimating else { return }
        isAnimating = true
        scrollProgress = 0

        withAnimation(.linear(duration: scrollDuration)) {
            scrollProgress = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + scrollDuration + 1) {
            isAnimating = false
            scrollProgress = 0
            startScrolling()
        }
    }

    private func colorName(for hue: CGFloat) -> String {
        switch hue {
        case 0..<0.03: return "Crimson"
        case 0.03..<0.08: return "Vermillion"
        case 0.08..<0.12: return "Tangerine"
        case 0.12..<0.17: return "Amber"
        case 0.17..<0.22: return "Gold"
        case 0.22..<0.30: return "Chartreuse"
        case 0.30..<0.40: return "Emerald"
        case 0.40..<0.50: return "Teal"
        case 0.50..<0.58: return "Cyan"
        case 0.58..<0.65: return "Azure"
        case 0.65..<0.72: return "Cobalt"
        case 0.72..<0.80: return "Indigo"
        case 0.80..<0.87: return "Violet"
        case 0.87..<0.93: return "Magenta"
        case 0.93..<0.97: return "Fuchsia"
        default: return "Rose"
        }
    }
}
