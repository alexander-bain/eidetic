import Photos
import AppKit
import CoreImage
import Vision
import Combine

@MainActor
class PhotoProvider: ObservableObject {
    @Published var photos: [AnalyzedPhoto] = []
    @Published var isLoading = false
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var loadingProgress: Double = 0

    /// When true, the wall is drawn *only* from photos you've favorited. When
    /// false (default), it's favorites-first blended: favorites dominate, with a
    /// small rediscovery sprinkle of your strongest non-favorites.
    @Published var favoritesOnly: Bool = UserDefaults.standard.object(forKey: "eidetic.favoritesOnly") as? Bool ?? false {
        didSet { UserDefaults.standard.set(favoritesOnly, forKey: "eidetic.favoritesOnly") }
    }

    private let imageManager = PHCachingImageManager()
    private let ciContext = CIContext()

    // Asset + photo lookup so display images can be fetched on demand.
    private var assetsByID: [String: PHAsset] = [:]
    private var photosByID: [String: AnalyzedPhoto] = [:]

    // Bounded set of photos whose display image is currently held in memory.
    private var loadedOrder: [String] = []
    private var inFlight: Set<String> = []
    private let maxLoadedImages = 400

    // Persisted on-device analysis (color + Vision) so re-launches are instant.
    private var analysisCache: [String: PhotoAnalysis] = [:]
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
        loadAnalysisCache()

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
        saveAnalysisCacheIfNeeded()

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
                    self.saveAnalysisCacheIfNeeded()
                }
            }
            if !buffer.isEmpty { self.photos.append(contentsOf: buffer) }
            self.saveAnalysisCacheIfNeeded()
        }
    }

    private func makePhoto(asset: PHAsset) async -> AnalyzedPhoto {
        let id = asset.localIdentifier
        // Screenshots are flagged by PhotoKit directly — free, no analysis needed.
        let isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)

        let analysis: PhotoAnalysis
        if let cached = analysisCache[id] {
            analysis = cached
        } else if let computed = await analyzeAsset(asset: asset) {
            analysis = computed
            analysisCache[id] = computed
            cacheDirty = true
        } else {
            analysis = .unknown
        }

        return AnalyzedPhoto(
            id: id,
            assetIdentifier: id,
            creationDate: asset.creationDate,
            location: asset.location,
            dominantColor: analysis.color,
            hue: analysis.hue,
            saturation: analysis.saturation,
            brightness: analysis.brightness,
            isFavorite: asset.isFavorite,
            isUtility: analysis.isUtility || isScreenshot,
            aestheticsScore: Float(analysis.aesthetics),
            saliencyRect: analysis.saliencyRect
        )
    }

    /// Fetches one small thumbnail (not retained) and runs all on-device
    /// analysis on it: dominant color, aesthetics/utility, and subject saliency.
    private func analyzeAsset(asset: PHAsset) async -> PhotoAnalysis? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.isSynchronous = false
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            var resumed = false
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 512, height: 512),
                contentMode: .aspectFit,
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

                let (color, h, s, b) = self.analyzeDominantColor(image: cgImage)
                let (aesthetics, isUtility) = self.analyzeAesthetics(image: cgImage)
                let saliency = self.analyzeSaliency(image: cgImage)

                continuation.resume(returning: PhotoAnalysis(
                    color: color,
                    hue: h,
                    saturation: s,
                    brightness: b,
                    aesthetics: aesthetics,
                    isUtility: isUtility,
                    saliencyRect: saliency
                ))
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

    /// Returns (overall aesthetics score, isUtility). Utility = screenshot,
    /// receipt, document, etc. Used only as a soft hint for non-favorite photos.
    private func analyzeAesthetics(image: CGImage) -> (Double, Bool) {
        let request = VNCalculateImageAestheticsScoresRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let result = request.results?.first else { return (0, false) }
            return (Double(result.overallScore), result.isUtility)
        } catch {
            return (0, false)
        }
    }

    /// Returns the most salient object's normalized bounding box (Vision's
    /// bottom-left origin), used to focus Ken Burns motion on the subject.
    private func analyzeSaliency(image: CGImage) -> CGRect? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first as? VNSaliencyImageObservation,
                  let object = observation.salientObjects?.first else { return nil }
            return object.boundingBox
        } catch {
            return nil
        }
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
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            Task { @MainActor in
                if let image { photo.image = image }
                // A non-degraded callback is terminal — whether it delivered the
                // final image or failed. Clear the in-flight marker either way so
                // a later appearance can retry instead of staying blank forever.
                if !isDegraded {
                    self?.inFlight.remove(photo.id)
                    if image != nil { self?.noteImageLoaded(photo) }
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

    // MARK: - Analysis cache persistence

    private struct PhotoAnalysis: Codable {
        let r: Double, g: Double, b: Double
        let h: Double, s: Double, br: Double
        let aesthetics: Double
        let isUtility: Bool
        let saliency: Rect?

        struct Rect: Codable { let x: Double, y: Double, w: Double, h: Double }

        init(color: NSColor, hue: CGFloat, saturation: CGFloat, brightness: CGFloat,
             aesthetics: Double, isUtility: Bool, saliencyRect: CGRect?) {
            let c = color.usingColorSpace(.deviceRGB) ?? color
            r = Double(c.redComponent)
            g = Double(c.greenComponent)
            b = Double(c.blueComponent)
            h = Double(hue)
            s = Double(saturation)
            br = Double(brightness)
            self.aesthetics = aesthetics
            self.isUtility = isUtility
            if let rect = saliencyRect {
                saliency = Rect(x: Double(rect.minX), y: Double(rect.minY),
                                w: Double(rect.width), h: Double(rect.height))
            } else {
                saliency = nil
            }
        }

        static var unknown: PhotoAnalysis {
            PhotoAnalysis(color: .darkGray, hue: 0, saturation: 0, brightness: 0.3,
                          aesthetics: 0, isUtility: false, saliencyRect: nil)
        }

        var color: NSColor { NSColor(deviceRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1) }
        var hue: CGFloat { CGFloat(h) }
        var saturation: CGFloat { CGFloat(s) }
        var brightness: CGFloat { CGFloat(br) }
        var saliencyRect: CGRect? {
            guard let s = saliency else { return nil }
            return CGRect(x: s.x, y: s.y, width: s.w, height: s.h)
        }
    }

    private var cacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Eidetic", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("analysis-cache.json")
    }

    private func loadAnalysisCache() {
        guard analysisCache.isEmpty,
              let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([String: PhotoAnalysis].self, from: data) else { return }
        analysisCache = decoded
    }

    private func saveAnalysisCacheIfNeeded() {
        guard cacheDirty else { return }
        cacheDirty = false
        let snapshot = analysisCache
        let url = cacheURL
        Task.detached {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    // MARK: - Filtered access

    /// Roughly how many favorites we show per rediscovery (non-favorite) photo
    /// in blended mode — so favorites stay clearly dominant.
    private let blendFavoritesPerOther = 5

    /// The pool every mode draws from. Favorites are trusted absolutely (never
    /// junk-filtered). In blended mode, a capped set of the strongest
    /// non-favorites is sprinkled in so favorites still dominate everywhere.
    var curatedPhotos: [AnalyzedPhoto] {
        let favorites = photos.filter { $0.isFavorite }

        if favoritesOnly {
            // No favorites yet (e.g., still loading) — show the junk-filtered set.
            return favorites.isEmpty ? photos.filter { !$0.isUtility } : favorites
        }

        let others = photos.filter { !$0.isFavorite && !$0.isUtility }
        guard !favorites.isEmpty else { return others }

        let sprinkleCount = min(others.count, max(8, favorites.count / blendFavoritesPerOther))
        let sprinkle = others
            .sorted { $0.aestheticsScore > $1.aestheticsScore }
            .prefix(sprinkleCount)
        return favorites + sprinkle
    }

    var favoritesCount: Int { photos.lazy.filter(\.isFavorite).count }
    var hiddenUtilityCount: Int { photos.lazy.filter { $0.isUtility && !$0.isFavorite }.count }

    func photosForToday(windowDays: Int = 3) -> [(Int, AnalyzedPhoto)] {
        let calendar = Calendar.current
        let today = Date()
        let month = calendar.component(.month, from: today)
        let day = calendar.component(.day, from: today)
        let currentYear = calendar.component(.year, from: today)

        return curatedPhotos.compactMap { photo in
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
        let sorted = curatedPhotos
            .filter { $0.saturation > 0.12 && $0.brightness > 0.15 }
            .sorted { $0.hue < $1.hue }

        guard sorted.count > limit else { return sorted }
        let step = Double(sorted.count) / Double(limit)
        return (0..<limit).compactMap { sorted[safe: Int(Double($0) * step)] }
    }

    /// Random photos for hero modes, preferring favorites first, then higher
    /// aesthetics. (When favorites-only is on, the pool is already all favorites,
    /// so this just biases by aesthetics within them.)
    func randomPhotos(_ count: Int) -> [AnalyzedPhoto] {
        let pool = curatedPhotos
        guard pool.count > count else { return pool.shuffled() }

        let sorted = pool.sorted { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            return a.aestheticsScore > b.aestheticsScore
        }
        let keepers = sorted.prefix(max(count * 4, pool.count / 2))
        return Array(keepers.shuffled().prefix(count))
    }

    func photosByYear() -> [Int: [AnalyzedPhoto]] {
        Dictionary(grouping: curatedPhotos.filter { $0.year != nil }, by: { $0.year! })
    }

    /// Photos from this same week of the year, across every past year, grouped
    /// and sorted by year — the raw material for Time Machine Radio. Broadens the
    /// window if this exact week is sparse so the mode always has a story to tell.
    func thisWeekAcrossYears() -> [(year: Int, photos: [AnalyzedPhoto])] {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let todayDayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 0

        func isNearToday(_ date: Date, within days: Int) -> Bool {
            guard let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) else { return false }
            let diff = abs(dayOfYear - todayDayOfYear)
            return min(diff, 365 - diff) <= days // wrap around the year boundary
        }

        func grouped(within days: Int) -> [(year: Int, photos: [AnalyzedPhoto])] {
            let matches = curatedPhotos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return calendar.component(.year, from: date) != currentYear && isNearToday(date, within: days)
            }
            return Dictionary(grouping: matches) { calendar.component(.year, from: $0.creationDate!) }
                .map { (year: $0.key, photos: $0.value) }
                .sorted { $0.year < $1.year }
        }

        let thisWeek = grouped(within: 3)
        return thisWeek.count >= 2 ? thisWeek : grouped(within: 15)
    }
}
