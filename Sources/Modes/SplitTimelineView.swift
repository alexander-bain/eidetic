import SwiftUI

struct SplitTimelineView: View {
    let photosByYear: [(Int, AnalyzedPhoto)]
    @State private var pairIndex = 0
    @State private var opacity: Double = 1.0

    private let cycleDuration: TimeInterval = 12

    private var pairs: [(AnalyzedPhoto, AnalyzedPhoto, Int, Int)] {
        guard photosByYear.count >= 2 else { return [] }
        var result: [(AnalyzedPhoto, AnalyzedPhoto, Int, Int)] = []
        var used = Set<String>()

        for i in 0..<photosByYear.count {
            for j in (i + 1)..<photosByYear.count {
                let (y1, p1) = photosByYear[i]
                let (y2, p2) = photosByYear[j]
                guard y1 != y2 else { continue }
                let key = "\(p1.id)-\(p2.id)"
                guard !used.contains(key) else { continue }
                used.insert(key)
                result.append((p1, p2, y1, y2))
            }
        }
        return Array(result.prefix(20))
    }

    var body: some View {
        GeometryReader { geo in
            if let pair = pairs[safe: pairIndex] {
                HStack(spacing: 3) {
                    timelinePanel(photo: pair.0, year: pair.2, alignment: .bottomLeading)
                        .frame(width: geo.size.width / 2 - 1.5)
                    timelinePanel(photo: pair.1, year: pair.3, alignment: .bottomTrailing)
                        .frame(width: geo.size.width / 2 - 1.5)
                }
                .opacity(opacity)
            } else if photosByYear.count == 1, let (year, photo) = photosByYear.first {
                singlePhotoFallback(photo: photo, year: year)
                    .opacity(opacity)
            } else {
                noMatchView
            }
        }
        .background(.black)
        .onAppear { scheduleCycle() }
    }

    private func timelinePanel(photo: AnalyzedPhoto, year: Int, alignment: Alignment) -> some View {
        ZStack(alignment: alignment) {
            if let img = photo.image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            }

            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: alignment == .bottomLeading ? .leading : .trailing, spacing: 6) {
                Spacer()
                if let date = photo.monthDay {
                    Text(date)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                Text(String(year))
                    .font(.system(size: 72, weight: .ultraLight, design: .serif))
                    .foregroundColor(.white)
            }
            .padding(44)
        }
    }

    private func singlePhotoFallback(photo: AnalyzedPhoto, year: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let img = photo.image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                Text("On This Day")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.5))
                if let date = photo.fullDateString {
                    Text(date)
                        .font(.system(size: 36, weight: .light, design: .serif))
                        .foregroundColor(.white)
                }
            }
            .padding(44)
        }
    }

    private var noMatchView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.2))
            Text("No matching memories for today")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            Text("Photos from this date in past years will appear here")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.15))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scheduleCycle() {
        guard pairs.isNotEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + cycleDuration) {
            withAnimation(.easeInOut(duration: 1.5)) {
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                pairIndex = (pairIndex + 1) % max(pairs.count, 1)
                withAnimation(.easeInOut(duration: 1.5)) {
                    opacity = 1
                }
                scheduleCycle()
            }
        }
    }
}
