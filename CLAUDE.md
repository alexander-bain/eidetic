# CLAUDE.md

## Project Overview

**Eidetic** is a photo display app that transforms your photo library into a living art installation. It cycles through creative visual modes — editorial magazine layouts, color-sorted galleries, time-travel comparisons, kaleidoscopes, and more — across your Mac, iPad, Apple TV, and as a screensaver.

**Vision**: Your photos, always on, always beautiful, always surprising.

**Target platforms**: macOS (app + screensaver), iPadOS (with external display), tvOS (Apple TV)

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| UI Framework | SwiftUI (shared across all platforms) |
| Photo Access | PhotoKit (PHPhotoLibrary, PHCachingImageManager) |
| Color Analysis | Core Image (CIAreaAverage filter) |
| Photo Intelligence | Vision — aesthetics/utility scoring + attention saliency (on-device) |
| Face Detection | Vision framework (planned) |
| Content Understanding | OpenAI vision + captions (planned, opt-in; hybrid on-device-first) |
| Depth Data | AVDepthData from Portrait Mode photos (planned) |
| Weather | WeatherKit (planned, for Weather Match mode) |
| Sleep Prevention | ProcessInfo.beginActivity (macOS) / isIdleTimerDisabled (iOS) |
| Minimum Target | macOS 14.0 (Sonoma), iOS 17.0, tvOS 17.0 |

No external dependencies. Apple frameworks only.

---

## Project Structure

```
Eidetic/
├── Package.swift                     # Swift Package (open in Xcode)
├── project.yml                       # XcodeGen spec (for full Xcode project)
├── Eidetic.entitlements              # App sandbox + Photos permission
├── Resources/
│   └── Info.plist                    # Photos usage description
├── Sources/
│   ├── App/
│   │   ├── EideticApp.swift           # @main entry point
│   │   ├── ContentView.swift         # Mode switcher, loading, onboarding
│   │   └── SettingsView.swift        # Preferences window
│   ├── Models/
│   │   └── AnalyzedPhoto.swift       # Photo data model with color/metadata
│   ├── Services/
│   │   └── PhotoProvider.swift       # Photo library access + color analysis
│   ├── Modes/
│   │   ├── DisplayMode.swift         # Mode enum (types, durations, icons)
│   │   ├── ModeCoordinator.swift     # Cycling logic + sleep prevention
│   │   ├── MagazineSpreadView.swift  # Editorial layout + Ken Burns
│   │   ├── SplitTimelineView.swift   # Same day, different years
│   │   └── ColorSortView.swift       # Hue-sorted scrolling strip
│   └── Utilities/
│       └── Extensions.swift          # Safe array subscript
└── docs/
    └── roadmap.md                    # Full product roadmap
```

---

## Architecture

```
PHPhotoLibrary
    ↓
PhotoProvider (loads photos, analyzes dominant color via CIAreaAverage)
    ↓
ModeCoordinator (cycles through enabled modes on a timer, manages sleep prevention)
    ↓
ContentView (switches between mode views with crossfade transitions)
    ↓
┌──────────────────┬──────────────────┬──────────────────┐
│ MagazineSpread   │ SplitTimeline    │ ColorSort         │
│ (editorial +     │ (same day,       │ (hue-sorted      │
│  Ken Burns)      │  diff years)     │  scrolling strip) │
└──────────────────┴──────────────────┴──────────────────┘
```

**Key design decisions**:
- Each display mode is a self-contained SwiftUI View that receives photos and manages its own internal animation timers
- ModeCoordinator owns the mode-to-mode cycling; individual modes own their within-mode photo cycling
- PhotoProvider does color analysis at load time (CIAreaAverage → HSB decomposition) so modes can filter/sort instantly
- Sleep prevention uses `ProcessInfo.beginActivity()` with `.idleDisplaySleepDisabled`

---

## Display Modes Catalog

| # | Mode | Status | Description |
|---|------|--------|-------------|
| 1 | Magazine Spread | Built | Editorial layout: metadata panel + hero photo with Ken Burns drift |
| 2 | Split Timeline | Built | Same day, different years — side-by-side comparison |
| 3 | Color Sort | Built | Photos sorted by hue, auto-scrolling strip with gradient background |
| 4 | Polaroid Drop | Planned | Physics-based Polaroids stacking on a surface |
| 5 | Photo Wall | Planned | Mosaic grid with Ken Burns on each tile |
| 6 | Kaleidoscope | Planned | Core Image mirror/rotate into kaleidoscope patterns |
| 7 | Clock Face | Planned | 12 photo segments as clock hours, time-aware |
| 8 | Puzzle Reveal | Planned | Jigsaw pieces drift into place over 30-60s |
| 9 | Film Strip | Planned | Sprocket-hole film frames, grain, speed varies by photo density |
| 10 | Weather Match | Planned | Current weather drives photo selection (rain → rainy photos) |
| 11 | Sunrise/Sunset | Planned | Real sun position drives tint, speed, and photo mood |
| 12 | This Week in History | Planned | Photos from this week across all years |
| 13 | Guess the Year | Planned | Interactive — guess when the photo was taken |
| 14 | Photo Roulette | Planned | Slot machine spin to a random photo |
| 15 | Face Clusters | Planned | Vision framework groups by person, themed sessions |
| 16 | Parallax Layers | Planned | Portrait Mode depth data for 3D parallax effect |
| 17 | Diptych/Triptych | Planned | 2-3 photos paired by color palette, gallery-style |
| 18 | Ken Burns Classic | Planned | Simple full-screen with slow drift (standalone mode) |

---

## Development Workflow

- **Open in Xcode**: Open `Package.swift` (File → Open), set destination to "My Mac", hit Run
- **Type-check from CLI**: `xcrun swiftc -typecheck -sdk $(xcrun --show-sdk-path) -target arm64-apple-macosx14.0 Sources/**/*.swift`
- **Full Xcode project** (when needed for signing/entitlements): Install xcodegen, run `xcodegen generate`, open `Eidetic.xcodeproj`

### Keyboard Shortcuts
| Key | Action |
|-----|--------|
| F | Toggle full screen |
| → | Skip to next mode |
| Space | Toggle stay-awake |
| Cmd+P | Play/Pause cycling (menu) |
| Cmd+→ | Next mode (menu) |
| Cmd+L | Toggle stay-awake (menu) |
| Cmd+, | Open Settings |

---

## Design Principles

1. **Ambient, not attention-demanding** — transitions are slow (1.5s+ crossfades), animations are gentle. This is background art, not a slideshow presentation.
2. **Dark-first** — black backgrounds, white typography, photos are the color. The app disappears; the photos shine.
3. **Typography as design** — large ultraLight serif fonts for dates/years, tight tracking on labels. Think gallery wall placard.
4. **Every photo gets its moment** — minimum 2 seconds visible per photo in any mode. No photo should whip by unseen.
5. **Graceful degradation** — modes should always show something beautiful, even with 10 photos or no date metadata.
6. **No chrome** — controls appear on hover/interaction and fade. Full screen is the default experience.

---

## Phase 1 Status — Resolved

1. ~~**No menu bar or dock controls**~~ — ✅ Menu bar (Playback menu: Play/Pause, Next Mode, Stay Awake, mode picker); dock icon via `NSApp.setActivationPolicy(.regular)`
2. ~~**Hardcoded 500-photo limit**~~ — ✅ Loads entire library; first batch shown immediately, rest analyzed in background chunks
3. ~~**Color Sort scrolls too fast**~~ — ✅ Scroll duration scales with photo count (≥2.5s/photo), gentle ease-in/out timing curve
4. ~~**Split Timeline empty most days**~~ — ✅ Falls back to random pairs from different years when no "on this day" matches
5. ~~**Settings don't persist**~~ — ✅ Enabled modes + stay-awake saved to UserDefaults; window frame autosaved
6. ~~**Timer leaks**~~ — ✅ `controlsTimer` invalidated in ContentView `.onDisappear`
7. ~~**Cycling queue stale**~~ — ✅ `ModeCoordinator.enabledModesDidChange()` rebuilds the queue immediately
8. ~~**No app lifecycle management**~~ — ✅ `AppDelegate` releases sleep-prevention assertion on quit

**Architecture note (Phase 1):** Display images load on demand via `PhotoProvider.requestImage(_:)` with a 400-image LRU cap, so memory stays flat regardless of library size. `AnalyzedPhoto` is a reference type (`ObservableObject`) so on-demand image loads update views in place.

**Photo Intelligence (on-device).** During the background pass, each photo gets one ~512px thumbnail through three analyzers in `PhotoProvider.analyzeAsset`: dominant color (CIAreaAverage), aesthetics + utility detection (`VNCalculateImageAestheticsScoresRequest`, macOS 15+), and subject saliency (`VNGenerateAttentionBasedSaliencyImageRequest`). Results are cached to `~/Library/Application Support/Eidetic/analysis-cache.json`. Effects:
- **Junk filtering** — screenshots (`PHAsset.mediaSubtypes.photoScreenshot`) + utility images (receipts/docs) are excluded via `displayablePhotos`; all modes select from it.
- **Aesthetic ranking** — `randomPhotos` biases hero modes toward frame-worthy shots.
- **Saliency-aware Ken Burns** — `AnalyzedPhoto.subjectAnchor` focuses the Magazine hero zoom on the subject.

See [`docs/vision.md`](docs/vision.md) for the product thesis and the planned OpenAI content-understanding layer.

---

## Code Style

- **SwiftUI-first**: All views are SwiftUI structs. No UIKit/AppKit views unless necessary.
- **`@MainActor`**: Only on async methods that mutate published state, not class-wide.
- **Structs over classes**: Models are structs. Only ObservableObject services are classes.
- **No external dependencies**: Apple frameworks only. No SPM packages.
- **Naming**: Modes are `{Name}View.swift`. Services are `{Name}.swift` in Services/. Models are `{Name}.swift` in Models/.
- **Comments**: None by default. Only when the WHY is non-obvious.
