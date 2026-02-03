# Technical Blueprint Document: Nura Neural MVP

**Version:** 1.0  
**Created:** February 1, 2026  
**Sprint Duration:** 48 hours  
**Target Completion:** February 3, 2026

---

## TBD-1: Requirements Registry

### Functional Requirements (FR-XXX)

| ID | Category | Requirement | Priority | MVP Scope |
|----|----------|-------------|----------|-----------|
| FR-001 | Ingestion | Poll Miniflux API for unread items every 15 minutes | P0 | ✅ |
| FR-002 | Ingestion | Extract clean text from URLs via SMRY service | P0 | ✅ |
| FR-003 | Ingestion | Store content in PostgreSQL with language detection | P0 | ✅ |
| FR-004 | Ingestion | Store raw HTML in Azure Blob Storage | P1 | ✅ |
| FR-005 | Ingestion | Support Farsi, Arabic, English content | P0 | ✅ |
| FR-006 | Ingestion | Detect text direction (RTL/LTR) | P1 | ✅ |
| FR-007 | Ingestion | Poll TwitterAPI.io for regime account tweets | P1 | ❌ Phase 2 |
| FR-008 | Ingestion | Search TwitterAPI.io for Farsi/Arabic keywords | P1 | ❌ Phase 2 |
| FR-009 | Analysis | Evaluate sources using IMTT framework | P0 | ✅ |
| FR-010 | Analysis | Score Identity pillar (ownership, funding) | P0 | ✅ |
| FR-011 | Analysis | Score Motivation pillar (editorial independence) | P0 | ✅ |
| FR-012 | Analysis | Score Transparency pillar (corrections, sourcing) | P0 | ✅ |
| FR-013 | Analysis | Score Track Record pillar (historical accuracy) | P0 | ✅ |
| FR-014 | Analysis | Calculate composite credibility score | P0 | ✅ |
| FR-015 | Analysis | Assign credibility tier (propaganda/unverified/credible) | P0 | ✅ |
| FR-016 | Analysis | Extract claims from content | P0 | ✅ |
| FR-017 | Analysis | Translate claims to English | P0 | ✅ |
| FR-018 | Analysis | Classify claim type (concrete/narrative) | P1 | ✅ |
| FR-019 | Analysis | Generate embeddings for claims | P0 | ✅ |
| FR-020 | Clustering | Index claims in Azure AI Search | P0 | ✅ |
| FR-021 | Clustering | Cluster related claims into narratives | P0 | ✅ |
| FR-022 | Clustering | Cross-language narrative clustering | P0 | ✅ |
| FR-023 | Clustering | Track narrative evolution over time | P1 | ✅ |
| FR-024 | Clustering | Generate narrative labels in English | P0 | ✅ |
| FR-025 | Clustering | Detect propaganda patterns | P0 | ✅ |
| FR-026 | API | Expose /webhook/credibility endpoint | P0 | ✅ |
| FR-027 | API | Expose /webhook/narratives endpoint | P0 | ✅ |
| FR-028 | API | Expose /webhook/narratives/:id endpoint | P1 | ✅ |
| FR-029 | API | Expose /webhook/fact-check endpoint | P1 | ❌ Phase 2 |
| FR-030 | API | Expose /webhook/search endpoint | P1 | ❌ Phase 2 |
| FR-031 | API | Cache API responses in Redis | P1 | ✅ |
| FR-032 | Escalation | Flag low-confidence evaluations | P2 | ❌ Phase 2 |
| FR-033 | Escalation | Route to o4-mini for deep analysis | P2 | ❌ Phase 2 |
| FR-034 | Escalation | Human review queue for contested cases | P2 | ❌ Phase 2 |

### Non-Functional Requirements (NFR-XXX)

| ID | Category | Requirement | Target | Measurement |
|----|----------|-------------|--------|-------------|
| NFR-001 | Performance | Ingestion workflow cycle time | <5 min | n8n execution time |
| NFR-002 | Performance | IMTT evaluation latency | <30s | GPT-4o response time |
| NFR-003 | Performance | API response time (cached) | <1s | Redis hit latency |
| NFR-004 | Performance | API response time (fresh) | <3s | PostgreSQL + format |
| NFR-005 | Performance | Embedding generation | <2s per claim | Azure OpenAI latency |
| NFR-006 | Accuracy | IMTT scoring accuracy | ≥80% | Human evaluation sample |
| NFR-007 | Accuracy | Claim extraction recall | ≥75% | Manual review |
| NFR-008 | Accuracy | Narrative clustering precision | ≥70% | Cluster quality audit |
| NFR-009 | Accuracy | Farsi/Arabic comprehension | ≥85% | Native speaker review |
| NFR-010 | Reliability | Workflow success rate | ≥95% | n8n execution logs |
| NFR-011 | Reliability | Database uptime | ≥99.9% | Azure SLA |
| NFR-012 | Reliability | API availability | ≥99% | Front Door metrics |
| NFR-013 | Scale | Content items per day | 500+ | Database row count |
| NFR-014 | Scale | Claims extracted per day | 1,000+ | Database row count |
| NFR-015 | Scale | Concurrent API requests | 50 | Load test |
| NFR-016 | Cost | Monthly LLM spend | <$250 | Azure billing |
| NFR-017 | Cost | Monthly infrastructure | <$350 | Azure billing |
| NFR-018 | Security | API authentication | Key-based | Header validation |
| NFR-019 | Security | Data encryption at rest | AES-256 | Azure managed |
| NFR-020 | Security | Data encryption in transit | TLS 1.3 | Front Door config |

---

## TBD-2: n8n Workflow Specifications

### WF-01: Ingestion Pipeline

| Attribute | Value |
|-----------|-------|
| **File** | `workflows/01_ingestion.json` |
| **Trigger** | Schedule: Every 15 minutes |
| **Input** | Miniflux API unread items |
| **Output** | PostgreSQL `content` table + Blob Storage |
| **Requirements** | FR-001, FR-002, FR-003, FR-004, FR-005, FR-006 |
| **LLM** | None (text extraction only) |

**Node Sequence:**
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Schedule   │───▶│  Miniflux   │───▶│   Filter    │───▶│    Loop     │
│  (15 min)   │    │  GET /items │    │  (unread)   │    │  (each item)│
└─────────────┘    └─────────────┘    └─────────────┘    └──────┬──────┘
                                                                │
       ┌────────────────────────────────────────────────────────┘
       ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    SMRY     │───▶│  Detect     │───▶│  PostgreSQL │───▶│    Blob     │
│  Extract    │    │  Language   │    │   INSERT    │    │   Upload    │
└─────────────┘    └─────────────┘    └─────────────┘    └──────┬──────┘
                                                                │
       ┌────────────────────────────────────────────────────────┘
       ▼
┌─────────────┐    ┌─────────────┐
│  Miniflux   │───▶│   Summary   │
│ Mark Read   │    │   Stats     │
└─────────────┘    └─────────────┘
```

**n8n Nodes Required:**
1. `Schedule Trigger` - Cron: `*/15 * * * *`
2. `HTTP Request` - GET Miniflux `/v1/entries?status=unread`
3. `IF` - Filter items with valid URLs
4. `Loop Over Items` - Process each entry
5. `HTTP Request` - POST to SMRY `/extract`
6. `Code` - Detect language (franc library or GPT)
7. `PostgreSQL` - INSERT into `content` table
8. `Azure Blob` - Upload raw HTML
9. `HTTP Request` - PUT Miniflux mark as read
10. `Code` - Aggregate stats for logging

---

### WF-02: Agent 1 - Source Evaluation (IMTT)

| Attribute | Value |
|-----------|-------|
| **File** | `workflows/02_agent_source.json` |
| **Trigger** | Webhook: Called by WF-01 after insert |
| **Input** | `content_id` from ingestion |
| **Output** | PostgreSQL `source_evaluations` + `claims` tables |
| **Requirements** | FR-009 through FR-018 |
| **LLM** | GPT-4o (Azure OpenAI) |

**Node Sequence:**
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Webhook    │───▶│  PostgreSQL │───▶│  Check      │───▶│  GPT-4o     │
│  Trigger    │    │  GET content│    │  Source     │    │  IMTT Eval  │
└─────────────┘    └─────────────┘    └─────────────┘    └──────┬──────┘
                                                                │
       ┌────────────────────────────────────────────────────────┘
       ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  PostgreSQL │───▶│  GPT-4o     │───▶│  PostgreSQL │───▶│  Trigger    │
│  Save IMTT  │    │  Claims Ext │    │  Save Claims│    │  WF-03      │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

**n8n Nodes Required:**
1. `Webhook` - POST `/webhook/evaluate-source`
2. `PostgreSQL` - SELECT content + source data
3. `IF` - Check if source needs re-evaluation (>7 days)
4. `OpenAI` - GPT-4o IMTT scoring prompt
5. `Code` - Parse IMTT JSON response
6. `PostgreSQL` - UPSERT `source_evaluations`
7. `OpenAI` - GPT-4o claim extraction prompt
8. `Code` - Parse claims array
9. `PostgreSQL` - INSERT INTO `claims`
10. `HTTP Request` - Trigger WF-03 for clustering

**IMTT Prompt Template:**
```
You are evaluating the credibility of a news source using the IMTT framework.

Source: {{source_name}} ({{source_domain}})
Country: {{country}}
Sample Content: {{content_text}}

Score each pillar from 0.0 to 1.0:

1. IDENTITY (0.0-1.0): Who owns/funds this source?
   - State-owned/controlled = 0.0-0.2
   - Opaque ownership = 0.2-0.4
   - Clear independent ownership = 0.6-1.0

2. MOTIVATION (0.0-1.0): What drives editorial decisions?
   - Propaganda mission = 0.0-0.2
   - Commercial/political bias = 0.2-0.5
   - Journalistic mission = 0.6-1.0

3. TRANSPARENCY (0.0-1.0): How transparent is their process?
   - No sourcing/corrections = 0.0-0.2
   - Partial transparency = 0.3-0.5
   - Full sourcing + corrections policy = 0.7-1.0

4. TRACK RECORD (0.0-1.0): Historical accuracy?
   - Known disinformation = 0.0-0.2
   - Mixed record = 0.3-0.5
   - Consistent accuracy = 0.7-1.0

Return JSON:
{
  "identity": {"score": 0.0, "reasoning": "..."},
  "motivation": {"score": 0.0, "reasoning": "..."},
  "transparency": {"score": 0.0, "reasoning": "..."},
  "track_record": {"score": 0.0, "reasoning": "..."},
  "composite_score": 0.0,
  "tier": "propaganda|unverified|credible"
}
```

---

### WF-03: Agent 2 - Narrative Clustering

| Attribute | Value |
|-----------|-------|
| **File** | `workflows/03_agent_narrative.json` |
| **Trigger** | Schedule: Every 6 hours + Webhook from WF-02 |
| **Input** | Unclustered claims from PostgreSQL |
| **Output** | Azure AI Search index + PostgreSQL `narratives` |
| **Requirements** | FR-019 through FR-025 |
| **LLM** | GPT-4o + text-embedding-3-large |

**Node Sequence:**
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Schedule   │───▶│  PostgreSQL │───▶│  OpenAI     │───▶│  Azure AI   │
│  (6 hours)  │    │  GET claims │    │  Embeddings │    │  Search     │
└─────────────┘    └─────────────┘    └─────────────┘    └──────┬──────┘
                                                                │
       ┌────────────────────────────────────────────────────────┘
       ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Search     │───▶│  GPT-4o     │───▶│  PostgreSQL │───▶│  Update     │
│  Similar    │    │  Cluster    │    │  Narratives │    │  Claims FK  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

**n8n Nodes Required:**
1. `Schedule Trigger` - Cron: `0 */6 * * *`
2. `PostgreSQL` - SELECT unclustered claims
3. `Loop Over Items` - Process each claim
4. `OpenAI` - Generate embedding (text-embedding-3-large)
5. `HTTP Request` - POST to Azure AI Search (upsert document)
6. `HTTP Request` - POST to Azure AI Search (vector search)
7. `Code` - Group similar claims (cosine similarity > 0.85)
8. `OpenAI` - GPT-4o narrative labeling prompt
9. `PostgreSQL` - UPSERT `narratives` table
10. `PostgreSQL` - UPDATE `claims` with `narrative_id`

---

### WF-04: Escalation Handler (Phase 2)

| Attribute | Value |
|-----------|-------|
| **File** | `workflows/04_escalation.json` |
| **Trigger** | Webhook from WF-02/WF-03 on low confidence |
| **Input** | `evaluation_id` or `claim_id` |
| **Output** | PostgreSQL `escalations` table |
| **Requirements** | FR-032, FR-033, FR-034 |
| **LLM** | o4-mini (deep reasoning) |
| **Status** | ❌ **Deferred to Phase 2** |

---

### WF-05: Public API Endpoints

| Attribute | Value |
|-----------|-------|
| **File** | `workflows/05_public_api.json` |
| **Trigger** | Webhook (multiple endpoints) |
| **Input** | HTTP requests from widgets |
| **Output** | JSON responses |
| **Requirements** | FR-026, FR-027, FR-028, FR-031 |
| **LLM** | GPT-4.1-mini (response formatting) |

**Endpoints Implemented:**

| Path | Method | Description |
|------|--------|-------------|
| `/webhook/credibility` | GET | Source credibility by domain |
| `/webhook/narratives` | GET | List trending narratives |
| `/webhook/narratives/:id` | GET | Narrative detail |

**Node Sequence (Credibility Endpoint):**
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Webhook    │───▶│   Redis     │───▶│  PostgreSQL │───▶│   Format    │
│  GET        │    │  Check Cache│    │  Query      │    │   Response  │
└─────────────┘    └─────────────┘    └─────────────┘    └──────┬──────┘
                                                                │
       ┌────────────────────────────────────────────────────────┘
       ▼
┌─────────────┐    ┌─────────────┐
│   Redis     │───▶│   Respond   │
│  Set Cache  │    │   Webhook   │
└─────────────┘    └─────────────┘
```

---

## TBD-3: Resource Configuration

### Deployed Resources (Ready)

| Resource | Type | Status | Action |
|----------|------|--------|--------|
| `irdecode-prod-n8n` | Container App | ✅ Running | Configure credentials |
| `irdecode-prod-psql` | PostgreSQL | ✅ Running | Apply schema.sql |
| `nura-miniflux` | Container App | ✅ Running | Add RSS feeds |
| `nura-rsshub` | Container App | ✅ Running | None |
| `nura-redis` | Container App | ✅ Running | None |
| `nura-search` | Azure AI Search | ✅ Running | Create indexes |
| `irdecode-prod-openai` | Azure OpenAI | ✅ Running | Verify deployments |
| `irdecode-prod-kv` | Key Vault | ✅ Running | Verify secrets |
| `irdecodeprodst` | Storage Account | ✅ Running | Create containers |

### Failed Resources (Fix Required)

| Resource | Type | Status | Fix Action |
|----------|------|--------|------------|
| `nura-smry` | Container App | ❌ Failed | Update image to ACR built version |

### Resources to Create

| Resource | Type | Action |
|----------|------|--------|
| `nura-content` | AI Search Index | Create with vector field |
| `nura-claims` | AI Search Index | Create with vector field |
| `content` | Blob Container | Create in storage account |
| `raw-html` | Blob Container | Create in storage account |

### n8n Credentials to Configure

| Credential | Type | Source |
|------------|------|--------|
| PostgreSQL | Database | `irdecode-prod-psql` connection string |
| Azure OpenAI | API | `irdecode-prod-openai` endpoint + key |
| Azure Blob | Storage | `irdecodeprodst` connection string |
| Azure AI Search | Search | `nura-search` endpoint + key |
| Redis | Cache | `nura-redis` internal URL |
| Miniflux | HTTP | Internal URL + API key |
| TwitterAPI.io | HTTP | Key Vault: `nura-twitterapi-io-key` |

---

## TBD-4: Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              EXTERNAL SOURCES                               │
│                                                                             │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│   │  RSS Feeds  │    │   RSSHub    │    │ TwitterAPI  │    │  Manual     │  │
│   │  (50+ Iran) │    │ (scraped)   │    │ (Phase 2)   │    │  Submit     │  │
│   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘  │
│          │                  │                  │                  │         │
└──────────┼──────────────────┼──────────────────┼──────────────────┼─────────┘
           │                  │                  │                  │
           ▼                  ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INGESTION LAYER                                │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                         WF-01: Ingestion                            │   │
│   │  Miniflux ──▶ SMRY ──▶ Language Detect ──▶ PostgreSQL + Blob       │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                      │
└──────────────────────────────────────┼──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              STORAGE LAYER                                  │
│                                                                             │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│   │ PostgreSQL  │    │ Azure Blob  │    │  Azure AI   │    │    Redis    │  │
│   │  - content  │    │  - raw-html │    │   Search    │    │   (cache)   │  │
│   │  - claims   │    │  - content  │    │  - vectors  │    │             │  │
│   │  - sources  │    │             │    │  - hybrid   │    │             │  │
│   │  - narratives│   │             │    │             │    │             │  │
│   └──────┬──────┘    └─────────────┘    └──────┬──────┘    └─────────────┘  │
│          │                                     │                            │
└──────────┼─────────────────────────────────────┼────────────────────────────┘
           │                                     │
           ▼                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              ANALYSIS LAYER                                 │
│                                                                             │
│   ┌─────────────────────────────────┐    ┌─────────────────────────────────┐│
│   │     WF-02: Agent 1 (GPT-4o)     │    │     WF-03: Agent 2 (GPT-4o)     ││
│   │  - IMTT source evaluation       │    │  - Embedding generation         ││
│   │  - Claim extraction             │    │  - Vector similarity search     ││
│   │  - Credibility scoring          │───▶│  - Narrative clustering         ││
│   │  - Tier assignment              │    │  - Label generation             ││
│   └─────────────────────────────────┘    └─────────────────────────────────┘│
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              SERVING LAYER                                  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                      WF-05: Public API                              │   │
│   │  /credibility ──▶ Redis Cache ──▶ PostgreSQL ──▶ JSON Response     │   │
│   │  /narratives  ──▶ Redis Cache ──▶ PostgreSQL ──▶ JSON Response     │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                      │
│                                      ▼                                      │
│                            ┌─────────────────┐                              │
│                            │  Azure Front    │                              │
│                            │     Door        │                              │
│                            └────────┬────────┘                              │
│                                     │                                       │
└─────────────────────────────────────┼───────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CONSUMER LAYER                                 │
│                                                                             │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│   │  IRdecode   │    │  Embedded   │    │  Analyst    │    │  API        │  │
│   │  Newsroom   │    │  Widgets    │    │  Dashboard  │    │  Consumers  │  │
│   └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## TBD-5: 48-Hour Task Backlog

| Hour | Task ID | Description | Deliverable | Dependencies |
|------|---------|-------------|-------------|--------------|
| 0-1 | TASK-01 | Project context analysis | Understanding confirmed | None |
| 1-3 | TASK-02 | Create Technical Blueprint | This document | TASK-01 |
| 3-4 | TASK-03 | Fix SMRY container | `nura-smry` running | None |
| 4-6 | TASK-04 | Apply schema.sql to PostgreSQL | Database tables created | TASK-03 |
| 6-8 | TASK-05 | Create Azure AI Search indexes | `nura-content`, `nura-claims` indexes | TASK-04 |
| 8-10 | TASK-06 | Configure n8n credentials | All credentials working | TASK-03, TASK-04 |
| 10-12 | TASK-07 | Seed Miniflux with Iran RSS feeds | 30+ feeds polling | TASK-06 |
| 12-18 | TASK-08 | Build WF-01: Ingestion | Workflow importing content | TASK-07 |
| 18-26 | TASK-09 | Build WF-02: Agent Source | IMTT scoring working | TASK-08 |
| 26-36 | TASK-10 | Build WF-03: Agent Narrative | Clustering working | TASK-09 |
| 36-42 | TASK-11 | Build WF-05: Public API | Endpoints responding | TASK-10 |
| 42-46 | TASK-12 | End-to-end testing | Full pipeline validated | TASK-11 |
| 46-48 | TASK-13 | Documentation + handoff | README updated | TASK-12 |

### Task Effort Estimates

| Task | Estimated Hours | Complexity | Risk |
|------|-----------------|------------|------|
| TASK-03 | 1h | Low | Low |
| TASK-04 | 2h | Low | Low |
| TASK-05 | 2h | Medium | Medium |
| TASK-06 | 2h | Low | Low |
| TASK-07 | 2h | Low | Low |
| TASK-08 | 6h | Medium | Medium |
| TASK-09 | 8h | High | High |
| TASK-10 | 10h | High | High |
| TASK-11 | 6h | Medium | Low |
| TASK-12 | 4h | Medium | Medium |
| TASK-13 | 2h | Low | Low |

---

## TBD-6: Risk Matrix

| Risk ID | Description | Probability | Impact | Severity | Mitigation |
|---------|-------------|-------------|--------|----------|------------|
| RISK-01 | SMRY container fails to start with new image | Low | High | 🟡 Medium | Test locally first; fallback to custom build |
| RISK-02 | Schema migration fails | Low | Critical | 🔴 High | Test on dev DB first; backup before apply |
| RISK-03 | GPT-4o Farsi/Arabic quality insufficient | Medium | High | 🔴 High | Test with sample content; adjust prompts |
| RISK-04 | Azure AI Search index schema wrong | Medium | High | 🟡 Medium | Validate schema before bulk insert |
| RISK-05 | n8n workflow complexity exceeds skill | Low | Medium | 🟡 Medium | Start simple; iterate; use code nodes |
| RISK-06 | Miniflux rate-limited by sources | Medium | Low | 🟢 Low | Spread feeds across time; respect robots.txt |
| RISK-07 | LLM costs exceed budget | Low | Medium | 🟡 Medium | Monitor usage; implement caching |
| RISK-08 | Embedding dimension mismatch | Low | High | 🟡 Medium | Verify 3072 dimensions in index schema |
| RISK-09 | Redis connection issues from n8n | Low | Medium | 🟡 Medium | Use internal DNS; test connectivity |
| RISK-10 | 48h timeline too aggressive | Medium | High | 🔴 High | Prioritize MVP scope; defer Phase 2 items |
| RISK-11 | Cross-language clustering fails | Medium | Medium | 🟡 Medium | Use multilingual embeddings; test thoroughly |

---

## TBD-7: Database Tables Reference

### Core Tables (WF-01: Ingestion)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `sources` | News source registry | `source_id`, `domain`, `credibility_tier` |
| `content` | Ingested articles | `content_id`, `source_id`, `title`, `content_text`, `language` |
| `content_raw` | Blob storage references | `content_id`, `blob_url`, `html_hash` |

### Analysis Tables (WF-02: Agent Source)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `source_evaluations` | IMTT scores | `evaluation_id`, `source_id`, `imtt_scores`, `tier` |
| `claims` | Extracted claims | `claim_id`, `content_id`, `claim_text`, `claim_text_en` |
| `claim_evidence` | Supporting evidence | `evidence_id`, `claim_id`, `evidence_type` |

### Clustering Tables (WF-03: Agent Narrative)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `narratives` | Clustered narratives | `narrative_id`, `label`, `cluster_size` |
| `narrative_claims` | Claim-narrative mapping | `narrative_id`, `claim_id`, `similarity_score` |
| `narrative_timeline` | Evolution tracking | `narrative_id`, `timestamp`, `event_type` |

### API Tables (WF-05: Public API)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `api_cache` | Response caching | `cache_key`, `response`, `expires_at` |
| `api_requests` | Request logging | `request_id`, `endpoint`, `timestamp` |

---

## TBD-8: Azure AI Search Index Schemas

### Index: `nura-content`

```json
{
  "name": "nura-content",
  "fields": [
    {"name": "id", "type": "Edm.String", "key": true},
    {"name": "content_id", "type": "Edm.String", "filterable": true},
    {"name": "source_id", "type": "Edm.String", "filterable": true},
    {"name": "title", "type": "Edm.String", "searchable": true, "analyzer": "standard.lucene"},
    {"name": "title_en", "type": "Edm.String", "searchable": true, "analyzer": "en.microsoft"},
    {"name": "content_text", "type": "Edm.String", "searchable": true},
    {"name": "language", "type": "Edm.String", "filterable": true, "facetable": true},
    {"name": "credibility_tier", "type": "Edm.String", "filterable": true, "facetable": true},
    {"name": "ingested_at", "type": "Edm.DateTimeOffset", "filterable": true, "sortable": true},
    {"name": "embedding", "type": "Collection(Edm.Single)", "dimensions": 3072, "vectorSearchProfile": "default"}
  ],
  "vectorSearch": {
    "profiles": [{"name": "default", "algorithm": "hnsw"}],
    "algorithms": [{"name": "hnsw", "kind": "hnsw", "hnswParameters": {"m": 4, "efConstruction": 400, "efSearch": 500, "metric": "cosine"}}]
  }
}
```

### Index: `nura-claims`

```json
{
  "name": "nura-claims",
  "fields": [
    {"name": "id", "type": "Edm.String", "key": true},
    {"name": "claim_id", "type": "Edm.String", "filterable": true},
    {"name": "content_id", "type": "Edm.String", "filterable": true},
    {"name": "narrative_id", "type": "Edm.String", "filterable": true},
    {"name": "claim_text", "type": "Edm.String", "searchable": true},
    {"name": "claim_text_en", "type": "Edm.String", "searchable": true, "analyzer": "en.microsoft"},
    {"name": "claim_type", "type": "Edm.String", "filterable": true, "facetable": true},
    {"name": "language", "type": "Edm.String", "filterable": true, "facetable": true},
    {"name": "source_credibility", "type": "Edm.String", "filterable": true},
    {"name": "extracted_at", "type": "Edm.DateTimeOffset", "filterable": true, "sortable": true},
    {"name": "embedding", "type": "Collection(Edm.Single)", "dimensions": 3072, "vectorSearchProfile": "default"}
  ],
  "vectorSearch": {
    "profiles": [{"name": "default", "algorithm": "hnsw"}],
    "algorithms": [{"name": "hnsw", "kind": "hnsw", "hnswParameters": {"m": 4, "efConstruction": 400, "efSearch": 500, "metric": "cosine"}}]
  }
}
```

---

## TBD-9: Cost Estimate (48-Hour Sprint)

| Component | Sprint Cost | Monthly Projection |
|-----------|-------------|-------------------|
| Azure OpenAI (GPT-4o) | ~$15 | ~$190 |
| Azure OpenAI (Embeddings) | ~$2 | ~$13 |
| Azure AI Search (Basic) | ~$5 | ~$75 |
| Container Apps (5 apps) | ~$4 | ~$60 |
| Storage (Blob) | <$1 | ~$5 |
| **Sprint Total** | **~$27** | - |
| **Monthly Total** | - | **~$343** |

---

## Appendix A: Key Vault Secrets Reference

| Secret Name | Purpose | Used By |
|-------------|---------|---------|
| `postgres-admin-password` | PostgreSQL admin password | n8n credentials |
| `openai-api-key` | Azure OpenAI API key | WF-02, WF-03, WF-05 |
| `nura-search-api-key` | Azure AI Search admin key | WF-03 |
| `storage-account-key` | Blob storage key | WF-01 |
| `miniflux-admin-password` | Miniflux admin password | WF-01 |
| `nura-twitterapi-io-key` | TwitterAPI.io key | WF-01 (Phase 2) |

---

## Appendix B: n8n Credential Types

| Credential Name | n8n Type | Configuration |
|-----------------|----------|---------------|
| `Nura PostgreSQL` | PostgreSQL | Host, Database, User, Password, SSL |
| `Nura Azure OpenAI` | OpenAI | API Key, Base URL (Azure endpoint) |
| `Nura Azure Blob` | Microsoft Azure Blob Storage | Connection String |
| `Nura AI Search` | HTTP Header Auth | api-key header |
| `Nura Miniflux` | HTTP Header Auth | X-Auth-Token header |
| `Nura Redis` | Redis | Host, Port, Password |

---

## Appendix C: External Service URLs

| Service | URL | Auth |
|---------|-----|------|
| n8n | `https://irdecode-prod-n8n.proudbeach-e6523ab9.australiaeast.azurecontainerapps.io` | Basic auth |
| Miniflux | `https://nura-miniflux.proudbeach-e6523ab9.australiaeast.azurecontainerapps.io` | Admin credentials |
| Azure AI Search | `https://nura-search.search.windows.net` | API key |
| Azure OpenAI | `https://irdecode-prod-openai.openai.azure.com` | API key |
| TwitterAPI.io | `https://api.twitterapi.io` | API key |

---

*End of Technical Blueprint Document*

**Next Steps:**
1. Fix SMRY container (TASK-03)
2. Apply database schema (TASK-04)
3. Create Azure AI Search indexes (TASK-05)
