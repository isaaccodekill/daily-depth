import Foundation
@main struct QualityChecks {
 @MainActor static func main() throws {
  var item=DailyRecommendation(title:"Worked eval design",url:"https://example.com/engineering/evals",publisher:"Engineer",why:"Build a failure-driven evaluation set.",question:"What failure would you test?",format:"Article",minutes:10)
  assert(!Discovery.hasLearningDepth(item))
  item.learningEvidence="The worked example constructs labeled failures, implements a scoring function, and compares false positives across two thresholds."
  item.resourceType="engineering_analysis";item.depth=4;item.durationEvidence="1,200 words with code, estimated 10 minutes."
  assert(Discovery.hasLearningDepth(item))
  item.resourceType="announcement";assert(!Discovery.hasLearningDepth(item))
  item.resourceType="tutorial";item.depth=2;assert(!Discovery.hasLearningDepth(item))
  item.depth=4;item.durationEvidence="";assert(!Discovery.hasLearningDepth(item))
  item.durationEvidence="Full runtime: 12 minutes"; item=DailyRecommendation(title:item.title,url:"https://www.youtube.com/watch?v=example",publisher:"AI Engineer",why:item.why,question:item.question,format:"Video",minutes:12,learningEvidence:item.learningEvidence,resourceType:"technical_talk",depth:4,durationEvidence:item.durationEvidence)
  assert(item.isVideo && Discovery.hasLearningDepth(item))
  print("PASS: announcements, shallow resources, missing evidence/duration rejected; substantial video accepted.")
 }
}
