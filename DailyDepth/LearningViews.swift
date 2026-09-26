import SwiftUI

struct LearningHub: View {
    @EnvironmentObject private var studio: LearningStudio
    @EnvironmentObject private var discovery: Discovery
    @State private var mode = "Discover"
    @State private var task: Task<Void, Never>?
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("A little wiser.").font(.system(size: 25, design: .serif))
                Spacer()
                Menu {
                    if studio.reelBusy { Button("Pause preparation") { studio.cancelReels() } }
                    else { Button("Prepare today's edition") { prepare() } }
                    Text("24 sourced concepts · six engineering areas")
                } label: { Image(systemName: "ellipsis.circle").font(.title3) }.accessibilityLabel("Daily learning options")
            }.padding(.horizontal, 20).padding(.top, 12)
            Picker("Learning collection", selection: $mode) {
                Text("Discover").tag("Discover"); Text("Saved").tag("Saved"); Text("My recall").tag("My recall")
            }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.vertical, 10)
            if mode == "My recall" { RecallFeed() }
            else { ConceptFeed(savedOnly: mode == "Saved", prepare: prepare) }
        }.background(canvas).tint(accent)
        .task { await studio.generateReels() }
        .onDisappear { task?.cancel() }
        .onChange(of: discovery.hasKey) { _, value in if value { prepare() } }
    }
    private func prepare() { task = Task { await studio.generateReels(manual: true) } }
}

private struct ConceptFeed: View {
    @EnvironmentObject private var studio: LearningStudio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let savedOnly: Bool
    let prepare: () -> Void
    @State private var focused: UUID?
    @State private var detail: ConceptReel?
    @State private var seed: CardSeed?
    @State private var reader: ReaderTarget?
    private var cards: [ConceptReel] { savedOnly ? studio.vault.saved : studio.vault.edition?.cards ?? [] }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(savedOnly ? "YOUR KEEPERS" : editionLabel).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1)
                Spacer()
                Text("\(cards.firstIndex(where: { $0.id == focused }).map { $0 + 1 } ?? (cards.isEmpty ? 0 : 1)) / \(cards.count)").font(.caption.monospacedDigit())
            }.foregroundStyle(muted).padding(.horizontal, 20).padding(.bottom, 8)
            if studio.reelBusy || (cards.isEmpty && !studio.reelStatus.isEmpty) {
                HStack(spacing: 10) { if studio.reelBusy { ProgressView().controlSize(.small) }; Text(studio.reelStatus).font(.caption) }
                    .padding(.horizontal, 20).padding(.bottom, 10).accessibilityElement(children: .combine)
            }
            if let error = studio.storageError { Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal) }
            if cards.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        RecallArtwork(style: 16).frame(height: 110).clipped()
                        Text(savedOnly ? "Ideas worth\ncoming back to." : "Small ideas.\nReal capability.").font(.system(size: 38, design: .serif))
                        Text(savedOnly ? "Bookmark a concept in Discover to keep its explanation and sources for later." : "Tools. Memory. Models. Systems. A fresh collection of 24 useful concepts, researched and checked against their sources.").font(.system(size: 18))
                        if !savedOnly {
                            Text("One minute to get the idea. Learn more to make it yours.").font(.system(size: 19, design: .serif))
                            Button(studio.reelBusy ? "Preparing your edition…" : "Prepare my daily learning") { prepare() }.buttonStyle(DarkButton()).disabled(studio.reelBusy)
                            Text("Uses your connected OpenAI account. Preparation takes several minutes; completed sections survive interruption.").font(.caption)
                        }
                    }.padding(28).foregroundStyle(ink).frame(maxWidth: 650, alignment: .leading).background(lilac, in: RoundedRectangle(cornerRadius: 30)).padding(12)
                }
            } else {
                GeometryReader { geometry in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                                ConceptFace(card: card, index: index,
                                    saved: studio.vault.saved.contains { $0.id == card.id },
                                    bookmark: { studio.toggleSaved(card) },
                                    learnMore: { detail = card },
                                    openSource: { link in if let url = URL(string: link.url) { reader = ReaderTarget(url: url) } })
                                    .frame(maxWidth: 760).frame(maxWidth: .infinity)
                                    .frame(height: max(0, geometry.size.height - 12))
                                    .background(RecallPalette.color(index), in: RoundedRectangle(cornerRadius: 30))
                                    .clipShape(RoundedRectangle(cornerRadius: 30))
                                    .scrollTransition(.interactive, axis: .vertical) { [reduceMotion] view, phase in view.scaleEffect(reduceMotion ? 1 : phase.isIdentity ? 1 : 0.97) }
                                    .padding(.horizontal, 12).padding(.bottom, 12).id(card.id)
                            }
                            VStack(spacing: 22) {
                                Image(systemName: "leaf.fill").font(.system(size: 55)).foregroundStyle(sage)
                                Text("Let it settle.").font(.system(size: 38, design: .serif))
                                Text(savedOnly ? "That's your saved collection. Return to any idea whenever you want." : "You've reached the end of this edition. Try one idea at work, or turn a keeper into a recall card. New ideas tomorrow.")
                                    .multilineTextAlignment(.center).foregroundStyle(muted)
                                Button("Back to the first idea") { withAnimation(reduceMotion ? nil : .smooth) { focused = cards.first?.id } }.buttonStyle(AccentButton())
                            }.padding(36).frame(maxWidth: .infinity).frame(height: geometry.size.height)
                        }.scrollTargetLayout()
                    }.scrollTargetBehavior(.paging).scrollPosition(id: $focused).scrollIndicators(.hidden)
                }
                if !studio.reelBusy, !studio.reelStatus.isEmpty, let date = studio.vault.edition?.date, !Calendar.current.isDateInToday(date), !savedOnly {
                    HStack { Text(studio.reelStatus).font(.caption).lineLimit(2); Button("Retry") { prepare() } }.padding(.horizontal, 16).padding(.bottom, 8)
                }
            }
        }
        .onChange(of: focused) { _, id in if let id { studio.markSeen(id) } }
        .onChange(of: savedOnly) { _, _ in focused = nil }
        #if os(iOS)
        .sensoryFeedback(.selection, trigger: focused)
        #endif
        .sheet(item: $detail) { card in ConceptDetail(card: card) }
        .sheet(item: $seed) { CardComposer(seed: $0) }
        .sheet(item: $reader) { target in ReaderView(url: target.url) { _ in } }
    }
    private var editionLabel: String {
        guard let edition = studio.vault.edition else { return "YOUR NEXT DISCOVERY" }
        return Calendar.current.isDateInToday(edition.date) ? "TODAY · SIX AREAS OF ENGINEERING" : "SAVED EDITION · \(edition.date.formatted(date: .abbreviated, time: .omitted))"
    }
}

private struct ConceptFace: View {
    let card: ConceptReel
    let index: Int
    let saved: Bool
    let bookmark: () -> Void
    let learnMore: () -> Void
    let openSource: (LearningLink) -> Void
    @State private var active = false
    @State private var revealed = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var shortExample: String {
        let words = card.example.split(whereSeparator: \.isWhitespace)
        return words.count <= 25 ? card.example : words.prefix(25).joined(separator: " ") + "…"
    }
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 680 || typeSize.isAccessibilitySize
            VStack(alignment: .leading, spacing: compact ? 12 : 18) {
                HStack(alignment: .top) {
                    Text(card.topic.uppercased()).font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1)
                    Spacer()
                    Button(action: bookmark) { Image(systemName: saved ? "bookmark.fill" : "bookmark").font(.title3).frame(width: 32, height: 32) }.accessibilityLabel(saved ? "Remove saved concept" : "Save concept")
                }
                if !compact { RecallArtwork(style: index * 17).frame(height: 45).clipped() }
                Text(card.title).font(.system(size: compact ? 27 : 34, weight: .medium, design: .serif)).fixedSize(horizontal: false, vertical: true)
                Text(active ? card.question : card.idea).font(.system(size: compact ? 18 : 21)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                if active {
                    if revealed { Text(card.answer).font(.system(size: 17)).lineLimit(5) }
                    else { Button("Reveal the idea") { revealed = true }.buttonStyle(DarkButton()) }
                } else if geometry.size.height > 540 && !typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("IN PRACTICE").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1)
                        Text(shortExample).font(.system(size: compact ? 15 : 16)).fixedSize(horizontal: false, vertical: true)
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 18))
                }
                Spacer(minLength: 0)
                if let source = card.sources.first { Button { openSource(source) } label: { Label(source.title, systemImage: "link").font(.caption).lineLimit(1) }.accessibilityLabel("Source: \(source.title)") }
                HStack {
                    Button("Learn more ↗", action: learnMore).buttonStyle(DarkButton())
                    Spacer()
                    Button(active ? "Back to idea" : "Try recalling") { active.toggle(); revealed = false }.font(.system(size: 13, weight: .medium))
                }
                Text("Swipe for a new idea ↑").font(.system(size: 11)).frame(maxWidth: .infinity).opacity(0.6)
            }.padding(compact ? 20 : 26).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }.foregroundStyle(ink).buttonStyle(.plain)
    }
}

private struct ConceptDetail: View {
    let card: ConceptReel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var studio: LearningStudio
    @State private var reader: ReaderTarget?
    @State private var seed: CardSeed?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Text(card.topic.uppercased()).font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text(card.title).font(.system(size: 35, design: .serif))
                    Text(card.idea).font(.title3)
                    section("How it works", card.detail)
                    section("Make it concrete", card.example)
                    section("The catch", card.pitfall)
                    section("Try this question", card.question)
                    DisclosureGroup("Reveal answer") { Text(card.answer).padding(.top, 8) }
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Sources & deeper reading").font(.headline)
                        ForEach(card.sources) { link in Button { if let url = URL(string: link.url) { reader = ReaderTarget(url: url) } } label: {
                            VStack(alignment: .leading, spacing: 4) { Text(link.title + " ↗"); Text(URL(string: link.url)?.host ?? link.url).font(.caption).foregroundStyle(.secondary) }
                        } }
                    }
                    Text("AI-written, source-backed explanation. Examples can be illustrative; check the linked docs before using an API.").font(.caption).foregroundStyle(.secondary)
                    Button("Make a recall card ✦") { seed = CardSeed(text: "\(card.question)\n\(card.answer)\n\(card.idea)\n\(card.example)", source: card.sources.first?.url ?? "") }.buttonStyle(AccentButton())
                }.textSelection(.enabled).padding(25).frame(maxWidth: 700, alignment: .leading).frame(maxWidth: .infinity)
            }.navigationTitle("A little deeper")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }; ToolbarItem(placement: .primaryAction) { Button { studio.toggleSaved(card) } label: { Image(systemName: studio.vault.saved.contains { $0.id == card.id } ? "bookmark.fill" : "bookmark") }.accessibilityLabel("Save concept") } }
        }.sheet(item: $reader) { ReaderView(url: $0.url) { _ in } }
            .sheet(item: $seed) { CardComposer(seed: $0) }
        #if os(macOS)
            .frame(width: 680, height: 800)
        #endif
    }
    private func section(_ title: String, _ text: String) -> some View { VStack(alignment: .leading, spacing: 10) { Text(title).font(.headline); Text(text).font(.system(size: 18)).lineSpacing(5) } }
}

struct TopicSeriesLibrary: View {
    @EnvironmentObject private var studio: LearningStudio
    @Environment(\.dismiss) private var dismiss
    @State private var topic = ""
    @State private var budget = 45
    @State private var onlyBookmarks = false
    @State private var selected: UUID?
    @State private var task: Task<Void, Never>?
    @State private var now = Date()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { Text("Follow your\nquestion.").font(.system(size: 38, design: .serif)); Spacer(); Image(systemName: "questionmark").font(.system(size: 65, weight: .light, design: .serif)).foregroundStyle(coral) }
                    Text("A short path from a first mental model to the details that matter.").font(.title3).foregroundStyle(.secondary)
                    TextField("What do you want to understand?", text: $topic, axis: .vertical).lineLimit(2...5).font(.title3).textFieldStyle(.plain).padding(20).foregroundStyle(ink).background(lime, in: RoundedRectangle(cornerRadius: 20)).environment(\.colorScheme, .light)
                    ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(["Toolsets & capabilities", "How KV caching works", "Agent memory", "Hybrid retrieval"], id: \.self) { example in Button(example) { topic = example }.buttonStyle(.bordered) } } }
                    Picker("Total reading budget", selection: $budget) { ForEach([30, 45, 60, 90], id: \.self) { Text("\($0) min total").tag($0) } }
                    Text("INTRO → INTERMEDIATE → DEEP").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(.secondary)
                    Button {
                        task = Task { if let id = await studio.createSeries(topic: topic, budget: budget) { selected = id } }
                    } label: { HStack { if studio.seriesBusy { ProgressView() }; Text(studio.seriesBusy ? "Building your path…" : "Find my learning series"); Spacer(); Image(systemName: "arrow.up.right") } }.buttonStyle(AccentButton()).disabled(studio.seriesBusy || topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if studio.seriesBusy { Button("Cancel research") { task?.cancel() } }
                    if !studio.seriesStatus.isEmpty { Text(studio.seriesStatus).font(.callout).foregroundStyle(.secondary) }
                    Text("Every series expires after 48 hours, including bookmarks. Uses your connected OpenAI account to research and check three articles.").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    HStack { Text("Your learning paths").font(.system(size: 26, design: .serif)); Spacer(); Toggle("Bookmarked", isOn: $onlyBookmarks).toggleStyle(.switch).fixedSize() }
                    let series = studio.vault.series.filter { $0.isActive(at: now) && (!onlyBookmarks || $0.bookmarked) }
                    if series.isEmpty { Text(onlyBookmarks ? "No active bookmarks. Save a series to return during its 48-hour window." : "Your active series will appear here. Expired series disappear automatically.").foregroundStyle(.secondary) }
                    ForEach(series) { item in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Button { selected = item.id } label: { Text(item.topic).font(.title3).multilineTextAlignment(.leading) }.buttonStyle(.plain); Spacer(); Button { studio.bookmark(item.id) } label: { Image(systemName: item.bookmarked ? "bookmark.fill" : "bookmark") }.accessibilityLabel(item.bookmarked ? "Remove bookmark" : "Bookmark series") }
                            Text("\(item.steps.filter(\.completed).count)/3 explored · \(item.steps.reduce(0) { $0 + $1.minutes }) min").font(.caption)
                            Text("Expires \(item.expires.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(panel, in: RoundedRectangle(cornerRadius: 22))
                    }
                    if let error = studio.storageError { Text(error).foregroundStyle(.red) }
                }.padding(24).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
            }.background(canvas).navigationTitle("Learning series")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .navigationDestination(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) { if let selected { SeriesDetail(id: selected) } }
        }.tint(accent)
        .onAppear { studio.expire(); now = Date() }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { now = $0; studio.expire(at: $0) }
        .onDisappear { task?.cancel() }
        #if os(macOS)
        .frame(width: 760, height: 850)
        #endif
    }
}

private struct SeriesDetail: View {
    let id: UUID
    @EnvironmentObject private var studio: LearningStudio
    @State private var reader: ReaderTarget?
    @State private var now = Date()
    var body: some View {
        Group {
            if let series = studio.vault.series.first(where: { $0.id == id && $0.isActive(at: now) }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        Text(series.topic).font(.system(size: 36, design: .serif))
                        Text(series.overview).font(.title3)
                        HStack { Label("\(max(0, Int(ceil(series.expires.timeIntervalSince(now) / 3600))))h remaining", systemImage: "hourglass"); Spacer(); Button { studio.bookmark(id) } label: { Label(series.bookmarked ? "Bookmarked" : "Bookmark", systemImage: series.bookmarked ? "bookmark.fill" : "bookmark") } }.font(.callout)
                        Text("Expires \(series.expires.formatted(date: .abbreviated, time: .shortened)), even if bookmarked.").font(.caption).foregroundStyle(.secondary)
                        ForEach(Array(series.steps.enumerated()), id: \.element.id) { index, step in
                            VStack(alignment: .leading, spacing: 18) {
                                HStack { Text("0\(index + 1) / \(step.level.uppercased())").font(.system(size: 12, weight: .bold, design: .monospaced)); Spacer(); Text("\(step.minutes) min").font(.caption) }
                                Text(step.title).font(.system(size: 27, design: .serif))
                                Text(step.outcome).font(.system(size: 18))
                                Text(step.bridge).font(.callout).opacity(0.75)
                                Button { if series.isActive(at: Date()), let url = URL(string: step.source.url) { reader = ReaderTarget(url: url) } } label: { Label(step.source.title, systemImage: "arrow.up.right").multilineTextAlignment(.leading) }.buttonStyle(DarkButton())
                                Button { studio.complete(id, level: step.level) } label: { Label(step.completed ? "Explored" : "Mark explored", systemImage: step.completed ? "checkmark.circle.fill" : "circle") }.buttonStyle(.plain)
                            }.padding(25).foregroundStyle(ink).frame(maxWidth: .infinity, alignment: .leading).background([coral, lilac, sage][index % 3], in: RoundedRectangle(cornerRadius: 26))
                        }
                    }.padding(24).frame(maxWidth: 700, alignment: .leading).frame(maxWidth: .infinity)
                }.background(canvas)
            } else { ContentUnavailableView("This series has expired", systemImage: "hourglass", description: Text("All series close after 48 hours. Start a new path to explore this topic again.")) }
        }.navigationTitle("Your path")
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in now = date; if studio.vault.series.first(where: { $0.id == id })?.isActive(at: date) == false { reader = nil; studio.expire(at: date) } }
        .sheet(item: $reader) { ReaderView(url: $0.url) { _ in } }
    }
}
