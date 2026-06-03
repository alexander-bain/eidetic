import Photos
import AppKit
import CoreImage
import Combine

@MainActor
class PhotoProvider: ObservableObject {
    @Published var photos: [AnalyzedPhoto] = []
    @Published var isLoading = false
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var loadingProgress: Double = 0

    private let imageManager = PHCachingImageManager()
    private let ciContext = CIContext()

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
    }

    func loadPhotos(limit: Int = 500) async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }

        isLoading = true
        defer { isLoading = false }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let assets = PHAsset.fetchAssets(with: options)
        var loaded: [AnalyzedPhoto] = []
        let total = assets.count

        for i in 0..<total {
            let asset = assets[i]
            if let photo = await loadSinglePhoto(asset: asset) {
                loaded.append(photo)
            }
            loadingProgress = Double(i + 1) / Double(total)
        }

        photos = loaded
    }

    private func loadSinglePhoto(asset: PHAsset) async -> AnalyzedPhoto? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.resizeMode = .exact

            let targetSize = CGSize(width: 800, height: 800)

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { [weak self] nsImage, info in
                guard let self, let nsImage else {
                    continuation.resume(returning: nil)
                    return
                }

                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded { return }

                let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
                let (color, h, s, b) = cgImage.map { self.analyzeDominantColor(image: $0) }
                    ?? (.gray, 0 as CGFloat, 0 as CGFloat, 0.5 as CGFloat)

                let photo = AnalyzedPhoto(
                    id: asset.localIdentifier,
                    assetIdentifier: asset.localIdentifier,
                    creationDate: asset.creationDate,
                    location: asset.location,
                    dominantColor: color,
                    hue: h,
                    saturation: s,
                    brightness: b,
                    image: nsImage
                )
                continuation.resume(returning: photo)
            }
        }
    }

    private func analyzeDominantColor(image: CGImage) -> (NSColor, CGFloat, CGFloat, CGFloat) {
        let ciImage = CIImage(cgImage: image)
        let extent = ciImage.extent

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ]),
        let outputImage = filter.outputImage else {
            return (.gray, 0, 0, 0.5)
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let color = NSColor(
            red: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0,
            alpha: 1.0
        )

        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)

        return (color, h, s, b)
    }

    // MARK: - Filtered access

    func photosForToday(windowDays: Int = 3) -> [(Int, AnalyzedPhoto)] {
        let calendar = Calendar.current
        let today = Date()
        let month = calendar.component(.month, from: today)
        let day = calendar.component(.day, from: today)

        return photos.compactMap { photo in
            guard let date = photo.creationDate else { return nil }
            let m = calendar.component(.month, from: date)
            let d = calendar.component(.day, from: date)
            let y = calendar.component(.year, from: date)
            let currentYear = calendar.component(.year, from: today)
            if m == month && abs(d - day) <= windowDays && y != currentYear {
                return (y, photo)
            }
            return nil
        }.sorted { $0.0 < $1.0 }
    }

    func photosSortedByHue() -> [AnalyzedPhoto] {
        photos
            .filter { $0.saturation > 0.12 && $0.brightness > 0.15 }
            .sorted { $0.hue < $1.hue }
    }

    func randomPhotos(_ count: Int) -> [AnalyzedPhoto] {
        Array(photos.shuffled().prefix(count))
    }

    func photosByYear() -> [Int: [AnalyzedPhoto]] {
        Dictionary(grouping: photos.filter { $0.year != nil }, by: { $0.year! })
    }
}
