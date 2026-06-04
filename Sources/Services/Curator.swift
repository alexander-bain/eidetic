import Foundation
import FoundationModels

/// A short gallery placard for the current segment.
struct CuratedPlacard: Equatable {
    let title: String      // exhibit title, e.g. "On This Day"
    let subtitle: String   // one evocative line beneath it
}

/// Facts about what's currently on screen, handed to the curator to write copy.
struct SegmentContext {
    let mode: DisplayModeType
    let photoCount: Int
    let years: [Int]        // distinct years present, ascending
    let onThisDay: Bool     // photos from today's date in past years
    let allFavorites: Bool
}

/// Writes curatorial placard copy for a segment. Uses Apple's on-device
/// Foundation Models when available (free, private), and always has an elegant
/// templated fallback so the gallery never goes wordless.
@MainActor
final class Curator {

    /// Immediate templated copy — used as the instant placard and the fallback
    /// whenever the on-device model is unavailable.
    static func fallback(for context: SegmentContext) -> CuratedPlacard {
        switch context.mode {
        case .splitTimeline:
            let subtitle: String
            if let first = context.years.first, let last = context.years.last, first != last {
                subtitle = "\(first) and \(last)"
            } else {
                subtitle = "the same day, across the years"
            }
            return CuratedPlacard(title: "Then & Now", subtitle: subtitle)

        case .colorSort:
            return CuratedPlacard(title: "Spectrum", subtitle: "your photos, sorted by color")

        case .magazineSpread:
            if context.onThisDay {
                return CuratedPlacard(title: "On This Day", subtitle: yearsPhrase(context.years))
            }
            return CuratedPlacard(
                title: context.allFavorites ? "Favorites" : "From the Archive",
                subtitle: "moments worth keeping"
            )
        }
    }

    /// On-device LLM copy, or nil if Foundation Models isn't available/usable.
    func generatedPlacard(for context: SegmentContext) async -> CuratedPlacard? {
        guard #available(macOS 26.0, *) else { return nil }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }

        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(to: Self.prompt(for: context))
            return Self.parse(response.content) ?? Self.fallback(for: context)
        } catch {
            return nil
        }
    }

    // MARK: - Prompting

    private static let instructions = """
    You are the curator of someone's private photo gallery. For each exhibit you \
    write a short placard: a TITLE and a SUBTITLE.

    - TITLE: 1–4 words, Title Case. Evocative, never cheesy or clickbait.
    - SUBTITLE: one line, at most ~10 words. Quiet, gallery-wall tone — like a \
    museum placard, not an ad.
    - Vary your phrasing; avoid repeating the same words each time.
    - Never invent specific people, places, or events you weren't told about.

    Respond with exactly two lines:
    Line 1: the title
    Line 2: the subtitle
    No labels, no quotes, no extra text.
    """

    private static func prompt(for c: SegmentContext) -> String {
        var facts: [String] = []
        facts.append("Presentation style: \(styleDescription(c.mode)).")
        facts.append("\(c.photoCount) photos on screen.")
        if c.onThisDay { facts.append("These were taken on today's date in earlier years.") }
        if !c.years.isEmpty {
            facts.append("Years represented: \(c.years.map(String.init).joined(separator: ", ")).")
        }
        facts.append(c.allFavorites ? "All are photos the owner favorited." : "A mix of favorites and rediscovered shots.")
        return "Write a placard for this exhibit.\n\n" + facts.joined(separator: "\n")
    }

    private static func styleDescription(_ mode: DisplayModeType) -> String {
        switch mode {
        case .magazineSpread: return "an editorial magazine spread with one hero photo"
        case .splitTimeline: return "two photos side by side from different years"
        case .colorSort: return "a flowing strip of photos arranged by color"
        }
    }

    private static func parse(_ text: String) -> CuratedPlacard? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let title = lines.first else { return nil }
        let subtitle = lines.count > 1 ? lines[1] : ""
        return CuratedPlacard(title: title, subtitle: subtitle)
    }

    private static func yearsPhrase(_ years: [Int]) -> String {
        guard let earliest = years.first else { return "moments from years past" }
        let span = Calendar.current.component(.year, from: Date()) - earliest
        if span > 0 { return span == 1 ? "one year ago" : "as far back as \(span) years ago" }
        return "from years past"
    }
}
