import Foundation
import SwiftData
import UserNotifications

@main struct NativeChecks {
    @MainActor static func main() throws {
        let configuration = ModelConfiguration(url: URL(fileURLWithPath: CommandLine.arguments[1]), cloudKitDatabase: .none)
        let id = UUID()
        do {
            let container = try ModelContainer(for: LearningEntry.self, configurations: configuration)
            let context = ModelContext(container)
            let entry = LearningEntry(); entry.id = id; entry.title = "Persistence check"; entry.takeaway = "A saved reflection survives a new container."; entry.confidence = 4
            context.insert(entry); try context.save()
        }
        do {
            let container = try ModelContainer(for: LearningEntry.self, configurations: configuration)
            let context = ModelContext(container)
            let entries = try context.fetch(FetchDescriptor<LearningEntry>())
            let entry = entries.first { $0.id == id }!
            assert(entry.confidence == 4)
            entry.title = "Edited"; try context.save()
            context.delete(entry); try context.save()
            let remaining = try context.fetch(FetchDescriptor<LearningEntry>())
            assert(remaining.allSatisfy { $0.id != id })
        }
        let pick: [String: Any] = ["title":"A real resource","url":"https://example.org/paper","publisher":"Example","why":"Relevant","question":"What is the tradeoff?","format":"Article","minutes":15]
        let text = String(data: try JSONSerialization.data(withJSONObject: ["plans": Array(repeating: ["title":"Test plan", "why":"Relevant", "resources":[pick]], count:3)]), encoding: .utf8)!
        func fixture(status: String = "completed", url: String = "https://example.org/paper", refused: Bool = false) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["status":status,"output":[["type":"web_search_call","action":["sources":[["url":url]]]], ["type":"message","content":[refused ? ["type":"refusal","refusal":"No"] : ["type":"output_text","text":text]]]]])
        }
        let result = try Discovery.parse(fixture()); assert(result.count == 1 && result[0].minutes == 15)
        for data in [try fixture(status: "incomplete"), try fixture(url: "https://example.org/other"), try fixture(refused:true), Data("{}".utf8)] {
            do { _ = try Discovery.parse(data); assertionFailure("Invalid response accepted") } catch {}
        }
        for url in ["https://example.org/", "https://example.org/blog/", "https://example.org/category/ai", "https://www.youtube.com/@engineer", "https://www.youtube.com/playlist?list=abc", "https://www.youtube.com/watch", "http://example.org/article"] { assert(!Discovery.isSpecificResource(url), url) }
        for url in ["https://example.org/blog/how-evals-work", "https://arxiv.org/abs/2501.12345", "https://www.youtube.com/watch?v=abcdefghijk", "https://youtu.be/abcdefghijk"] { assert(Discovery.isSpecificResource(url), url) }
        print("PASS: homepage/index/channel/playlist rejection and direct article/paper/video acceptance")
        assert(Discovery.canonical("https://example.org/article/?utm_source=search#intro") == Discovery.canonical("https://example.org/article"))
        assert(Discovery.canonical("https://youtu.be/abcdefghijk?si=test") == Discovery.canonical("https://www.youtube.com/watch?v=abcdefghijk"))
        assert(Discovery.canonical("https://example.org/article?id=one") != Discovery.canonical("https://example.org/article?id=two"))
        var bad = pick; bad["url"] = "https://example.org/"
        let mixed = ["plans": [["title":"Valid", "why":"Relevant", "resources":[pick]], ["title":"Homepage", "why":"Invalid", "resources":[bad]]]]
        let mixedText = String(data: try JSONSerialization.data(withJSONObject: mixed), encoding: .utf8)!
        let mixedData = try JSONSerialization.data(withJSONObject: ["status":"completed", "output":[["type":"web_search_call","action":["sources":[["url":"https://example.org/paper?utm_source=web"]]]], ["type":"message", "content":[["type":"output_text","text":mixedText]]]]])
        let surviving = try Discovery.parse(mixedData, budget: 15)
        assert(surviving.count == 1 && surviving[0].resources[0].title == "A real resource")
        do { _ = try Discovery.parse(mixedData, budget: 5); assertionFailure("Over-budget resource accepted") } catch {}
        print("PASS: tracking URL matching, video aliases, ID preservation, partial edition recovery, time-budget enforcement")
        let longPaper = DailyRecommendation(title: "Dense paper", url: "https://example.org/report.pdf", publisher: "Research", why: "A useful but lengthy technical research report with many details to consider when building real production systems with agents and models.", question: "Why?", format: "Paper", minutes: 20)
        assert(!Discovery.fitsReadingScope(longPaper, budget: 25))
        assert(longPaper.preview.split(separator: " ").count <= 18)
        print("PASS: short-session paper rejection and concise preview cap")
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 19, minute: 30), repeats: true)
        assert(trigger.repeats && trigger.nextTriggerDate() != nil)
        assert(trigger.dateComponents.hour == 19 && trigger.dateComponents.minute == 30)
        print("PASS: persistent create/reopen/edit/delete; sourced recommendation parsing; incomplete/refused/uncited response rejection; recurring calendar trigger.")
    }
}
