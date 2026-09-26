# Daily Depth

A native SwiftUI learning journal for Mac and iPhone. Built for a working AI engineer: explore one source, capture the idea, examine the evidence, and develop your own view.

## Current update — September 23

Today now applies a second substance review and broader topic selection. The floating **?** creates a three-stage learning series; **every series expires after 48 hours, including bookmarks**. **Learn** offers a daily 24-card concept edition, saved concepts, and the existing personal recall cards. Generation uses the OpenAI connection configured in Ritual.

See [Learning design and verification](LEARNING_DESIGN.md) for the curriculum, source checks, resumable generation, data handling and remaining live validation. The latest build was installed on September 23; iOS blocked launch pending signing/developer-trust resolution. See [project context](PROJECT_CONTEXT.md) for details. The sections below include historical setup and changelog entries; this update supersedes older descriptions of recommendations and Learn.

## Repository

This repository contains the current native app, widget, assets, project notes, and standalone regression checks in `Tests/`. Generated builds, device backups, local databases, and Xcode user state are excluded. The earlier web prototype remains in the original development workspace.

Open `DailyDepth.xcodeproj` to work on the app. The iPhone install helper contains the original developer team/device settings and uses a sibling `../../work` build directory; adjust those settings for another machine. TestFlight preparation is documented in `TestFlight/README.md`.

## Everyday use

1. Open Daily Depth and go to **Ritual**.
2. Choose a time, press **Enable daily reminder**, and allow notifications.
3. Use **Send a test in 5 seconds** to verify delivery on that device.
4. Visit **Today** for a rotating source recommendation. **Library** contains all ten sources.
5. Tap **Reflect** to record your takeaway, source, topic, time, and confidence. Mechanism, evidence, tradeoff, and opinion are optional prompts.
6. **Growth** shows learning days, a 12-week activity grid, topic coverage, and your first/latest confidence ratings. These are self-ratings, not measured proficiency.
7. **Journal** supports searching, editing, deletion, and Markdown export.

On Mac, the menu-bar book opens the journal quickly; Command-N creates a reflection. Notification actions include a 15-minute snooze and opening a reflection. Reminders repeat daily at the device's local time, even with the app closed. Focus modes and system notification settings may silence or delay them. Configure reminders independently on each device. The app does not enable a schedule until you choose it.

## Open in Xcode

Open `DailyDepth.xcodeproj`, select the **DailyDepth** scheme, and choose **My Mac**, an iPhone simulator, or your connected iPhone. Requirements: macOS 14+ / iOS 17+; Xcode 16.2+.

There are no third-party packages, API keys, or network services required for local journaling and notifications.

## Install on an iPhone

1. In Xcode > Settings > Accounts, sign in with your Apple account.
2. In the DailyDepth target > Signing & Capabilities, select your team. Use an available bundle identifier, identical across your Mac/iPhone builds if enabling sync.
3. Connect and trust your iPhone, enable Developer Mode if requested, choose it as the destination, and Run.
4. Enable the app's daily reminder on the iPhone itself.

The included iOS app and widget use an App Group, which requires a team with that capability. Select the same signing team for both DailyDepth and DailyDepthWidgets, and configure the same available App Group identifier in both entitlement files and Session.swift. A free Personal Team may require removing the widget target and App Group functionality. A provisioned physical-device build could not be supplied without your account. The included Mac build uses local ad-hoc signing; it is not notarized for distribution.

## Optional automatic iCloud sync

The app saves to SwiftData on each device by default. Its model is CloudKit-compatible and its container uses `.automatic`, but **sync is not enabled in the default build**. Enabling it requires an Apple Developer team with the necessary capabilities.

1. Add **iCloud** to Signing & Capabilities and select **CloudKit**.
2. Create/select the same iCloud container for both platform builds (for example `iCloud.com.isaacbello.dailydepth`, subject to availability in your team).
3. Add **Background Modes > Remote notifications** for iOS. Let Xcode manage platform-specific push entitlements; do not copy a Mac push entitlement into iOS or vice versa.
4. Keep the existing sandbox/user-selected-file entitlements. `DailyDepth/iCloud.entitlements.example` documents the additional CloudKit settings but is not used for signing.
5. Run both builds with the same Apple Account and iCloud enabled. Create a test entry on one, confirm it appears on the other, then test an edit and a deletion. CloudKit sync is asynchronous.
6. For App Store/TestFlight distribution, deploy the CloudKit schema to production in CloudKit Console.

Do not assume the local build is syncing just because you are signed into iCloud. Until signed capabilities are configured and tested, use Journal's Markdown export as a readable backup. Avoid writing the same entry simultaneously on two devices during sync testing.

## Privacy and persistence

Your reflections stay in the app's local SwiftData store, or your private iCloud database in an appropriately configured build. Opening a source presents an in-app website and, where extraction works, a native reader powered by bundled Mozilla Readability (Apache 2.0; license in DailyDepth/Reader). It does not bypass paywalls. No analytics or fabricated progress data is included. A save failure preserves the editor's text; a store initialization failure shows an error without deleting or replacing the store.

## Source layout

- `Models.swift`: persisted reflections, source library, calendar calculations.
- `Reminders.swift`: permissions, repeating local notification, test, snooze, notification handling.
- `RootView.swift`: responsive Mac/iPhone views and editing/export.
- `DailyDepthApp.swift`: persistence setup, windows, and Mac menu bar.


## Personalized daily cards

In **Ritual**, enter an OpenAI API key in the secure field and save it to the device Keychain. Choose your interests, time budget and preferred format. Enable automatic discovery to search once per day when you open the app, or use the manual search button. API usage is billed to your OpenAI account; a ChatGPT subscription is separate. No key is included in the project.

Discovery uses the Responses API with web search and structured output. It returns three alternatives, each containing one resource or two short resources. Source URLs must appear in search results. Cached recommendations remain available if a request fails. With no key, the swipe deck contains explicitly labeled starter source homepages; their duration is a session budget, not a measured article length. Changing the time budget applies to subsequent searches and sessions; saved recommendations keep their original estimated duration.

Only interests, preferences, and the latest ten reflection titles/topics/confidence ratings are sent to OpenAI; reflection bodies are excluded. The key stays on each device and does not sync. Live API requests have not been tested with a personal key.

## Reader, widgets and Live Activities

The native reader offers paper/night themes, adjustable type, selectable text and code blocks, and a return to the original website. Videos and pages that cannot be extracted use the embedded website. Articles currently require a connection to load; offline article downloads and automatic reading-position recovery are not yet implemented.

Add Daily Depth from the iPhone widget gallery for small/medium Home Screen or circular/rectangular Lock Screen widgets. Widgets show the latest saved suggestion and progress, subject to system refresh scheduling. Start a learning session to request its Live Activity with countdown, Reflect and End actions. Dynamic Island appears on supported iPhones. Live Activities are session-bound and governed by iOS; they are not permanent all-day notifications. Daily reminders are scheduled separately in Ritual.

## Validation

The redesigned Mac app and iOS Simulator app plus widget extension build successfully in Xcode 16.2. Persistence checks cover create/reopen/edit/delete; parser checks cover cited responses and rejection of incomplete/refused/uncited output. Daily reminder trigger construction is verified. Physical iPhone provisioning, notification delivery, Live Activity behavior and iCloud sync still require device/account validation. The included Mac app is locally signed, not notarized.

## Experience update

Today now includes a visible AI-curator entry point. Ritual leads with OpenAI connection, interests, format, time budget and **Curate my next edition**, followed by reminder setup. A saved key is not proof of successful authentication; the first curation request verifies it. The library remains available without a key.

Reflection requires only a takeaway. A title is derived from the first 80 characters when omitted. Confidence is a quick selection; title, source, topic, opinion and deeper prompts are optional under a disclosure. Illustrations are animated SwiftUI vectors, with larger floral compositions integrated into headers and cards; Reduce Motion disables the continuous motion.

Sessions can be paused/resumed from Today or the reader. Pause persists across app relaunch, cancels the completion alert and updates the Live Activity to a frozen countdown. Resume schedules the alert for the remaining time. The simulator was used to verify start, pause, force-quit/relaunch, resume and end. Pausing/resuming from the Live Activity itself is not yet exposed; open the app to use those controls.

## Personal Team device preview

For the free Personal Team, the phone build uses `DailyDepth/PersonalPreview.entitlements` and `OTHER_SWIFT_FLAGS=-DPERSONAL_PREVIEW`. This keeps the app and session Live Activity while excluding the Home/Lock Screen progress widget that requires shared App Group storage. The full build retains that widget. Personal provisioning must include the connected device and the iPhone must have Developer Mode enabled. The preview uses local storage; iCloud sync is not enabled.

## Exact-resource and appearance update

Today no longer substitutes source homepages for daily recommendations. Until an edition is generated, it offers the curator setup/search action. General author/publication links remain in Library. OpenAI is instructed to select specific articles, papers, videos or episodes and provide a concrete learning preview. Validation rejects root homepages, common indexes, categories, YouTube channels and playlists; selected URLs must still be backed by search evidence. These URL checks do not guarantee publisher availability or bypass access restrictions. Previously cached broad links are ignored.

Ritual is divided into Learning, Reminders and Appearance. Choose White or Charcoal under Appearance; the choice persists on that device. Reader paper/night mode is separate. URL validation and parser/persistence checks pass; the white theme was visually verified in iPhone Simulator.

## Automatic curation reliability update

Automatic daily curation is enabled for this update and when saving a key. A successful edition is reused for the calendar day; failures may retry after a 15-minute cooldown. Unusable output gets at most one immediate repair search. Valid plans survive other invalid candidates, while direct-link, search-evidence, preview and time-budget checks remain enforced. URL matching ignores known tracking parameters and normalizes YouTube aliases without dropping article/video identifiers.

The app requests opportunistic iOS background refresh and also checks on opening. iOS controls background execution, so a fresh edition is not guaranteed to be ready before launch. Manual refresh is still available. Default model: gpt-5.4-mini, using the Responses API web_search tool; the same response selects resources and writes learning previews. Search is not restricted to Library examples.

Verified on the physical iPhone: the automatic run saved a new edition on 2026-09-14 at 00:55 UTC with three plans, specific resource URLs and learning previews. Background execution timing has not been verified.

## Sol and shorter sessions

Curation now defaults to gpt-5.6-sol with low reasoning effort and OpenAI web search. One-time migration selects Sol and requests a fresh edition. Previews display at most 18 words and generation requests a single short sentence. Short sessions reject PDF/arXiv/paper resources; papers require a budget and suggested duration of at least 45 minutes. The prompt requests complete-resource duration, conservative prose/code reading estimates, and actual video runtime rather than unspecified excerpts. Article estimates remain model estimates, not independently measured full-text counts.

Today uses one primary learning surface with inline curator, reflection, focus and progress controls. Curation loading uses a Canvas animation of flowing blurred colors at up to 30 frames/second and respects Reduce Motion. Link, preview length and paper-budget checks pass. Sol supports Responses, structured outputs and web search: https://developers.openai.com/api/docs/models/gpt-5.6-sol

## Integrated curation and practical learning
The loading color field now sits behind the entire scroll viewport on Today and Ritual, with feathered edges, subdued opacity for readable text, no hit testing, and Reduce Motion support. The curation prompt includes all library sources and asks Sol to search these first, then expand for gaps or contrasting evidence. It targets two applied options and one deeper perspective, with a practical first pick and concrete experiments in discussion prompts. This is model-guided selection, not a separate domain-restricted retrieval stage or a quality guarantee. Existing daily caches remain intact; the policy applies to the next curation. iOS Release and macOS Debug builds passed.

## Reader illustrations
Reader extraction now retains image blocks, captions, relative source URLs, browser-selected responsive images, common lazy-image attributes, and inline SVG diagrams converted to inert image documents before Readability cleanup. Images render in script-disabled WebKit surfaces without cropping; original dimensions determine layout where available. External images include full-size links. Interactive canvas graphics and protected media may require the original website. Fixture checks passed for image/text ordering, relative URLs, lazy loading, captions, and SVG preservation; iOS Release and macOS Debug builds passed.

## Explain selected reader text
Select a word or phrase in the native reader and choose Explain (iPhone selection menu; Mac contextual menu). A dismissible sheet requests a short contextual explanation, a practical example and up to three explanatory source links using the configured OpenAI model and web search. It sends only the selected phrase (up to 300 characters), current text block (up to 4,000 characters), and article title/URL (up to 500 characters), on explicit Explain action. Requests use the existing Keychain key, store:false, and cancel when dismissed. Resource URLs must match response search evidence and pass direct-resource validation. API usage is billed to the connected account. Build and parser fixture checks passed; live on-device explanation and selection interactions have not yet been verified.

## Reader links and formatting
Article blocks now retain styled text runs instead of flattening textContent. Native selectable text renders links, nested bold/italic, inline code, strikethrough, underline, superscript/subscript, line breaks and ordered list markers. Relative link destinations resolve against the original document URL; only http, https and mailto become clickable. Explain selection continues to use the exact displayed text. Tables retain row breaks and cell tabs, not original website styling. Extraction fixtures cover these styles, URL safety, selection text consistency and image preservation. iOS and macOS builds passed.

## Recall and reading notes — September 15
Recall is the center mobile tab. It offers a vertically snapping collection, reveal-answer interaction, due/all filters, archive/restore and editing. Sixteen readable paper colors combine with four original animated vector pattern families; the composer avoids the latest eight saved colors and offers remix/pattern controls. Reduce Motion stops artwork motion. Cards are stored in SwiftData alongside reflections. This is a simple interval scheduler (Again: 10 minutes; initial Hard/Good: 1 day; Easy: 4 days; subsequent intervals multiply by 1.3/2.2/3, capped at 365 days), not Anki/FSRS or Anki sync.
Select article text → Ankilize, use Ankilize in a reflection, or create a thought from Recall. The configured OpenAI model drafts a front, back and category from the supplied text; users can edit before saving or write manually without an API connection. Draft generation sends up to 8,000 characters to OpenAI with store:false. It does not fact-check personal thoughts.
Reader reflections now open above the article instead of dismissing it. Notes reopen the latest saved reflection for that source; unsaved fields persist locally as a draft by source or reflection ID. Done for now keeps the draft; Keep this thought commits it to Journal. Drafts are not themselves Journal entries.
Incomplete curation triggers a bounded follow-up search, merges distinct verified options and retries partial cached editions on subsequent checks. It never fabricates a third source; if still incomplete, status explains the remaining gap. Technical library additions: Pydantic, Pydantic AI, OpenAI computer use, LangGraph memory, Anthropic harness engineering.
Validated iOS Release, simulator and Mac builds; native card persistence/schedule/archive and deduplicated refill checks; reader extraction regression checks. Simulator: manual card creation, reveal/rating, due queue, draft persistence across restart. Live AI card generation and live third-option search have not been end-to-end verified.
Design reference: https://www.pinterest.com/pin/4362930876177305/ (reference only; no assets copied).

## Practical-topic correction
Removed the five technical library additions from September 15: the user intended them as topic examples, not saved publishers. Curation now explicitly searches for practical implementation articles across typed outputs, tool loops, computer agents, memory, context management, checkpointing, harnesses and related approaches. It prioritizes code, architecture, measured tradeoffs and failure analysis, preserves the existing library-first baseline and broader conceptual balance, and permits wider-web discovery. Applies on the next curation; existing daily picks remain cached. iOS and Mac builds passed; recommendation quality remains model-guided and was not live-evaluated for this prompt change.

## Full-screen Recall, reflection fixes, and History
Recall now fills the viewport above mobile tabs and pages vertically one card at a time. Controls sit in a top overlay; reviews show a brief growth reward and iOS success haptic. Cards accept a typed answer, offer an AI question variation based on the saved idea, and request feedback compared with the saved reference. Feedback is not external fact-checking; users choose the interval rating. AI requests use the existing configured model/key and store:false. Full-card and feedback sheets keep long content readable. Empty states offer capture or continued exploration.
Reflections use an item-based presentation target to bind the intended entry; initial values load once, preserving edits when returning from Ankilize. The source URL is visible/editable at the top. Reader notes reopen the existing source-linked reflection.
Library has Sources / History segments. ReadingVisit stores URLs, titles, visit counts, latest visits and explicit read status. Reader links navigate within the reader where supported; history covers in-app reader visits going forward, not external browser history or reconstructed past activity. Mark read records completion explicitly.
Today uses a native horizontally snapping scroll view with adjacent-card peeking, interactive scale/rotation and spring navigation. One resource per card; old paired caches flatten into separate cards. New curation requests and validation keep one resource per plan.
Verification: iOS/simulator/Mac builds passed; native persistence, source validation and reader extraction tests passed. Simulator verified source attachment, saving and reopening edits from reader and Journal, reading-history read status, full-height Recall layout and Today option navigation. Live AI feedback/question variation and physical-device gesture/haptic behavior remain unverified.

## Tidbits / Recall modes
The center section now has a persistent Tidbits / Recall picker. Both use nearly full-height, rounded cards with 12-point side margins and vertical paging. Tidbits presents saved card knowledge openly, with topic/question context and full-text access, without grading or changing review dates. Try recalling this switches to the same card in Recall, where question/answer and spacing controls remain. Both modes share the existing collection; this does not create a separate AI facts feed. Simulator verified rounded layouts and transition to Recall; iOS and Mac builds passed.


## Reader, curation quality, and tactile review — September 16
The reader shows publication metadata (not modification dates), a top-right percentage ring, and a direct original-site switch. Safari browser fallback is available; YouTube/Vimeo opens in website mode without text extraction. Explanation sources open a nested reader, preserving the explanation and original article. History is reachable from the top bar and records in-app reader visits, including explanation sources.
Scroll progress is isolated in a small observable ring. Modern scroll geometry produces integer percentages, and legacy geometry does not write into ReaderView state. UIKit paragraphs cache their attributed-text rendering inputs; changing font/theme/content still rebuilds them. This removes whole-article invalidation on every scroll tick.
Recall has rounded nearly full-height cards, a 60-point pull threshold with a small counter-offset that springs away, a medium 0.9-intensity impact at the threshold, and a selection tap when the next card lands. Reduce Motion disables the visual resistance effect. The stronger threshold replaces the initial subtle haptic after physical-device user feedback.
Curation requires technical learning evidence, an allowed substantive resource type, depth 4/5 and duration evidence. Search starts with the library, expands to technical practitioners, explicitly searches AI Engineer and other video educators, and makes a dedicated video pass if needed. Runtime/reading estimates must come from the original publisher or observed content, not aggregator badges. Recency guidance aims for two recent resources (90 days, widening to 180) and an optional still-relevant foundational piece, rejecting obsolete implementation advice. This is model-guided selection, not a guarantee of factual quality. Cache version 4 requests one refreshed edition under these criteria, then resumes daily caching.
Verification: simulator rendered publication date and 0→100 progress on a real article; navigated a fixture explanation into a real source article; opened the original site and Safari fallback; displayed both articles in History; opened and played a real AI Engineer YouTube talk. The explanation navigation fixture is DEBUG-only and requires the explicit --test-explanation launch argument; it makes no AI request. Reader extraction fixtures, card/history persistence, review intervals and quality validation checks pass. Live earlier quality edition contained two substantive technical articles and one AI Engineer video (16:46 independently verified against YouTube). Updated recency edition and the revised physical feel/performance still require live confirmation.


### Live verification completed
The September16 controlled refresh saved cache version4 on the phone with three resources dated July1, July2 and August3 2026. Original pages were inspected: Cloudflare's Kimi/GLM serving report contains measured quantization tradeoffs; Doris Xin's reliability article describes concrete agent failures and supervision/memory corrections; Hamel's inference-latency note explains request shapes and links a timing notebook. All fit the current25-minute budget. This run honestly reports no new qualifying video; an earlier live run selected a verified16:46 AI Engineer video, whose playback was tested. The user confirmed the optimized scrolling and stronger Recall feel are much better.
Curation status now survives launches; an interrupted prior search is labeled. DEBUG and PERSONAL_PREVIEW builds accept --refresh-edition to exercise the manual-refresh path once on launch; it never extracts a Keychain secret. Video format is passed from recommendation cards so other video hosts also open in original-site mode.
