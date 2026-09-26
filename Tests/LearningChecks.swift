import Foundation

@main struct LearningChecks {
    @MainActor static func main() async throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("learning.json")
        let now = Date()
        let sources = (1...3).map { LearningLink(title: "Source \($0)", url: "https://example\($0).org/guide") }
        let steps = zip(["Intro", "Intermediate", "Deep"], sources).map { SeriesStep(level: $0.0, title: "A useful step", outcome: "Learn a concrete mechanism", bridge: "Apply it to a small example", minutes: 10, source: $0.1) }
        var series = TopicSeries(topic: "Toolsets", overview: "One coherent path.", created: now.addingTimeInterval(-3600), steps: steps)
        series.bookmarked = true
        assert(series.isActive(at: series.expires.addingTimeInterval(-0.001)))
        assert(!series.isActive(at: series.expires))
        assert(!series.isActive(at: series.expires.addingTimeInterval(1)))
        var expired = series; expired.id = UUID(); expired.created = now.addingTimeInterval(-48 * 3600)
        var vault = LearningVault(); vault.series = [series, expired]
        let card = ConceptReel(topic: LearningCurriculum.lanes[0], title: "Typed tools", idea: "A contract", example: "Use a typed function", pitfall: "Validation is not authorization", detail: "Details", question: "Why?", answer: "To constrain inputs", sources: [sources[0]])
        vault.edition = ReelEdition(date: now, cards: [card]); vault.pendingDate = now; vault.pending = [card]; vault.completedLanes = [card.topic]
        try JSONEncoder().encode(vault).write(to: file)
        let studio = LearningStudio(file: file)
        assert(studio.vault.series.count == 1 && studio.vault.series[0].bookmarked)
        studio.complete(series.id, level: "Intro"); studio.toggleSaved(card); studio.markSeen(card.id)
        let reopened = LearningStudio(file: file)
        assert(reopened.vault.series[0].steps[0].completed)
        assert(reopened.vault.saved.count == 1 && reopened.vault.edition!.cards[0].seen)
        assert(reopened.vault.completedLanes == [card.topic] && reopened.vault.pending.count == 1)
        reopened.expire(at: series.expires)
        assert(reopened.vault.series.isEmpty && reopened.vault.saved.count == 1)
        let before = reopened.vault.edition!.cards.map(\.id)
        await reopened.generateReels(manual: true) // Today's saved edition prevents ANY network request.
        assert(reopened.vault.edition!.cards.map(\.id) == before)
        print("PASS: strict 48h expiry includes bookmarks; source progress, saved reels, seen state and partial-generation checkpoints survive reopening; daily cache reused.")

        let broken = directory.appendingPathComponent("broken.json")
        let brokenBytes = Data("not-json-original-data".utf8)
        try brokenBytes.write(to: broken)
        let badStore = LearningStudio(file: broken)
        assert(badStore.storageError != nil)
        badStore.toggleSaved(card)
        let preserved = try Data(contentsOf: broken); assert(preserved == brokenBytes)
        print("PASS: corrupt content storage is preserved, never silently reset.")

        let evidence = Set(sources.map { Discovery.canonical($0.url) })
        let response = ResearchResponse(data: Data(), evidence: evidence)
        let input = zip(["Intro", "Intermediate", "Deep"], sources).map { LearningStudio.SeriesStepPayload(level: $0.0, title: "Learn", outcome: "One outcome", bridge: "Next", minutes: 10, source: $0.1) }
        let validSteps = try LearningStudio.validateSeries(input, response: response, budget: 30); assert(validSteps.count == 3)
        for mode in 0..<4 {
            var changed = input
            if mode == 0 { changed[1].source = changed[0].source }
            if mode == 1 { changed[0].source.url = "https://invented.org/guide" }
            if mode == 2 { changed.swapAt(0, 2) }
            if mode == 3 { changed[2].minutes = 11 }
            do { _ = try LearningStudio.validateSeries(changed, response: response, budget: 30); fatalError("Invalid series accepted") } catch {}
        }
        print("PASS: series rejects duplicated/uncited URLs, incorrect progression and total-budget overrun.")

        let mechanism = ["Validate tool inputs against a typed schema", "Restrict available tool actions by execution context"]
        let explanation = "The documentation explains how typed arguments are validated before execution and shows how context controls tool availability with concrete implementation examples."
        let review = EditorialPolicy.Assessment(url: sources[0].url, topic: "tools", promotional: false, inspected: true, wordCount: 900, fullMinutes: 8, kind: "article", mechanisms: mechanism, evidence: explanation)
        assert(EditorialPolicy.eligible(review, budget: 10))
        for mode in 0..<6 {
            var changed = review
            switch mode { case 0: changed.promotional = true; case 1: changed.inspected = false; case 2: changed.wordCount = 300; case 3: changed.mechanisms = ["Generic praise"]; case 4: changed.fullMinutes = 11; default: changed.kind = "rejected" }
            assert(!EditorialPolicy.eligible(changed, budget: 10))
        }
        let resources = sources.map { DailyRecommendation(title: "Guide", url: $0.url, publisher: "Publisher", why: "One benefit", question: "Why", format: "Article", minutes: 5) }
        var reviews = sources.map { source -> EditorialPolicy.Assessment in var copy = review; copy.url = source.url; return copy }
        reviews[0].topic = "evals"; reviews[1].topic = "evals"; reviews[2].topic = "memory"
        let selection = EditorialPolicy.select(resources, reviews: reviews, evidence: evidence, budget: 10, diverse: true)
        assert(selection.count == 2 && selection.last!.topic == "memory" && selection[0].minutes == 8)
        assert(EditorialPolicy.select(resources, reviews: reviews, evidence: [], budget: 10, diverse: true).isEmpty)
        print("PASS: editorial gate rejects promotions, thin articles, uninspected content and inflated fit; applies topic variety and audited duration.")

        func words(_ count: Int) -> String { Array(repeating: "mechanism", count: count).joined(separator: " ") }
        var draft = LearningStudio.ReelDraft(title: "A typed boundary", idea: words(30), example: words(12), pitfall: words(10), detail: words(90), question: "What is constrained?", answer: "The input shape", sources: [sources[0]])
        assert(LearningStudio.validateReels([draft, draft], lane: "Tools & contracts", response: response).count == 1)
        draft.sources[0].url = "https://invented.org/doc"
        assert(LearningStudio.validateReels([draft], lane: "Tools & contracts", response: response).isEmpty)
        draft.sources = [sources[0]]; draft.idea = "A tool is useful"
        assert(LearningStudio.validateReels([draft], lane: "Tools & contracts", response: response).isEmpty)
        let all = LearningCurriculum.lanes.flatMap { lane in (0..<4).map { number -> ConceptReel in var copy = card; copy.id = UUID(); copy.topic = lane; copy.title = "\(lane)-\(number)"; return copy } }
        let interleaved = LearningStudio.interleave(all)
        assert(interleaved.count == 24 && Set(interleaved.prefix(6).map(\.topic)).count == 6)
        print("PASS: reels reject unsourced/shallow/duplicate drafts; 24-card edition interleaves all six areas.")

        func envelope(_ status: String, refusal: Bool = false, search: Bool = true) throws -> Data {
            var output: [[String: Any]] = []
            if search { output.append(["type": "web_search_call", "action": ["sources": [["url": sources[0].url]]]]) }
            output.append(["type": "message", "content": refusal ? [["type": "refusal"]] : [["type": "output_text", "text": "{}"]]])
            return try JSONSerialization.data(withJSONObject: ["status": status, "output": output])
        }
        let parsed = try LearningResearch.parse(envelope("completed")); assert(parsed.supports(sources[0].url))
        for data in [try envelope("incomplete"), try envelope("completed", refusal: true), try envelope("completed", search: false)] {
            do { _ = try LearningResearch.parse(data); fatalError("Invalid response accepted") } catch {}
        }
        print("PASS: research envelope rejects incomplete/refused/unsearched output.")
    }
}
