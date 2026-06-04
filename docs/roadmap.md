# Eidetic — Roadmap

## Phase 1: Solid Mac App

Fix what's broken and make it feel like a real application.

### App Shell
- [x] Rename from PhotoCycler → Eidetic (bundle ID, display name, struct names, entitlements, filenames)
- [x] Add AppDelegate for proper lifecycle management (window close, app termination, sleep/wake notifications)
- [x] Menu bar: Play/Pause, Next Mode, Stay Awake toggle, mode picker submenu, Quit
- [x] Dock icon with app name (via `setActivationPolicy(.regular)`)
- [x] Settings window accessible from menu bar (Cmd+,) — currently exists but unreachable

### Photo Loading
- [x] Remove 500-photo hardcoded limit — load entire library
- [x] Background batch color analysis (don't block launch; show photos as they're analyzed)
- [x] Cache analyzed color data to disk so re-launches are instant
- [x] Progress indicator during initial analysis (first launch only)
- [x] On-demand display-image loading with LRU cap (memory stays flat at any library size)

### Mode Fixes
- [x] **Color Sort**: Scale scroll duration to photo count — minimum 2 seconds visible per photo. If 200 photos, scroll takes 400s minimum. Add gentle easing at start/end instead of linear scroll.
- [x] **Split Timeline**: When no today-matches exist, fall back to random year pairs from the full library. Always show something interesting.
- [x] **Magazine Spread**: More Ken Burns direction variety (8+ patterns instead of 4). Randomize instead of cycling deterministically.

### Stability
- [x] Fix controlsTimer leak in ContentView (invalidate on disappear)
- [x] Update cycling queue immediately when enabled modes change in Settings
- [x] Persist settings via UserDefaults (enabled modes, stay awake, window state)
- [x] Clean up sleep prevention on app quit

---

## Photo Intelligence (cross-cutting)

The differentiator — see [`vision.md`](vision.md) for the full thesis. Built
incrementally alongside the phases below.

- [x] **On-device quality + saliency** — Vision aesthetics/utility scoring (junk
  filtering), aesthetic-biased selection, attention-saliency-aware Ken Burns
- [ ] On-device face/pet clustering + `featurePrint` embeddings (similarity/dedup)
- [ ] **OpenAI semantic cache** — captions + mood/activity tags per frame-worthy
  photo, cached to disk; caption embeddings for concept search (opt-in)
- [ ] **The Curator** — daily AI-planned themed sessions with generative placards
- [ ] Concept/mood modes + narrative diptychs over the semantic index

---

## Phase 2: AI-Native Modes

The original 18-mode catalog was **retired** — most of it re-skinned what Apple
already does well. The new catalog (chosen via the review in
`docs/vision.md`) is 12 modes that only make sense in 2026 and reward a deep,
richly-tagged library. Built in **waves by shared infrastructure**, cheapest
first, so each wave reuses the last.

### Wave 1 — LLM + existing metadata (reuses Curator + PhotoProvider)
- [x] **Time Machine Radio** — this week across all years, narrated as a memoir by the on-device LLM (Apple Foundation Models). *First build — done.*
- [ ] **Reverse Postcard** — picks a trip, writes (in your voice) the postcard you never sent.

### Wave 2 — Geo (MapKit + reverse geocoding)
- [x] **Reverse-geocoding grounding layer** (`Geocoder`) — coordinates → real place names, cached; reused by all geo modes. *Done.*
- [x] **The Map Room** — animated map flying between your photo locations, blooming each memory (photo + date + geocoded place name). *Done.*
- [x] **Same Spot, Different Time** — one place (coarse-coordinate cluster) revisited across years; photos cross-fade chronologically under the geocoded place name. *Done.* (Framing auto-alignment is a future refinement.)

### Wave 3 — Face clustering (Vision faceprints + naming UI)
- [ ] **A Life in Faces** — one person, aging across every photo, date-ordered and morphing.
- [ ] **The Cast** — your social universe as a living credits roll (central / new / drifted-from).

### Wave 4 — Semantic substrate (captions/tags + embeddings; opt-in cloud/local-VLM)
- [ ] **Thematic Threads** — a hidden visual motif across the whole library, as a wandering essay.
- [ ] **The Algorithm's Favorite** — photos *it* finds striking that *you* never favorited, argued.

### Wave 5 — Generative imaging (on-device diffusion / depth / Image Playground / MLX)
- [ ] **Living Portraits** — depth + motion bring stills to life (the surviving Parallax idea). *Start here — cheapest of the wave.*
- [ ] **Beyond the Frame** — outpainting extends each photo past its edges into dreamlike motion.
- [ ] **The Style Wing** — each photo re-rendered in an art movement the AI judges fits it.
- [ ] **The Composite** — many photos fused into one impossible image.

### Backlog (needs refinement before building)
The Critic · Mood Ring · Lexicon (Tag Rooms) · Together · Chrono-Morph ·
Anniversary Engine (build as an *ambient layer*, not a mode) · Window Rhyme ·
Tell Me About This · Hard Mode Trivia.

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
