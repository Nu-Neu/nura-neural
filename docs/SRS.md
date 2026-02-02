<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# Base on last meeting  as business analysis write all possible use cases for all 4 layer of Nura  in a simple minimal SRS document

Below is a minimal SRS-style document for Nura, listing the main use cases for all four layers, aligned with our last architecture decisions and specs.[^1][^2]

***

# Nura Platform – Minimal SRS for 4-Layer Architecture

## 1. System Overview

Nura is an Iran-focused news intelligence platform that ingests multi-source content, scores **trust**, clusters narratives, and exposes them via a product UI and APIs for analysts and activists.[^2][^1]
The architecture has four conceptual layers:

1. Data Ingestion Layer
2. AI Reasoning Layer
3. Application / Product Layer
4. Governance \& Operations Layer

Each section below lists core use cases (functional requirements) per layer.

***

## 2. Data Ingestion Layer – Use Cases

Scope: Bring external content into the system, normalize it, and store it in the relational and vector stores.[^2]

### UC-D1: Ingest RSS / Web Articles

- System periodically fetches RSS feeds and site content from the Source Bible list.[^2]
- System extracts title, body, author, publish date, URL, language, and platform metadata and writes a new record into `items` plus HTML snapshot to blob storage.[^2]


### UC-D2: Ingest Social Media Posts

- System pulls posts from Twitter/X (and other social APIs where configured) based on curated account lists and queries.[^2]
- System normalizes post text, author handle, timestamp, and link into `items` with platform = `X` and stores raw JSON in blob storage.[^2]


### UC-D3: Source Profile Synchronization

- System loads and maintains `sourceprofiles` with source class, subclass, base score, transparency attributes, and context statement based on the 6‑layer media spectrum.[^1][^2]
- System automatically updates `historicalaccuracy` and `lastaudit` after editorial review or batch quality checks.[^1][^2]


### UC-D4: Pre-LLM Triage \& Filtering

- System runs deduplication (URL hash, content hash) to drop reprints and exact duplicates before expensive AI calls.[^1]
- System filters spam/irrelevant items based on length, forbidden keywords, and language gates (FA, EN, AR allowed).[^1]


### UC-D5: Embedding \& Search Indexing

- System generates embeddings for each new item and pushes vectors into Azure AI Search plus `embedding` column in `items`.[^2]
- System maintains hybrid (keyword + vector) indices for downstream retrieval and corroboration queries.[^1][^2]

***

## 3. AI Reasoning Layer – Use Cases

Scope: Hard logic and LLM workflows that assign trust scores, detect proxies, and cluster narratives.[^1][^2]

### UC-R1: Source Trust Base Scoring

- System assigns a base reliability score to each source according to `sourceclass` / `sourcesubclass` (Regime media, Grey tabloid, NGO watchdog, etc.).[^1][^2]
- System persists `basescore` and rationale (context statement and transparency features) in `sourceprofiles`.[^2][^1]


### UC-R2: Proxy Detection for Regime-Affiliated Outlets

- System periodically computes proxy scores (content overlap, narrative alignment, amplification network, tech overlap) for candidate sources.[^1]
- System labels suspected proxies, applies penalties, and enforces that they cannot corroborate other regime sources.[^1]


### UC-R3: Item Trust Scoring

- System calculates the `trustsignals` record per item using Base, Provenance, Corroboration, Transparency, and Modifier components under fixed formulas.[^2][^1]
- System outputs `finalscore`, `trustlevel`, badges, and a human-readable explanation JSON contract for the frontend.[^1]


### UC-R4: Corroboration \& Ownership-Cluster Check

- System runs vector search across independent sources to count corroborating items for a claim/story.[^2][^1]
- System zeros corroboration if all matches belong to the same ownership cluster (e.g., all IRGC-linked outlets).[^1]


### UC-R5: Narrative Clustering \& Maintenance

- System groups items into narratives using cosine similarity, entity overlap, main event IDs, and time windows tuned by topic type (breaking, protests, policy).[^2][^1]
- System updates `narratives` (title, summary, AISummary, trend score, first/last seen, item count) on each new item.[^2][^1]


### UC-R6: Narrative-Level Debunk / Context

- System stores manual and AI-generated narrative debunks (`NarrativeManualDebunk` style) including key claims and fact-check verdicts.[^3][^2]
- System links narrative debunks back to items and exposes status fields (pending, in-review, published) for editorial workflows.[^3][^2]


### UC-R7: Multi-Model Chain-of-Thought Reasoning

- System routes tasks to small models for cleaning, o3‑mini for deep reasoning (trust and narratives), and GPT‑4o for final natural-language answers.[^1][^2]
- System enforces token budget and batching rules for background processing versus interactive chat calls.[^2]

***

## 4. Application / Product Layer – Use Cases

Scope: User-facing features (feed, item view, narrative view, chat, external API).[^2]

### UC-A1: Trust-Scored News Feed

- User views a ranked feed of items with trust badges, scores, source class labels, and key metadata.[^1][^2]
- User filters by language, trust level, source class, and timeframe.


### UC-A2: Item Detail – Trust Breakdown

- User opens an item and sees full text, trust breakdown (base/provenance/corroboration/transparency/modifiers), badges, and warnings (e.g., regime proxy, anonymous sourcing).[^1][^2]
- User can expand to see corroborating items list and narrative membership.


### UC-A3: Narrative Explorer

- User lists narratives with title, AISummary, trend score, item count, and trust distribution.[^2][^1]
- User opens a narrative to see timeline of items, stance diversity, and any attached manual debunk or context note.[^3][^1]


### UC-A4: Investigative \& Activist Views (Nura / irdcode.com)

- User searches by actor, outlet, or claim to inspect propaganda patterns, spreaders, and narrative evolution tied into the propaganda workflow.[^4][^3]
- User exports evidence packages (JSON/CSV/PDF) to support outreach, reports, or campaigns.


### UC-A5: Conversational Analysis Assistant

- User asks questions in natural language (e.g., “How reliable is X on Iran executions?”).[^3][^2]
- System performs RAG over items, narratives, and trustsignals and responds with contextual, cited answers respecting fairness and human-rights documentation principles.[^3][^2]


### UC-A6: Public / Partner APIs

- External clients can call read-only APIs to fetch feeds, specific items, narrative details, and trust objects for integration in other dashboards.[^2]
- APIs enforce pagination, authentication, and schema contracts as defined in the MVP spec (e.g., `GET /feed`, `GET /narrative/{id}`, `GET /item/{id}/trust`).[^2]

***

## 5. Governance \& Operations Layer – Use Cases

Scope: Quality, ethics, configuration, and operational control over the platform.[^4][^3][^2]

### UC-G1: Source Bible Governance

- Editorial lead maintains the master Source Bible (URLs, RSS, class, base scores, context statements) with versioning and clear change logs.[^2]
- System applies new classifications to future items and can trigger retroactive audits where necessary.[^2]


### UC-G2: Fairness \& Editorial Policy Enforcement

- System prompts and guardrails enforce fairness policies (no personal attacks on journalists; distinguish structural constraints vs. malice).[^4][^3]
- Analysts must explicitly classify criticism as factual, contextual, or advocacy, and system logs these actions.


### UC-G3: Human Rights \& Safety Checks

- System and workflow ensure “do no harm” for Iranian sources, including anonymization, consent, and controlled exposure of sensitive evidence.[^4][^3]
- High-risk content (e.g., identifiable protesters) is flagged for manual review before publication.


### UC-G4: Quality Assurance \& KPIs

- System tracks KPIs: ingestion volume, trust scoring latency, narrative clustering accuracy, DAU, and error budgets.[^2]
- Periodic audits sample trust decisions and narrative clusters for expert review, with corrections feeding back into config and weights.[^3][^1]


### UC-G5: Cost \& Performance Management

- System monitors token usage, compute cost, and latency per model and pipeline stage, raising alerts when thresholds are exceeded.[^2]
- Operators can switch some workloads to smaller models or batch modes without changing business semantics.


### UC-G6: Transparency \& Public Methodology

- System publishes methodology pages summarizing scoring logic, propaganda analysis frameworks, and limitations for external stakeholders.[^4][^3][^1]
- Any major change in scoring or classification rules is logged and communicated as a versioned policy update.

***

If you like this structure, the next step can be to turn this into a numbered, fully formal SRS (with IDs like FR‑D1, FR‑R3, etc.) and plug it into your Confluence or repo.
<span style="display:none">[^5]</span>

<div align="center">⁂</div>

[^1]: Master-Functional-Specification_-Source-Evaluation.md

[^2]: Meeting-Minutes-Strategic.docx

[^3]: let-s-look-at-this-process-as-a-expert-which-exprt.docx

[^4]: Propagand-Workflow.docx

[^5]: Iran Propaganda Archive Jan2026

