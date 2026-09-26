import SwiftUI
import WebKit
import SwiftData
#if os(iOS)
import SafariServices
#endif

struct ReaderTarget: Identifiable { let id = UUID(); let url: URL; var video = false }
private func isVideoPage(_ url: URL) -> Bool {
    let host=(url.host ?? "").lowercased()
    return host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com") || host == "vimeo.com" || host.hasSuffix(".vimeo.com")
}
struct ArticleBlock: Decodable { let kind: String; let text: String; let src: String?; let width: Double?; let height: Double?; let runs: [ArticleRun]?; let marker: String? }
struct ArticleRun: Decodable, Equatable { let text: String; let bold: Bool?; let italic: Bool?; let code: Bool?; let strike: Bool?; let underline: Bool?; let baseline: Int?; let link: String? }
struct ReadableArticle: Decodable { let title: String; let byline: String; let blocks: [ArticleBlock]; let words: Int; let published: String? }

@MainActor final class ArticleLoader: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    private let initialVideoURL: URL?
    @Published var article: ReadableArticle?
    @Published var loading = true
    @Published var message = "Opening the original source…"
    @Published var currentURL: URL
    init(url: URL, video: Bool = false) {
        initialVideoURL = video ? url : nil
        currentURL = url
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true
        #endif
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { loading = true; article = nil; message = "Opening the original source…" }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        currentURL = webView.url ?? currentURL
        if isVideoPage(currentURL) || initialVideoURL == currentURL { loading=false; message="Watch on the original site, or open in your browser." }
        else { extract() }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { loading = false; message = "Couldn’t load this page. Check your connection or try the original website." }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { loading = false; message = error.localizedDescription }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased()
        if navigationAction.targetFrame?.isMainFrame != false, ["http","https"].contains(scheme ?? ""), let url=navigationAction.request.url, url != currentURL { article=nil; currentURL=url }
        decisionHandler(["https", "http", "about"].contains(scheme ?? "") ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url, ["https", "http"].contains(url.scheme ?? "") { webView.load(navigationAction.request) }
        return nil
    }
    func extract() {
        guard let file = Bundle.main.url(forResource: "Readability", withExtension: "js"), let library = try? String(contentsOf: file, encoding: .utf8) else { loading = false; message = "Reader is unavailable. The original page is still here."; return }
        let extraction = #"""
        (() => {
          if (location.pathname === "/" || location.pathname === "/blog/" || location.pathname === "/blog") return null;
          let published = document.querySelector('meta[property="article:published_time"],meta[name="date"],meta[name="pubdate"],meta[itemprop="datePublished"]')?.getAttribute('content') || document.querySelector('time[itemprop="datePublished"]')?.getAttribute('datetime') || null;
          function findPublished(value) {
            if (!value || typeof value !== 'object') return null;
            if (Array.isArray(value)) { for (const v of value) { const d=findPublished(v); if(d) return d; } }
            if (typeof value.datePublished === 'string' && /Article|Posting/i.test(String(value['@type'] || ''))) return value.datePublished;
            return value['@graph'] ? findPublished(value['@graph']) : null;
          }
          if (!published) for (const node of document.querySelectorAll('script[type="application/ld+json"]')) { try { published=findPublished(JSON.parse(node.textContent)); if(published) break; } catch {} }
          const clone = document.cloneNode(true);
          // Preserve browser-selected responsive sources and lazy images before Readability cleans the DOM.
          const originals = document.querySelectorAll('img');
          clone.querySelectorAll('img').forEach((img, i) => {
            const live = originals[i];
            const candidates = [img.getAttribute('data-src'), img.getAttribute('data-original'), img.getAttribute('data-lazy-src'), live?.currentSrc, img.getAttribute('src')];
            const src = candidates.find(v => v && !v.startsWith('data:image/gif'));
            if (src) { try { img.setAttribute('src', new URL(src, document.baseURI).href); } catch {} }
            if (live?.naturalWidth) img.setAttribute('width', live.naturalWidth);
            if (live?.naturalHeight) img.setAttribute('height', live.naturalHeight);
          });
          clone.querySelectorAll('script,style,noscript,[hidden],[aria-hidden="true"]').forEach(n=>n.remove());
          // Readability drops SVG elements; preserve article diagrams as inert image sources first.
          clone.querySelectorAll('svg').forEach(svg => {
            const img = clone.createElement('img');
            svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
            img.setAttribute('src', 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(new XMLSerializer().serializeToString(svg)))));
            img.setAttribute('alt', svg.getAttribute('aria-label') || svg.querySelector('title')?.textContent || 'Article diagram');
            const bounds = (svg.getAttribute('viewBox') || '').split(/[ ,]+/).map(Number);
            img.setAttribute('width', svg.getAttribute('width') || bounds[2] || 600);
            img.setAttribute('height', svg.getAttribute('height') || bounds[3] || 400);
            svg.replaceWith(img);
          });
          const article = new Readability(clone, {maxElemsToParse: 50000}).parse();
          if (!article || article.textContent.trim().length < 350) return null;
          const dom = new DOMParser().parseFromString(article.content, 'text/html');
          const blocks = [];
          function media(node) {
            let src = node.getAttribute('src');
            if (node.tagName.toLowerCase() === 'svg') {
              src = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(new XMLSerializer().serializeToString(node))));
            }
            if (!src) return;
            try { src = new URL(src, document.baseURI).href; } catch { return; }
            if (!/^(https?:|data:image\/)/i.test(src)) return;
            const width = parseFloat(node.getAttribute('width')) || node.viewBox?.baseVal?.width || 0;
            const height = parseFloat(node.getAttribute('height')) || node.viewBox?.baseVal?.height || 0;
            if (width > 0 && height > 0 && width <= 3 && height <= 3) return;
            blocks.push({kind:'image', text:node.getAttribute('alt') || node.getAttribute('aria-label') || '', src, width, height});
          }
          function walk(node) {
            if (node.nodeType !== 1) return;
            const tag = node.tagName.toLowerCase();
            if (['script','style','iframe','form'].includes(tag)) return;
            if (['img','svg'].includes(tag)) { media(node); return; }
            if (['h1','h2','h3','h4','h5','h6','p','pre','blockquote','li','table','figcaption'].includes(tag)) {
              let runs = [];
              const marker = tag === 'li' && node.parentElement?.tagName === 'OL'
                ? String((parseInt(node.parentElement.getAttribute('start')) || 1) + Array.from(node.parentElement.children).indexOf(node)) + '.' : '•';
              function flush() {
                if (!runs.length) return;
                if (tag !== 'pre') {
                  runs[0].text = runs[0].text.trimStart();
                  runs[runs.length-1].text = runs[runs.length-1].text.trimEnd();
                }
                const text = runs.map(r => r.text).join('');
                if (text.trim()) blocks.push({kind:tag, text, runs, marker});
                runs = [];
              }
              function inline(n, style = {}) {
                if (n.nodeType === 3) {
                  const text = tag === 'pre' ? n.textContent : n.textContent.replace(/\s+/g, ' ');
                  if (text) runs.push({...style, text});
                  return;
                }
                if (n.nodeType !== 1) return;
                const t = n.tagName.toLowerCase();
                if (['script','style','iframe','form'].includes(t)) return;
                if (['img','svg'].includes(t)) { flush(); media(n); return; }
                if (['ul','ol'].includes(t)) { flush(); for (const child of n.children) walk(child); return; }
                if (t === 'br') { runs.push({...style, text:'\n'}); return; }
                const next = {...style};
                if (['b','strong'].includes(t)) next.bold = true;
                if (['i','em'].includes(t)) next.italic = true;
                if (['code','kbd','samp'].includes(t)) next.code = true;
                if (['del','s','strike'].includes(t)) next.strike = true;
                if (t === 'u') next.underline = true;
                if (t === 'sup') next.baseline = 1;
                if (t === 'sub') next.baseline = -1;
                if (t === 'a') {
                  try {
                    const url = new URL(n.getAttribute('href'), document.baseURI);
                    if (n.hasAttribute('href') && ['https:','http:','mailto:'].includes(url.protocol)) next.link = url.href;
                  } catch {}
                }
                for (const child of n.childNodes) inline(child, next);
                if (['p','div','tr'].includes(t)) runs.push({text:'\n'});
                else if (['td','th'].includes(t)) runs.push({text:'\t'});
              }
              for (const child of node.childNodes) inline(child);
              flush();
            } else for (const child of node.children) walk(child);
          }
          walk(dom.body);
          return JSON.stringify({title:article.title || document.title, byline:article.byline || '', words:article.textContent.split(/\s+/).length, published, blocks});
        })();
        """#
        webView.evaluateJavaScript(library + "\n" + extraction, in: nil, in: .defaultClient) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.loading = false
                if case .success(let value) = result, let json = value as? String, let data = json.data(using: .utf8), let article = try? JSONDecoder().decode(ReadableArticle.self, from: data), !article.blocks.isEmpty {
                    self.article = article; self.message = ""
                } else { self.message = "This page works best in its original format. You can read or watch it below." }
            }
        }
    }
}

struct ReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var loader: ArticleLoader
    @EnvironmentObject private var session: LearningSession
    @AppStorage("sessionMinutes") private var sessionMinutes = 15
    @AppStorage("readerFontSize") private var fontSize = 20.0
    @AppStorage("readerPaper") private var paper = true
    @State private var original = false
    @State private var browserSource: ReaderTarget?
    @State private var showType = false
    @State private var question: PassageQuestion?
    @State private var cardSeed: CardSeed?
    @State private var noteOpen = false
    @Environment(\.modelContext) private var context
    @Query private var readingVisits: [ReadingVisit]
    @State private var recordedURL = ""
    @State private var historyError: String?
    @State private var readerProgress = ReaderProgress()
    @Query(sort: \LearningEntry.date, order: .reverse) private var notes: [LearningEntry]
    let onReflect: (String) -> Void
    private let initialVideoURL: URL?
    private var video: Bool { isVideoPage(loader.currentURL) || initialVideoURL == loader.currentURL }
    init(url: URL, video: Bool = false, onReflect: @escaping (String) -> Void) { _loader = StateObject(wrappedValue: ArticleLoader(url: url, video:video)); self.onReflect = onReflect; self.initialVideoURL = video ? url : nil; _original=State(initialValue:video || isVideoPage(url)) }
    private var background: Color { paper ? Color(red: 0.96, green: 0.93, blue: 0.82) : Color(red: 0.055, green: 0.055, blue: 0.052) }
    private var ink: Color { paper ? Color(red: 0.13, green: 0.15, blue: 0.19) : Color(red: 0.90, green: 0.91, blue: 0.94) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 28, height: 28) }.accessibilityLabel("Close reader")
                VStack(alignment: .leading, spacing: 3) { Text(video ? "VIDEO" : "READER").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.5); Text(loader.currentURL.host ?? "Source").font(.system(size: 13)).lineLimit(1).opacity(0.65) }
                Spacer()
                if !video {
                Button { withAnimation(.smooth) { original.toggle() } } label: { Image(systemName: original ? "doc.text" : "globe").frame(width: 28, height: 28) }.accessibilityLabel(original ? "Reader view" : "Original website")
                }
                Button { openInBrowser() } label: { Image(systemName:"safari").frame(width:28,height:28) }.accessibilityLabel("Open in browser")
                if !video {
                Button { showType.toggle() } label: { Image(systemName: "textformat.size").frame(width: 28, height: 28) }.accessibilityLabel("Reading appearance")
                    .popover(isPresented: $showType) { VStack(spacing: 20) { Text("Make yourself comfortable").font(.headline); HStack { Button("A−") { fontSize = max(16, fontSize - 2) }; Text("\(Int(fontSize)) pt"); Button("A+") { fontSize = min(32, fontSize + 2) } }; Toggle("Paper theme", isOn: $paper) }.padding(24).frame(width: 270) }
                }
                if !original, loader.article != nil {
                    ReadingProgressRing(progress:readerProgress,paper:paper)
                }
            }.buttonStyle(.plain).padding(18)
            Rectangle().fill(ink.opacity(0.12)).frame(height: 1)
            ZStack {
                WebSurface(webView: loader.webView).opacity(original || loader.article == nil ? 1 : 0)
                if !original, let article = loader.article {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 23) {
                            Text("\(max(1, article.words / 220)) MIN READ").font(.system(size: 12, weight: .semibold, design: .monospaced)).tracking(2).opacity(0.55)
                            Text(article.title).font(.system(size: fontSize * 1.85, weight: .bold, design: .serif)).fixedSize(horizontal: false, vertical: true)
                            Text(publicationLabel(article.published)).font(.system(size:13)).opacity(0.65)
                            if !article.byline.isEmpty { Text(article.byline).font(.system(size: 15)).opacity(0.65) }
                            Button("View original source ↗") { original=true }.font(.system(size: 14)).tint(paper ? .indigo : .cyan)
                            Divider().padding(.vertical, 8)
                            ForEach(Array(article.blocks.enumerated()), id: \.offset) { _, block in
                                switch block.kind {
                                case "image":
                                    if let src = block.src, let url = URL(string: src) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ArticleImage(url: url, width: block.width, height: block.height)
                                                .accessibilityLabel(block.text.isEmpty ? "Article illustration" : block.text)
                                            if url.scheme != "data" { Link("Open full-size image ↗", destination: url).font(.system(size: 12)) }
                                        }
                                    }
                                case "figcaption": passage(block, size: fontSize * 0.72).opacity(0.7)
                                case "h1", "h2", "h3", "h4", "h5", "h6": passage(block, size: fontSize * 1.3, bold: true).padding(.top, 14)
                                case "pre", "table": passage(block, size: fontSize * 0.75, mono: true).padding(18).background(ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                                case "blockquote": passage(block, size: fontSize).padding(.leading, 20).overlay(alignment: .leading) { Rectangle().fill(.purple.opacity(0.6)).frame(width: 3) }
                                case "li": HStack(alignment: .top, spacing: 12) { Text(block.marker ?? "•"); passage(block, size: fontSize) }
                                default: passage(block, size: fontSize)
                                }
                            }
                            Divider().padding(.vertical, 12)
                            Text("What stayed with you?").font(.system(size: 27, weight: .semibold, design: .serif))
                            Button("Capture your takeaway") { noteOpen = true }.buttonStyle(AccentButton())
                        }.textSelection(.enabled).frame(maxWidth: 660, alignment: .leading).padding(.horizontal, 26).padding(.vertical, 42).frame(maxWidth: .infinity)
                            .modifier(LegacyArticleMeasurement())
                    }.modifier(ReaderScrollProgress(progress:readerProgress))
                        .id(loader.currentURL)
                        .background(background)
                }
                if loader.loading { VStack(spacing: 16) { ProgressView(); Text(loader.message).font(.system(size: 15)); Button("Show website now") { original = true; loader.loading = false } }.padding(28).background(background, in: RoundedRectangle(cornerRadius: 18)) }
            }
            if !loader.loading, loader.article == nil, !video { HStack { Text(loader.message).font(.system(size: 13)); Spacer(); Button("Retry reader") { loader.extract() } }.padding(14).background(ink.opacity(0.04)) }
            HStack {
                if let end = session.end {
                    Image(systemName: "timer"); Group { if session.isPaused { Text(session.pausedTime) } else { Text(timerInterval: min(session.start ?? Date(), end)...end, countsDown: true) } }.monospacedDigit().frame(width: 65)
                    Button(session.isPaused ? "Resume" : "Pause") { Task { await session.togglePause() } }
                    Button("End session") { Task { await session.finish() } }
                } else { Button { Task { await session.begin(title: loader.article?.title ?? loader.currentURL.host ?? "Learning", minutes: sessionMinutes) } } label: { Label("Start \(sessionMinutes)-minute session", systemImage: "timer") } }
                Spacer()
                Button(readingVisits.first { $0.url == loader.currentURL.absoluteString }?.finished == true ? "Read ✓" : "Mark read") { recordVisit(finished: true) }
                Button("Reflect") { noteOpen = true }.fontWeight(.semibold)
            }.font(.system(size: 14)).buttonStyle(.plain).padding(18).background(ink.opacity(0.05))
        }.foregroundStyle(ink).background(background).tint(paper ? .indigo : .cyan)
        #if os(macOS)
        .frame(minWidth: 660, idealWidth: 860, minHeight: 660, idealHeight: 900)
        #endif
        .sheet(isPresented: $noteOpen) { EntryEditor(entry: notes.first { $0.source == loader.currentURL.absoluteString }, initialSource: loader.currentURL.absoluteString) }
        #if os(iOS)
        .sheet(item:$browserSource) { target in SourceBrowser(url:target.url).ignoresSafeArea() }
        #endif
        .sheet(item: $cardSeed) { CardComposer(seed: $0) }
        .sheet(item: $question) { question in PassageExplanationView(question: question) }
        .onAppear { recordVisit() }
        .onChange(of: loader.currentURL) { _, _ in readerProgress.percent=0; recordVisit() }
        .onChange(of: loader.article?.title) { _, _ in
            recordVisit()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--test-explanation"), loader.currentURL.path.contains("/writing/product-evals") {
                question=PassageQuestion(phrase:"Evaluation harness",context:"Simulator navigation fixture",article:loader.currentURL.absoluteString)
            }
            #endif
        }
        .environment(\.openURL, OpenURLAction { url in
            guard ["http", "https"].contains(url.scheme ?? "") else { return .systemAction }
            loader.webView.load(URLRequest(url: url)); original = false; return .handled
        })
        .alert("History couldn’t save", isPresented: Binding(get: { historyError != nil }, set: { if !$0 { historyError = nil } })) { Button("OK") {} } message: { Text(historyError ?? "") }
        .onDisappear { loader.webView.stopLoading() }
    }
    private func openInBrowser() {
        #if os(iOS)
        browserSource=ReaderTarget(url:loader.currentURL)
        #else
        NSWorkspace.shared.open(loader.currentURL)
        #endif
    }
    private func publicationLabel(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "Publication date not provided by source" }
        let day=String(raw.prefix(10)); let formatter=DateFormatter(); formatter.dateFormat="yyyy-MM-dd"; formatter.locale=Locale(identifier:"en_US_POSIX")
        if let date=formatter.date(from:day) { return "Published " + date.formatted(date:.abbreviated,time:.omitted) }
        return "Published " + String(raw.prefix(60))
    }
    private func recordVisit(finished: Bool = false) {
        let url = loader.currentURL.absoluteString
        guard ["http", "https"].contains(loader.currentURL.scheme ?? "") else { return }
        let existing = readingVisits.first { $0.url == url }
        let visit = existing ?? ReadingVisit()
        if existing == nil { visit.url = url; visit.visits = 0; context.insert(visit) }
        if recordedURL != url { visit.lastVisited = Date(); visit.visits += 1; recordedURL = url }
        if let title = loader.article?.title { visit.title = title }
        else if visit.title.isEmpty { visit.title = loader.currentURL.host ?? url }
        if finished { visit.finished = true }
        do { try context.save() } catch { context.rollback(); historyError = error.localizedDescription }
    }
    private func passage(_ block: ArticleBlock, size: Double, bold: Bool = false, mono: Bool = false) -> some View {
        SelectablePassage(text: block.text, runs: block.runs, size: size, bold: bold, mono: mono, paper: paper, openLink: { url in loader.webView.load(URLRequest(url: url)); original = false }, ankilize: { selected in
            cardSeed = CardSeed(text: selected, source: loader.currentURL.absoluteString)
        }) { selected in
            question = PassageQuestion(phrase: selected, context: block.text, article: "\(loader.article?.title ?? "Article") — \(loader.currentURL.absoluteString)")
        }
    }
}
#if os(iOS)
private struct SourceBrowser: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url:url) }
    func updateUIViewController(_ controller:SFSafariViewController,context:Context) {}
}
#endif
#if os(macOS)
struct WebSurface: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#else
struct WebSurface: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif

// A script-free image document also handles SVG, animated GIF and WebP sources.
// The image uses its original aspect ratio; no crop or article scripts are imported.
private struct ArticleImage: View {
    let url: URL
    let width: Double?
    let height: Double?
    @State private var webView: WKWebView?
    var body: some View {
        GeometryReader { geometry in
            if let webView { WebSurface(webView: webView) }
        }
        .aspectRatio(ratio, contentMode: .fit)
        .task(id: url) {
            let configuration = WKWebViewConfiguration()
            configuration.defaultWebpagePreferences.allowsContentJavaScript = false
            let view = WKWebView(frame: .zero, configuration: configuration)
            #if os(iOS)
            view.isOpaque = false
            view.backgroundColor = .clear
            view.scrollView.isScrollEnabled = false
            #else
            view.setValue(false, forKey: "drawsBackground")
            #endif
            let source = url.absoluteString.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "<", with: "&lt;")
            view.loadHTMLString("<html><head><meta name='viewport' content='width=device-width, initial-scale=1'><style>html,body{margin:0;width:100%;height:100%;background:transparent}img{width:100%;height:100%;object-fit:contain}</style></head><body><img src=\"\(source)\" alt='Article illustration'></body></html>", baseURL: nil)
            webView = view
        }
    }
    private var ratio: CGFloat {
        guard let width, let height, width > 0, height > 0 else { return 1.5 }
        return CGFloat(width / height)
    }
}

private struct PassageExplanationView: View {
    @State private var sourceReader: ReaderTarget?
    let question: PassageQuestion
    @Environment(\.dismiss) private var dismiss
    @State private var answer: PassageExplanation?
    @State private var error: String?
    @State private var attempt = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("A LITTLE MORE CLARITY", systemImage: "sparkles").font(.system(size: 11, weight: .bold, design: .monospaced))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) }.buttonStyle(.plain).accessibilityLabel("Back to reading")
            }.padding(24)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(question.phrase).font(.system(size: 30, weight: .medium, design: .serif)).textSelection(.enabled)
                    if let answer {
                        Text(answer.explanation).font(.system(size: 18)).lineSpacing(6).textSelection(.enabled)
                        if !answer.example.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("IN PRACTICE").font(.system(size: 11, weight: .bold, design: .monospaced))
                                Text(answer.example).font(.system(size: 16)).lineSpacing(5).textSelection(.enabled)
                            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.purple.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
                        }
                        Text("Sources & deeper reading").font(.headline)
                        ForEach(Array(answer.sources.enumerated()), id: \.offset) { index, source in
                            if let url = URL(string: source.url) {
                                Button { sourceReader=ReaderTarget(url:url) } label: { VStack(alignment: .leading, spacing: 4) {
                                    Text("[\(index + 1)] \(source.title) ↗").font(.system(size: 15, weight: .medium))
                                    Text(url.host ?? "Source").font(.caption).foregroundStyle(.secondary)
                                } }
                            }
                        }
                        Text("AI explanation · checked against web sources").font(.caption).foregroundStyle(.secondary)
                    } else if let error {
                        Text(error).foregroundStyle(.secondary)
                        Button("Try again") { attempt += 1 }.buttonStyle(.borderedProminent)
                    } else {
                        HStack(spacing: 14) { ProgressView(); Text("Making sense of this passage…").foregroundStyle(.secondary) }.padding(.vertical, 24)
                    }
                }.padding(.horizontal, 24).padding(.bottom, 30)
            }
        }
        .background(.background)
        .sheet(item:$sourceReader) { target in ReaderView(url:target.url) { _ in }.presentationDetents([.large]) }
        .task(id: attempt) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--test-explanation") {
                answer=PassageExplanation(explanation:"Navigation test: an evaluation harness runs repeatable checks against a system.",example:"Compare two prompts against the same labeled examples.",sources:[.init(title:"Building a copilot for Obsidian",url:"https://eugeneyan.com/writing/obsidian-copilot/")])
                return
            }
            #endif
            error = nil
            do { let result = try await PassageExplainer.explain(question); try Task.checkCancellation(); answer = result }
            catch is CancellationError { }
            catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        #else
        .frame(width: 540, height: 620)
        #endif
    }
}

private struct PassageRendering: Equatable {
    let text: String
    let runs: [ArticleRun]?
    let size: Double
    let bold: Bool
    let mono: Bool
    let paper: Bool
}
#if os(iOS)
private struct SelectablePassage: UIViewRepresentable {
    let text: String
    let runs: [ArticleRun]?
    let size: Double
    let bold: Bool
    let mono: Bool
    let paper: Bool
    let openLink: (URL) -> Void
    let ankilize: (String) -> Void
    let explain: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false; view.isSelectable = true; view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero; view.textContainer.lineFragmentPadding = 0
        view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        let rendering=PassageRendering(text:text,runs:runs,size:size,bold:bold,mono:mono,paper:paper)
        guard context.coordinator.rendering != rendering else { return }
        context.coordinator.rendering=rendering
        let base = mono ? UIFont.monospacedSystemFont(ofSize: size, weight: .regular) : UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        let font = mono ? base : UIFont(descriptor: base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor, size: size)
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 8
        let color = paper ? UIColor(red: 0.13, green: 0.15, blue: 0.19, alpha: 1) : UIColor(red: 0.90, green: 0.91, blue: 0.94, alpha: 1)
        let value = readerAttributedText(text: text, runs: runs, font: font, color: color, paragraph: paragraph)
        if view.attributedText != value { view.attributedText = value }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectablePassage
        var rendering: PassageRendering?
        init(parent: SelectablePassage) { self.parent = parent }
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            if ["http", "https"].contains(URL.scheme ?? "") { parent.openLink(URL); return false }; return true
        }
        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard range.length > 0, NSMaxRange(range) <= (parent.text as NSString).length else { return UIMenu(children: suggestedActions) }
            let selected = (parent.text as NSString).substring(with: range)
            let action = UIAction(title: "Explain", image: UIImage(systemName: "sparkles")) { [weak self] _ in self?.parent.explain(String(selected.prefix(300))) }
            let remember = UIAction(title: "Ankilize", image: UIImage(systemName: "sparkles.rectangle.stack")) { [weak self] _ in self?.parent.ankilize(String(selected.prefix(8000))) }
            return UIMenu(children: [action, remember] + suggestedActions)
        }
    }
}
#else
private struct SelectablePassage: NSViewRepresentable {
    let text: String
    let runs: [ArticleRun]?
    let size: Double
    let bold: Bool
    let mono: Bool
    let paper: Bool
    let openLink: (URL) -> Void
    let ankilize: (String) -> Void
    let explain: (String) -> Void
    func makeNSView(context: Context) -> ExplainTextView {
        let view = ExplainTextView()
        view.isEditable = false; view.isSelectable = true; view.drawsBackground = false
        view.textContainerInset = .zero; view.textContainer?.lineFragmentPadding = 0
        view.isHorizontallyResizable = false; view.isVerticallyResizable = true
        view.textContainer?.widthTracksTextView = true
        return view
    }
    func updateNSView(_ view: ExplainTextView, context: Context) {
        view.openLink = openLink
        view.delegate = view
        view.explain = explain
        view.ankilize = ankilize
        let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular) : NSFont(name: bold ? "Georgia-Bold" : "Georgia", size: size) ?? NSFont.systemFont(ofSize: size)
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 8
        let color = paper ? NSColor(red: 0.13, green: 0.15, blue: 0.19, alpha: 1) : NSColor(red: 0.90, green: 0.91, blue: 0.94, alpha: 1)
        let value = readerAttributedText(text: text, runs: runs, font: font, color: color, paragraph: paragraph)
        if view.attributedString() != value { view.textStorage?.setAttributedString(value) }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ExplainTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, let container = nsView.textContainer, let manager = nsView.layoutManager else { return nil }
        container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        manager.ensureLayout(for: container)
        return CGSize(width: width, height: ceil(manager.usedRect(for: container).height))
    }
}
private final class ExplainTextView: NSTextView, NSTextViewDelegate {
    var openLink: ((URL) -> Void)?
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = (link as? URL) ?? (link as? String).flatMap(URL.init(string:)), ["http", "https"].contains(url.scheme ?? "") else { return false }
        openLink?(url); return true
    }
    var explain: ((String) -> Void)?
    var ankilize: ((String) -> Void)?
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        if selectedRange().length > 0 {
            let item = NSMenuItem(title: "Explain", action: #selector(explainSelection), keyEquivalent: "")
            item.target = self; menu.insertItem(item, at: 0)
            let remember = NSMenuItem(title: "Ankilize", action: #selector(rememberSelection), keyEquivalent: "")
            remember.target = self; menu.insertItem(remember, at: 1)
        }
        return menu
    }
    @objc private func rememberSelection() {
        let range = selectedRange()
        guard range.length > 0, NSMaxRange(range) <= (string as NSString).length else { return }
        ankilize?(String((string as NSString).substring(with: range).prefix(8000)))
    }
    @objc private func explainSelection() {
        let range = selectedRange()
        guard range.length > 0, NSMaxRange(range) <= (string as NSString).length else { return }
        explain?(String((string as NSString).substring(with: range).prefix(300)))
    }
}
#endif

#if os(iOS)
private typealias ReaderFont = UIFont
private typealias ReaderColor = UIColor
#else
private typealias ReaderFont = NSFont
private typealias ReaderColor = NSColor
#endif
private func readerAttributedText(text: String, runs: [ArticleRun]?, font: ReaderFont, color: ReaderColor, paragraph: NSParagraphStyle) -> NSAttributedString {
    let result = NSMutableAttributedString(string: "")
    guard let runs, !runs.isEmpty else { return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]) }
    for run in runs {
        var styled = font
        #if os(iOS)
        if run.code == true { styled = .monospacedSystemFont(ofSize: font.pointSize * 0.88, weight: .regular) }
        var traits = styled.fontDescriptor.symbolicTraits
        if run.bold == true { traits.insert(.traitBold) }
        if run.italic == true { traits.insert(.traitItalic) }
        if let descriptor = styled.fontDescriptor.withSymbolicTraits(traits) { styled = UIFont(descriptor: descriptor, size: styled.pointSize) }
        #else
        if run.code == true { styled = .monospacedSystemFont(ofSize: font.pointSize * 0.88, weight: .regular) }
        if run.bold == true { styled = NSFontManager.shared.convert(styled, toHaveTrait: .boldFontMask) }
        if run.italic == true { styled = NSFontManager.shared.convert(styled, toHaveTrait: .italicFontMask) }
        #endif
        var attributes: [NSAttributedString.Key: Any] = [.font: styled, .foregroundColor: color, .paragraphStyle: paragraph]
        if run.code == true { attributes[.backgroundColor] = color.withAlphaComponent(0.08) }
        if run.strike == true { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if run.underline == true { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if let baseline = run.baseline { attributes[.baselineOffset] = Double(baseline) * font.pointSize * 0.25 }
        if let link = run.link, let url = URL(string: link), ["http", "https", "mailto"].contains(url.scheme ?? "") { attributes[.link] = url; attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        result.append(NSAttributedString(string: run.text, attributes: attributes))
    }
    return result
}

private struct ArticleFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value=nextValue() }
}
private struct ReaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value=nextValue() }
}

// Only the small ring observes percentage changes. Scrolling never invalidates
// ReaderView or reconstructs every paragraph's attributed text.
@MainActor private final class ReaderProgress: ObservableObject {
    @Published var percent = 0
    var articleFrame = CGRect.zero
    var viewportHeight: CGFloat = 0
    func updateLegacy() {
        guard viewportHeight > 0, articleFrame.height > 0 else { return }
        let distance=articleFrame.height-viewportHeight
        let value=distance <= 1 ? 1 : min(1,max(0,-articleFrame.minY/distance))
        let next=Int((value*100).rounded())
        if next != percent { percent=next }
    }
}
private struct ReadingProgressRing: View {
    @ObservedObject var progress: ReaderProgress
    let paper: Bool
    var body: some View {
        ZStack {
            Circle().stroke((paper ? Color.black : .white).opacity(0.12),lineWidth:3)
            Circle().trim(from:0,to:Double(progress.percent)/100).stroke(paper ? Color.indigo : .cyan,style:StrokeStyle(lineWidth:3,lineCap:.round)).rotationEffect(.degrees(-90))
            Text("\(progress.percent)").font(.system(size:11,weight:.semibold,design:.rounded)).monospacedDigit()
        }.frame(width:34,height:34).accessibilityLabel("Reading progress").accessibilityValue("\(progress.percent) percent")
    }
}
private struct LegacyArticleMeasurement: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18,macOS 15,*) { content }
        else { content.background(GeometryReader { proxy in Color.clear.preference(key:ArticleFrameKey.self,value:proxy.frame(in:.named("articleReading"))) }) }
    }
}
private struct ReaderScrollProgress: ViewModifier {
    let progress: ReaderProgress
    func body(content: Content) -> some View {
        if #available(iOS 18, macOS 15, *) {
            content.onScrollGeometryChange(for: Int.self) { geometry in
                let total = geometry.contentSize.height - geometry.containerSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom
                guard total > 1 else { return geometry.contentSize.height > 0 ? 100 : 0 }
                return Int((min(1,max(0,(geometry.contentOffset.y + geometry.contentInsets.top)/total))*100).rounded())
            } action: { _, value in progress.percent=value }
        } else {
            content.coordinateSpace(name:"articleReading")
                .background(GeometryReader { proxy in Color.clear.preference(key:ReaderHeightKey.self,value:proxy.size.height) })
                .onPreferenceChange(ArticleFrameKey.self) { progress.articleFrame=$0; progress.updateLegacy() }
                .onPreferenceChange(ReaderHeightKey.self) { progress.viewportHeight=$0; progress.updateLegacy() }
        }
    }
}
