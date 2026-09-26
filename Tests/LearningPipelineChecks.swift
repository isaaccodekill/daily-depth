import Foundation

@MainActor final class ResearchFixture {
    var requests = 0
    var failSecondLane = true
    var rejectReview = false
    var auditedMinutes = 8
    let links = (1...3).map { LearningLink(title: "Documentation", url: "https://example\($0).org/engineering/guide") }
    func call(_ prompt: String, _ schema: [String: Any], _ name: String, _ domains: [String]?, _ tokens: Int) async throws -> ResearchResponse {
        requests += 1
        func words(_ n: Int) -> String { Array(repeating: "mechanism", count: n).joined(separator: " ") }
        var object: [String: Any] = [:]
        func link(_ index: Int) -> [String: String] { ["title": links[index].title, "url": links[index].url] }
        if name == "concept_batch" {
            let lane = LearningCurriculum.lanes.first { prompt.contains("Lane: \($0).") }!
            if failSecondLane && lane == LearningCurriculum.lanes[1] { throw DiscoveryError.message("Simulated interruption") }
            object = ["cards": (0..<4).map { index in ["title": "\(lane) lesson \(index)", "idea": words(30), "example": words(15), "pitfall": words(10), "detail": words(100), "question": "What changes?", "answer": "The mechanism changes", "sources": [link(index % 2)]] as [String: Any] }]
        } else if name == "concept_review" {
            let text = String(prompt[prompt.range(of: " Cards: ")!.upperBound...])
            let cards = try JSONDecoder().decode([ConceptReel].self, from: Data(text.utf8))
            object = ["reviews": cards.map { ["id": $0.id.uuidString, "approved": !rejectReview, "reason": "Fixture review", "sources": $0.sources.map { ["title": $0.title, "url": $0.url] }] as [String: Any] }]
        } else if name == "topic_series" {
            object = ["overview": "A researched learning path", "steps": ["Intro", "Intermediate", "Deep"].enumerated().map { index, level in ["level": level, "title": "Step \(index)", "outcome": "Understand one concrete mechanism", "bridge": "Try the mechanism", "minutes": 10, "source": link(index)] as [String: Any] }]
        } else if name == "resource_editor" {
            object = ["reviews": links.map { ["url": $0.url, "topic": "tools", "promotional": false, "inspected": true, "wordCount": 900, "fullMinutes": auditedMinutes, "kind": "documentation", "mechanisms": [words(6), words(7)], "evidence": words(20)] as [String: Any] }]
        } else { fatalError("Unexpected request \(name)") }
        return ResearchResponse(data: try JSONSerialization.data(withJSONObject: object), evidence: Set(links.map { Discovery.canonical($0.url) }))
    }
}
@main struct LearningPipelineChecks {
    @MainActor static func main() async throws {
        let dir = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fixture = ResearchFixture()
        let transport: ResearchTransport = { try await fixture.call($0, $1, $2, $3, $4) }
        let file = dir.appendingPathComponent("learning.json")
        let first = LearningStudio(file: file, research: transport)
        await first.generateReels(manual: true)
        assert(first.vault.edition == nil && first.vault.pending.count == 4 && fixture.requests == 3)
        fixture.failSecondLane = false
        let resumed = LearningStudio(file: file, research: transport)
        await resumed.generateReels(manual: true)
        assert(resumed.vault.edition?.cards.count == 24 && resumed.vault.pending.isEmpty && fixture.requests == 13)
        let ids = resumed.vault.edition!.cards.map(\.id)
        await resumed.generateReels(manual: true)
        assert(fixture.requests == 13 && resumed.vault.edition!.cards.map(\.id) == ids)
        print("PASS: interrupted generation checkpoints four reviewed cards, resumes only five remaining batches and caches the complete daily edition.")
        fixture.rejectReview = true
        let rejected = LearningStudio(file: dir.appendingPathComponent("rejected.json"), research: transport)
        await rejected.generateReels(manual: true)
        assert(rejected.vault.edition == nil && rejected.vault.pending.isEmpty && !rejected.reelBusy)
        print("PASS: failed source review publishes no cards and clears busy state.")
        let seriesID = await resumed.createSeries(topic: "Typed tools", budget: 30)
        assert(seriesID != nil && resumed.vault.series.first!.steps.map(\.minutes) == [8, 8, 8])
        resumed.bookmark(seriesID!); resumed.complete(seriesID!, level: "Intro")
        let persisted = LearningStudio(file: file, research: transport)
        assert(persisted.vault.series.first!.bookmarked && persisted.vault.series.first!.steps.first!.completed)
        persisted.expire(at: persisted.vault.series.first!.expires)
        assert(persisted.vault.series.isEmpty)
        fixture.auditedMinutes = 11
        let overBudget = await persisted.createSeries(topic: "Typed tools", budget: 30)
        assert(overBudget == nil && persisted.vault.series.isEmpty)
        print("PASS: full series research/editorial pipeline uses audited durations, persists progress, expires bookmarks and rejects audited total-time overruns.")
    }
}
