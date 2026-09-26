import WidgetKit
import SwiftUI
import ActivityKit

private let navy = Color(red: 0.055, green: 0.055, blue: 0.052)
private let lime = Color(red: 0.96, green: 0.91, blue: 0.71)
struct DepthTimelineEntry: TimelineEntry {
    let date: Date
    let title: String
    let count: Int
    let streak: Int
    let done: Bool
}
struct DepthProvider: TimelineProvider {
    func placeholder(in context: Context) -> DepthTimelineEntry { .init(date: Date(), title: "One good idea awaits.", count: 0, streak: 0, done: false) }
    func getSnapshot(in context: Context, completion: @escaping (DepthTimelineEntry) -> Void) { completion(current()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DepthTimelineEntry>) -> Void) { completion(Timeline(entries: [current()], policy: .after(Date().addingTimeInterval(1800)))) }
    func current() -> DepthTimelineEntry {
        let d = WidgetBridge.defaults
        let fresh = (d.object(forKey: "widgetUpdated") as? Date).map { Calendar.current.isDateInToday($0) } ?? false
        return .init(date: Date(), title: d.string(forKey: "widgetTitle") ?? "Open Daily Depth for your next idea.", count: d.integer(forKey: "widgetCount"), streak: d.integer(forKey: "widgetStreak"), done: fresh && d.bool(forKey: "widgetLearnedToday"))
    }
}
struct DepthWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: DepthTimelineEntry
    var body: some View {
        Group {
            if family == .accessoryCircular {
                VStack(spacing: 2) { Image(systemName: entry.done ? "checkmark" : "book.closed"); Text("\(entry.streak)").font(.headline) }.widgetAccentable()
            } else if family == .accessoryRectangular {
                VStack(alignment: .leading) { Text(entry.done ? "Learning captured" : "A little deeper today").font(.headline); Text(entry.title).font(.caption).lineLimit(2) }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Image(systemName: "book.closed.fill").foregroundStyle(lime); Text("daily depth").font(.system(size: 14, weight: .bold, design: .rounded)); Spacer(); if entry.done { Image(systemName: "checkmark.circle.fill").foregroundStyle(lime) } }
                    Text(entry.title).font(.system(size: family == .systemSmall ? 16 : 20, weight: .semibold, design: .rounded)).lineLimit(3)
                    Spacer(minLength: 0)
                    HStack { Label("\(entry.streak) day streak", systemImage: "flame.fill").foregroundStyle(lime); if family == .systemMedium { Spacer(); Text("\(entry.count) reflections").foregroundStyle(.white.opacity(0.7)) } }.font(.system(size: 12))
                }.foregroundStyle(.white)
            }
        }.containerBackground(for: .widget) { Rectangle().fill(navy.gradient) }.widgetURL(URL(string: "dailydepth://today"))
    }
}
struct DepthWidget: Widget {
    let kind = "DailyDepthWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DepthProvider()) { DepthWidgetView(entry: $0) }
            .configurationDisplayName("Your daily depth").description("Your next idea and your learning rhythm.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
struct DepthLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LearningActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack { Label(context.state.paused ? "Learning paused" : context.isStale ? "Ready to reflect" : "Learning in progress", systemImage: "book.closed.fill").font(.subheadline.weight(.semibold)); Spacer(); ActivityTimer(state: context.state).monospacedDigit().font(.title2.weight(.bold)).foregroundStyle(lime).frame(width: 80) }
                Text(context.attributes.title).font(.headline).lineLimit(2)
                if !context.state.paused { ProgressView(timerInterval: context.state.start...context.state.end, countsDown: false).tint(lime) }
                HStack { Link("Open & reflect", destination: URL(string: "dailydepth://reflect")!); Spacer(); Button(intent: EndLearningSessionIntent()) { Label("End", systemImage: "stop.fill") } }.font(.subheadline.weight(.semibold)).tint(lime)
            }.padding(18).foregroundStyle(.white).activityBackgroundTint(navy).activitySystemActionForegroundColor(lime)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("daily depth", systemImage: "book.closed.fill").foregroundStyle(lime).font(.headline) }
                DynamicIslandExpandedRegion(.trailing) { ActivityTimer(state: context.state).monospacedDigit().foregroundStyle(lime).frame(width: 70) }
                DynamicIslandExpandedRegion(.bottom) { VStack(alignment: .leading, spacing: 10) { Text(context.attributes.title).lineLimit(2); if !context.state.paused { ProgressView(timerInterval: context.state.start...context.state.end, countsDown: false).tint(lime) }; HStack { Link("Reflect", destination: URL(string: "dailydepth://reflect")!); Spacer(); Button(intent: EndLearningSessionIntent()) { Text("End session") } }.font(.caption.weight(.semibold)).tint(lime) } }
            } compactLeading: { Image(systemName: "book.closed.fill").foregroundStyle(lime) }
            compactTrailing: { ActivityTimer(state: context.state).monospacedDigit().frame(width: 48).foregroundStyle(lime) }
            minimal: { Image(systemName: "book.closed.fill").foregroundStyle(lime) }
            .widgetURL(URL(string: "dailydepth://today")).keylineTint(lime)
        }
    }
}
@main struct DailyDepthWidgets: WidgetBundle {
    var body: some Widget {
        #if !PERSONAL_PREVIEW
        DepthWidget()
        #endif
        DepthLiveActivity()
    }
}

private struct ActivityTimer: View {
    let state: LearningActivityAttributes.ContentState
    var body: some View {
        if state.paused { Text(String(format: "%02d:%02d", Int(ceil(state.remaining)) / 60, Int(ceil(state.remaining)) % 60)) }
        else { Text(timerInterval: state.start...state.end, countsDown: true) }
    }
}
