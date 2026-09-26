import SwiftUI
import SwiftData
import UniformTypeIdentifiers

let ink = Color(red: 0.055, green: 0.055, blue: 0.052)
let canvas = adaptiveColor(light: (1, 1, 1), dark: (0.055, 0.055, 0.052))
let accent = adaptiveColor(light: (0.34, 0.24, 0.47), dark: (0.96, 0.91, 0.71))
let panel = adaptiveColor(light: (0.95, 0.945, 0.93), dark: (0.10, 0.10, 0.095))
let lime = Color(red: 0.96, green: 0.91, blue: 0.71)
let coral = Color(red: 0.96, green: 0.45, blue: 0.31)
let lilac = Color(red: 0.73, green: 0.67, blue: 0.92)
let sage = Color(red: 0.73, green: 0.82, blue: 0.52)
let muted = adaptiveColor(light: (0.38, 0.38, 0.36), dark: (0.67, 0.67, 0.63))

enum Screen: String, CaseIterable, Identifiable {
    case today = "Today", journal = "Journal", recall = "Learn", growth = "Growth", library = "Library", ritual = "Ritual"
    var id: String { rawValue }
    var icon: String {
        switch self { case .recall: "sparkles.rectangle.stack.fill"; case .today: "sun.max"; case .journal: "book.closed"; case .growth: "chart.xyaxis.line"; case .library: "square.stack"; case .ritual: "bell" }
    }
}

struct ReflectionTarget: Identifiable { let id = UUID(); let entry: LearningEntry?; let source: String }

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @EnvironmentObject private var reminders: Reminders
    @EnvironmentObject private var discovery: Discovery
    @EnvironmentObject private var session: LearningSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("learningInterests") private var interests = "AI engineering, model efficiency, agents, and evidence-based opinions about AI"
    @AppStorage("preferredFormat") private var preferredFormat = "Any format"
    @AppStorage("sessionMinutes") private var sessionMinutes = 15
    @AppStorage("openAIModel") private var model = "gpt-5.6-sol"
    @Query(sort: \LearningEntry.date, order: .reverse) private var entries: [LearningEntry]
    @EnvironmentObject private var studio: LearningStudio
    @State private var showSeries = false
    @State private var screen: Screen = .today
    @State private var didRequestLaunchRefresh = false
    @State private var cardIndex = 0
    @State private var reader: ReaderTarget?
    @State private var pendingReflection: String?
    @GestureState private var cardDrag: CGFloat = 0
    @State private var reflectionTarget: ReflectionTarget?
    @State private var deckPosition: Int? = 0
    @State private var libraryHistory = false
    @Query(sort: \ReadingVisit.lastVisited, order: .reverse) private var visits: [ReadingVisit]
    @State private var selectedEntry: LearningEntry?
    @State private var suggestedSource = ""
    @State private var search = ""
    @State private var error: String?
    @State private var deleting: LearningEntry?
    @State private var exporting = false
    @State private var exportDocument = JournalDocument(text: "")
    private var todayEntries: [LearningEntry] { entries.filter { Calendar.current.isDateInToday($0.date) } }
    private var suggestion: LearningSource { LearningSource.all[(Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0) % LearningSource.all.count] }
    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 760
            HStack(spacing: 0) {
                if wide { sidebar }
                VStack(spacing: 0) {
                    if screen != .recall {
                    HStack {
                        if !wide { brand; Spacer() }
                        else { Text("A SMALL DAILY DISCOVERY").font(.system(size: 12, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(muted); Spacer() }
                        Button { libraryHistory=true; screen = .library } label: { Image(systemName:"clock.arrow.circlepath").font(.title3) }.accessibilityLabel("Reading history")
                        Button { selectedEntry = nil; suggestedSource = ""; presentReflection() } label: { Label("Reflect", systemImage: "plus").fontWeight(.semibold) }.buttonStyle(AccentButton())
                    }.padding(.horizontal, wide ? 36 : 20).padding(.vertical, wide ? 18 : 10)
                    }
                    if screen == .recall { LearningHub() } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 26) {
                            switch screen {
                            case .recall: EmptyView()
                            case .today: today
                            case .journal: journal
                            case .growth: growth
                            case .library: library
                            case .ritual: RitualView()
                            }
                        }.frame(maxWidth: 940, alignment: .leading).padding(wide ? 36 : 20).padding(.bottom, screen == .today ? 70 : 0).frame(maxWidth: .infinity)
                    }.id(screen)
                    .overlay(alignment: .bottomTrailing) {
                        if screen == .today {
                            Button { showSeries = true } label: {
                                Image(systemName: "questionmark").font(.system(size: 27, weight: .semibold, design: .serif))
                                    .frame(width: 58, height: 58).foregroundStyle(ink).background(lilac, in: Circle())
                                    .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
                            }.buttonStyle(.plain).padding(20).accessibilityLabel("What do you want to learn? Open learning series")
                        }
                    }
                    .background {
                        if discovery.busy && (screen == .today || screen == .ritual) {
                            LiquidCurationField()
                                .transition(.opacity)
                        }
                    }
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.9), value: discovery.busy)
                    }
                    if !wide { mobileTabs }
                }
            }.background(canvas).tint(accent)
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 550)
        #endif
        .sheet(item: $reader, onDismiss: { if let source = pendingReflection { selectedEntry = nil; suggestedSource = source; pendingReflection = nil; presentReflection() } }) { target in ReaderView(url: target.url, video:target.video) { source in pendingReflection = source }.environmentObject(session) }
        .onOpenURL { url in if url.scheme == "dailydepth" { screen = .today; if url.host == "reflect" { selectedEntry = nil; presentReflection() } } }
        .onChange(of: entries.map { "\($0.id)-\($0.title)-\($0.minutes)" }) { _, _ in updateWidget() }
        #if os(iOS)
        .sensoryFeedback(.selection, trigger: cardIndex)
        #endif
        .onChange(of: discovery.hasKey) { _, hasKey in if hasKey { Task { await discover() } } }
        .onChange(of: discovery.cached?.date) { _, _ in cardIndex = 0; updateWidget() }
        .sheet(isPresented: $showSeries) { TopicSeriesLibrary() }
        .sheet(item: $reflectionTarget) { target in EntryEditor(entry: target.entry, initialSource: target.source).environmentObject(reminders) }
        .onChange(of: reminders.openJournal) { _, open in if open { selectedEntry = nil; suggestedSource = ""; presentReflection(); reminders.openJournal = false } }
        .task { updateWidget(); session.restore(); await reminders.refresh(); await discoverOnLaunch(); if reminders.openJournal { presentReflection(); reminders.openJournal = false } }
        .onChange(of: phase) { _, p in if p == .active { Task { session.restore(); await reminders.refresh(); await discover() } } else if p == .background { discovery.scheduleBackgroundRefresh() } }
        .alert("Couldn’t complete that", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        .confirmationDialog("Delete this reflection?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete reflection", role: .destructive) { if let e = deleting { context.delete(e); do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription } }; deleting = nil }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: { Text("This cannot be undone. Export your journal first if you want a backup.") }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .plainText, defaultFilename: "Daily-Depth-Journal.md") { result in if case .failure(let e) = result { error = e.localizedDescription } }
    }
    private func presentReflection() {
        let source = selectedEntry?.source ?? (suggestedSource.isEmpty ? visits.first?.url ?? "" : suggestedSource)
        reflectionTarget = ReflectionTarget(entry: selectedEntry, source: source)
    }
    private func updateWidget() {
        WidgetBridge.update(title: discovery.cached?.plans.first?.title ?? suggestion.name, count: entries.count, streak: Growth.streak(entries.map(\.date)), learnedToday: !todayEntries.isEmpty)
    }
    private func discover(force: Bool = false) async {
        async let concepts: Void = studio.generateReels()
        await discovery.find(interest: interests, preferredFormat: preferredFormat, minutes: sessionMinutes, history: entries.prefix(10).map { "\($0.title.prefix(160)) | \($0.topic) | confidence \($0.confidence)/5" }, model: model, force: force)
        await concepts
    }
    private var brand: some View {
        HStack(spacing: 10) { Image(systemName: "book.closed.fill").foregroundStyle(accent).font(.title2); Text("daily depth").font(.system(size: 24, weight: .regular, design: .serif)) }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 38) {
            brand.padding(.top, 12)
            VStack(spacing: 8) {
                ForEach(Screen.allCases) { s in
                    Button { withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.9)) { screen = s } } label: {
                        HStack(spacing: 13) { Image(systemName: s.icon).frame(width: 22); Text(s.rawValue); Spacer(); if s == .journal && !entries.isEmpty { Text("\(entries.count)").font(.caption) } }
                            .font(.system(size: 16, weight: screen == s ? .semibold : .regular)).padding(14)
                            .foregroundStyle(screen == s ? accent : muted).background(screen == s ? lime.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 10) { Image(systemName: "sparkle").foregroundStyle(accent); Text("Small sessions.\nLasting understanding.").font(.system(size: 18, weight: .medium, design: .serif)); Text("One idea is enough for today.").font(.caption).foregroundStyle(muted) }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(panel, in: RoundedRectangle(cornerRadius: 16))
        }.padding(22).frame(width: 240).background(Color.white.opacity(0.018)).overlay(alignment: .trailing) { Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1) }
    }
    private func discoverOnLaunch() async {
        #if DEBUG || PERSONAL_PREVIEW
        let refresh = ProcessInfo.processInfo.arguments.contains("--refresh-edition") && !didRequestLaunchRefresh
        didRequestLaunchRefresh = true
        await discover(force:refresh)
        #else
        await discover()
        #endif
    }
    private var mobileTabs: some View {
        HStack(spacing: 0) { ForEach([Screen.today, .journal, .recall, .library, .ritual]) { s in Button { withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.9)) { screen = s } } label: { VStack(spacing: 5) { Image(systemName: s.icon).font(.system(size: s == .recall ? 25 : 19)).foregroundStyle(s == .recall ? coral : screen == s ? accent : muted); Text(s.rawValue).font(.system(size: 12, weight: .medium)) }.foregroundStyle(screen == s ? accent : muted).frame(maxWidth: .infinity).padding(.vertical, 12) }.buttonStyle(.plain).accessibilityLabel(s.rawValue) } }.background(panel)
    }
    private func heading(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.system(size: 34, weight: .semibold, design: .rounded)); Text(detail).font(.system(size: 16)).foregroundStyle(muted) }
    }
    private var today: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text(Date().formatted(.dateTime.weekday(.wide).day().month(.abbreviated))).eyebrow(); Spacer(); Image(systemName: "sparkle").foregroundStyle(coral) }
            Text(todayEntries.isEmpty ? "A little more\ncurious, today." : "Look how far\nyour mind went.").font(.system(size: 38, weight: .regular, design: .serif)).tracking(-1.8).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 22).background(alignment: .trailing) { GardenArt().frame(width: 155, height: 140).opacity(0.35).allowsHitTesting(false) }
            Text("For your commute. Your coffee. Your next good idea.").font(.system(size: 15)).foregroundStyle(muted)
            HStack(spacing: 8) {
                ForEach([5, 10, 15, 25], id: \.self) { minutes in
                    Button { withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) { sessionMinutes = minutes } } label: {
                        Text("\(minutes) min").font(.system(size: 14, weight: .medium)).padding(.horizontal, 16).padding(.vertical, 10).foregroundStyle(sessionMinutes == minutes ? ink : accent).background(sessionMinutes == minutes ? lime : panel, in: Capsule())
                    }.buttonStyle(.plain).accessibilityLabel("Set learning time to \(minutes) minutes").accessibilityAddTraits(sessionMinutes == minutes ? .isSelected : [])
                }
            }
            HStack {
                Label(discovery.hasKey ? "Your daily edition · Sol" : "Connect your curator", systemImage: "sparkles").font(.system(size: 13, weight: .medium))
                Spacer(); Button { screen = .ritual } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Learning preferences")
            }.foregroundStyle(accent).buttonStyle(.plain)
            if discovery.busy { LiquidCuration(status: discovery.status) }
            if let pick = discovery.cached {
                if pick.curationVersion != 5 { Text("Previous edition · your next search applies the new substance and variety checks.").font(.caption).foregroundStyle(muted) }
                learningDeck(pick)
            } else if !discovery.busy {
                VStack(alignment: .leading, spacing: 14) {
                    Text("A real read.\nA useful next step.").font(.system(size: 30, design: .serif))
                    Text(discovery.hasKey ? "Your curator will find exact articles, videos or episodes, with a preview of what you’ll learn." : "Connect OpenAI to get a daily edition of exact articles and videos, chosen for you.").font(.system(size: 16))
                    Button { if discovery.hasKey { Task { await discover(force: true) } } else { screen = .ritual } } label: { Label(discovery.busy ? "Curating your edition…" : discovery.hasKey ? "Find my first edition" : "Set up my curator", systemImage: "sparkles") }.buttonStyle(DarkButton()).disabled(discovery.busy)
                }.padding(24).foregroundStyle(ink).frame(maxWidth: .infinity, alignment: .leading).background(coral, in: RoundedRectangle(cornerRadius: 28))
            }
            HStack {
                Button { screen = .ritual } label: { Label("Shape my interests", systemImage: "slider.horizontal.3") }
                Spacer()
                if discovery.hasKey { Button { Task { await discover(force: true) } } label: { if discovery.busy { ProgressView().controlSize(.small) } else { Label("Find my next read", systemImage: "sparkles") } }.disabled(discovery.busy) }
            }.font(.system(size: 13)).buttonStyle(.borderless)
            if !discovery.status.isEmpty && !discovery.busy { Text(discovery.status).font(.system(size: 13)).foregroundStyle(muted) }
            Button { selectedEntry = nil; suggestedSource = discovery.cached?.singlePlans[safe: cardIndex]?.resources.map(\.url).joined(separator: "\n") ?? ""; presentReflection() } label: {
                HStack(spacing: 16) {
                    Image(systemName: "pencil.and.scribble").font(.system(size: 27))
                    VStack(alignment: .leading, spacing: 5) { Text("Keep a little of what you learn.").font(.system(size: 20, design: .serif)); Text("One idea. Your own words.").font(.system(size: 13)).opacity(0.7) }
                    Spacer(); Image(systemName: "arrow.up.right")
                }.padding(.vertical, 16).foregroundStyle(.primary)
            }.buttonStyle(.plain)
            Divider()
            if session.end != nil { sessionCard }
            else { Button { Task { await session.begin(title: discovery.cached?.singlePlans[safe: cardIndex]?.title ?? "A little learning", minutes: discovery.cached?.singlePlans[safe: cardIndex]?.minutes ?? sessionMinutes) } } label: { HStack { Label("Start a focused moment", systemImage: "play.circle"); Spacer(); Text("\(sessionMinutes) min") } }.buttonStyle(.plain).foregroundStyle(accent).padding(.vertical, 10) }
            Button { screen = .recall } label: {
                HStack { Image(systemName: "sparkles.rectangle.stack"); Text("Your daily concepts"); Spacer(); Text(studio.reelBusy ? "Preparing…" : "Explore ↗") }
            }.buttonStyle(.plain).foregroundStyle(accent).padding(.vertical, 10)
            Button { showSeries = true } label: {
                HStack { Image(systemName: "bookmark"); Text("Your learning series"); Spacer(); Text("48h paths ↗") }
            }.buttonStyle(.plain).foregroundStyle(accent).padding(.vertical, 10)
            HStack { Text("Quiet progress.").font(.system(size: 26, design: .serif)); Spacer(); Button("Your growth ↗") { screen = .growth }.font(.system(size: 13)).buttonStyle(.plain).foregroundStyle(accent) }
            Text("\(Growth.days(entries.map(\.date)).count) learning days   ·   \(entries.count) thoughts collected").font(.system(size: 14)).foregroundStyle(muted)
            if let recent = entries.first { Text("A THOUGHT TO RETURN TO").eyebrow(); entryCard(recent) }
            if !reminders.enabled { Button { screen = .ritual } label: { Label("Make this a daily ritual", systemImage: "bell") }.buttonStyle(.plain).foregroundStyle(accent) }
        }
    }
    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "timer").font(.title2)
                Text(session.end == nil ? "A little focus goes a long way." : "Your learning moment").font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer()
            }
            if let end = session.end {
                Text(session.title).font(.system(size: 15)).lineLimit(2)
                Group { if session.isPaused { Text(session.pausedTime) } else { Text(timerInterval: min(session.start ?? Date(), end)...end, countsDown: true) } }.font(.system(size: 44, weight: .medium, design: .rounded)).monospacedDigit()
                HStack { Button(session.isPaused ? "Resume" : "Pause") { Task { await session.togglePause() } }; Button("End session") { Task { await session.finish() } }; Spacer(); Button("Save a reflection") { selectedEntry = nil; presentReflection() } }.buttonStyle(.borderless)
            } else {
                Text("Give this moment your attention. We’ll keep the time.").font(.system(size: 15))
                Button { Task { await session.begin(title: discovery.cached?.singlePlans[safe: cardIndex]?.title ?? suggestion.name, minutes: discovery.cached?.singlePlans[safe: cardIndex]?.minutes ?? sessionMinutes) } } label: { Label("Start \(discovery.cached?.singlePlans[safe: cardIndex]?.minutes ?? sessionMinutes)-minute session", systemImage: "play.fill") }.buttonStyle(DarkButton())
            }
            if !session.status.isEmpty { Text(session.status).font(.system(size: 13)).opacity(0.8) }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.white).background(LinearGradient(colors: [Color(red: 0.30, green: 0.24, blue: 0.42), Color(red: 0.40, green: 0.30, blue: 0.52)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
    }
    private func learningDeck(_ saved: CachedPick) -> some View {
        let pick = CachedPick(date: saved.date, interest: saved.interest, plans: saved.singlePlans)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(discovery.cached == nil ? "A FEW PLACES TO BEGIN" : Calendar.current.isDateInToday(pick.date) ? "YOUR DAILY EDITION" : "YOUR SAVED EDITION").eyebrow()
                Spacer()
                Text("\(min(cardIndex + 1, pick.plans.count)) / \(pick.plans.count)").font(.system(size: 13, design: .monospaced)).foregroundStyle(muted)
            }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(pick.plans.enumerated()), id: \.offset) { index, plan in
                        planCard(plan, isFirst: index == 0)
                            .containerRelativeFrame(.horizontal) { width, _ in max(260, width - 24) }
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content.scaleEffect(reduceMotion ? 1 : phase.isIdentity ? 1 : 0.95)
                                    .rotationEffect(.degrees(reduceMotion ? 0 : phase.value * 2))
                            }.id(index)
                    }
                }.scrollTargetLayout()
            }.scrollIndicators(.hidden).scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $deckPosition)
                .onChange(of: deckPosition) { _, value in if let value { cardIndex = value } }
                .onChange(of: cardIndex) { _, value in withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { deckPosition = value } }
            HStack {
                Button { withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) { cardIndex = max(0, cardIndex - 1) } } label: { Image(systemName: "chevron.left").frame(width: 38, height: 32) }.disabled(cardIndex == 0).accessibilityLabel("Previous learning option")
                Spacer()
                ForEach(pick.plans.indices, id: \.self) { index in Button { withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) { cardIndex = index } } label: { Capsule().fill(index == cardIndex ? accent : muted.opacity(0.35)).frame(width: index == cardIndex ? 24 : 8, height: 8).padding(.vertical, 12) }.accessibilityLabel("Option \(index + 1)") }
                Spacer()
                Button { withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) { cardIndex = min(pick.plans.count - 1, cardIndex + 1) } } label: { Image(systemName: "chevron.right").frame(width: 38, height: 32) }.disabled(cardIndex == pick.plans.count - 1).accessibilityLabel("Next learning option")
            }.buttonStyle(.plain).foregroundStyle(accent)
            Text(discovery.cached == nil ? "Swipe to explore · Starter sources, choose a piece to read" : "Swipe to explore · Selected \(pick.date.formatted(date: .abbreviated, time: .omitted))").font(.system(size: 12)).foregroundStyle(muted)
        }
    }
    private func planCard(_ plan: LearningPlan, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text(discovery.cached == nil ? "EXPLORE" : isFirst ? "FOR YOUR CURIOUS MIND" : "ANOTHER DIRECTION").font(.system(size: 12, weight: .bold, design: .monospaced)); Spacer(); Text("\(plan.minutes) MIN · \(plan.resources.count == 2 ? "2 SHORT TOPICS" : "1 TOPIC")").font(.system(size: 12, weight: .bold)) }
            HStack(alignment: .top) { Text(plan.title).font(.system(size: 28, weight: .regular, design: .serif)).tracking(-0.8); Spacer(minLength: 8); BloomMark().scaleEffect(1.05).frame(width: 65, height: 76).accessibilityHidden(true) }
            if discovery.cached != nil { DisclosureGroup("Why this is for you") { VStack(alignment:.leading,spacing:10) { Text(plan.why); if let evidence=plan.resources.first?.learningEvidence { Text(evidence).font(.system(size:13)) } }.font(.system(size:15)).padding(.top,6) }.tint(ink) }
            ForEach(Array(plan.resources.enumerated()), id: \.offset) { index, resource in
                VStack(alignment: .leading, spacing: 10) {
                    if plan.resources.count > 1 { Text("0\(index + 1) / \(resource.minutes) MIN").font(.system(size: 12, weight: .bold, design: .monospaced)) }
                    Button { reader = ReaderTarget(url: URL(string: resource.url)!,video:resource.isVideo) } label: { Text(resource.title).font(.system(size: 19, weight: .semibold)).multilineTextAlignment(.leading) }.buttonStyle(.plain).foregroundStyle(ink)
                    Text("\(resource.publisher) · \(resource.format)").font(.system(size: 13)).opacity(0.75)
                    Text("THE TAKEAWAY").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1)
                    Text(resource.preview).font(.system(size: 16)).fixedSize(horizontal: false, vertical: true)
                    DisclosureGroup("A question to think about") { Text(resource.question).font(.system(size: 16, design: .serif)).padding(.top, 6) }.font(.system(size: 13)).tint(ink)
                    HStack {
                        Button { reader = ReaderTarget(url: URL(string: resource.url)!,video:resource.isVideo) } label: { Label(resource.isVideo ? "Watch video" : "Read resource", systemImage: "arrow.up.right") }.buttonStyle(DarkButton())
                        Spacer()
                        Button("Reflect") { selectedEntry = nil; suggestedSource = resource.url; presentReflection() }.font(.system(size: 14, weight: .semibold)).buttonStyle(.plain)
                    }
                }.padding(.vertical, 10)
            }
        }.padding(24).foregroundStyle(ink).background(isFirst ? coral : lilac, in: RoundedRectangle(cornerRadius: 30))
    }
    private func stat(_ number: String, _ label: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Image(systemName: icon).foregroundStyle(muted); Text(number).font(.system(size: 29, weight: .medium, design: .rounded)).foregroundStyle(icon == "flame" ? Color(red: 1, green: 0.44, blue: 0.34) : icon == "clock" ? adaptiveColor(light: (0.14, 0.40, 0.51), dark: (0.45, 0.80, 0.95)) : accent); Text(label).font(.system(size: 12)).foregroundStyle(muted) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(panel, in: RoundedRectangle(cornerRadius: 16))
    }
    private var journal: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Your thinking, collected.", "A record of ideas you’ve made your own.")
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(muted)
                TextField("Search reflections or topics", text: $search).textFieldStyle(.plain)
                if !entries.isEmpty { Button { exportDocument = JournalDocument(text: entries.map { e in "# \(e.title)\n\n\(e.date.formatted()) · \(e.topic) · \(e.minutes) minutes · Confidence \(e.confidence)/5\n\nSource: \(e.source)\n\n## The idea\n\(e.takeaway)\n\n## How it works\n\(e.mechanism)\n\n## Evidence\n\(e.evidence)\n\n## Tradeoff\n\(e.tradeoff)\n\n## My view\n\(e.opinion)\n" }.joined(separator: "\n---\n\n")); exporting = true } label: { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Export journal as Markdown") }
            }.padding(16).background(panel, in: RoundedRectangle(cornerRadius: 12))
            let filtered = entries.filter { search.isEmpty || "\($0.title) \($0.topic) \($0.takeaway) \($0.opinion)".localizedCaseInsensitiveContains(search) }
            if filtered.isEmpty { ContentUnavailableView(search.isEmpty ? "Your first idea belongs here" : "No matching reflections", systemImage: "book.closed", description: Text(search.isEmpty ? "Save a reflection after your next read, listen, or experiment." : "Try a different word or topic.")) }
            ForEach(filtered) { entryCard($0) }
        }
    }
    private func entryCard(_ e: LearningEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(e.topic).font(.system(size: 12, weight: .semibold)).foregroundStyle(accent); Spacer(); Text(e.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(muted) }
            Button { selectedEntry = e; suggestedSource = ""; presentReflection() } label: { Text(e.title).font(.system(size: 21, weight: .semibold, design: .rounded)).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain)
            Text(e.takeaway).font(.system(size: 16)).foregroundStyle(muted).lineLimit(3)
            HStack { Text("\(e.minutes) min · Confidence \(e.confidence)/5").font(.caption).foregroundStyle(muted); Spacer(); Button { selectedEntry = e; suggestedSource = ""; presentReflection() } label: { Image(systemName: "pencil") }.accessibilityLabel("Edit \(e.title)"); Button(role: .destructive) { deleting = e } label: { Image(systemName: "trash") }.accessibilityLabel("Delete \(e.title)") }.buttonStyle(.borderless)
        }.card()
    }
    private var growth: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Understanding compounds.", "Show up, connect ideas, and watch your perspective develop.")
            HStack(spacing: 12) { stat("\(entries.count)", "reflections", "pencil"); stat("\(Set(entries.map(\.topic)).count)", "topics explored", "square.grid.2x2"); stat("\(Growth.streak(entries.map(\.date)))", "day streak", "flame") }
            VStack(alignment: .leading, spacing: 18) {
                HStack { Text("The last 12 weeks").font(.title3.weight(.semibold)); Spacer(); Text("\(Growth.days(entries.map(\.date)).count) days total").font(.caption).foregroundStyle(muted) }
                let days = Growth.lastDays(84)
                let learned = Growth.days(entries.map(\.date))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 14), spacing: 5) {
                    ForEach(days, id: \.self) { day in RoundedRectangle(cornerRadius: 4).fill(learned.contains(day) ? lime : Color.white.opacity(0.06)).aspectRatio(1, contentMode: .fit).accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)): \(learned.contains(day) ? "Learned" : "No reflection")").help(day.formatted(date: .abbreviated, time: .omitted)) }
                }
                Text("Each bright square is a day you captured something. Missing a day is fine—return when you can.").font(.system(size: 14)).foregroundStyle(muted)
            }.card()
            VStack(alignment: .leading, spacing: 20) {
                Text("Your areas of depth").font(.title3.weight(.semibold))
                ForEach(topics, id: \.self) { topic in
                    let related = entries.filter { $0.topic == topic }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(topic).font(.system(size: 15)); Spacer(); Text("\(related.count) reflections").font(.caption).foregroundStyle(muted) }
                        GeometryReader { geo in Capsule().fill(.white.opacity(0.06)).overlay(alignment: .leading) { Capsule().fill(lime.opacity(0.85)).frame(width: geo.size.width * CGFloat(related.count) / CGFloat(max(entries.count, 1))) } }.frame(height: 5)
                        if let newest = related.first, let oldest = related.last { Text("Self-rated confidence: \(oldest.confidence)/5 → \(newest.confidence)/5").font(.caption).foregroundStyle(muted) }
                    }
                }
                Text("Confidence is your self-assessment, not a test score.").font(.caption).foregroundStyle(muted)
            }.card()
            if let first = entries.last, entries.count > 1 { VStack(alignment: .leading, spacing: 12) { Text("REVISIT AN EARLY IDEA").eyebrow(); Text(first.title).font(.title3); Text("What would you explain differently today?").foregroundStyle(muted); Button("Read your reflection") { selectedEntry = first; suggestedSource = ""; presentReflection() }.buttonStyle(AccentButton()) }.card() }
        }
    }
    private var library: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Good inputs. Better questions.", "Your reading and listening rotation, chosen for an AI engineer.")
            Picker("Library view", selection: $libraryHistory) { Text("Sources").tag(false); Text("History").tag(true) }.pickerStyle(.segmented)
            if libraryHistory {
                if visits.isEmpty { ContentUnavailableView("Your reading trail starts here", systemImage: "clock", description: Text("Pages opened in the reader appear here. Mark an article read when you finish.")) }
                ForEach(visits) { visit in
                    VStack(alignment: .leading, spacing: 10) {
                        Button { if let url = URL(string: visit.url) { reader = ReaderTarget(url: url) } } label: { Text(visit.title.isEmpty ? visit.url : visit.title).font(.headline).multilineTextAlignment(.leading) }.buttonStyle(.plain)
                        Text(visit.url).font(.caption).foregroundStyle(muted).lineLimit(2)
                        HStack { Text(visit.lastVisited.formatted(date: .abbreviated, time: .shortened)); Spacer(); Text(visit.finished ? "Read ✓" : "Opened") }.font(.caption).foregroundStyle(muted)
                        Button("Continue reflection") { selectedEntry = entries.first { $0.source == visit.url }; suggestedSource = visit.url; presentReflection() }.buttonStyle(.borderless)
                    }.padding(.vertical, 12)
                    Divider()
                }
            } else {
            ForEach(LearningSource.all) { source in
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Image(systemName: source.symbol).font(.title2).foregroundStyle(accent).frame(width: 36); VStack(alignment: .leading, spacing: 5) { Text(source.name).font(.system(size: 19, weight: .semibold)); Text(source.focus).font(.system(size: 14)).foregroundStyle(muted) }; Spacer() }
                    HStack { Text(source.kind).eyebrow(); Spacer(); Button("Open source ↗") { reader = ReaderTarget(url: URL(string: source.url)!) }.font(.system(size: 14, weight: .semibold)); Button("Reflect") { selectedEntry = nil; suggestedSource = source.url; presentReflection() }.buttonStyle(AccentButton()) }
                }.card()
            }
            }
        }
    }
}

struct RitualView: View {
    @EnvironmentObject private var reminders: Reminders
    @EnvironmentObject private var discovery: Discovery
    @AppStorage("learningInterests") private var interests = "AI engineering, model efficiency, agents, and evidence-based opinions about AI"
    @AppStorage("preferredFormat") private var format = "Any format"
    @AppStorage("sessionMinutes") private var minutes = 15
    @AppStorage("autoDiscover") private var autoDiscover = true
    @AppStorage("openAIModel") private var model = "gpt-5.6-sol"
    @State private var key = ""
    @AppStorage("reminderTime") private var timeValue = Calendar.current.date(from: DateComponents(hour: 19, minute: 30))!.timeIntervalSince1970
    private var time: Binding<Date> { Binding(get: { Date(timeIntervalSince1970: timeValue) }, set: { timeValue = $0.timeIntervalSince1970 }) }
    @Query(sort: \LearningEntry.date, order: .reverse) private var entries: [LearningEntry]
    @State private var connectionExpanded = false
    @State private var selectedPane = "Learning"
    @AppStorage("appAppearance") private var appearance = "Charcoal"
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack { VStack(alignment: .leading, spacing: 8) { Text("YOUR DAILY RITUAL").eyebrow(); Text("Make it yours.").font(.system(size: 36, design: .serif)) }; Spacer(); BloomMark().frame(width: 65, height: 75) }
            Picker("Ritual settings", selection: $selectedPane) { ForEach(["Learning", "Reminders", "Appearance"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
            switch selectedPane {
            case "Learning": learningSettings
            case "Reminders": reminderSettings
            default: appearanceSettings
            }
        }.onAppear { connectionExpanded = !discovery.hasKey }
    }
    private var learningSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Substance before promotion. Your curator explores tools, memory, models, inference and more, then checks the articles for depth and variety.").font(.system(size: 16)).foregroundStyle(muted)
            VStack(alignment: .leading, spacing: 18) {
                DisclosureGroup(discovery.hasKey ? "Manage OpenAI connection" : "01 / Connect OpenAI", isExpanded: $connectionExpanded) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Use an OpenAI API key. It’s stored securely in this device’s Keychain.").font(.system(size: 14)).foregroundStyle(muted)
                        Link("Get an API key ↗", destination: URL(string: "https://platform.openai.com/api-keys")!)
                        SecureField(discovery.hasKey ? "Paste a replacement key" : "Paste your API key", text: $key).textFieldStyle(.plain).padding(16).background(canvas, in: RoundedRectangle(cornerRadius: 14))
                        Button("Save connection securely") { discovery.saveKey(key); if discovery.hasKey { key = ""; connectionExpanded = false } }.buttonStyle(AccentButton()).disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if discovery.hasKey { Button("Disconnect OpenAI", role: .destructive) { discovery.removeKey(); connectionExpanded = true } }
                        Text("API and web-search usage are billed to your OpenAI account, separately from ChatGPT. A saved key is verified when you curate an edition.").font(.caption).foregroundStyle(muted)
                    }.padding(.top, 16)
                }.font(.headline)
            }.card()
            VStack(alignment: .leading, spacing: 20) {
                Text("What’s pulling at your curiosity?").font(.system(size: 27, design: .serif))
                TextField("e.g. Better evals, smaller models, or the limits of agents…", text: $interests, axis: .vertical).environment(\.colorScheme, .light).lineLimit(3...6).font(.system(size: 18, design: .serif)).textFieldStyle(.plain).padding(18).foregroundStyle(ink).background(lime, in: RoundedRectangle(cornerRadius: 18))
                ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(["Model efficiency", "Agent design", "Evals", "AI & society"], id: \.self) { topic in Button(topic) { if !interests.localizedCaseInsensitiveContains(topic) { interests += interests.isEmpty ? topic : ", " + topic } }.buttonStyle(.borderless).padding(10).background(panel, in: Capsule()) } } }
                Picker("I’m in the mood for", selection: $format) { ForEach(["Any format", "Articles & papers", "Videos & talks", "Podcasts"], id: \.self) { Text($0) } }
                Stepper("A moment of \(minutes) minutes", value: $minutes, in: 5...120, step: 5)
                Button { Task { await discovery.find(interest: interests, preferredFormat: format, minutes: minutes, history: entries.prefix(10).map { "\($0.title.prefix(160)) | \($0.topic) | confidence \($0.confidence)/5" }, model: model, force: true) } } label: {
                    HStack { if discovery.busy { ProgressView().controlSize(.small) } else { Image(systemName: "sparkles") }; Text(discovery.busy ? "Finding the good stuff…" : "Curate my next edition"); Spacer(); Image(systemName: "arrow.right") }
                }.buttonStyle(AccentButton()).disabled(!discovery.hasKey || discovery.busy)
                if !discovery.hasKey { Text("Connect your API key above. Your first edition starts automatically and appears on Today.").font(.caption).foregroundStyle(muted) }
                if discovery.busy { LiquidCuration(status: discovery.status) }
                if !discovery.status.isEmpty && !discovery.busy { Text(discovery.status).font(.system(size: 14)).foregroundStyle(accent).accessibilityAddTraits(.updatesFrequently) }
                Toggle("Automatically curate my daily edition", isOn: $autoDiscover).onChange(of: autoDiscover) { _, enabled in discovery.scheduleBackgroundRefresh(); if enabled { Task { await discovery.refreshAutomatically() } } }.disabled(!discovery.hasKey)
                Text("One article edition and one 24-concept edition per day. We check when you open the app and request background refresh when iOS permits. Failed searches can retry after 15 minutes. No daily button press needed.").font(.caption).foregroundStyle(muted)
            }
            DisclosureGroup("Privacy & advanced settings") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Curation sends your interests, format, time budget and the last ten reflection titles, topics and confidence ratings to OpenAI. Full journal bodies are excluded. Daily concept editions send your interests and recent concept titles. Learning series send your topic and reading budget. These use additional research and editorial-check requests billed to your API account. Saved concept explanations are available offline; linked articles still need a connection. Using Explain in the reader sends the selected phrase, surrounding paragraph and article title/URL to OpenAI. Your key stays in this device’s Keychain.")
                    Text("Journal entries stay local unless iCloud capabilities are configured in your signed build. Export a backup from Journal.")
                    TextField("OpenAI model", text: $model).textFieldStyle(.roundedBorder)
                }.font(.caption).foregroundStyle(muted).padding(.top, 14)
            }.tint(accent)
        }
    }
    private var reminderSettings: some View {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Text("A gentle nudge.").font(.system(size: 29, design: .serif)); Spacer(); Image(systemName: "bell.badge.fill").font(.system(size: 32)).foregroundStyle(coral) }
                Text(reminders.enabled ? "Your daily reminder is on." : "Let curiosity become a familiar part of your day.").foregroundStyle(muted)
                DatePicker("Your moment", selection: time, displayedComponents: .hourAndMinute).font(.title3)
                Button { Task { await reminders.schedule(at: time.wrappedValue) } } label: { Text(reminders.busy ? "Scheduling…" : reminders.enabled ? "Update my reminder" : "Remind me every day").frame(maxWidth: .infinity) }.buttonStyle(AccentButton()).disabled(reminders.busy)
                HStack { Button("Test in 5 seconds") { Task { await reminders.test() } }; Spacer(); if reminders.enabled { Button("Turn off") { reminders.disable() } } }.buttonStyle(.borderless)
                Text(reminders.status).font(.caption).foregroundStyle(muted)
                Text("Local time on this device. Focus and notification settings may silence reminders.").font(.caption).foregroundStyle(muted)
            }.card()
    }
    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set the mood.").font(.system(size: 28, design: .serif))
            Text("The same colorful cards, on a background that feels right to you.").foregroundStyle(muted)
            HStack(spacing: 16) {
                ForEach(["White", "Charcoal"], id: \.self) { name in
                    Button { appearance = name } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Circle().fill(coral).frame(width: 24, height: 24); Circle().fill(lilac).frame(width: 24, height: 24); Spacer(); if appearance == name { Image(systemName: "checkmark.circle.fill") } }
                            RoundedRectangle(cornerRadius: 12).fill(coral).frame(height: 65)
                            Text(name).font(.headline)
                        }.padding(18).foregroundStyle(name == "White" ? ink : Color.white).background(name == "White" ? Color.white : ink, in: RoundedRectangle(cornerRadius: 22)).overlay { RoundedRectangle(cornerRadius: 22).stroke(appearance == name ? coral : muted.opacity(0.3), lineWidth: appearance == name ? 3 : 1) }
                    }.buttonStyle(.plain)
                }
            }
            Text("Reader paper/night settings remain independent. Motion follows your device’s Reduce Motion setting.").font(.caption).foregroundStyle(muted)
        }.card()
    }
    private func ritualStep(_ n: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) { Text(n).font(.system(size: 15, design: .monospaced)).foregroundStyle(accent); VStack(alignment: .leading, spacing: 6) { Text(title).font(.headline); Text(detail).font(.system(size: 14)).foregroundStyle(muted) } }
    }
}

struct EntryEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var entry: LearningEntry?
    var initialSource: String
    @State private var title = ""
    @State private var topic = topics[0]
    @State private var source = ""
    @State private var takeaway = ""
    @State private var mechanism = ""
    @State private var evidence = ""
    @State private var tradeoff = ""
    @State private var opinion = ""
    @State private var minutes = 15
    @State private var confidence = 3
    @State private var error: String?
    @State private var confirmDiscard = false
    @State private var initialSnapshot = ""
    private var snapshot: String { [title, topic, source, takeaway, mechanism, evidence, tradeoff, opinion, String(minutes), String(confidence)].joined(separator: "\u{001F}") }
    @State private var cardSeed: CardSeed?
    @State private var draftLoaded = false
    private var draftKey: String { "reflectionDraft." + (entry?.id.uuidString ?? (initialSource.isEmpty ? "new" : initialSource)) }
    @State private var details = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LET IT TAKE ROOT").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(2)
                            Text("What stayed\nwith you?").font(.system(size: 32, design: .serif)).tracking(-1)
                        }; Spacer(); GardenArt().frame(width: 90, height: 120)
                    }.padding(22).foregroundStyle(ink).background(coral, in: RoundedRectangle(cornerRadius: 28))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("READING & SOURCE").eyebrow()
                        if let url = URL(string: source), ["https", "http"].contains(url.scheme ?? "") { Link(source, destination: url).font(.caption).lineLimit(2) }
                        TextField("Article link or source", text: $source).textFieldStyle(.roundedBorder).autocorrectionDisabled()
                    }
                    Text("A sentence is enough. This is a place to think, not a test.").font(.system(size: 16, design: .serif)).foregroundStyle(muted)
                    TextField("The thing I want to remember is…", text: $takeaway, axis: .vertical).lineLimit(3...14).textFieldStyle(.plain).font(.system(size: 23, design: .serif)).padding(22).foregroundStyle(ink).background(lime, in: RoundedRectangle(cornerRadius: 23)).environment(\.colorScheme, .light).accessibilityLabel("Your takeaway")
                    HStack {
                        Text("Draft saved as you write").font(.caption).foregroundStyle(muted)
                        Spacer()
                        Button("Ankilize ✦") { cardSeed = CardSeed(text: [takeaway, mechanism, evidence, tradeoff, opinion].filter { !$0.isEmpty }.joined(separator: "\n"), source: source) }.disabled(takeaway.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    HStack { Image(systemName: "sparkle").foregroundStyle(lilac); Text("How does this feel now?").font(.headline) }
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { value in
                            Button { withAnimation(reduceMotion ? nil : .spring(response: 0.3)) { confidence = value } } label: {
                                VStack(spacing: 8) { Image(systemName: value < 3 ? "leaf" : value < 5 ? "leaf.fill" : "tree.fill").font(.title2); Text("\(value)").font(.caption) }.frame(maxWidth: .infinity).padding(.vertical, 14).foregroundStyle(confidence == value ? ink : accent).background(confidence == value ? sage : panel, in: RoundedRectangle(cornerRadius: 17))
                            }.buttonStyle(.plain).accessibilityLabel("Confidence \(value) of 5").accessibilityAddTraits(confidence == value ? .isSelected : [])
                        }
                    }
                    HStack { Text("Still taking root"); Spacer(); Text("Could explain it") }.font(.caption).foregroundStyle(muted)
                    DisclosureGroup("Give it a name & go deeper", isExpanded: $details) {
                        VStack(alignment: .leading, spacing: 20) {
                            field("TITLE · OPTIONAL", "We’ll use your first sentence if you leave this blank", text: $title)
                            Picker("Topic", selection: $topic) { ForEach(topics, id: \.self) { Text($0) } }.pickerStyle(.menu)
                            field("SOURCE", "Article, video, or experiment", text: $source)
                            note("MY VIEW", "What do I think about this?", text: $opinion)
                            note("HOW IT WORKS", "What makes it possible?", text: $mechanism)
                            note("THE EVIDENCE", "What convinced me?", text: $evidence)
                            note("THE TRADEOFF", "What’s the catch?", text: $tradeoff)
                            Stepper("Time invested: \(minutes) minutes", value: $minutes, in: 1...480, step: 5)
                        }.padding(.top, 18)
                    }.tint(accent)
                    if let error { Text(error).foregroundStyle(.red) }
                }.padding(20)
            }.background(canvas).navigationTitle(entry == nil ? "Reflect" : "Your thought")
            .safeAreaInset(edge: .bottom) {
                Button(action: save) { HStack { Text(entry == nil ? "Keep this thought" : "Save my changes"); Spacer(); Image(systemName: "arrow.up.right") }.font(.system(size: 17, weight: .semibold)).padding(18).foregroundStyle(ink).background(sage, in: Capsule()).opacity(takeaway.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1) }.buttonStyle(.plain).disabled(takeaway.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).padding(20).background(canvas)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done for now") { dismiss() } } }
        }
        .tint(accent)
        #if os(macOS)
        .frame(width: 620, height: 780)
        #endif
        .sheet(item: $cardSeed) { CardComposer(seed: $0) }
        .onChange(of: snapshot) { _, _ in
            if draftLoaded { UserDefaults.standard.set([title, topic, source, takeaway, mechanism, evidence, tradeoff, opinion, String(minutes), String(confidence)], forKey: draftKey) }
        }
        .confirmationDialog("Discard your unsaved changes?", isPresented: $confirmDiscard, titleVisibility: .visible) { Button("Discard changes", role: .destructive) { dismiss() }; Button("Keep writing", role: .cancel) {} }
        .onAppear {
            guard !draftLoaded else { return }
            if let e = entry { title = e.title; topic = e.topic; source = e.source; takeaway = e.takeaway; mechanism = e.mechanism; evidence = e.evidence; tradeoff = e.tradeoff; opinion = e.opinion; minutes = e.minutes; confidence = e.confidence } else { source = initialSource; minutes = UserDefaults.standard.integer(forKey: "sessionMinutes"); if minutes < 1 { minutes = 15 } }
            if !draftLoaded, let saved = UserDefaults.standard.stringArray(forKey: draftKey), saved.count == 10 {
                title = saved[0]; topic = saved[1]; source = saved[2]; takeaway = saved[3]; mechanism = saved[4]; evidence = saved[5]; tradeoff = saved[6]; opinion = saved[7]; minutes = Int(saved[8]) ?? 15; confidence = Int(saved[9]) ?? 3
            }
            if source.isEmpty { source = initialSource }
            draftLoaded = true
            initialSnapshot = snapshot
        }
    }
    private func field(_ label: String, _ hint: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 9) { Text(label).eyebrow(); TextField(hint, text: text).textFieldStyle(.plain).padding(14).background(panel, in: RoundedRectangle(cornerRadius: 10)).accessibilityLabel(label) }
    }
    private func note(_ label: String, _ hint: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 9) { Text(label).eyebrow(); TextField(hint, text: text, axis: .vertical).lineLimit(3...12).textFieldStyle(.plain).font(.system(size: 16)).padding(14).background(panel, in: RoundedRectangle(cornerRadius: 10)).accessibilityLabel(label) }
    }
    private func save() {
        let e = entry ?? LearningEntry()
        if entry == nil { context.insert(e) }
        e.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(takeaway.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)) : title.trimmingCharacters(in: .whitespacesAndNewlines); e.topic = topic; e.source = source; e.takeaway = takeaway; e.mechanism = mechanism; e.evidence = evidence; e.tradeoff = tradeoff; e.opinion = opinion; e.minutes = minutes; e.confidence = confidence
        do { try context.save(); draftLoaded = false; UserDefaults.standard.removeObject(forKey: draftKey); dismiss() } catch { context.rollback(); self.error = "Your writing is still here. Couldn’t save: \(error.localizedDescription)" }
    }
}

struct JournalDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}
struct AccentButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 14, weight: .semibold)).padding(.horizontal, 17).padding(.vertical, 12).foregroundStyle(ink).background(lime.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 10)) }
}
struct DarkButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 14, weight: .semibold)).padding(.horizontal, 17).padding(.vertical, 12).foregroundStyle(.white).background(ink.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 10)) }
}
extension View {
    fileprivate func card() -> some View { self.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(panel, in: RoundedRectangle(cornerRadius: 18)).overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.05), lineWidth: 1) } }
    fileprivate func eyebrow() -> some View { self.font(.system(size: 12, weight: .semibold, design: .monospaced)).tracking(1).foregroundStyle(muted) }
}

extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

private struct BloomMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drifting = false
    var body: some View {
        ZStack {
            ForEach(0..<6) { i in Ellipse().fill(Color(red: 0.36, green: 0.22, blue: 0.50)).frame(width: 23, height: 42).offset(y: -16).rotationEffect(.degrees(Double(i) * 60)) }
            Circle().fill(Color(red: 0.97, green: 0.81, blue: 0.40)).frame(width: 19, height: 19)
        }.rotationEffect(.degrees(drifting && !reduceMotion ? 18 : -8)).animation(reduceMotion ? nil : .easeInOut(duration: 4).repeatForever(autoreverses: true), value: drifting).onAppear { drifting = true }.accessibilityHidden(true)
    }
}

private struct GardenArt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Ellipse().fill(sage).frame(width: geo.size.width * 0.65, height: 30).rotationEffect(.degrees(-35)).offset(x: -16, y: 35)
                Ellipse().fill(lilac).frame(width: geo.size.width * 0.6, height: 35).rotationEffect(.degrees(30)).offset(x: 22, y: 55)
                Capsule().fill(Color(red: 0.24, green: 0.36, blue: 0.22)).frame(width: 8, height: 80).offset(y: 30)
                BloomMark().scaleEffect(1.4).offset(y: -20)
                Image(systemName: "sparkle").font(.system(size: 28)).foregroundStyle(accent).offset(x: -44, y: -46)
            }.frame(width: geo.size.width, height: geo.size.height).offset(y: breathe && !reduceMotion ? -4 : 4)
        }.animation(reduceMotion ? nil : .easeInOut(duration: 3).repeatForever(autoreverses: true), value: breathe).onAppear { breathe = true }.accessibilityHidden(true)
    }
}

private func adaptiveColor(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
    #if os(iOS)
    return Color(uiColor: UIColor { traits in
        let rgb = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    })
    #else
    return Color(nsColor: NSColor(name: nil) { appearance in
        let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        return NSColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    })
    #endif
}

// One continuous field behind the scroll viewport, shared by all page sections.
private struct LiquidCurationField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                context.addFilter(.blur(radius: 44))
                let colors: [Color] = [coral, lilac, sage, Color(red: 1, green: 0.69, blue: 0.30)]
                for i in 0..<4 {
                    let phase = t * 0.4 + Double(i) * 1.7
                    let x = size.width * (0.5 + 0.48 * sin(phase))
                    let y = size.height * (0.48 + 0.33 * cos(phase * 0.7))
                    let width = min(size.width, 650) * (0.65 + 0.12 * sin(phase + 1))
                    let height = max(180, size.height * 0.38)
                    context.fill(Path(ellipseIn: CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)), with: .color(colors[i]))
                }
            }
        }
        .opacity(colorScheme == .dark ? 0.24 : 0.20)
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.16), .init(color: .white, location: 0.82), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct LiquidCuration: View {
    let status: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A little discovery in motion.").font(.system(size: 26, design: .serif))
            Text(status).font(.system(size: 13)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 30)
        .accessibilityElement(children: .combine)
    }
}

struct CardComposer: View {
    let seed: CardSeed
    var editing: RecallCard? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RecallCard.created, order: .reverse) private var cards: [RecallCard]
    @State private var input = ""
    @State private var front = ""
    @State private var back = ""
    @State private var category = "Engineering"
    @State private var style = 0
    @State private var busy = false
    @State private var error: String?
    @State private var generation: Task<Void, Never>?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Give an idea\na little staying power.").font(.system(size: 32, design: .serif))
                    TextField("A thought, a passage, something worth remembering…", text: $input, axis: .vertical).lineLimit(3...8).textFieldStyle(.plain).padding(18).background(panel, in: RoundedRectangle(cornerRadius: 18))
                    Button { generate() } label: { HStack { if busy { ProgressView() }; Text(busy ? "Shaping your thought…" : "Ankilize with AI ✦") } }.buttonStyle(AccentButton()).disabled(busy || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("AI uses this text to draft one card. Read and edit it before saving.").font(.caption).foregroundStyle(muted)
                    if let error { Text(error).foregroundStyle(.red).font(.callout) }
                    VStack(alignment: .leading, spacing: 18) {
                        TextField("Topic", text: $category).font(.system(size: 12, weight: .bold, design: .monospaced))
                        TextField("Front · what do you want to recall?", text: $front, axis: .vertical).font(.system(size: 25, weight: .medium, design: .serif)).lineLimit(2...6)
                        Divider()
                        TextField("Back · the idea in a few sentences", text: $back, axis: .vertical).font(.system(size: 18)).lineLimit(3...10)
                    }.textFieldStyle(.plain).padding(26).foregroundStyle(ink).background(RecallPalette.color(style), in: RoundedRectangle(cornerRadius: 28))
                    HStack {
                        Button("Remix colors ✦") { remix() }.buttonStyle(.bordered)
                        Picker("Pattern", selection: Binding(get: { style / 16 }, set: { style = $0 * 16 + style % 16 })) {
                            Text("Blooms").tag(0); Text("Orbits").tag(1); Text("Confetti").tag(2); Text("Waves").tag(3)
                        }
                    }
                    Button(editing == nil ? "Keep this card" : "Save card") { save() }.buttonStyle(AccentButton()).disabled(busy || front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding(24)
            }.background(canvas).navigationTitle("Ankilize")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .onAppear { input = seed.text; if let editing { front = editing.prompt; back = editing.answer; category = editing.category; style = editing.style } else { remix(); if !input.isEmpty { generate() } } }
        .onDisappear { generation?.cancel() }
        #if os(macOS)
        .frame(width: 600, height: 760)
        #endif
    }
    private func remix() {
        let recent = Set(cards.prefix(8).map { $0.style % 16 })
        let options = (0..<16).filter { !recent.contains($0) && $0 != style % 16 }
        style = (options.randomElement() ?? Int.random(in: 0..<16)) + 16 * Int.random(in: 0..<4)
    }
    private func generate() {
        busy = true; error = nil
        generation = Task {
            defer { busy = false }
            do { let draft = try await CardWriter.create(from: input); try Task.checkCancellation(); front = draft.prompt; back = draft.answer; category = draft.category }
            catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }
    private func save() {
        let card = editing ?? RecallCard()
        if editing == nil { context.insert(card) }
        card.prompt = front; card.answer = back; card.original = input; card.source = seed.source; card.category = category; card.style = style
        do { try context.save(); dismiss() } catch { context.rollback(); self.error = error.localizedDescription }
    }
}

enum RecallPalette {
    // Sixteen paper colors, each chosen for legible dark type; four artwork families.
    static let hex: [UInt32] = [0xFF886B,0xB9A0FF,0xE6EE64,0x67D6CF,0xFFA9CC,0xFFBD55,0xA8D87C,0x92BFFF,0xF18ADB,0xD2BC94,0x80DDD1,0xD2B5F5,0xFFAA89,0xD7E8A0,0xE8A8B5,0x99CBDE]
    static func color(_ seed: Int) -> Color {
        let value = hex[abs(seed) % hex.count]
        return Color(red: Double((value >> 16) & 255)/255, green: Double((value >> 8) & 255)/255, blue: Double(value & 255)/255)
    }
}
struct RecallArtwork: View {
    let style: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/24.0, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let shift = sin(t * 0.45) * 7
                let strong = Color(red: 0.19, green: 0.20, blue: 0.65)
                for i in 0..<12 {
                    let x = Double(i % 4) * Double(size.width) / 3.0 + shift
                    let y = Double(i / 4) * 75 + 30
                    var path = Path()
                    switch (style / 16) % 4 {
                    case 0:
                        for petal in 0..<6 {
                            let angle = Double(petal) * .pi/3 + t * (reduceMotion ? 0 : 0.025)
                            path.addEllipse(in: CGRect(x: x + cos(angle)*22 - 14, y: y + sin(angle)*22 - 14, width: 28, height: 28))
                        }
                        ctx.fill(path, with: .color(i % 2 == 0 ? strong : .white.opacity(0.6)))
                    case 1:
                        for ring in 0..<3 { path.addEllipse(in: CGRect(x:x-Double(ring)*10, y:y-Double(ring)*10, width:30+Double(ring)*20, height:30+Double(ring)*20)) }
                        ctx.stroke(path, with:.color(strong), lineWidth:5)
                    case 2:
                        path.move(to:CGPoint(x:x,y:y)); path.addLine(to:CGPoint(x:x+24,y:y-25)); path.addLine(to:CGPoint(x:x+40,y:y+20)); path.closeSubpath()
                        ctx.fill(path, with:.color(i % 2 == 0 ? strong : .white.opacity(0.8)))
                    default:
                        path.move(to:CGPoint(x:x-30,y:y)); path.addCurve(to:CGPoint(x:x+70,y:y), control1:CGPoint(x:x,y:y-50), control2:CGPoint(x:x+30,y:y+50))
                        ctx.stroke(path, with:.color(strong), style:StrokeStyle(lineWidth:12,lineCap:.round))
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
struct RecallFeed: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \RecallCard.due) private var cards: [RecallCard]
    @State private var seed: CardSeed?
    @State private var editing: RecallCard?
    @AppStorage("recallMode") private var mode = "Tidbits"
    @State private var focusedCard: UUID?
    @State private var browse = false
    @State private var archive = false
    @State private var error: String?
    @State private var now = Date()
    @State private var reward = 0
    @State private var showReward = false
    @State private var swipeArmed = false
    @State private var resistedPull: CGFloat = 0
    @State private var swipeFeedback = 0
    @State private var pageFeedback = 0
    private var visible: [RecallCard] { cards.filter { $0.archived == archive && (mode == "Tidbits" || archive || browse || $0.due <= now) } }
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Picker("Learning mode", selection: $mode) { Text("Tidbits").tag("Tidbits"); Text("Recall").tag("Recall") }.pickerStyle(.segmented)
                    Menu {
                        Button("Due now") { mode="Recall"; browse=false; archive=false }
                        Button("Explore all") { browse=true; archive=false }
                        Button("Archived") { archive=true }
                    } label: { Image(systemName:"line.3.horizontal.decrease") }.accessibilityLabel("Filter cards")
                    Button { seed=CardSeed(text:"",source:"") } label:{Image(systemName:"plus.circle.fill").font(.title2)}.accessibilityLabel("Create card")
                }.padding(.horizontal,16).padding(.vertical,10).tint(accent)
                GeometryReader { viewport in
                ZStack(alignment: .top) {
                if visible.isEmpty {
                    VStack(spacing:24) {
                        Spacer()
                        RecallArtwork(style:32).frame(height:160).clipped()
                        Text(archive ? "Nothing tucked away." : cards.isEmpty ? "A thought today.\nYours for longer." : "A little wiser.\nA little more you.").font(.system(size:38,design:.serif)).multilineTextAlignment(.center)
                        Text(archive ? "Restore archived cards here." : cards.isEmpty ? "Capture an idea. Try recalling it. Come back and feel it getting familiar." : "You’re caught up. Keep exploring your cards or let your mind rest until the next review.").font(.system(size:17)).multilineTextAlignment(.center)
                        if !cards.filter({ !$0.archived }).isEmpty { Button("Keep exploring →") { archive=false; browse=true }.buttonStyle(DarkButton()) }
                        Button("Capture a thought ✦") { seed=CardSeed(text:"",source:"") }.buttonStyle(DarkButton())
                        Spacer()
                    }.padding(28).frame(maxWidth:.infinity,maxHeight:.infinity).foregroundStyle(ink).background(lilac,in:RoundedRectangle(cornerRadius:32)).padding(.horizontal,12).padding(.bottom,10)
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(spacing:0) {
                            ForEach(visible) { card in
                                Group {
                                if mode == "Tidbits" {
                                    TidbitFace(card:card, edit:{editing=card}, practice:{ mode="Recall"; browse=true; archive=false; focusedCard=card.id })
                                } else {
                                RecallFace(card:card, practice:!archive, edit:{ editing=card }, archive:{ card.archived.toggle(); save() }, rate:{ rating in
                                    card.review(rating)
                                    if save() { reward += 1; withAnimation(reduceMotion ? nil : .spring(response:0.3)) { showReward=true } }
                                })
                                }
                                }.frame(width:max(0,geo.size.width-24))
                                    .frame(height:max(0,viewport.size.height-10))
                                    .clipShape(RoundedRectangle(cornerRadius:32))
                                    .shadow(color:.black.opacity(0.20),radius:12,y:7)
                                    .offset(y:mode == "Recall" && (focusedCard == nil || focusedCard == card.id) && !reduceMotion ? resistedPull : 0)
                                    .scrollTransition(.interactive,axis:.vertical) { content, phase in
                                        content.scaleEffect(reduceMotion ? 1 : phase.isIdentity ? 1 : 0.965)
                                            .rotation3DEffect(.degrees(reduceMotion ? 0 : phase.value * 3),axis:(x:1,y:0,z:0))
                                    }
                                    .padding(.horizontal,12).padding(.bottom,10)
                                    .id(card.id)
                            }
                        }.scrollTargetLayout()
                    }.scrollTargetBehavior(.paging).scrollPosition(id:$focusedCard).scrollIndicators(.hidden)
                        .simultaneousGesture(DragGesture(minimumDistance:12).onChanged { value in
                            guard mode == "Recall", abs(value.translation.height) > abs(value.translation.width) else { return }
                            if abs(value.translation.height) > 60 && !swipeArmed {
                                swipeArmed=true; swipeFeedback += 1
                                withAnimation(reduceMotion ? nil : .spring(response:0.24,dampingFraction:0.68)) { resistedPull=0 }
                            } else if !swipeArmed {
                                resistedPull = -value.translation.height * 0.22
                            }
                        }.onEnded { _ in
                            swipeArmed=false
                            withAnimation(reduceMotion ? nil : .spring(response:0.3,dampingFraction:0.78)) { resistedPull=0 }
                        })
                        .onChange(of:focusedCard) { old,new in if mode == "Recall", old != nil, new != nil, old != new { pageFeedback += 1 } }
                }
                if showReward {
                    Label("\(reward) moment\(reward == 1 ? "" : "s") of growth",systemImage:"sparkles").font(.system(size:18,weight:.semibold)).padding(20).foregroundStyle(ink).background(lime,in:Capsule()).padding(.top,65).transition(.scale.combined(with:.opacity)).allowsHitTesting(false)
                }
                }
                }
            }.background(canvas)
        }
        .task(id:reward) { if reward > 0 { try? await Task.sleep(for:.seconds(1.2)); if !Task.isCancelled { withAnimation { showReward=false } } } }
        #if os(iOS)
        .sensoryFeedback(.success,trigger:reward)
        .sensoryFeedback(.impact(weight:.medium,intensity:0.9),trigger:swipeFeedback)
        .sensoryFeedback(.selection,trigger:pageFeedback)
        #endif
        .onChange(of:mode) { _,newMode in
            archive=false
            if newMode == "Tidbits" { browse=false }
            showReward=false
        }
        .onChange(of:cards.map(\.id)) { _,_ in now=Date() }
        .onAppear { now=Date() }
        .onReceive(Timer.publish(every:30,on:.main,in:.common).autoconnect()) { now=$0 }
        .sheet(item:$seed) { CardComposer(seed:$0) }
        .sheet(item:$editing) { CardComposer(seed:CardSeed(text:$0.original,source:$0.source),editing:$0) }
        .alert("Couldn’t save",isPresented:Binding(get:{error != nil},set:{if !$0 {error=nil}})) { Button("OK") {} } message:{Text(error ?? "")}
    }
    @discardableResult private func save() -> Bool { do { try context.save(); return true } catch { context.rollback(); self.error=error.localizedDescription; return false } }
}
private struct RecallFace: View {
    let card: RecallCard
    let practice: Bool
    let edit: () -> Void
    let archive: () -> Void
    let rate: (Int) -> Void
    @State private var revealed = false
    @State private var response = ""
    @State private var showFullCard = false
    @State private var showFeedback = false
    @State private var feedback: String?
    @State private var alternate: RecallDraft?
    @State private var busy = false
    @State private var tutorError: String?
    @State private var task: Task<Void, Never>?
    private var question: String { alternate?.prompt ?? card.prompt }
    private var answer: String { alternate?.answer ?? card.answer }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment:.leading,spacing:22) {
            HStack { Label("RECALL",systemImage:"brain.head.profile").font(.system(size:12,weight:.bold,design:.monospaced)).tracking(2); Spacer(); Menu { Button("Edit card",action:edit); Button(card.archived ? "Restore" : "Archive",action:archive) } label:{Image(systemName:"ellipsis").padding(8)} }
            RecallArtwork(style:card.style).frame(height:65).clipped()
            Text(question).font(.system(size:32,weight:.medium,design:.serif)).lineLimit(6).minimumScaleFactor(0.7)
            if revealed {
                Divider()
                Text(answer).font(.system(size:19)).lineSpacing(4).lineLimit(12).minimumScaleFactor(0.75).transition(.opacity.combined(with:.offset(y:8)))
                Button("Read full card") { showFullCard=true }.font(.caption)
                if let url = URL(string:card.source), ["https","http"].contains(url.scheme ?? "") { Link("Return to source ↗",destination:url).font(.caption) }
            }
            if busy { HStack { ProgressView(); Text("Thinking with your card…").font(.caption) } }
            if feedback != nil { Button("Read your feedback ✦") { showFeedback=true }.buttonStyle(DarkButton()) }
            if let tutorError { Text(tutorError).font(.caption) }
            Spacer(minLength:12)
            if !revealed {
                TextField("Try answering in your own words…", text: $response, axis: .vertical).lineLimit(2...5).textFieldStyle(.plain).padding(16).background(.white.opacity(0.5),in:RoundedRectangle(cornerRadius:16))
                HStack {
                    Button("Check my answer") { checkAnswer() }.buttonStyle(DarkButton()).disabled(busy || response.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                    Button("Reveal") { withAnimation(reduceMotion ? nil : .spring(response:0.4,dampingFraction:0.85)) { revealed=true } }.buttonStyle(.plain)
                }
                Button("Ask me another way ✦") { anotherQuestion() }.font(.caption).disabled(busy)
            }
            else if practice {
                Text("How easily did it come back?").font(.caption)
                HStack(spacing:8) { ForEach(Array(["Again","Hard","Good","Easy"].enumerated()),id:\.offset) { index,label in Button(label) { rate(index) }.font(.system(size:14,weight:.semibold)).padding(.vertical,12).frame(maxWidth:.infinity).background(.white.opacity(0.45),in:Capsule()) } }.buttonStyle(.plain)
            } else { Text("Next review \(card.due.formatted(date:.abbreviated,time:.shortened))").font(.caption) }
            Text("Recall it. Reveal it. Swipe to keep going ↑").font(.system(size:11,weight:.medium)).frame(maxWidth:.infinity).opacity(0.65)
        }.padding(.horizontal,26).padding(.top,22).padding(.bottom,16).frame(maxWidth:.infinity,maxHeight:.infinity).foregroundStyle(ink).background(RecallPalette.color(card.style))
        .sheet(isPresented:$showFullCard) { ScrollView { VStack(alignment:.leading,spacing:20) { Text(question).font(.title); Text(answer).font(.title3); Button("Back") { showFullCard=false } }.padding(28) }.presentationDetents([.medium,.large]) }
        .sheet(isPresented:$showFeedback) { ScrollView { VStack(alignment:.leading,spacing:20) { Text("A little feedback").font(.largeTitle); Text(feedback ?? "").font(.title3); Button("Back to the card") { showFeedback=false } }.padding(28) }.presentationDetents([.medium,.large]) }
        .onDisappear { task?.cancel() }
    }
    private func checkAnswer() {
        busy=true; tutorError=nil
        task=Task { defer { busy=false }; do { let result=try await RecallTutor.feedback(question:question,reference:answer,answer:response); try Task.checkCancellation(); feedback=result; revealed=true; showFeedback=true } catch { if !Task.isCancelled { tutorError=error.localizedDescription } } }
    }
    private func anotherQuestion() {
        busy=true; tutorError=nil
        task=Task { defer { busy=false }; do { let result=try await CardWriter.create(from:"Saved question: \(card.prompt)\nSaved answer: \(card.answer)\nOriginal context: \(card.original)", variation: true); try Task.checkCancellation(); alternate=result; response=""; feedback=nil; revealed=false } catch { if !Task.isCancelled { tutorError=error.localizedDescription } } }
    }
}

private struct TidbitFace: View {
    let card: RecallCard
    let edit: () -> Void
    let practice: () -> Void
    @State private var expanded = false
    var body: some View {
        VStack(alignment:.leading,spacing:24) {
            HStack { Label("TIDBIT",systemImage:"sparkle").font(.system(size:11,weight:.bold,design:.monospaced)).tracking(1); Spacer(); Button(action:edit) { Image(systemName:"pencil") }.accessibilityLabel("Edit tidbit") }
            RecallArtwork(style:card.style).frame(height:140).clipped()
            Text(card.category.uppercased()).font(.system(size:12,weight:.bold,design:.monospaced)).opacity(0.7)
            Text(card.prompt).font(.system(size:14,weight:.medium)).lineLimit(2).opacity(0.7)
            Text(card.answer).font(.system(size:32,weight:.medium,design:.serif)).lineLimit(7).minimumScaleFactor(0.85)
            Button("Read the whole thought") { expanded=true }.font(.caption)
            Spacer(minLength:8)
            Button("Try recalling this ✦",action:practice).buttonStyle(DarkButton())
            Text("Small ideas. No quiz. Swipe for another ↑").font(.system(size:12)).opacity(0.7)
        }.padding(26).frame(maxWidth:.infinity,maxHeight:.infinity).foregroundStyle(ink).background(RecallPalette.color(card.style))
        .sheet(isPresented:$expanded) { ScrollView { VStack(alignment:.leading,spacing:20) { Text(card.answer).font(.title2); if let url=URL(string:card.source),["https","http"].contains(url.scheme ?? "") { Link("Original source ↗",destination:url) }; Button("Back") { expanded=false } }.padding(28) }.presentationDetents([.medium,.large]) }
    }
}
