import Foundation
import SwiftData

@Model final class LearningEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var title: String = ""
    var topic: String = "AI engineering"
    var source: String = ""
    var takeaway: String = ""
    var mechanism: String = ""
    var evidence: String = ""
    var tradeoff: String = ""
    var opinion: String = ""
    var minutes: Int = 15
    var confidence: Int = 3
    init() {}
}

struct LearningSource: Identifiable {
    let id: String
    let name: String
    let focus: String
    let url: String
    let kind: String
    let symbol: String
    static let all: [LearningSource] = [
        .init(id: "simon", name: "Simon Willison", focus: "New models, practical experiments & agents", url: "https://simonwillison.net/", kind: "READ", symbol: "terminal"),
        .init(id: "interconnects", name: "Interconnects", focus: "Reasoning, post-training & open models", url: "https://www.interconnects.ai/", kind: "READ", symbol: "point.3.connected.trianglepath.dotted"),
        .init(id: "raschka", name: "Ahead of AI", focus: "Understand the architecture behind the release", url: "https://magazine.sebastianraschka.com/", kind: "READ", symbol: "cpu"),
        .init(id: "hamel", name: "Hamel Husain", focus: "Evals, failure analysis & better AI products", url: "https://hamel.dev/", kind: "READ", symbol: "checkmark.seal"),
        .init(id: "chip", name: "Chip Huyen", focus: "Inference & production system design", url: "https://huyenchip.com/blog/", kind: "READ", symbol: "square.stack.3d.up"),
        .init(id: "engineer", name: "AI Engineer", focus: "Engineering talks from people building systems", url: "https://www.youtube.com/@aiDotEngineer", kind: "WATCH", symbol: "play.rectangle"),
        .init(id: "latent", name: "Latent Space", focus: "The people, tools & decisions shaping AI", url: "https://www.latent.space/podcast", kind: "LISTEN", symbol: "waveform"),
        .init(id: "mlst", name: "Machine Learning Street Talk", focus: "Intelligence, research & competing ideas", url: "https://www.youtube.com/@MachineLearningStreetTalk", kind: "WATCH", symbol: "brain"),
        .init(id: "dwarkesh", name: "Dwarkesh Podcast", focus: "Scaling, research & the bigger picture", url: "https://www.dwarkesh.com/", kind: "LISTEN", symbol: "mic"),
        .init(id: "snake", name: "AI Snake Oil", focus: "Challenge the claim. Follow the evidence.", url: "https://www.aisnakeoil.com/", kind: "READ", symbol: "magnifyingglass")
    ]
}

let topics = ["AI engineering", "Models & training", "Agents", "Evals", "Inference & hardware", "AI & society"]

struct Growth {
    static func days(_ dates: [Date], calendar: Calendar = .current) -> Set<Date> {
        Set(dates.map { calendar.startOfDay(for: $0) })
    }
    static func streak(_ dates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let completed = days(dates, calendar: calendar)
        var day = calendar.startOfDay(for: now)
        if !completed.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var count = 0
        while completed.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
    static func lastDays(_ count: Int, now: Date = Date()) -> [Date] {
        let today = Calendar.current.startOfDay(for: now)
        return (0..<count).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: today) }
    }
}


@Model final class RecallCard {
    var id: UUID = UUID()
    var created: Date = Date()
    var prompt: String = ""
    var answer: String = ""
    var source: String = ""
    var original: String = ""
    var category: String = "Engineering"
    var style: Int = 0
    var due: Date = Date()
    var intervalDays: Double = 0
    var reviews: Int = 0
    var archived: Bool = false
    init() {}
    func review(_ rating: Int, now: Date = Date()) {
        reviews += 1
        if rating == 0 { intervalDays = 0; due = now.addingTimeInterval(600) }
        else {
            let multiplier = rating == 1 ? 1.3 : rating == 2 ? 2.2 : 3.0
            intervalDays = min(365, max(rating == 3 ? 4 : 1, intervalDays * multiplier))
            due = now.addingTimeInterval(intervalDays * 86400)
        }
    }
}

@Model final class ReadingVisit {
    var id: UUID = UUID()
    var url: String = ""
    var title: String = ""
    var lastVisited: Date = Date()
    var visits: Int = 1
    var finished: Bool = false
    init() {}
}
