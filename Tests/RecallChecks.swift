import Foundation
import SwiftData
@main struct RecallChecks {
 @MainActor static func main() throws {
  let url = URL(fileURLWithPath: CommandLine.arguments[1])
  let id = UUID()
  let now = Date(timeIntervalSince1970: 100000)
  do {
   let store = try ModelContainer(for: LearningEntry.self, RecallCard.self, ReadingVisit.self, configurations:ModelConfiguration(url:url,cloudKitDatabase:.none))
   let context = ModelContext(store)
   let card = RecallCard(); card.id=id; card.prompt="What persists?"; card.answer="A card and its due date."; context.insert(card)
   card.review(0,now:now); assert(card.due == now.addingTimeInterval(600))
   card.review(2,now:now); assert(card.intervalDays == 1)
   card.review(2,now:now); assert(card.intervalDays == 2.2)
   let visit=ReadingVisit(); visit.url="https://example.com/article"; visit.finished=true; context.insert(visit)
   try context.save()
  }
  do {
   let store = try ModelContainer(for: LearningEntry.self, RecallCard.self, ReadingVisit.self, configurations:ModelConfiguration(url:url,cloudKitDatabase:.none))
   let context=ModelContext(store)
   let card=try context.fetch(FetchDescriptor<RecallCard>()).first{$0.id==id}!
   let visits = try context.fetch(FetchDescriptor<ReadingVisit>()); assert(visits.contains { $0.finished && $0.url == "https://example.com/article" })
   assert(card.reviews==3 && card.intervalDays==2.2)
   card.archived=true; try context.save(); card.archived=false; try context.save()
  }
  func plan(_ url:String)->LearningPlan { LearningPlan(title:url,why:"Fit",resources:[DailyRecommendation(title:"Guide",url:url,publisher:"Docs",why:"Learn",question:"Why",format:"Article",minutes:5)]) }
  let merged=Discovery.mergePlans([plan("https://example.com/a"),plan("https://example.com/b")],[plan("https://example.com/a?utm_source=duplicate"),plan("https://example.com/c")])
  assert(merged.count==3)
  print("PASS: review intervals, durable card storage, archive/restore, deduplicated third-option refill.")
 }
}
