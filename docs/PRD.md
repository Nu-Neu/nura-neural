# Product Requirements Document: Nura Neural / IRdecode AI Newsroom

**Version:** 1.1  
**Date:** January 31, 2026  
**Project Name:** Nura Neural / IRdecode AI Newsroom  
**Target Launch:** June 30, 2026

---

## 1. Project Overview
**Nura Neural** is an AI-powered intelligence platform designed to automatically detect propaganda, verify claims, and profile sources for media and activist organizations.

For the first release, the primary product surface is the **IRdecode AI Newsroom**: an Iran-focused, mobile-first experience that aggregates Iran-related news and X/Twitter posts, clusters them into narratives, and evaluates each item and narrative for stance/bias, propaganda risk, virality, and plausibility ("closeness to reality"). Users get a daily briefing and narrative views, plus an automatically generated **daily morning podcast** summarising the last 24 hours.

Embeddable web widgets (fact-check form, credibility badge, etc.) remain a core long-term goal of Nura Neural but are explicitly treated as a **later phase** and are not part of the initial IRdecode MVP scope.

The MVP will launch by June 30, 2026, with IRdecode.com as the primary client (and Action4Iran.com as a later widget consumer in subsequent phases).

## 2. User Stories

### 2.1 IRdecode AI Newsroom (Phase 1 MVP)
- **As a Reader in the Iranian diaspora**, I want to open IRdecode on my phone each morning and see the top Iran-related narratives from the last 24 hours (e.g., rumours of a US attack) so I can quickly understand what is being said and by whom.
- **As a Reader**, I want each narrative and item to show stance/bias, propaganda risk, virality, and a simple plausibility band so I can judge which stories to take seriously.
- **As a Reader**, I want to see major articles (e.g., from NYT) together with key reaction tweets/X posts (from regime media, opposition figures, journalists, etc.) so I can see how different actors are responding to the same story.
- **As a Reader**, I want a short explanation of why an item or narrative has been rated as propaganda-heavy or plausible so I can build trust in the system’s judgement.
- **As a Reader**, I want to subscribe to a daily morning podcast that summarises the previous 24 hours of Iran narratives in 8–15 minutes so I can stay updated while commuting or doing other tasks.
- **As an Admin/Editor at IRdecode**, I want to configure and maintain curated source lists (feeds, accounts, newsletters) and see basic health of ingestion so I know the newsroom view is complete and reliable.

### 2.2 Nura Widgets (Phase 2+)
- **As an Admin**, I want to configure RSS feeds and Twitter keywords so **Nura Neural** automatically ingests relevant content for analysis.
- **As a Researcher**, I want "Agent 1" to evaluate sources using the **IMTT rubric** (Independence, Methodology, Transparency, Triangulation) to identify propaganda outlets.
- **As a Researcher**, I want "Agent 2" to cluster semantically similar claims into narratives so I can track the evolution of disinformation campaigns.
- **As a Journalist**, I want to use the **Nura Neural Widget** to instantly fact-check text or URLs against verified evidence.
- **As a Site Owner**, I want to embed a "Credibility Badge" that displays a source's trust score to my readers.

## 3. Key Features

### 3.1 Dual-Agent Backend (Core Platform)
* **Source Evaluator (Agent 1):** Classifies sources (Baseline, Propaganda, etc.) with evidence logs and confidence scores based on the IMTT rubric.
* **Narrative Clusterer (Agent 2):** Groups semantically similar claims to map narrative evolution over time.

### 3.2 IRdecode AI Newsroom (Phase 1 MVP)
* **Iran-Focused Aggregation:** Ingests Iran-related content from curated RSS/news feeds, newsletters, regime/official outlets, and selected X/Twitter accounts/keywords.
* **Narrative Discovery:** Clusters individual items (articles and tweets) into narratives and labels them with concise, English summaries (e.g., "US preparing imminent strike on Iran").
* **Evaluation Signals:** For each item and narrative, assigns stance/bias (e.g., pro-regime, anti-regime, neutral), propaganda/manipulation risk level, virality/reach indicator, and a plausibility band (e.g., unlikely / uncertain / plausible).
* **Article↔Tweet Linking:** Automatically associates news articles with key reaction tweets/X posts (from regime media, opposition, journalists, etc.) so users can see who is amplifying, contesting, or ignoring a story.
* **Daily Briefing View:** Mobile-first daily view of the top narratives from the last 24 hours, with links to representative items and quick-read explanations.
* **User Feedback:** Lightweight feedback controls (e.g., "seems right" / "seems off") on item and narrative evaluations to support iterative tuning.

### 3.3 Daily Morning Podcast (Phase 1 MVP)
* **Automatic Script Generation:** Once per day, composes an English script summarising the top narratives and their evaluations from the last 24 hours using an LLM (e.g., Gemini or GPT-4o).
* **Text-to-Speech Audio:** Converts the script into an 8–15 minute audio episode in a neutral news-style voice.
* **Distribution:** Publishes the episode as a podcast feed (RSS) and exposes it via an embedded player on IRdecode.com, with basic metadata (title, date, covered narratives).

### 3.4 Embeddable Widget Suite (Phase 2+)
* **Fact-Check Form:** Instant verification for user-submitted text/URLs.
* **Propaganda Detector:** Visual indicator (Clean/Biased/Propaganda) with technique analysis.
* **Narrative Tracker:** Real-time feed of trending disinformation narratives.
* **Source Credibility Badge:** Visual trust score for cited domains.

### 3.5 OSINT Profiling (Platform Capability)
* **Automated Profiling:** Generates source profiles based on historical accuracy, bias, and network behavior, to support both newsroom views and future analyst workflows.

## 4. Technical Constraints
* **Infrastructure:** Microsoft Azure (Container Apps, SQL Database/PostgreSQL, Blob Storage, Azure Front Door, Azure Key Vault).
* **AI Stack:** **OpenAI GPT-4o / GPT-4.1-mini** (and/or Gemini) for reasoning, summarisation, evaluation, and podcast scripts; **Azure AI Search** with vector indexing for similarity and narrative clustering; orchestrated via **n8n** and supporting libraries.
* **Performance:**
    * Cached widget responses (Phase 2+): **<3 seconds**
    * Fresh analysis for public API/web use (including newsroom views): **<30 seconds**
    * Daily podcast generation window: completes within a defined early-morning time slot.
* **Scope:**
    * Topical scope fixed to Iran-related content.
    * MVP limited to English & Persian input (English output only) and RSS/Twitter/newsletter sources, with clear growth path to additional channels.
* **Timeline:** Alpha (Feb 2026), Beta (April 2026), MVP Launch (June 30, 2026).

## 5. Success Metrics
* **Narrative Coverage & Freshness:**
    * Top Iran-related narratives from major sources (Western, regime, opposition, independent) are consistently captured and clustered.
    * Median time from a major Iran story breaking on monitored sources to appearing in the IRdecode AI Newsroom narratives is within target (e.g., <30–60 minutes).
* **Evaluation Quality:**
    * **≥80% match** between system propaganda/factuality assessments and expert/manual review on sampled items.
    * Positive user feedback ratio on evaluations ("seems right" significantly outweighs "seems off").
* **User Adoption & Engagement (IRdecode):**
    * Steady growth in daily and weekly active users viewing the AI Newsroom and narrative details.
    * Meaningful engagement with the daily morning podcast (subscribers, plays, completion rates).
    * Mobile users can reach the daily briefing and top narratives in a small number of taps and within a few seconds on typical connections.
* **Platform Scale & Future Widget Readiness:**
    * System supports **500+ concurrent users** browsing narratives and listening to the podcast with stable performance.
    * Underlying narrative and evaluation services are ready to be exposed to future Nura Neural widgets and additional clients without major redesign.
