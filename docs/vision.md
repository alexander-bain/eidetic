# Eidetic — Product Vision

## The thesis

**Eidetic isn't a screensaver — it's an AI curator that mounts a new exhibition
of your life every day.** The Mac, the iPad, the Apple TV, the screensaver are
just *output surfaces*. The product is **taste, understanding, and narrative**.

We will never out-polish Apple on motion or aerials, and we shouldn't try. We
win on the things Apple's locked black box structurally *won't* do.

## What Apple already owns (don't compete here)

- Buttery motion, aerials, polished Ken Burns.
- On-device curation basics: faces, pets, scenes, OCR, locations, junk hiding.
- Music-synced themed Memories with titles and transitions.
- Total privacy — everything stays on device.

## Where Apple is structurally weak (our opening)

- It understands **categories, not meaning** — "beach, dog, 3 people" but never
  "a candid mid-laugh," "this rhymes with a photo five years ago," "this feels
  lonely."
- It **can't curate by abstract concept or narrative** — no "photos that feel
  like Sunday morning," no "this dog growing up," no meaningful juxtaposition.
- It's **episodic and generic**, not a persistent, ever-changing exhibition.
- You **can't program its taste** — no "only frame-worthy shots, golden-hour
  weighted, museum-placard voice, never screenshots."
- **No generative voice** — canned titles, never a curator writing about *your*
  life.

## The intelligence architecture (hybrid, on-device first)

Cheap/private work runs on-device; OpenAI is used sparingly for the reasoning
Apple can't do — and the curator usually reasons over *distilled text*, not the
images, which is cheaper **and** more private.

| Tier | Where | What | Status |
|------|-------|------|--------|
| 0 | On-device | Dominant color (CIAreaAverage) | ✅ Done |
| 1 | On-device (Vision) | Aesthetics + utility/junk detection, attention saliency; *planned:* face/pet clustering, `featurePrint` embeddings, OCR | ✅ Partial |
| 2 | OpenAI (opt-in, once/photo, cached) | Rich caption + mood/activity/composition tags; caption embeddings for concept search | ⏳ Planned |
| 3 | OpenAI (on-demand, text-only, cheap) | **The Curator** — plans daily themed sessions and writes placards from cached tags + live context | ⏳ Planned |

Because Tiers 0–2 are cached to disk, **most playback runs with zero live API
calls.** Tier 3 sends text, not images.

## What this unlocks

- **The Curator** — "Today: blue hour. Seven dusk photos across five years, with
  a one-line meditation on endings." Different every day, never repeats.
- **Concept / mood modes** — "Sunday morning," "people you love laughing,"
  "empty rooms," via tags + embeddings.
- **Narrative diptychs** — pairings that *mean* something (same pose/decade, a
  kid growing up, every doorway you've shot), not just matched by color.
- **Museum placards in a voice you choose** — art-critic, poet, deadpan,
  Attenborough. Silent/text by default; narration strictly opt-in.
- **"Always beautiful" for real** — tunable junk filtering + saliency-aware
  framing so the wall is only frame-worthy shots, well-composed.
- **Programmable taste + natural-language control** — "show me beach trips, no
  screenshots" (a great fit for the Siri Remote on tvOS).

## Realities we respect

- **Privacy** — sending photos to OpenAI is an explicit opt-in. A fully-local
  mode (Tiers 0–1 only) is always available; Tier 3 sends text, not images.
- **Cost** — an on-device quality gate runs first, so only frame-worthy photos
  are ever enriched; mini models, 512px inputs, sampling, a user budget, and a
  permanent cache keep spend low.
- **Taste** — LLM curation can misfire; caching means a bad day costs nothing to
  re-roll, and guardrails constrain the output.

## Build order

1. **On-device quality + saliency** ✅ — junk filtering, aesthetic ranking,
   saliency-aware Ken Burns. Free, private, immediate. (Done.)
2. **OpenAI semantic cache** — background caption/tag enrichment of frame-worthy
   photos, cached, with caption embeddings.
3. **The Curator** — daily AI-planned themed sessions with placards.
4. Concept/mood modes and narrative diptychs on top of the semantic index.
