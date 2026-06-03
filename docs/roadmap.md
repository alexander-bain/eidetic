# Eidetic — Roadmap

## Phase 1: Solid Mac App

Fix what's broken and make it feel like a real application.

### App Shell
- [ ] Rename from PhotoCycler → Eidetic (bundle ID, display name, struct names, entitlements, filenames)
- [ ] Add AppDelegate for proper lifecycle management (window close, app termination, sleep/wake notifications)
- [ ] Menu bar: Play/Pause, Next Mode, Stay Awake toggle, mode picker submenu, Quit
- [ ] Dock icon with app name
- [ ] Settings window accessible from menu bar (Cmd+,) — currently exists but unreachable

### Photo Loading
- [ ] Remove 500-photo hardcoded limit — load entire library
- [ ] Background batch color analysis (don't block launch; show photos as they're analyzed)
- [ ] Cache analyzed color data to disk so re-launches are instant
- [ ] Progress indicator during initial analysis (first launch only)

### Mode Fixes
- [ ] **Color Sort**: Scale scroll duration to photo count — minimum 2 seconds visible per photo. If 200 photos, scroll takes 400s minimum. Add gentle easing at start/end instead of linear scroll.
- [ ] **Split Timeline**: When no today-matches exist, fall back to random year pairs from the full library. Always show something interesting.
- [ ] **Magazine Spread**: More Ken Burns direction variety (8+ patterns instead of 4). Randomize instead of cycling deterministically.

### Stability
- [ ] Fix controlsTimer leak in ContentView (invalidate on disappear)
- [ ] Update cycling queue immediately when enabled modes change in Settings
- [ ] Persist settings via UserDefaults (enabled modes, stay awake, window state)
- [ ] Clean up sleep prevention on app quit

---

## Phase 2: More Modes

Build out the full 18-mode catalog. Each mode is a self-contained SwiftUI View conforming to the same pattern.

### Tier A — Visual showcase (build first)
- [ ] **Ken Burns Classic** — Simple full-screen photo with slow drift. The baseline. No metadata overlay, just the photo.
- [ ] **Polaroid Drop** — Photos appear as Polaroid-framed cards that drop onto a surface with physics (SpriteKit or manual spring animation). Old ones fade. Slight random rotation on each.
- [ ] **Photo Wall** — Grid of thumbnails filling the screen. Each tile has subtle Ken Burns. One tile slowly enlarges to highlight, then shrinks back. Grid reshuffles every few minutes.
- [ ] **Film Strip** — Vertical sprocket-holed film frames scrolling upward. CIFilter grain/flicker overlay. Scroll speed inversely proportional to photo density (fast-forward through boring months, slow on trips).

### Tier B — Data-driven (use metadata)
- [ ] **Clock Face** — Screen divided into 12 hour segments, each containing a photo. As the real clock advances, the current hour's photo fades to full screen briefly. Functional ambient clock.
- [ ] **This Week in History** — Horizontal filmstrip of all photos from this calendar week across every year. Year labels above each cluster. Auto-scrolls slowly.
- [ ] **Diptych/Triptych** — Pairs or triples of photos matched by dominant color palette, displayed gallery-style with even white borders.
- [ ] **Weather Match** — Pulls current weather via WeatherKit. Selects photos matching the vibe: rain → moody/gray photos, sun → bright/saturated, snow → white/blue. Requires location permission.

### Tier C — Ambient/generative (visual effects)
- [ ] **Kaleidoscope** — Takes a photo, applies CIKaleidoscope filter with slow rotation. Morphs parameters as it transitions to next photo.
- [ ] **Puzzle Reveal** — Photo broken into ~20 jigsaw-like pieces scattered around the screen. Over 30-60s, pieces drift into place. Hold complete image for 5s, then scatter and reform as next photo.
- [ ] **Parallax Layers** — Uses Portrait Mode depth map to separate foreground/background. Applies subtle parallax drift as if the photo has physical depth. Falls back to faked split on non-portrait photos.
- [ ] **Sunrise/Sunset Cycle** — Photos tinted to match real sun position (warm golden hour, cool blue night). Transition speed matches time of day — slow and contemplative at dusk, brighter and faster at noon.

### Tier D — Interactive (idle → auto, active → play)
- [ ] **Guess the Year** — Shows photo with date hidden. Four year buttons. Auto-reveals after 10s if no input. Idle mode auto-cycles.
- [ ] **Photo Roulette** — Slot-machine rapid scroll, decelerates to stop on random photo. Auto-spins every 2 minutes in idle mode.
- [ ] **Face Cluster Shuffle** — Groups photos by detected faces (Vision framework). Dedicates time to each person with a subtle "The [Name] Collection" label. Tap/click face bubbles to jump between people.

---

## Phase 3: Multi-Platform

### Shared Framework
- [ ] Extract all modes, PhotoProvider, ModeCoordinator, and models into a shared Swift package
- [ ] Platform-conditional compilation (`#if os(macOS)`, `#if os(tvOS)`, etc.) for platform-specific APIs
- [ ] Abstract input handling: keyboard (Mac), Siri Remote (tvOS), touch/gestures (iPadOS)

### iPad + External Display
- [ ] iPadOS app target
- [ ] Detect connected external display via `UIScreen.screens` / `UIWindowScene`
- [ ] iPad screen = control surface (mode picker, photo browser, settings)
- [ ] External monitor = display surface (the mode view, full screen)
- [ ] `UIApplication.shared.isIdleTimerDisabled = true` for stay-awake
- [ ] Stage Manager support: filter for foreground-active `UIWindowScene`

### Apple TV
- [ ] tvOS app target — simplest platform (one screen, no controls overlay)
- [ ] Siri Remote: Play/Pause (center button), Next Mode (swipe right), Menu (back to mode picker)
- [ ] Top Shelf extension showing recent photo highlights
- [ ] Focus engine for interactive modes (Guess the Year, Photo Roulette)

### Mac Screensaver
- [ ] macOS screensaver bundle target (`.saver`)
- [ ] `ScreenSaverView` subclass wrapping SwiftUI mode views via `NSHostingView`
- [ ] Screensaver preferences panel for mode selection
- [ ] No sleep prevention needed (screensaver handles this)
- [ ] Test with System Settings → Screen Saver picker

---

## Phase 4: Intelligence & Polish

### Smart Curation
- [ ] Photo density detection — identify trips (clusters of 50+ photos in 3 days) vs. mundane days
- [ ] Auto-generate "highlight reels" from trip clusters
- [ ] Seasonal awareness: summer photos in summer, holiday photos in December
- [ ] Recency bias option: weight toward recent photos or weight evenly across all time

### Location Intelligence
- [ ] Reverse geocode photo locations → place names ("Summer in Maine", "Tokyo 2023")
- [ ] Map cluster visualization mode
- [ ] Location-themed sessions: tap a place, see all photos from there

### People
- [ ] Vision framework face detection + clustering (on-device, no cloud)
- [ ] Name faces via Photos app integration (if available)
- [ ] Person-themed display sessions
- [ ] "Faces through the years" — same person across time

### Audio Integration
- [ ] Optional background music from Apple Music
- [ ] Tempo-aware transitions (beat-synced mode changes)
- [ ] Ambient sound generation (gentle piano, nature sounds)

### Sync & Sharing
- [ ] iCloud Photo Library support for accessing full library across devices
- [ ] AirPlay from iPad → Apple TV (send current mode to big screen)
- [ ] Share a "moment" (screenshot of current mode display) to Messages/social
- [ ] Mac desktop widget showing current photo

---

## Design North Stars

- **It should feel like a window into your memories**, not a tech demo
- **Every mode should be something you'd leave running** at a dinner party
- **10 photos or 10,000** — it should look great either way
- **Silence is golden** — no sounds by default, no notifications, no badges
- **The best feature is the one running when no one's watching**
