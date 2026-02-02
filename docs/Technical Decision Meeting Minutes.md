<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# Iran Affairs Intelligence Platform - Technical Decision Meeting Minutes

**Project:** Nura Neural Intelligence Platform
**Date:** February 2, 2026
**Version:** 1.0 Final
**Status:** Approved for Implementation

***

## Executive Summary

This document captures all strategic decisions, system architecture, data models, technology stack, workflows, and action items for the **Nura Neural** MVP (Minimum Viable Product). The platform leverages AI to aggregate, analyze, and present Iran affairs news with transparent trust scoring and narrative-driven intelligence briefings.

***

## 1. Strategic Decisions

### 1.1 Architecture: The Sandwich Model

The system operates through **4 operational layers**, each optimized for cost and quality:


| Layer | Role | AI Model | Monthly Cost (USD) |
| :-- | :-- | :-- | :-- |
| 1. Ingestion | Data worker (fast \& cheap) | GPT-4o-mini | 50-80 |
| 2. Logic | Detective (reasoning) | o3-mini | 100-150 |
| 3. Presentation | Editor (polished writing) | GPT-4o | 80-120 |
| 4. Interaction | Assistant (user chat) | GPT-4o-mini (RAG) | 30-50 |

**Total Estimated Cost:** \$260-400/month (within \$500 budget)

**Key Decision:**

- **GPT-4o** removed from general processing (too expensive).
- **Presentation layer only** uses GPT-4o to ensure high-quality, journalistic Persian text.
- **o3-mini** handles all reasoning/fact-checking (superior logic, lower cost than GPT-4o).
- **GPT-4o-mini** handles bulk processing and RAG chat (20x cheaper).

***

### 1.2 Data Model Simplification

**Decision: Remove `claims` entity from MVP**

**Rationale:**

- The concept of "canonical claims" adds unnecessary complexity.
- Narratives already serve this purpose through AI-generated summaries.
- Manual claim linking is error-prone and time-consuming.

**Impact:**

- Simplified database schema (4 tables instead of 5).
- 2-week acceleration in development timeline.
- Narratives become the primary user-facing unit, not individual claims.

**Alternative for edge cases:**

- Admins can manually create "Manual Debunk" narratives for viral rumors not in RSS feeds.

***

### 1.3 Narrative-First Architecture

**Core Philosophy:** Users consume **narratives** (story clusters), not individual news items.

**Benefits:**

- Reduces information overload (10 narratives/day vs. 1000 raw items).
- Aligns with bulletin-style product vision.
- Allows AI to synthesize contradictions and provide context.

**Data Flow:**

```
Raw Items → Clustering → Narrative Creation → AI Summary (o3-mini) → Polished Bulletin (GPT-4o) → User
```


***

## 2. Data Model (PostgreSQL)

### 2.1 Schema Overview

| Table | Purpose | Key Fields |
| :-- | :-- | :-- |
| `source_profiles` | Master list of sources with classification | id, name, base_score, type, transparency_audit (JSONB) |
| `items` | Raw news articles with embeddings | id, source_id, title, body, embedding (vector), narrative_id (FK) |
| `narratives` | Story clusters with AI-generated summaries | id, title, ai_summary, trend_score, key_facts (JSONB) |
| `trust_signals` | Detailed scoring breakdown per item | item_id (FK), provenance_score, final_score, explanation |

**Key Relationships:**

- `items.narrative_id` → `narratives.id` (Many-to-One)
- `items.source_id` → `source_profiles.id` (Many-to-One)
- `trust_signals.item_id` → `items.id` (One-to-One)

**Technical Notes:**

- Use `pgvector` extension for embedding storage and similarity search.
- Embeddings generated using `text-embedding-3-large` (1536 dimensions).
- `narrativeid` allows grouping related items without complex claim mapping.

***

### 2.2 Source Classification: The 6-Layer Spectrum

**Designed by:** Dr. Kaveh (Media Analyst)


| Class | Examples | Base Score | Context Statement Purpose |
| :-- | :-- | :-- | :-- |
| **Regime Media** | IRNA, Fars, Tasnim | 35-40 | Identify state-controlled outlets; high score only for official quotes |
| **Mainstream Diaspora** | BBC Persian, Iran Intl | 70-80 | Professional standards but may have editorial bias; require corroboration |
| **Activists** | 1500tasvir, Vahid Online | 50-65 | Early warning signals; mark as "Unverified" until confirmed |
| **NGOs** | HRANA, Amnesty, NetBlocks | 85-95 | "Anchor of truth"; meticulously documented |
| **Grey/Tabloid** | Anonymous Telegram channels | 20-30 | Track rumor origins only; do not use for verification |
| **International Wires** | Reuters, AP, NYT | 90-100 | Final arbiters; highest credibility |

**Deliverable:** Dr. Kaveh will produce a complete "Source Bible" (Excel) with:

- 40 primary sources
- Exact RSS feed URLs
- Class assignment and base score
- Context statements (Persian + English) for each class

***

## 3. Technology Stack

### 3.1 Core Infrastructure (Azure Cloud)

| Component | Service | Monthly Cost (USD) |
| :-- | :-- | :-- |
| **AI Models** | Azure OpenAI (GPT-4o, o3-mini, 4o-mini) | 200-300 |
| **Search \& Vectors** | Azure AI Search (Basic tier) | 75 |
| **Database** | PostgreSQL Flexible Server | 50-100 |
| **Storage** | Blob Storage (raw HTML archive) | 5 |
| **Compute** | Container Apps (n8n, FastAPI) | 20-50 |
| **Secrets** | Key Vault | 5 |
| **Monitoring** | Application Insights | 10 |

**Total:** \$365-545/month (buffer under \$500 cap)

***

### 3.2 Supporting Tools

1. **Workflow Orchestration:** n8n (self-hosted on Azure Container Apps)
    - Handles RSS polling, event triggers, and API orchestration
    - Low-code visual workflows for rapid iteration
2. **Backend API:** FastAPI (Python)
    - RESTful endpoints for frontend
    - Async processing for embeddings and scoring
3. **Frontend:** Framer (no-code/low-code)
    - Rapid UI/UX prototyping
    - Suitable for MVP; can migrate to Next.js later
4. **RSS Management:** Miniflux (self-hosted)
    - Centralized feed aggregation
    - Deduplication and polling management
5. **Social Media Scraping:** TwitterAPI.io
    - Access to Twitter/X without official API costs
    - Fallback for Telegram via web scraping
6. **Vector Search:** pgvector extension
    - Native PostgreSQL vector similarity search
    - Reduces dependency on external vector databases

**Rationale for n8n over custom code:**

- Visual workflow debugging (non-engineers can understand).
- Faster iteration during MVP phase.
- Self-hosting avoids vendor lock-in and data privacy concerns.

**Cost-Saving Decision:** Self-host n8n on Azure Container Apps instead of cloud version (\$300-500/month savings).

***

## 4. System Workflows

### WF1: Feed Ingestion Pipeline

**Trigger:** Cron job (every 15 minutes)

**Steps:**

1. n8n polls 40 RSS feeds + TwitterAPI.io
2. Deduplication check (URL or embedding similarity >95%)
3. Store raw HTML in Azure Blob Storage
4. Emit event: `ItemCreated(item_id)`

**Technology:**

- n8n (orchestration)
- Miniflux (RSS aggregation)
- Azure Blob Storage

**Output:** New records in `items` table (uncleaned)

***

### WF2: Metadata Extraction \& Normalization

**Trigger:** Event `ItemCreated`

**Steps:**

1. Call GPT-4o-mini with prompt:

```
Extract: title, summary (max 500 chars), author, publish_date, language (fa/ar/en).
Return JSON.
```

2. Validate date formats and language codes
3. Update `items` table with structured metadata
4. Emit event: `ItemNormalized(item_id)`

**Cost:** ~\$0.0005 per item

***

### WF3: Embedding Generation \& Indexing

**Trigger:** Event `ItemNormalized`

**Steps:**

1. Generate embedding using `text-embedding-3-large` (Azure OpenAI)
2. Input: `title + summary`
3. Store in `items.embedding` (vector column)
4. Index in Azure AI Search for fast retrieval
5. Emit event: `ItemIndexed(item_id)`

**Cost:** ~\$0.0001 per item

***

### WF4: Trust Scoring Engine

**Trigger:** Event `ItemIndexed`

**Steps:**

1. **Provenance Score (0-20 points):**
    - Has author? (+7)
    - Has valid publish_date? (+7)
    - Has direct URL? (+6)
2. **Corroboration Score (0-40 points):**
    - Vector search in Azure AI Search (similarity > 0.85)
    - Count independent sources (different `source_id`)
    - Apply weighting by source class (State Media Cap):

```
Class 1 (Regime): weight 0.3
Class 2-4: weight 1.0
Class 5 (Grey): weight 0.1
Class 6 (International): weight 1.5
```

    - **Exception:** Items <6 hours old get "Breaking" badge with no corroboration penalty
3. **Transparency Score (0-15 points):**
    - Read from `source_profiles.transparency_score`
4. **Final Score:**

```
final_score = base_score + provenance + corroboration + transparency
final_score = CLAMP(15, 95)
```

5. **Assign Trust Level:**
    - 80-95: Green (Verified)
    - 65-79: Light Green (Reliable)
    - 50-64: Yellow (Check Sources)
    - 35-49: Orange (Unverified)
    - 15-34: Red (Caution)
6. Generate explanation text (GPT-4o-mini template)
7. Store in `trust_signals` table
8. Emit event: `ItemScored(item_id, score)`

**Technology:**

- n8n (logic orchestration)
- Azure AI Search (vector similarity)
- Azure Functions (complex calculations)

***

### WF5: Narrative Clustering

**Trigger:** Scheduled job (every 6 hours)

**Steps:**

1. Fetch all `items` from past 14 days where `narrative_id = NULL`
2. Run clustering algorithm:
    - Method: HDBSCAN or K-means
    - Input: `embedding` vectors
    - Threshold: Cosine similarity > 0.75
    - Min cluster size: 5 items
3. For each cluster:
    - Create record in `narratives`
    - Generate title using GPT-4o-mini
    - Extract `key_phrases` (JSONB)
4. Update `items.narrative_id` for clustered items
5. Emit event: `NarrativeCreated(narrative_id)`

**Technology:**

- Python script (scikit-learn)
- Azure Functions (if heavy compute needed)
- GPT-4o-mini (title generation)

**Open Decision (for Meeting 2):**

- Should Persian and English narratives be merged or separate?
- Who approves/rejects bad clusters before publication?

***

### WF6: Narrative Summarization (The Bulletin Generator)

**Trigger:** Event `NarrativeCreated` OR scheduled (daily for Top 10)

**Steps:**

1. Fetch all `items` linked to `narrative_id`
2. **Call o3-mini (Detective Agent):**
    - Prompt: *"Read these 10 articles. Identify: facts agreed upon, contradictions, unverified claims."*
    - Output: Structured JSON report
3. **Call GPT-4o (Journalist Agent):**
    - Prompt: *"Based on this analysis, write a 200-word neutral bulletin in Persian. Include what regime sources say vs. what independent sources report."*
    - Output: Final polished text
4. Update `narratives.ai_summary` with final text
5. Emit event: `NarrativePublished(narrative_id)`

**Cost:** ~\$0.05-0.10 per narrative (only for Top 10/day → \$1/day max)

***

### WF7: Chat RAG Pipeline (User Interaction)

**Trigger:** User sends query via `/api/chat` endpoint

**Steps:**

1. Detect language (fa/ar/en)
2. Convert query to embedding vector
3. **Hybrid Search in Azure AI Search:**
    - Vector search (semantic similarity)
    - Keyword search (exact match)
    - Filter: `trust_score > 50` only
    - Limit: Top 10 results
4. Prioritize by source class (Class 4-6 sources ranked higher)
5. **Generate Response (GPT-4o-mini):**
    - System prompt includes Fairness Policy (show contradictions, avoid certainty)
    - Context: 10 retrieved items
6. Format citations with clickable links
7. Stream response to frontend
8. **NO STORAGE:** Query is never saved (privacy protection)

**Technology:**

- FastAPI (endpoint)
- Azure AI Search (retrieval)
- GPT-4o-mini (generation)

**Cost:** ~\$0.0005 per query

***

## 5. Security \& Privacy

| Concern | Mitigation |
| :-- | :-- |
| **Logging** | Never log user queries or chat history |
| **API Keys** | Store in Azure Key Vault only; never in code |
| **Encryption** | TLS 1.3 for all traffic; Azure-managed encryption at rest |
| **Access Control** | Admin endpoints require API keys; frontend is read-only by default |
| **GDPR Compliance** | No PII collected; users anonymous unless they create accounts (Phase 2) |


***

## 6. Development Roadmap (4 Weeks)

### Pre-Sprint: Infrastructure Setup (Days 1-3)

- **Azure provisioning** (all services listed above)
- **Schema deployment** (run SQL migrations)
- **n8n + Miniflux deployment** on Container Apps


### Sprint 1: Onboarding \& Ingestion (Week 1)

1. **Source Onboarding:**
    - Import "Source Bible" into `source_profiles`
    - Write transparency audits and context statements
    - Test RSS feed validity (ensure no 404s)
2. **Ingestion Pipeline:**
    - Build n8n workflow for RSS/Twitter polling
    - Implement deduplication logic
    - Deploy ingestion cron job
3. **Metadata Extraction:**
    - Integrate GPT-4o-mini for cleaning
    - Test on 100 sample items

### Sprint 2: Trust Scoring \& Embeddings (Week 2)

1. **Provenance Scorer:**
    - Build scoring logic (n8n JavaScript nodes)
2. **Corroboration API:**
    - Implement weighted corroboration with State Media Cap
    - Add "breaking news" and "official statement" exception rules
    - Deploy as Azure Function for reusability
3. **Embedding Pipeline:**
    - Build n8n workflow for embedding generation
    - Index in Azure AI Search
    - Test deduplication via vector similarity
4. **Trust Explanation Generator:**
    - Template-based explanations (avoid LLM hallucination)

### Sprint 3: Narrative Engine (Week 3)

1. **Clustering Implementation
