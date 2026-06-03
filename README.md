<div align="center">

# Eidetic

**Your photo library, reimagined as a living art installation.**

Eidetic turns the photos you already have into ambient art — cycling through
creative visual modes that make you stop and look again. Editorial magazine
spreads, color-sorted galleries, time-travel comparisons, and more. Always on,
always beautiful, always surprising.

*macOS today · iPad, Apple TV, and screensaver on the roadmap.*

</div>

---

## Why

Most of your photos live in the dark — buried in a library you scroll past once
and never open again. Eidetic is the opposite of a slideshow: it's **background
art** designed to be left running. Slow, gentle transitions. Gallery-wall
typography. Every photo gets its moment. It's the thing playing on the screen in
the corner of the room that makes a guest ask *"wait — is that *your* photos?"*

## Display Modes

| Mode | What it does |
|------|--------------|
| **Magazine Spread** | Editorial layout — a metadata placard beside a hero photo with a slow Ken Burns drift. Eight randomized drift patterns so no two spreads feel alike. |
| **Split Timeline** | The same calendar day across different years, side by side. When there's no match for today, it gracefully falls back to pairs from different years so it always shows something. |
| **Color Sort** | Every photo sorted into a flowing strip by hue, over a gradient that shifts with the spectrum. Scroll speed scales to your library so it's contemplative, never dizzying. |

…with 15 more modes on the roadmap — kaleidoscope, photo wall, polaroid drop,
face clusters, depth-based parallax, and weather-driven selection among them.

## Design Principles

- **Ambient, not attention-demanding.** 1.5s+ crossfades, gentle motion. This is art, not a presentation.
- **Dark-first.** Black backgrounds, white typography — the app disappears so the photos shine.
- **Every photo gets its moment.** A minimum of seconds on screen; nothing whips by unseen.
- **10 photos or 10,000.** It looks great either way, and memory stays flat regardless of library size.
- **No chrome.** Controls fade in on hover and disappear. Full screen is the default.

## Built With

100% Apple frameworks, zero third-party dependencies.

- **SwiftUI** — shared UI across every target
- **PhotoKit** (`PHCachingImageManager`) — reads your library in place; photos are *never* copied
- **Core Image** (`CIAreaAverage`) — dominant-color analysis, cached to disk so re-launches are instant
- **ProcessInfo** activity assertions — keeps the display awake while running

### How it scales

Eidetic tracks your **entire** library but holds at most a few hundred decoded
images in memory at once (LRU eviction), loading each photo on demand as a mode
needs it. The only thing written to disk is a tiny color cache — six numbers per
photo — so a 50,000-photo library produces a cache measured in single-digit
megabytes. Your photos stay exactly where they are.

## Getting Started

Requires macOS 14 (Sonoma) and Xcode 16.

```bash
git clone https://github.com/alexander-bain/eidetic.git
cd eidetic
open Package.swift   # then set the run destination to "My Mac" and hit Run
```

On first launch, grant Photos access. The first batch of photos appears almost
immediately while the rest of the library analyzes in the background.

Command-line type-check:

```bash
xcrun swiftc -typecheck -sdk $(xcrun --show-sdk-path) \
  -target arm64-apple-macosx14.0 Sources/**/*.swift
```

### Controls

| Key | Action |
|-----|--------|
| `F` | Toggle full screen |
| `→` | Skip to next mode |
| `Space` | Toggle keep-awake |
| `⌘P` | Play / Pause |
| `⌘,` | Settings |

## Roadmap

Eidetic is built in phases — see [`docs/roadmap.md`](docs/roadmap.md) for the
full plan. Phase 1 (a solid, polished Mac app) is complete; Phase 2 expands the
mode catalog to all 18, and Phase 3 brings iPad, Apple TV, and a Mac screensaver.

## License

[MIT](LICENSE) © 2026 Alex Bain. You're welcome to learn from and build on this
code — please keep the attribution.
