# Daily Depth — project context and decisions

Consolidated September 23, 2026 from the current Swift source, project configuration, README, validation fixtures, September 16 audit, and all pages of the original task history: **Explain DeepSeek releases and Edge-Z** (`01a09cfc-e2c7-7a01-aa2d-f2d3f694cc65`). This is a handoff snapshot, not a fresh runtime certification. No app code was changed during this review.

## Purpose

Isaac already works as an AI engineer. He wants broader technical understanding, useful knowledge for work, stronger opinions grounded in evidence, and more confidence discussing AI. The app should make learning inviting during a tram commute, coffee break, or other free moment, and make accumulated understanding tangible.

The loop is: **discover → read/watch → reflect → retain → revisit**. Daily reminders and session timers support it; progress reflects actual saved activity. The experience should be enjoyable enough to return to voluntarily.

## Decisions and their reasons

| Area | Current decision | Reason from the conversation |
| --- | --- | --- |
| Platform | Native SwiftUI on iPhone and Mac | Explicit request for native notifications and Apple platform integration. |
| Daily edition | Up to three alternatives; exactly one resource per card | Original paired short resources were later rejected as confusing. Old paired caches flatten into individual cards. |
| Links | Exact article, video, paper or episode; general source links stay in Library | Homepage recommendations were not actionable. Today no longer fills an empty edition with homepages. |
| Curation cadence | Automatically check on launch/foreground and opportunistic background refresh; reuse a complete edition for the local calendar day | User wants to open the app and find useful choices without pressing a daily button. Manual refresh remains available. |
| Curation model | Code defaults to `gpt-5.6-sol`, low reasoning effort, Responses API web search | User explicitly requested Sol after dissatisfaction with earlier results. Model remains editable in Ritual. |
| Source strategy | Library first, then wider web for stronger fits, gaps and contrasting evidence | Preserve a trusted baseline without restricting discovery to a whitelist. This ordering is prompt-guided. |
| Subject matter | Practical implementation plus deeper perspective; aim for two applied choices and one conceptual choice | Knowledge should transfer to work, with code, architecture, failure analysis and measured tradeoffs. |
| Topic examples | Pydantic, memory, harnesses and computer use are examples of interests | User explicitly corrected an earlier implementation that added these as Library sources. Those additions were removed. |
| Quality | Substantive technical resources; reject shallow announcements/promos | User found earlier suggestions weak or strange. Short sessions narrow the concept rather than lower the depth bar. |
| Time | Fit the complete resource; no pretending a long paper fits by reading an unspecified excerpt | User objected to a 20-page paper in a 20-minute session. Papers/PDFs require at least a 45-minute budget and estimate. |
| Recency | Aim for two resources within 90 days, widen to 180 if necessary, allow a relevant foundational third | AI engineering changes quickly; avoid obsolete implementation advice without chasing novelty alone. |
| Video | Deliberately search technical video educators, including AI Engineer; report when no qualifying video fits | Video discovery should work, but a weak or overlong video should not be forced into an edition. |
| Previews | One concrete sentence, displayed at no more than 18 words | Earlier previews were too long. Detailed rationale sits behind disclosure. |
| Reflection | Only the takeaway is required; title derives from it if blank; deeper prompts are optional | The original modal felt boring and burdensome for daily use. |
| Reading notes | Keep the article open beneath the editor; reopen its latest saved note; preserve unfinished drafts | User wanted continuous reading/thinking and reliable editing with the source attached. |
| Retention | Shared saved-card collection with Tidbits and Recall modes | Tidbits exposes the idea without grading; Recall tests it. There is no separate generated-facts feed. |
| Recall interaction | Nearly full-height rounded cards, vertical paging, typed answers, optional AI variations/feedback, brief rewards | User asked for a Reels-like flow while retaining the card shape and margins. |
| Design | Editorial serif type, charcoal or white, coral/lilac/sage/cream, bold native vector artwork | Selected warm editorial and expressive floral references, with fluidity from a utility reference. |
| Motion | Page-integrated liquid color field, connected card motion, tactile Recall threshold/landing feedback | Boxed loading animation and weak haptics were explicitly revised. Reduce Motion is respected. |
| Progress | Reflection days, counts, topics, streak and self-rated confidence | Track growth without presenting self-ratings as measured proficiency. |

## Implementation map

The actual app is this `outputs/DailyDepth` directory. The enclosing `ex` folder contains a web starter scaffold, build products, test fixtures and historical generation scripts. Its `app/` and npm configuration are not the native app. The directory is not currently in a Git repository.

| File | Responsibility |
| --- | --- |
| `DailyDepth/DailyDepthApp.swift` | App entry, SwiftData container, shared observable services, background refresh, Mac window/menu bar. |
| `DailyDepth/Models.swift` | `LearningEntry`, `RecallCard`, `ReadingVisit`, ten curated Library sources, growth calculations and review intervals. |
| `DailyDepth/RootView.swift` | Adaptive navigation; Today, Journal, Growth, Library/History, Ritual; reflection editor; Recall/Tidbits/composer; theme and artwork. |
| `DailyDepth/Discovery.swift` | Device Keychain access, recommendation cache/migrations, curation requests/validation/retries, explanations, card drafting and recall feedback. |
| `DailyDepth/ReaderView.swift` | WebKit loading, bundled Readability extraction, native text/images, selection actions, nested explanation sources, notes, history, progress and browser fallback. |
| `DailyDepth/Session.swift` | Persistent timer state, pause/resume, completion alerts, Live Activity attributes/intents and widget data bridge. |
| `DailyDepth/Reminders.swift` | Notification authorization, recurring local reminder, test alert, snooze and reflection action. |
| `DailyDepthWidgets/DailyDepthWidgets.swift` | Home/Lock Screen widgets and session Live Activity/Dynamic Island. |
| `DailyDepth.xcodeproj` | App and widget targets, iOS 17/macOS 14 minimums, signing and resource inclusion. |

Mobile tabs are Today, Journal, Recall, Library and Ritual; Growth is reached from Today. Wide layouts have a sidebar with all six sections.

## State and data flow

- SwiftData stores reflections, recall cards and reading visits. Initialization failure shows an error instead of resetting the store. Explicit saves generally roll back model mutations on failure while retaining editor text.
- UserDefaults/AppStorage stores preferences, curation status, migration flags and reflection drafts. Draft keys use source URL or existing reflection ID; drafts are distinct from committed Journal entries.
- The recommendation edition is an atomically written JSON file at the app container's `Application Support/DailyDepth/recommendation.json`. Cache version 5 denotes the latest breadth/substance policy, including a separate editorial review. A failed search preserves the prior edition.
- Session dates and paused remaining time persist in the widget bridge defaults. Full iOS builds use an App Group; Personal Preview uses ordinary defaults. Pause cancels the completion alert; resume reschedules it and updates the Live Activity.
- Reminders are per-device local schedules. Background curation is opportunistic, not a server job or a guaranteed morning delivery.
- CloudKit-compatible models and `.automatic` configuration are present, but the current signed entitlements do not enable iCloud sync. Local storage is the operative baseline.
- The OpenAI key uses device-only Keychain accessibility after first unlock. No key is bundled or synced.

## AI boundaries and validation

Curation sends interests, format, budget, the last ten reflection titles/topics/confidence ratings, and previous recommendation URLs. It excludes reflection bodies. Explain sends a selected phrase (up to 300 characters), its text block (4,000), and article metadata (500). Ankilize sends up to 8,000 characters of supplied material. Recall feedback sends the question/reference and up to 4,000 characters of the learner answer. Requests use `store: false`.

Curation checks completed output, search evidence, canonical URL matching, direct-resource URL heuristics, nonempty titles/previews, numerical duration budget, paper restrictions, allowed resource types, depth 4–5, and evidence fields. It keeps valid candidates when others fail and deduplicates canonical URLs. There is at most one repair request, one refill request, and one dedicated video request after the initial request. Automatic failures/partial editions can retry after 15 minutes; forced manual refresh bypasses the daily/cooldown checks.

These checks do not independently prove that an article has the claimed depth, word count, publication date, factual accuracy or relevance. Those judgments remain model-guided; evidence-field presence is not independent verification. URL evidence matching proves a URL occurred in the response's search evidence, not that every explanation claim is supported.

Card drafting/variation and recall feedback do not perform web fact-checking. The learner edits before saving and chooses the spaced-review rating. The scheduler is custom and simple: Again = 10 minutes, initial Hard/Good = 1 day, Easy = 4 days; subsequent multipliers 1.3/2.2/3 with a 365-day cap. It is not Anki integration or FSRS.

## Reader choices worth preserving

Readability extracts ordered blocks and styled runs, including images, captions, lazy/responsive images and SVG diagrams. Images render in script-disabled WebKit documents. Native text supports formatting, selectable text, links, Explain and Ankilize. Video recommendations open the original site. Unsupported extraction falls back to the website, with a separate browser option.

Explanation sources open a nested reader so the original article and explanation remain available. Reading history tracks in-app visits going forward; explicit Mark read records completion. It does not reconstruct old activity or external browser history.

The September 16 scroll fix isolated percentage observation to a small ring and cached UIKit attributed-text rendering inputs. Avoid making the full article depend on scroll-position state again. The user confirmed smoother scrolling and stronger Recall haptics were “much better.”

## Verification history and remaining work

Prior records report successful Mac, iOS Release and simulator builds; SwiftData persistence/edit/delete, recall intervals/archive, history, recommendation parsing/refill, URL validation and reader extraction checks. Fixtures are in the enclosing `work/` directory, including `NativeChecks.swift`, `RecallChecks.swift`, `QualityChecks.swift`, `ExplanationChecks.swift` and `reader-check/check.cjs`. The older `test_growth.swift` duplicates growth logic rather than directly testing the production type.

September 16 records include live phone curation, independent inspection of three recent articles, a separately verified AI Engineer video/playback, simulator reader navigation/progress/history checks, and user confirmation of scrolling/haptics. These are historical results, not tests rerun for this review. Live AI card generation, question variation/feedback and full explanation interaction do not have the same recorded end-to-end verification. Background execution timing and older-OS geometry fallback remain unverified.

Offline article downloads and reading-position restoration are not implemented. Live Activity pause/resume controls require opening the app. Markdown export covers Journal reflections, not a complete backup/import of cards, history, drafts and preferences.

The README is an accumulated changelog: earlier statements about starter homepage cards, two-resource plans, GPT-5.4 mini, untested live curation and technical Library additions are superseded by later entries and current code.

Maintenance observations from source review: substantial UI and network logic is concentrated in two large files; some obsolete state/callbacks and paired-card copy remain. Reader time uses extracted words / 220, whereas curation requests more conservative estimates, so displayed times can differ. Some format and quality constraints are prompt-only. These are observations for future work, not changes made or newly reproduced bug reports.

## Latest distribution decision

The last user request in the original task was to move to TestFlight after the free Personal Team phone install became unavailable. The prior task inspected its provisioning profile and recorded expiry on September 21 at 02:31 Oslo time.

September 22 preparation added `TestFlight/ExportOptions.plist`, an archive script and distribution notes. No TestFlight upload or invitation was completed. The last recorded blockers were a free Personal Team and an outdated macOS/Xcode toolchain. Account/toolchain state and Apple's current requirements must be rechecked when resuming distribution work.

Preserve `com.isaacbello.dailydepth`, the associated extension identity and existing local app data. The distribution notes call for a phone-container backup before the first TestFlight installation; that backup was not taken during preparation because the phone was unavailable. Full distribution should use standard App Group entitlements, not the Personal Preview override. Privacy manifest/API audit, disclosures, signing, archive validation and upload remain outstanding.

## September 23 implemented direction

The user requested broader substantive recommendations, topic-to-article learning paths, and daily AI engineering concept reels. These are implemented in `EditorialPolicy.swift`, `LearningContent.swift` and `LearningViews.swift`; see `LEARNING_DESIGN.md` for the complete policy and verification record. Today has a floating question-mark entry point. Learn now separates generated Discover/Saved concepts from the existing My recall workflow. The daily edition has 24 cards across six engineering areas and uses checkpointed research plus source review.

Explicit user decision: **every learning series expires 48 hours after creation, including bookmarked series**. Saving a concept card is a different feature and retains that card beyond the day. Generated learning data is separate from the original SwiftData journal/recall/history schema.

The user explicitly deferred phone installation: finish the updates locally. Attempts to read the connected phone's container timed out; no successful phone backup or installation occurred. Local fixture and build checks are not live AI quality verification. Preserve this distinction when resuming installation and content QA.

### Phone installation follow-up

The user subsequently connected the phone and explicitly requested installation. On September 23, the latest signed Personal Preview build installed successfully in place on Isaac's iPhone 16 Plus. Container backup timed out again, so no successful phone backup is claimed. Launch was denied by iOS with a signing/entitlements/developer-trust security error. Local signature verification passed, entitlements match the profile, the phone is provisioned, and the profile expires September 29 at 23:04 UTC. The remaining likely step is explicit developer trust on the phone. No successful app launch or live content QA is claimed.
