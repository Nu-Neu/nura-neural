## Plan: IRdecode AI Newsroom Requirements Package

Define a focused, Iran‑centric AI newsroom that aggregates articles and X/Twitter content, clusters them into narratives, and evaluates each item’s influence and plausibility so mobile users can quickly see “what’s being said” and “how close to reality” it likely is. Widgets are deferred; this phase delivers a mobile‑first daily briefing and narrative explorer for IRdecode.com, built on the existing Azure + n8n + OpenAI + Azure Search + Postgres stack.

### Steps

1. Capture Business Goals & Users (for dev kickoff)
   - Goal: One panel where diaspora and non‑Iranians see key Iran narratives (e.g., “US attack rumors”) with AI guidance on propaganda risk and plausibility.
   - Primary users: English‑speaking Iranian diaspora and non‑Iranian observers; mostly mobile, wanting fast, digested insight rather than raw firehose.
   - Success (MVP): daily active users consuming the briefing; coverage of major Iran stories; users report the “weight”/“closeness to reality” signals as useful.

2. Lock Content & Source Scope
   - Topic: fixed to “Iran” (no user topic selection), with AI‑discovered sub‑topics (sanctions, nuclear, protests, US–Iran tensions, etc.).
   - Sources (MVP): curated Iran‑relevant RSS/news sites, regime/state media, official statements, selected newsletters, and key X/Twitter accounts/keywords.
   - Languages: ingest at least Farsi and English; all user‑facing summaries, labels, and explanations in English (with optional original text view later).

3. Define Core AI Capabilities
   - Per item (article or tweet), system must compute:  
     - Stance/bias (e.g., pro‑regime, anti‑regime, neutral).  
     - Propaganda/manipulation risk level (Low/Med/High).  
     - Factuality / “closeness to reality” band (e.g., unlikely / uncertain / plausible).  
     - Short English summary and topic tag(s).  
   - Per narrative (cluster of items), system must compute:  
     - Narrative label and 1–2 sentence description.  
     - Aggregated reach/virality (across X + news).  
     - Aggregated propaganda risk and plausibility.  
   - Link items together: connect articles and their key reaction tweets; connect both into narratives automatically.

4. Specify User Experience (Mobile‑First IRdecode)
   - Default view: daily “Iran Decode” briefing with 3–7 top narratives, each showing:  
     - Narrative title, brief description, reach, propaganda risk, plausibility, and example items.  
   - Narrative view: list of top items split by source camp (regime media, opposition, Western media, independent analysts, viral X posts), with per‑item badges for weight and reality‑closeness.
   - Item view: card with summary, original link, stance/bias, propaganda risk, plausibility indicator, and short explanation (“why we think this”).  
   - Feedback: simple “this evaluation seems right/wrong” control per item/narrative, with optional short comment.

5. Nail Constraints, Risks, and Metrics
   - Tech constraints: use existing Azure infra, n8n for orchestration, OpenAI GPT‑4o/4.1‑mini, Azure AI Search, and Postgres; no new major platforms.
   - Risks to manage: model bias/accuracy (especially on short tweets), cost vs. volume (cap daily items), user trust (avoid overconfident labels, always show uncertainty bands).
   - Metrics:  
     - Engagement: daily/weekly actives, narratives/items viewed, mobile bounce rate.  
     - Coverage/freshness: presence of major Iran stories and time‑to‑include.  
     - Quality: ratio of positive user feedback on evaluations; qualitative feedback that “weight” and “closeness to reality” feel helpful.

### Further Considerations

1. For the dev team, next step is to turn this into epics: ingestion & storage, AI evaluation pipeline, narrative clustering, and IRdecode UI/API, each with clear tickets.  
2. We should also schedule a separate pass to define editorial/ethical guidelines (how we label propaganda, how we phrase uncertainty) before public launch.

---

## Plan: Update PRD & Architecture for IRdecode AI Newsroom + Podcast

A doc-only change plan so another agent (or you) can safely update the existing specs without ambiguity.

### PRD (docs/PRD.md)

1. Reframe the overview and scope
   - Rewrite the Project Overview to foreground “IRdecode – AI Newsroom for Iran” as the main MVP, not widgets.  
   - Explicitly name target users: English‑speaking Iranian diaspora and non‑Iranians wanting to decode Iran‑related narratives.  
   - State fixed topical scope: Iran only (events, rumors, propaganda, and policy around Iran).  
   - Add a short “Out of scope (current phase)” note that Nura Neural widgets are deferred to a later phase.

2. Refresh personas and user stories
   - Add/adjust personas for: (a) diaspora user on mobile wanting a quick daily understanding; (b) non‑Iran policy/research user.  
   - Add user stories for: viewing top narratives of last 24h; seeing stance/bias, propaganda risk, plausibility, and virality per narrative/item; seeing reaction tweets linked to major articles.  
   - Add user stories for the daily morning podcast (subscribe, listen to 8–15 min brief, see covered narratives).  
   - Move existing widget‑centric stories into a clearly labeled “Phase 2/3 – Widgets” subsection.

3. Expand key features and functional requirements
   - Define “AI Newsroom” features: narrative clustering, narrative views (today / last 7 days), per‑item evaluation (stance/bias, propaganda risk, plausibility, virality), and article↔tweet linking.  
   - Specify ingestion coverage: tweets/X posts, long‑form articles, RSS feeds, newsletters, regime/official sources.  
   - Add a dedicated podcast feature bullet set: last‑24h narrative selection, LLM script generation, TTS audio, RSS feed + on‑site player.  
   - Clearly mark widget features as future roadmap, not MVP.

4. Clarify content, AI evaluation, and data requirements
   - List required metadata per item: source identity, source category (regime, opposition, Western, independent), language, timestamp, URL, engagement metrics, raw + translated text.  
   - Define evaluation dimensions: narrative cluster, stance/bias category, propaganda risk level, plausibility band, virality score, plus short explanation text.  
   - Capture requirements for linking items into narratives and connecting articles with their key reaction tweets.

5. Update metrics, success criteria, and roadmap
   - Adjust success metrics to focus on IRdecode readers/listeners: daily active users, narrative views, time on briefing, podcast plays/downloads, and feedback on evaluation quality.  
   - Add qualitative success criteria: users report that “weight” and “closeness to reality” signals help them navigate rumors/propaganda (e.g., US attack rumors).  
   - Define phases: Phase 1 (AI Newsroom + podcast), later phases for analyst tools and Nura widgets.

### Architecture (docs/Architecture.md)

1. Refresh high-level architecture and diagrams
   - Update the top architecture diagram to show IRdecode.com AI Newsroom as the primary client (web/mobile), with widgets as a future consumer.  
   - Emphasize subsystems: Ingestion (RSSHub, Miniflux, X/Twitter), Storage (Postgres, Blob), Narrative Engine (clustering + scoring), AI Evaluation, Newsroom API, and Podcast Pipeline.  
   - Distinguish online user‑facing paths (narrative browsing, item views, podcast playback) from offline batch jobs (clustering, scoring, daily podcast generation).

2. Detail ingestion and storage for Iran-focused feeds
   - Expand ingestion section to cover: curated X/Twitter accounts/keywords, Iran‑relevant RSS/news feeds, newsletters, regime and official sources.  
   - Document normalization into common entities: RawItem, SourceProfile, NarrativeCluster, NarrativeMetrics, PodcastEpisode.  
   - Clarify Miniflux/RSSHub as ingestion helpers vs. Postgres as system‑of‑record.  
   - Confirm where embeddings and search indexes live (Azure AI Search) for narrative similarity and linking tweets/articles.

3. Describe narrative engine and evaluation pipelines
   - Add a “Narrative Engine” section describing how new items are clustered into narratives using embeddings + LLMs and updated over time.  
   - Document per‑item evaluations: stance/bias, propaganda risk, plausibility, virality; and per‑narrative aggregates.  
   - Show how these pipelines are implemented as scheduled n8n workflows (or equivalent) and how results are stored back into Postgres/AI Search.  
   - Include monitoring considerations (job failures, clustering anomalies).

4. Update AI/LLM stack usage
   - Enumerate LLM use cases: narrative labeling/summaries, item/narrative evaluation (stance/bias, propaganda risk, plausibility), explanation text, and daily podcast script generation.  
   - Keep the model provider abstract (e.g., Gemini or GPT‑4o) but note that scripts + evaluations must be in English and safe for public consumption.  
   - Add brief notes on prompt design, safety filters, and retrial strategies.

5. Define Newsroom API and podcast pipeline
   - Add/extend API section to describe endpoints for: daily briefing (top narratives), narrative details, item details (with linked tweets/articles), and podcast episode metadata/audio.  
   - Add a dedicated “Podcast Generation Pipeline” section: daily cron, fetch last‑24h narratives, LLM script generation, TTS audio, storage, and RSS + web integration.  
   - Document error handling for the podcast job (e.g., retries, skip day with notice).

6. Capture operational constraints and extensibility
   - Clarify external API constraints (X/Twitter limits, LLM usage quotas) and how ingestion is rate‑limited.  
   - Note security and privacy posture: minimal user data, secrets via Key Vault, careful handling of sensitive content.  
   - Add a short roadmap subsection in Architecture showing how the same Narrative Engine + Evaluation will later power Nura widgets and analyst tools.

### Consistency Notes

- Use “IRdecode AI Newsroom” for this phase; “Nura Neural widgets” only in clearly marked future sections.  
- Keep key terms aligned between both docs: narrative, narrative cluster, stance/bias, propaganda risk, plausibility, virality, daily podcast.  
- Ensure “Iran” is always the explicit topical scope for this MVP.
