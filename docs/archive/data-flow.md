---
doc_type: architecture
version: 1.0
last_updated: 2026-02-03
owner: Amir (Software Architect) & Reyhaneh (Database Specialist)
status: approved
traceability:
  - Ref: HLD-v2.0
  - Ref: SRS-v2.4
  - Ref: design-trust-narrative-system-v1.0
  - Ref: workflow-pg-to-ai-search-sync-v1.0
---

# Data Flow Architecture - Nura Intelligence Platform v1.0

## Document Control

| Field | Value |
|-------|-------|
| **Version** | 1.0 (MVP) |
| **Date** | February 3, 2026 |
| **Contributors** | Amir (Architect), Reyhaneh (DB), Navid (AI), Saman (n8n) |
| **Status** | ✅ APPROVED for Implementation |

---

## 1. Overview

This document describes the **end-to-end data flow** in the Nura platform, from raw news ingestion to user-facing Trust Score visualization. The architecture follows a **4-layer microservices pattern**:

1. **Layer 1: Ingestion** - Data collection and deduplication
2. **Layer 2: Reasoning** - AI analysis (Trust Scoring, Narrative Clustering)
3. **Layer 3: Persistence** - PostgreSQL + Azure Blob + Redis
4. **Layer 4: Presentation** - API Gateway + Framer UI

**Design Philosophy:**
- **PostgreSQL is the single source of truth**
- **Azure AI Search is a read-optimized cache** (Hybrid Search for semantic queries)
- **n8n orchestrates all workflows** (no custom cron jobs)
- **Idempotency everywhere** (url_hash prevents duplicates)

---

## 2. High-Level System Architecture

\`\`\`mermaid
graph TB
    subgraph "External Sources"
        RSS[RSS Feeds<br/>500 sources]
        Twitter[Twitter API<br/>200 accounts<br/>via twitterapi.io]
    end

    subgraph "Layer 1: Ingestion (n8n Orchestration)"
        Miniflux[Miniflux Container<br/>RSS Aggregator]
        N8N[n8n Workflow Engine<br/>Deduplication + Language Filter]
    end

    subgraph "Layer 2: AI Reasoning"
        OpenAI[Azure OpenAI<br/>GPT-4o-mini + text-embedding-3-small]
        TrustEngine[Trust Scoring Engine<br/>Python Logic]
        ClusterEngine[Narrative Clustering<br/>pgvector HNSW]
    end

    subgraph "Layer 3: Persistence"
        PG[(PostgreSQL B2s<br/>Source of Truth<br/>articles, trust_signals, narratives)]
        Blob[Azure Blob Storage<br/>Raw HTML Archive]
        Redis[(Redis Cache<br/>Sync State + Vectors)]
    end

    subgraph "Layer 4: Presentation"
        AISearch[Azure AI Search<br/>Basic SKU<br/>Hybrid Search Cache]
        FastAPI[FastAPI Gateway<br/>/feed, /items/:id]
        Framer[Framer UI<br/>Trust Badge + Modal]
    end

    subgraph "Users"
        Sarah[Sarah - Activist]
        Reza[Reza - Journalist]
    end

    RSS -->|15min poll| Miniflux
    Twitter -->|5min poll| N8N
    Miniflux -->|Webhook| N8N
    N8N -->|Extract Metadata| OpenAI
    N8N -->|Generate Embeddings| OpenAI
    OpenAI -->|Insert Articles| PG
    PG -->|Calculate Trust Score| TrustEngine
    TrustEngine -->|Store trust_signals| PG
    PG -->|Vector Search| ClusterEngine
    ClusterEngine -->|Assign Narratives| PG
    N8N -->|Archive HTML| Blob
    PG -->|Incremental Sync<br/>Every 15min| AISearch
    PG -->|Direct Query<br/>Fallback| FastAPI
    AISearch -->|Hybrid Search| FastAPI
    Redis -->|Cache Responses| FastAPI
    FastAPI --> Framer
    Framer --> Sarah
    Framer --> Reza

    style PG fill:#4CAF50,color:#fff
    style N8N fill:#FF6B6B,color:#fff
    style OpenAI fill:#FFD93D,color:#000
    style AISearch fill:#6BCB77,color:#fff
\`\`\`

---

## 3. Layer 1: Ingestion Pipeline

### 3.1 Data Sources

| Source Type | Tool | Polling Frequency | Volume |
|-------------|------|-------------------|--------|
| RSS Feeds | Miniflux (self-hosted) | Every 15 minutes | 500 sources |
| Twitter/X | twitterapi.io (API) | Every 5 minutes | 200 accounts |

### 3.2 Ingestion Flow (Mermaid Sequence Diagram)

\`\`\`mermaid
sequenceDiagram
    participant RSS as RSS Feed
    participant Miniflux
    participant n8n as n8n Workflow
    participant PG as PostgreSQL
    participant OpenAI as Azure OpenAI
    participant Blob as Blob Storage

    RSS->>Miniflux: Poll every 15min
    Miniflux->>n8n: Webhook (new article)

    Note over n8n: Stage 1: Deduplication
    n8n->>PG: Check url_hash (SHA-256)
    alt Duplicate Found
        PG-->>n8n: EXISTS = true
        n8n->>n8n: Skip (log DUPLICATE_URL)
    else New Article
        PG-->>n8n: EXISTS = false

        Note over n8n: Stage 2: Language Filter
        n8n->>n8n: Detect language (langdetect)
        alt Not EN/FA/AR
            n8n->>n8n: Discard (log LANGUAGE_MISMATCH)
        else Supported Language

            Note over n8n: Stage 3: AI Processing
            n8n->>Blob: Store raw HTML (archive)
            n8n->>OpenAI: GPT-4o-mini (extract metadata)
            OpenAI-->>n8n: {author, entities, sentiment}
            n8n->>OpenAI: text-embedding-3-small (vectorize)
            OpenAI-->>n8n: embedding [512 dims]

            Note over n8n: Stage 4: Insert to DB
            n8n->>PG: INSERT INTO articles<br/>(status='pending')
            PG-->>n8n: article_id
        end
    end
\`\`\`

### 3.3 Deduplication Logic

**URL-based (Primary):**
\`\`\`sql
-- Fast hash check (indexed)
SELECT EXISTS(
    SELECT 1 FROM articles 
    WHERE url_hash = SHA256($1)
) AS is_duplicate;
\`\`\`

**Content-based (Secondary):**
\`\`\`sql
-- SimHash for near-duplicates (24h window)
SELECT id, content_hash 
FROM articles
WHERE simhash_distance(content_hash, $1) <= 3  -- Hamming distance
  AND created_at > NOW() - INTERVAL '24 hours'
LIMIT 1;
\`\`\`

### 3.4 n8n Workflow Configuration

**Key Nodes:**
1. **Webhook Trigger** - Receives Miniflux events
2. **Deduplication Check** - PostgreSQL query node
3. **Language Filter** - Function node (langdetect)
4. **GPT-4o-mini Extract** - HTTP Request to OpenAI
5. **Generate Embedding** - OpenAI API (text-embedding-3-small)
6. **Insert Article** - PostgreSQL insert node
7. **Error Handler** - Retry (3x) + Dead Letter Queue

**Performance Targets:**
- Processing time: **< 5 seconds per article** (P95)
- Batch size: **50 articles per run**
- Error rate: **< 2%** (network failures excluded)

---

## 4. Layer 2: AI Reasoning Engine

### 4.1 Trust Scoring Flow

\`\`\`mermaid
sequenceDiagram
    participant PG as PostgreSQL
    participant TS as Trust Scorer (Python)
    participant OpenAI as Azure OpenAI

    Note over TS: Triggered by processing_status='pending'

    TS->>PG: SELECT articles WHERE status='pending'
    PG-->>TS: article + source metadata

    Note over TS: Component 1: Base Score
    TS->>TS: base = 0.45 × source.basescore<br/>(e.g., HRANA=90 → 40.5 pts)

    Note over TS: Component 2: Provenance
    TS->>TS: Check: URL valid? Timestamp? Author?<br/>Max 20 points

    Note over TS: Component 3: Corroboration
    TS->>PG: Vector Search (HNSW)<br/>Find similar articles from OTHER sources
    PG-->>TS: 3 independent confirmations
    TS->>TS: corroboration = min(20, count × 7)

    Note over TS: Component 4: Transparency
    TS->>TS: source.transparency_score + item flags<br/>Max 15 points

    Note over TS: Component 5: Modifiers
    TS->>TS: Red flags (-18 max)<br/>Green flags (+11 max)

    Note over TS: Final Calculation
    TS->>TS: final = CLAMP(15, 95, Σ components)

    Note over TS: Generate Explanation
    TS->>OpenAI: GPT-4o-mini: "Explain why score=72"
    OpenAI-->>TS: "High credibility due to..."

    TS->>PG: INSERT INTO trust_signals<br/>(finalscore, breakdown, explanation)
    TS->>PG: UPDATE articles SET status='processed'
\`\`\`

**Formula:**
\`\`\`
FinalScore = CLAMP(15, 95, Base + Provenance + Corroboration + Transparency + Modifiers)

Where:
- Base          = 0.45 × source.basescore (0-45 pts)
- Provenance    = URL(6) + Timestamp(5) + Author(4) + Dateline(3) + Media(2) (0-20 pts)
- Corroboration = min(20, independent_confirmations × 7) (0-20 pts)
- Transparency  = source_level(9) + item_level(6) (0-15 pts)
- Modifiers     = RedFlags(-18 max) + GreenFlags(+11 max) (-18 to +11 pts)
\`\`\`

### 4.2 Narrative Clustering

**Algorithm: Hybrid (Vector + Logic)**

\`\`\`mermaid
flowchart TD
    Start[New Article Processed] --> GetVec[Get article.embedding]
    GetVec --> VecSearch[pgvector HNSW Search<br/>Find similar clusters]
    VecSearch --> CheckSim{Cosine Similarity<br/> > 0.85?}

    CheckSim -->|Yes| Assign[Assign to Cluster]
    CheckSim -->|No| CheckMedium{Similarity > 0.75<br/>AND<br/>Entity Overlap ≥ 2?}

    CheckMedium -->|Yes| Assign
    CheckMedium -->|No| CheckTime{Within 7-day<br/>window?}

    CheckTime -->|Yes| GPTDecide[Ask GPT-4o-mini:<br/>"Is this same event?"]
    CheckTime -->|No| NewCluster[Create New Narrative]

    GPTDecide -->|Yes| Assign
    GPTDecide -->|No| NewCluster

    Assign --> UpdateCentroid[Update cluster.embedding<br/>Recalculate centroid]
    NewCluster --> GenTitle[GPT-4o-mini:<br/>Generate narrative title]
    GenTitle --> Done[Done]
    UpdateCentroid --> Done
\`\`\`

**Key Parameters:**
- **High similarity threshold:** 0.85 (auto-merge)
- **Medium similarity + entities:** 0.75 + 2 shared entities
- **Time window:** 7 days (protests) | 3 days (normal news)
- **Clustering frequency:** After each article ingestion

---

## 5. Layer 3: Persistence Layer

### 5.1 PostgreSQL Schema (Source of Truth)

**Core Tables:**

\`\`\`sql
-- Table 1: articles (main content)
CREATE TABLE articles (
    id UUID PRIMARY KEY,
    url_hash TEXT UNIQUE,
    source_id INT REFERENCES sources(id),
    title TEXT,
    content TEXT,
    published_at TIMESTAMPTZ,

    ai_metadata JSONB DEFAULT '{}',
    trust_score FLOAT CHECK (trust_score BETWEEN 0 AND 100),
    embedding VECTOR(512),  -- Reduced from 1536 for cost

    processing_status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 2: trust_signals (scoring details)
CREATE TABLE trust_signals (
    id UUID PRIMARY KEY,
    article_id UUID REFERENCES articles(id),
    finalscore INT CHECK (finalscore BETWEEN 15 AND 95),
    breakdown JSONB,  -- {base: 40, provenance: 18, ...}
    explanation TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 3: narratives (clusters)
CREATE TABLE narratives (
    id UUID PRIMARY KEY,
    title TEXT,
    summary TEXT,
    embedding VECTOR(512),  -- Centroid
    article_count INT DEFAULT 0,
    last_updated_at TIMESTAMPTZ
);

-- Table 4: article_narratives (many-to-many)
CREATE TABLE article_narratives (
    article_id UUID REFERENCES articles(id),
    narrative_id UUID REFERENCES narratives(id),
    similarity_score FLOAT,
    PRIMARY KEY (article_id, narrative_id)
);
\`\`\`

**Indexes:**
\`\`\`sql
-- HNSW for vector search
CREATE INDEX idx_articles_embedding ON articles 
    USING hnsw (embedding vector_cosine_ops) 
    WITH (m = 16, ef_construction = 64);

-- GIN for JSONB queries
CREATE INDEX idx_articles_metadata ON articles 
    USING GIN (ai_metadata jsonb_path_ops);

-- Composite for feed queries
CREATE INDEX idx_articles_trust_date ON articles 
    (trust_score DESC, published_at DESC);

-- Partial for n8n workflow
CREATE INDEX idx_articles_pending ON articles(processing_status) 
    WHERE processing_status = 'pending';
\`\`\`

### 5.2 Data Sync: PostgreSQL → Azure AI Search

**Why Sync?**
- Azure AI Search provides **Hybrid Search** (keyword + semantic)
- Offloads read traffic from PostgreSQL
- Optimized for user-facing queries

**Sync Strategy (via n8n):**

\`\`\`mermaid
sequenceDiagram
    participant n8n
    participant Redis as Redis (State)
    participant PG as PostgreSQL
    participant AIS as Azure AI Search

    Note over n8n: Triggered every 15 minutes

    n8n->>Redis: GET sync:last_run
    Redis-->>n8n: "2026-02-03 10:45:00"

    n8n->>PG: SELECT * FROM articles<br/>WHERE updated_at > last_run<br/>AND trust_score >= 50<br/>AND published_at > NOW() - 14 days
    PG-->>n8n: 175 articles (delta)

    Note over n8n: Transform (remove bodytext, truncate)
    n8n->>n8n: Batch into groups of 100

    n8n->>AIS: POST /indexes/nura-items/docs/index<br/>Action: mergeOrUpload
    AIS-->>n8n: 200 OK (indexed)

    n8n->>Redis: SET sync:last_run = NOW()
    n8n->>Redis: INCR sync:items_today BY 175

    Note over n8n: Daily Cleanup (2 AM)
    n8n->>AIS: DELETE documents older than 14 days<br/>OR trust_score < 50
    AIS-->>n8n: 500 docs deleted
\`\`\`

**Constraints (Free Tier → Basic Upgrade):**
- **Storage:** 50 MB (Free) → 2 GB (Basic)
- **Documents:** 10,000 (Free) → 1M (Basic)
- **Our Usage:** ~4,200 docs, 28 MB (within limits)

---

## 6. Layer 4: Presentation (API + UI)

### 6.1 FastAPI Gateway Endpoints

| Endpoint | Method | Purpose | Data Source |
|----------|--------|---------|-------------|
| `/api/v1/feed` | GET | Narrative list (homepage) | Azure AI Search (cached) |
| `/api/v1/items/:id` | GET | Article detail + Trust Breakdown | PostgreSQL (direct) |
| `/api/v1/narratives/:id` | GET | Cluster view + timeline | PostgreSQL + AI Search |
| `/api/v1/sources/:id` | GET | Source profile | PostgreSQL (cached) |

**Query Flow Example (Feed Endpoint):**

\`\`\`mermaid
sequenceDiagram
    participant User as User (Sarah)
    participant Framer
    participant FastAPI
    participant Redis
    participant AIS as Azure AI Search
    participant PG as PostgreSQL

    User->>Framer: Visit homepage
    Framer->>FastAPI: GET /api/v1/feed?limit=20&language=en

    FastAPI->>Redis: GET cache:feed:en:20
    alt Cache Hit
        Redis-->>FastAPI: Cached JSON
        FastAPI-->>Framer: 200 OK (< 100ms)
    else Cache Miss
        Redis-->>FastAPI: null

        FastAPI->>AIS: Hybrid Search (keyword + semantic)<br/>Filter: trust_score >= 40, language=en
        AIS-->>FastAPI: 20 narratives (< 300ms)

        FastAPI->>Redis: SET cache:feed:en:20 (TTL=2min)
        FastAPI-->>Framer: 200 OK
    end

    Framer->>Framer: Render Trust Badges (color-coded)
    User->>Framer: Click badge
    Framer->>FastAPI: GET /api/v1/items/:id

    FastAPI->>PG: SELECT articles JOIN trust_signals<br/>WHERE id = :id
    PG-->>FastAPI: Full article + breakdown
    FastAPI-->>Framer: 200 OK (< 200ms)

    Framer->>Framer: Show Trust Breakdown Modal
\`\`\`

### 6.2 Framer UI Components

**Key UI Elements (Ref: design-trust-narrative-system-v1.0.md):**

1. **Trust Badge** (System 1: 3-second assessment)
   - Color-coded: Green (70-95), Yellow (40-69), Red (15-39)
   - Clickable → Opens Breakdown Modal

2. **Trust Breakdown Modal** (System 2: 30-second analysis)
   - 4 horizontal progress bars (Base, Provenance, Corroboration, Transparency)
   - Warnings/Red flags
   - "Learn More" link to methodology

3. **Narrative Cluster View** (2-5 minute exploration)
   - Timeline of articles
   - Trust Distribution pie chart
   - Propaganda Alert banner (for regime sources)

---

## 7. Data Flow Metrics & Performance

### 7.1 Latency Targets

| Stage | Target (P95) | Measurement |
|-------|--------------|-------------|
| Ingestion (per article) | < 5 seconds | n8n logs |
| Trust Score Calculation | < 60 seconds | Application logs |
| Vector Search (HNSW) | < 300 ms | PostgreSQL EXPLAIN ANALYZE |
| API Response (/feed) | < 500 ms | FastAPI metrics |
| UI First Paint | < 1.5 seconds | Lighthouse |

### 7.2 Data Volume (MVP)

| Metric | Daily | Monthly | Storage |
|--------|-------|---------|---------|
| Articles Ingested | 5,000 | 150,000 | 750 MB (text) |
| Embeddings (512d) | 5,000 | 150,000 | 1.2 GB (vectors) |
| Raw HTML Archived | 5,000 | 150,000 | 10 GB (Blob) |
| AI Search Index | 4,200 | - | 28 MB |

### 7.3 Cost Breakdown (Monthly)

| Component | Cost | Justification |
|-----------|------|---------------|
| Azure OpenAI (GPT-4o-mini) | $100 | 5K articles × 2K tokens × $0.15/1M |
| PostgreSQL (B2s) | $35 | Burstable tier (2 vCore, 4GB) |
| Azure AI Search (Basic) | $75 | Hybrid Search (keyword + semantic) |
| Blob Storage (Hot/Cool) | $10 | 10GB Hot + 50GB Cool |
| Container Apps (n8n, FastAPI) | $40 | 3 containers × 0.5 CPU |
| **Total** | **$295/month** | 17-month runway with $5K budget |

---

## 8. Error Handling & Resilience

### 8.1 Retry Strategy (n8n)

\`\`\`javascript
{
  "retryOnFail": true,
  "maxTries": 3,
  "waitBetweenTries": 1000,  // Start with 1 second
  "retryBackoff": "exponential"  // 1s → 2s → 4s
}
\`\`\`

### 8.2 Dead Letter Queue (DLQ)

**Failed Articles:**
- Stored in Redis list: `sync:failed_items` (TTL: 7 days)
- Manual replay via admin UI (Phase 2)

### 8.3 Monitoring & Alerts

| Alert | Condition | Action |
|-------|-----------|--------|
| High Error Rate | > 5% failures in 15min | Slack notification |
| Vector Index Slow | Query time > 500ms | Reindex + Vacuum |
| AI Search Full | Storage > 90% (45 MB) | Auto-cleanup + PagerDuty |
| PostgreSQL Down | Connection timeout | PagerDuty + Failover |

---

## 9. Security & Compliance

### 9.1 Data Privacy

- **PII Handling:** No user data stored in MVP (public feed only)
- **Encryption at Rest:** TDE (Transparent Data Encryption) enabled on PostgreSQL
- **Encryption in Transit:** HTTPS/TLS 1.3 for all API calls
- **Access Control:** Azure Managed Identity (no hardcoded secrets)

### 9.2 Rate Limiting

| Endpoint | Limit | Method |
|----------|-------|--------|
| `/api/v1/feed` | 100 req/min per IP | Cloudflare |
| `/api/v1/items/:id` | 200 req/min per IP | Cloudflare |
| OpenAI API | 500K tokens/day | Built-in |

---

## 10. Future Enhancements (Phase 2)

1. **Real-time Streaming:** Replace 15-min polling with WebSockets (for breaking news)
2. **Multi-tenancy:** User accounts + personalized feeds
3. **Advanced Analytics:** Propaganda trend dashboards
4. **Mobile Apps:** iOS/Android with offline mode
5. **RAG Chat:** Conversational interface over narratives

---

## 11. Traceability Matrix

| Data Flow Stage | Requirement ID | Design Doc | Implementation |
|-----------------|----------------|------------|----------------|
| Ingestion | REQ-ING-001 | HLD-v2.0 § 2.1 | n8n workflow |
| Trust Scoring | REQ-AI-001 | SRS-v2.4 § 2.2.1 | TrustScorer.py |
| Narrative Clustering | REQ-AI-002 | HLD-v2.0 § 3.3 | ClusterEngine.py |
| API Gateway | REQ-API-001 | SRS-v2.4 § 2.3.1 | FastAPI routes |
| UI Components | REQ-UI-001 | design-trust-narrative-system-v1.0 | Framer components |

---

## 12. Approval & Sign-off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| **Software Architect** | Amir | ✅ Approved | 2026-02-03 |
| **Database Specialist** | Reyhaneh | ✅ Approved | 2026-02-03 |
| **AI Engineer** | Navid | ✅ Approved | 2026-02-03 |
| **Automation Lead** | Saman | ✅ Approved | 2026-02-03 |
| **Product Owner** | [Your Name] | ⏳ Pending | - |

---

## 13. References

- **[HLD-v2.0](hld-nura-v2.0.md):** High-Level Design (Architecture)
- **[SRS-v2.4](srs-nura-v2.4.md):** Software Requirements Specification
- **[Schema](schema-v1.0-mvp.sql):** PostgreSQL Database Schema
- **[UX Design](design-trust-narrative-system-v1.0.md):** Trust Badge & Modal UI
- **[Sync Workflow](workflow-pg-to-ai-search-sync-v1.0.md):** PG → AI Search

---

**Document Status:** ✅ **APPROVED** - Ready for Implementation  
**Last Updated:** Tuesday, February 3, 2026, 11:29 PM NZDT  
**File:** `docs/data-flow-architecture-v1.0.md`

---

**Next Steps:**
1. ✅ Database schema finalized → Migrate to Azure PostgreSQL
2. 🔄 n8n workflows → Deploy ingestion pipeline
3. 🔄 FastAPI endpoints → Implement /feed and /items/:id
4. 🔄 Framer UI → Build Trust Badge component

**Questions?** Escalate to **Amir (Architecture)** or **Product Owner**.
