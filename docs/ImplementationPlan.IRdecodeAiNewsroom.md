# Implementation Plan: Nura Neural / IRdecode AI Newsroom (Dev/MVP)

**Version:** 0.1  
**Date:** January 31, 2026  
**Scope:** Deliver IRdecode AI Newsroom + Daily Morning Podcast by June 30, 2026

---

## 1. Goal & Scope

Deliver a working **IRdecode AI Newsroom** that:
- Aggregates Iran-related news and X/Twitter posts from curated sources.
- Evaluates each item and narrative (stance/bias, propaganda risk, plausibility, virality).
- Clusters items into labeled narratives, with article↔tweet linking.
- Exposes a mobile-first daily briefing for IRdecode.com.
- Produces an **automated daily morning podcast** summarising the last 24 hours.

Widgets remain **Phase 2+** and are not part of this implementation plan beyond reusability considerations.

---

## 2. Tech Stack (MVP)

**Orchestration**
- n8n on Azure Container Apps (cron jobs, batch workflows, public webhooks via Front Door).

**Ingestion Services**
- Miniflux (RSS aggregator) on Azure Container Apps.
- RSSHub (RSS generator/scraper) on Azure Container Apps.
- SMRY-based text extraction service (Node/Express) on Azure Container Apps.
- Redis container (cache) for RSSHub and API response caching.

**Data Layer**
- Azure PostgreSQL Flexible (`irdecode-prod-psql`) for:
  - `sources`, `content`, `claims`, `narratives`, `podcast_episodes`.
- Azure Blob Storage (`irdecodeprodst`) for:
  - Raw HTML snapshots, extracted text snapshots (optional), podcast audio files.
- Azure AI Search (`nura-search`) for:
  - Vector + hybrid search over content/claims for clustering and retrieval.

**AI/LLM**
- Azure OpenAI GPT-4o for:
  - Agent 1 (source + item evaluation, claim extraction, translation, summarisation).
  - Agent 2 (narrative clustering, narrative labelling).
- Azure OpenAI GPT-4.1-mini for:
  - Fast responses where needed (e.g., lightweight API responses, future widgets).
- Azure OpenAI o4-mini for:
  - Escalation / deeper reasoning on contested items (limited use).
- Azure OpenAI text-embedding-3-large for:
  - Multilingual embeddings (claims and/or content).

**External APIs**
- TwitterAPI.io (Growth plan) for:
  - Tweets, threads, and searches from curated regime/actor accounts and keywords.

**Delivery & Clients**
- Azure Front Door (`irdecode-prod-fd`) in front of n8n webhooks.
- IRdecode.com frontend (Framer or custom) consuming Newsroom JSON APIs.
- Podcast: RSS feed endpoint + MP3 audio from Blob, with embedded player on IRdecode.

---

## 3. Basic Architecture

### 3.1 Layers

- **Ingestion Layer**  
  - RSSHub → Miniflux → n8n ingestion workflows.
  - n8n → TwitterAPI.io → normalised tweet items.
  - SMRY text extraction as an internal HTTP service.

- **Storage & Indexing Layer**  
  - PostgreSQL as system-of-record.
  - Blob Storage for large/raw content and podcast audio.
  - Azure AI Search for embeddings, similarity search, and narrative support.

- **Analysis Layer**  
  - Agent 1 (n8n + GPT-4o): source & item evaluation, claim extraction.
  - Agent 2 (n8n + GPT-4o + embeddings + AI Search): narrative clustering and maintenance.

- **Serving Layer**  
  - n8n webhooks (read APIs) exposed via Front Door.
  - Redis caching of hot responses.
  - IRdecode frontend for AI Newsroom.
  - Daily podcast pipeline (script → TTS → RSS).

### 3.2 Key Data Flows (High-Level)

1. **Ingestion**
   - Miniflux polls RSS/RSSHub feeds; n8n pulls new/unread items.
   - n8n calls SMRY for clean text; writes rows into `content` and optionally stores snapshots in Blob.
   - n8n polls TwitterAPI.io for configured accounts/keywords; normalises tweets/threads as `content` rows of type `tweet`.

2. **Analysis**
   - Agent 1 workflow runs on new `content` rows with `analysis_status = 'pending'`:
     - Evaluates stance/bias, propaganda risk, plausibility, virality proxy.
     - Extracts 0–N claims with translations; stores in `claims`.
     - Updates `sources` with IMTT-style metrics as needed.
   - Embedding workflow:
     - Creates embeddings for claims and/or content; upserts docs into Azure AI Search.
   - Agent 2 workflow (scheduled):
     - Uses embeddings + GPT-4o to group items/claims into narratives; writes `narratives` and narrative links.

3. **Serving**
   - n8n webhooks provide:
     - Daily narratives list and details.
     - Daily digest (items grouped by narrative).
     - Source credibility summaries.
   - IRdecode frontend renders mobile-first Newsroom and narrative detail views, calling these endpoints.

4. **Podcast**
   - Daily cron job queries top narratives and representative items for the last 24h.
   - LLM generates a 8–15 minute script; TTS produces audio; episode metadata stored in `podcast_episodes` + MP3 in Blob.
   - Podcast RSS endpoint reads from `podcast_episodes` and Blob to expose episodes.

---

## 4. Phased Implementation Plan

### Phase 1 – Data & Ingestion Foundations

**Objectives**
- Reliable ingestion of Iran-focused articles and tweets into PostgreSQL + Blob.
- Basic observability over ingestion health.

**Tasks**
1. **Schema & DB Setup**
   - Finalise and apply schema for:
     - `sources` (domains/accounts, language, tier, IMTT fields).
     - `content` (articles/tweets with language, type, ingestion and analysis statuses).
     - `claims` (linked to content, with translations and verification status).
     - `narratives` (labels, cluster size, languages, timeline metadata).
     - `podcast_episodes` (title, date range, file URL, duration, status).

2. **RSS Ingestion via Miniflux**
   - Configure Miniflux with curated lists of:
     - Regime/state media, opposition, Western media, newsletters.
   - Build n8n workflow:
     - Cron trigger (e.g., every 10–15 minutes).
     - Call Miniflux API for new/unread entries.
     - For each entry: call SMRY service to get clean text.
     - Insert/update `content` row and optional Blob snapshot.
     - Mark entry as processed in Miniflux.

3. **Twitter/X Ingestion via TwitterAPI.io**
   - Configure TwitterAPI.io credentials via n8n credentials (using Key Vault secret).
   - Define monitored accounts and keyword sets.
   - Build n8n workflow:
     - Cron trigger (e.g., every 15–30 minutes during active hours).
     - Fetch tweets/threads for configured accounts/keywords.
     - Normalise into `content` rows (type `tweet`) with language and source metadata.

**Deliverable:**
- New `content` rows (articles and tweets) flowing continuously for target sources, with ingestion logs available in n8n/Log Analytics.

---

### Phase 2 – Analysis Agents & Search

**Objectives**
- Automatic evaluation of items and sources (Agent 1).
- Embeddings and narrative clustering (Agent 2) backed by Azure AI Search.

**Tasks**
1. **Agent 1 – Source & Item Evaluation**
   - Design LLM prompts for:
     - Source-level IMTT-style assessment (where not already evaluated).
     - Item-level evaluation: stance/bias, propaganda risk, plausibility band, virality proxy, short explanation, translations.
   - Build n8n workflow triggered by new `content` rows with `analysis_status = 'pending'`:
     - Fetch source metadata and update/insert into `sources` if needed.
     - Call GPT-4o with structured prompt.
     - Parse and persist results into `content` and `sources`.
     - Extract 0–N claims with translations into `claims`.
     - Set `analysis_status = 'evaluated'`.

2. **Embeddings + Azure AI Search**
   - Decide on embedding granularity (per-claim and/or per-content).
   - Create or update Azure AI Search index schema to support narrative clustering and querying.
   - Build n8n workflow:
     - Batch or streaming processing of new items/claims needing embeddings.
     - Call text-embedding-3-large.
     - Upsert documents (with vectors + metadata) into `nura-search`.

3. **Agent 2 – Narrative Clustering**
   - Design clustering strategy combining embeddings and GPT-4o (e.g., seed clustering + label generation).
   - Build n8n scheduled workflow (e.g., every 4–6 hours):
     - Pull recent items/claims that are unassigned or due for re-clustering.
     - Use embeddings/AI Search and GPT-4o to group into narratives.
     - Create/update `narratives` and narrative–content/claim relationships.

**Deliverable:**
- Items and tweets automatically evaluated and clustered into labeled narratives, queryable via Azure AI Search and PostgreSQL.

---

### Phase 3 – Newsroom API & IRdecode Integration

**Objectives**
- Public, read-only APIs for IRdecode Newsroom.
- Initial IRdecode UI that surfaces narratives and evaluations.

**Tasks**
1. **API Design & Implementation (n8n Webhooks)**
   - Implement read-only endpoints such as:
     - `GET /webhook/narratives?window=24h` – top narratives for last 24h.
     - `GET /webhook/narratives/:id` – narrative detail, key items, basic timeline.
     - `GET /webhook/streams/daily-digest` – flat list of items grouped by narrative for homepage.
     - `GET /webhook/source-credibility` – source tier + simplified IMTT metrics.
   - Integrate Redis caching for hot responses (e.g., top narratives, daily digest).

2. **IRdecode Frontend Integration**
   - Define JSON contracts between backend and IRdecode frontend.
   - Implement minimum Newsroom UI:
     - Daily briefing view: list of top narratives with short labels, key metrics, and links.
     - Narrative detail view: articles + tweets, evaluations, short explanation.
     - Inline source credibility badges (e.g., next to domains or tweet authors).

**Deliverable:**
- Live IRdecode “AI Newsroom” providing daily Iran narratives and evaluated items.

---

### Phase 4 – Daily Morning Podcast

**Objectives**
- Automatically generate and publish a daily audio briefing based on the last 24h.

**Tasks**
1. **Script Generation**
   - Design a robust GPT-4o prompt for a ~8–15 minute narrative:
     - Intro/outro, sections by narrative, caveats/disclaimers.
   - Build n8n daily cron workflow:
     - Query top narratives and representative items for the last 24h.
     - Call GPT-4o to generate a structured script.
     - Optionally call o4-mini for a sanity/consistency check on the script.

2. **Audio Production & RSS Publishing**
   - Integrate with Azure Neural TTS (or chosen TTS) to convert script → MP3.
   - Store MP3 in Blob with stable path and public/Front Door URL.
   - Insert `podcast_episodes` row with metadata and URL.
   - Implement podcast RSS endpoint (n8n webhook or lightweight service) that:
     - Reads `podcast_episodes` and generates RSS XML.
   - Add player component to IRdecode.com and document how to subscribe in podcast apps.

**Deliverable:**
- Daily morning podcast auto-generated and published via RSS + IRdecode player.

---

### Phase 5 – Monitoring, Safety, and Editor Tools (Light)

**Objectives**
- Operational stability and basic human control over narratives.

**Tasks**
1. **Monitoring & Alerts**
   - Dashboards/alerts for:
     - n8n workflow failures.
     - Azure AI Search latency and errors.
     - LLM token usage vs. budget.
     - Ingestion gaps (e.g., no new content from a key source).

2. **Minimal Editor/Ops Tools**
   - Provide a simple interface (could be:
     - n8n dashboard, or
     - a minimal internal admin page) to:
     - Override narrative titles/labels.
     - Hide or de-prioritise specific items.
     - Mark items/narratives for re-analysis.

**Deliverable:**
- Basic operational control and visibility, with the ability to correct or suppress problematic outputs.

---

## 5. Notes on Reusability for Future Widgets

- All evaluation and narrative logic lives in backend agents and APIs that are **client-agnostic**.
- The same `content`, `claims`, and `narratives` tables, plus Azure AI Search index, will power future widgets (fact-check form, credibility badge, narrative tracker).
- Newsroom endpoints are designed so that future widget-specific APIs can be thin wrappers around the same data and models.
