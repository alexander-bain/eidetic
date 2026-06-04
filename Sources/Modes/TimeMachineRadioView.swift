import SwiftUI

/// One "chapter" of the memoir: a year, a representative photo, and a narrated line.
struct TimeMachineChapter: Identifiable {
    let year: Int
    let photo: AnalyzedPhoto
    let line: String
    var id: Int { year }
}

/// Time Machine Radio — this same week, across every past year, played as a
/// slow narrated memoir. One year per chapter, cross-fading, with the on-device
/// curator's line beneath a large year. (See Curator.memoir.)
struct TimeMachineRadioView: View {
    let chapters: [TimeMachineChapter]

    @State private var index = 0
    @State private var opacity: Double = 1.0

    private let chapterDuration: TimeInterval = 11

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let chapter = chapters[safe: index] {
                    AsyncPhotoImage(photo: chapter.photo)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [.black.opacity(0.15), .clear, .clear, .black.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(alignment: .bottomLeading) { chapterCaption(chapter, in: geo) }
                        .opacity(opacity)
                } else {
                    emptyState
                }
            }
        }
        .background(.black)
        .onAppear { scheduleNext() }
    }

    private func chapterCaption(_ chapter: TimeMachineChapter, in geo: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(chapter.year))
                .font(.system(size: 96, weight: .ultraLight, design: .serif))
                .foregroundColor(.white)
            if !chapter.line.isEmpty {
                Text(chapter.line)
                    .font(.system(size: 21, weight: .light, design: .serif))
                    .foregroundColor(.white.opacity(0.82))
                    .frame(maxWidth: geo.size.width * 0.62, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .shadow(color: .black.opacity(0.6), radius: 14, y: 2)
        .padding(56)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.2))
            Text("Tuning in\u{2026}")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scheduleNext() {
        guard chapters.count > 1 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + chapterDuration) {
            withAnimation(.easeInOut(duration: 1.5)) { opacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                index = (index + 1) % max(chapters.count, 1)
                withAnimation(.easeInOut(duration: 1.5)) { opacity = 1 }
                scheduleNext()
            }
        }
    }
}
