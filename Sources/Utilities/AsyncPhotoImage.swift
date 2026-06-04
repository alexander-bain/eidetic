import SwiftUI

/// Renders an `AnalyzedPhoto`'s display image, requesting it from the
/// `PhotoProvider` on demand. While the image loads (or after it has been
/// evicted from memory) it shows a tint of the photo's dominant color so the
/// layout stays stable and the screen never flashes empty.
///
/// Sizing/clipping/effects are applied by the caller on the returned view.
struct AsyncPhotoImage: View {
    @EnvironmentObject private var provider: PhotoProvider
    @ObservedObject var photo: AnalyzedPhoto
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let image = photo.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Color(nsColor: photo.dominantColor).opacity(0.25))
            }
        }
        // Fires on appear AND whenever the photo changes — so single-image modes
        // that swap the photo (Magazine hero, Split Timeline, Time Machine) load
        // each new photo, not just the first.
        .task(id: photo.id) { provider.requestImage(for: photo) }
    }
}
