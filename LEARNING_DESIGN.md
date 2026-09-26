# September 23 learning update

## What changed

Today now favors substantive engineering articles across different topics and publishers. An independent model editorial pass inspects candidate sources, rejects promotional or thin content, checks complete reading time, and identifies the primary topic. Code enforces distinct primary topics and publishers with at most one eval recommendation. Article bodies must have at least 600 words; documentation needs 250 words and two concrete mechanisms. These thresholds apply to reading recommendations, not to compact concept cards. A failed refresh preserves the previous edition.

The floating question-mark button opens learning series. Enter a topic and choose a total reading budget of 30, 45, 60 or 90 minutes. Research produces three different source articles in Intro → Intermediate → Deep order, with outcomes, connections between stages, and progress tracking. A second editorial pass checks the sources and their combined reading time before saving. Every series expires exactly 48 hours after successful creation, including bookmarked series. Reading or bookmarking does not extend the deadline. Expired content is hidden and removed when the app runs; physical cleanup cannot occur while the app is suspended.

Learn now contains Discover, Saved and My recall. My recall retains the existing personal cards and spaced review. Discover is a finite daily edition of 24 concept cards, four from each area:

- Tools and contracts: typed tools, toolsets, capabilities, structured outputs and MCP.
- Agents and orchestration: state, durable execution, checkpoints, handoffs and bounded loops.
- Retrieval and memory: embeddings, search, reranking, context and memory lifecycles.
- Models and inference: attention, tokenization, batching, quantization and adaptation.
- Systems and safety: streaming, observability, retries, security, cost and deployment.
- Foundations and modalities: mathematics, representations, vision and audio.

Each card includes an explanation, concrete example, limitation, deeper lesson, recall question/answer, and clickable sources. The small card previews the example; Learn more contains the full explanation. Save retains a concept beyond its daily edition. Try recall introduces active retrieval without making reading mandatory. The edition interleaves the six areas, tracks seen cards, and ends after 24 instead of scrolling indefinitely. Recent concept titles are supplied to later generation to discourage repetition.

## Research and reliability

Each daily batch uses a research call followed by an independent source review: twelve calls for a complete edition, plus the existing article curation flow. Search targets official documentation from major frameworks and tools, with accessible Wikipedia, Brilliant and other educational references for fundamentals. Gated lessons are not treated as available evidence. The curriculum rotates tools over time; it cannot cover every tool every day.

Each four-card batch needs two source hosts, adequate explanation lengths, unique titles and source URLs present in search evidence. The editorial pass must approve every card and support its original citations. Only complete reviewed batches are checkpointed. Failure preserves completed sections and the previous published edition; manual retry resumes the unfinished sections. A complete edition is reused for the rest of the local calendar day. Automatic retries wait at least 15 minutes; manual retries bypass that delay. The UI can pause generation.

Generation runs on-device through the configured OpenAI connection when the app is active or iOS grants background time. It is not a server scheduler and cannot guarantee a new edition while the app remains closed. Generation may take several minutes and adds API/web-search usage. Ritual's automatic preparation setting controls automatic generation; manual preparation remains available.

The prompts and second review improve selection but do not prove factual correctness, semantic diversity, word counts or promotional intent. URL matching proves the URL occurred in search evidence. Live output quality still needs inspection with the user's API connection; offline fixtures verify application behavior, not model performance.

## Data and compatibility

Journal entries, recall cards and reading history retain their existing SwiftData schema. Generated concepts, saved concepts, learning series and resumable batches use a separate versioned, atomically written `Application Support/DailyDepth/learning-v1.json`. Unreadable storage is preserved rather than reset. No API key is bundled. Research uses `store: false`; topic research sends the entered topic and budget, while concept research sends configured interests and recent concept titles. Editorial checks send candidate content and source links.

## Verification

Passed local pipeline fixtures for interrupted generation/resume, source-review rejection, once-per-day reuse, all 24 cards, complete series creation, independently audited total duration, progress persistence and strict 48-hour bookmarked expiry. Validation fixtures cover corrupt-file preservation, source-evidence matching, thin/promotional content rejection and topic diversity.

Existing journal persistence, recall/history, recommendation validation, explanation citation and reader extraction regression checks were rerun. Mac Debug and iOS Release builds include the new files; simulator UI checks covered the floating button, series detail/progress, card saving, deeper lessons and opening a real Pydantic documentation source. UI content was explicitly test fixtures.

Phone installation is deferred at the user's request. No phone data backup or live new-generation quality check is claimed. TestFlight work remains separate.
