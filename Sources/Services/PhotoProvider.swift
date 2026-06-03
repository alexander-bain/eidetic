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

    // Asset + photo lookup so display images can be fetched on demand.
    private var assetsByID: [String: PHAsset] = [:]
    private var photosByID: [String: AnalyzedPhoto] = [:]

    // Bounded set of photos whose display image is currently held in memory.
    private var loadedOrder: [String] = []
    private var inFlight: Set<String> = []
    private let maxLoadedImages = 400

    // Persisted color analysis (so re-launches don't re-analyze).
    private var colorCache: [String: ColorRecord] = [:]
    private var cacheDirty = false

    private let firstBatchSize = 60
    private let backgroundChunkSize = 50

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
    }

    // MARK: - Loading

    func loadPhotos() async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }

        isLoading = true
        loadColorCache()

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let fetch = PHAsset.fetchAssets(with: options)
        let total = fetch.count
        guard total > 0 else {
            isLoading = false
            return
        }

        var allAssets: [PHAsset] = []
        allAssets.reserveCapacity(total)
        fetch.enumerateObjects { asset, _, _ in allAssets.append(asset) }

        // First batch: analyze synchronously so the app can start showing photos.
        let firstCount = min(firstBatchSize, total)
        var initial: [AnalyzedPhoto] = []
        for i in 0..<firstCount {
            let asset = allAssets[i]
            let photo = await makePhoto(asset: asset)
            assetsByID[photo.id] = asset
            photosByID[photo.id] = photo
            initial.append(photo)
            loadingProgress = Double(i + 1) / Double(firstCount)
        }
        photos = initial
        isLoading = false
        saveColorCacheIfNeeded()

        // Remaining photos: analyze in the background, appending in chunks so the
        // library fills in progressively without blocking the UI.
        guard total > firstCount else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            var buffer: [AnalyzedPhoto] = []
            for i in firstCount..<total {
                let asset = allAssets[i]
                let photo = await self.makePhoto(asset: asset)
                self.assetsByID[photo.id] = asset
                self.photosByID[photo.id] = photo
                buffer.append(photo)
                if buffer.count >= self.backgroundChunkSize {
                    self.photos.append(contentsOf: buffer)
                    buffer.removeAll(keepingCapacity: true)
                    self.saveColorCacheIfNeeded()
                }
            }
            if !buffer.isEmpty { self.photos.append(contentsOf: buffer) }
            self.saveColorCacheIfNeeded()
        }
    }

    private func makePhoto(asset: PHAsset) async -> AnalyzedPhoto {
        let id = asset.localIdentifier
        let color: NSColor
        let h: CGFloat, s: CGFloat, b: CGFloat

        if let record = colorCache[id] {
            color = record.color
            h = record.hue
            s = record.saturation
            b = record.brightness
        } else if let analyzed = await analyzeColor(asset: asset) {
            (color, h, s, b) = analyzed
            colorCache[id] = ColorRecord(color: color, hue: h, saturation: s, brightness: b)
            cacheDirty = true
        } else {
            (color, h, s, b) = (.darkGray, 0, 0, 0.3)
        }

        return AnalyzedPhoto(
            id: id,
            assetIdentifier: id,
            creationDate: asset.creationDate,
            location: asset.location,
            dominantColor: color,
            hue: h,
            saturation: s,
            brightness: b
        )
    }

    /// Computes the dominant color from a small thumbnail (not retained).
    private func analyzeColor(asset: PHAsset) async -> (NSColor, CGFloat, CGFloat, CGFloat)? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.isSynchronous = false
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            var resumed = false
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 120, height: 120),
                contentMode: .aspectFill,
                options: options
            ) { [weak self] nsImage, _ in
                guard !resumed else { return }
                resumed = true
                guard let self,
                      let nsImage,
                      let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: self.analyzeDominantColor(image: cgImage))
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

    // MARK: - On-demand display images

    /// Loads a full-size display image for the given photo if not already held.
    /// Keeps at most `maxLoadedImages` decoded images in memory (LRU eviction).
    func requestImage(for photo: AnalyzedPhoto) {
        guard photo.image == nil,
              !inFlight.contains(photo.id),
              let asset = assetsByID[photo.id] else { return }

        inFlight.insert(photo.id)

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 1100, height: 1100),
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, info in
            guard let image else { return }
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            Task { @MainActor in
                photo.image = image
                if !isDegraded {
                    self?.inFlight.remove(photo.id)
                    self?.noteImageLoaded(photo)
                }
            }
        }
    }

    private func noteImageLoaded(_ photo: AnalyzedPhoto) {
        loadedOrder.removeAll { $0 == photo.id }
        loadedOrder.append(photo.id)
        while loadedOrder.count > maxLoadedImages {
            let evicted = loadedOrder.removeFirst()
            if evicted != photo.id {
                photosByID[evicted]?.image = nil
            }
        }
    }

    // MARK: - Color cache persistence

    private struct ColorRecord: Codable {
        let r: Double, g: Double, b: Double
        let h: Double, s: Double, br: Double

        init(color: NSColor, hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
            let c = color.usingColorSpace(.deviceRGB) ?? color
            r = Double(c.redComponent)
            g = Double(c.greenComponent)
            b = Double(c.blueComponent)
            h = Double(hue)
            s = Double(saturation)
            br = Double(brightness)
        }

        var color: NSColor { NSColor(deviceRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1) }
        var hue: CGFloat { CGFloat(h) }
        var saturation: CGFloat { CGFloat(s) }
        var brightness: CGFloat { CGFloat(br) }
    }

    private var cacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Eidetic", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("color-cache.json")
    }

    private func loadColorCache() {
        guard colorCache.isEmpty,
              let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([String: ColorRecord].self, from: data) else { return }
        colorCache = decoded
    }

    private func saveColorCacheIfNeeded() {
        guard cacheDirty else { return }
        cacheDirty = false
        let snapshot = colorCache
        let url = cacheURL
        Task.detached {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    // MARK: - Filtered access

    func photosForToday(windowDays: Int = 3) -> [(Int, AnalyzedPhoto)] {
        let calendar = Calendar.current
        let today = Date()
        let month = calendar.component(.month, from: today)
        let day = calendar.component(.day, from: today)
        let currentYear = calendar.component(.year, from: today)

        return photos.compactMap { photo in
            guard let date = photo.creationDate else { return nil }
            let m = calendar.component(.month, from: date)
            let d = calendar.component(.day, from: date)
            let y = calendar.component(.year, from: date)
            if m == month && abs(d - day) <= windowDays && y != currentYear {
                return (y, photo)
            }
            return nil
        }.sorted { $0.0 < $1.0 }
    }

    /// Photos for Split Timeline: prefers "on this day" matches, otherwise falls
    /// back to random photos from different years so the mode always shows something.
    func splitTimelinePhotos(windowDays: Int = 3) -> [(Int, AnalyzedPhoto)] {
        let today = photosForToday(windowDays: windowDays)
        if today.count >= 2 { return today }
        return randomYearPairs()
    }

    private func randomYearPairs(maxYears: Int = 12) -> [(Int, AnalyzedPhoto)] {
        let byYear = photosByYear()
        guard byYear.count >= 2 else { return photosForToday() }

        let years = Array(byYear.keys).shuffled().prefix(maxYears)
        let pairs: [(Int, AnalyzedPhoto)] = years.compactMap { year in
            guard let photo = byYear[year]?.randomElement() else { return nil }
            return (year, photo)
        }
        return pairs.sorted { $0.0 < $1.0 }
    }

    /// Hue-sorted photos, evenly sampled across the spectrum so the Color Sort
    /// strip stays a manageable length even for very large libraries.
    func photosSortedByHue(limit: Int = 200) -> [AnalyzedPhoto] {
        let sorted = photos
            .filter { $0.saturation > 0.12 && $0.brightness > 0.15 }
            .sorted { $0.hue < $1.hue }

        guard sorted.count > limit else { return sorted }
        let step = Double(sorted.count) / Double(limit)
        return (0..<limit).compactMap { sorted[safe: Int(Double($0) * step)] }
    }

    func randomPhotos(_ count: Int) -> [AnalyzedPhoto] {
        Array(photos.shuffled().prefix(count))
    }

    func photosByYear() -> [Int: [AnalyzedPhoto]] {
        Dictionary(grouping: photos.filter { $0.year != nil }, by: { $0.year! })
    }
}
