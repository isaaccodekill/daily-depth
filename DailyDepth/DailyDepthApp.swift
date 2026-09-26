import SwiftUI
import SwiftData

@main struct DailyDepthApp: App {
    @AppStorage("appAppearance") private var appearance = "Charcoal"
    @StateObject private var reminders = Reminders()
    @StateObject private var discovery = Discovery()
    @StateObject private var session = LearningSession()
    @StateObject private var studio = LearningStudio()
    private let persistence: Result<ModelContainer, Error> = Result {
        // Automatic enables CloudKit only when the signed build includes its entitlements.
        try ModelContainer(for: LearningEntry.self, RecallCard.self, ReadingVisit.self, configurations: ModelConfiguration(cloudKitDatabase: .automatic))
    }
    var body: some Scene {
        WindowGroup(id: "main") {
            switch persistence {
            case .success(let container):
                RootView().modelContainer(container).environmentObject(reminders).environmentObject(discovery).environmentObject(session).environmentObject(studio)
                    .preferredColorScheme(appearance == "White" ? .light : .dark)
            case .failure(let error):
                ContentUnavailableView("Your journal couldn’t open", systemImage: "externaldrive.badge.exclamationmark", description: Text("Your saved data has not been reset. \(error.localizedDescription)"))
            }
        }
        #if os(iOS)
        .backgroundTask(.appRefresh("com.isaacbello.dailydepth.curate")) {
            await discovery.refreshAutomatically()
            await studio.generateReels()
        }
        #endif
        #if os(macOS)
        .defaultSize(width: 1140, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New reflection") { reminders.openJournal = true }.keyboardShortcut("n", modifiers: .command)
            }
        }
        #endif
        #if os(macOS)
        MenuBarExtra("Daily Depth", systemImage: "book.closed") {
            MenuContent().environmentObject(reminders)
        }
        #endif
    }
}
#if os(macOS)
struct MenuContent: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var reminders: Reminders
    var body: some View {
        Button("Open Daily Depth") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
        Button("Write a reflection") { openWindow(id: "main"); reminders.openJournal = true; NSApp.activate(ignoringOtherApps: true) }
        Divider()
        Text(reminders.enabled ? "Daily reminder is on" : "Set your reminder in Ritual")
        Divider()
        Button("Quit Daily Depth") { NSApplication.shared.terminate(nil) }
    }
}
#endif
