import Foundation
@main struct ExplanationChecks {
 @MainActor static func main() throws {
  let url = "https://example.com/guides/evaluation"
  func payload(source: String, status: String = "completed") throws -> Data {
   let text = try JSONSerialization.data(withJSONObject: ["explanation":"Compare observed output to a rubric.","example":"Test failure cases before deploying.","sources":[["title":"Evaluation guide","url":source]]])
   return try JSONSerialization.data(withJSONObject: ["status":status,"output":[["type":"web_search_call","action":["sources":[["url":url]]]],["type":"message","content":[["type":"output_text","text":String(decoding:text,as:UTF8.self)]]]]])
  }
  let result = try PassageExplainer.parse(payload(source:url))
  assert(result.sources.count == 1)
  for data in [try payload(source:"https://invented.example/article"),try payload(source:url,status:"incomplete"),try payload(source:"https://example.com/")] {
   do { _ = try PassageExplainer.parse(data); fatalError("Expected rejection") } catch {}
  }
  print("PASS: supported source accepted; invented, generic, and incomplete results rejected.")
 }
}
