# Software Requirements Specification (SRS)
## Nura Intelligence Platform - MVP v2.0

---

## Document Control

| Attribute | Details |
|-----------|---------|
| **Document Type** | Software Requirements Specification (IEEE 830) |
| **Version** | 2.0 |
| **Date** | 2026-02-04 |
| **Status** | Approved for Implementation |
| **Authors** | Product Team (Amir, Navid, Reyhaneh) |
| **Approvers** | Product Owner, System Architect, Domain Expert |
| **Related Docs** | MVP Scope v2.0, Workflow Architecture v1.0, AI Engineering Guide v1.0 |
| **Revision History** | v1.0 (2026-01-15): Initial draft with RAG Chat<br/>v2.0 (2026-02-04): Removed Chat/API, simplified architecture |

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Overall Description](#2-overall-description)
3. [Functional Requirements](#3-functional-requirements)
4. [Non-Functional Requirements](#4-non-functional-requirements)
5. [System Requirements](#5-system-requirements)
6. [Data Requirements](#6-data-requirements)
7. [Interface Requirements](#7-interface-requirements)
8. [Quality Attributes](#8-quality-attributes)
9. [Constraints](#9-constraints)
10. [Appendices](#10-appendices)

---

## 1. Introduction

### 1.1 Purpose

This Software Requirements Specification (SRS) document defines the complete functional and non-functional requirements for the **Nura Intelligence Platform MVP v2.0**. It is intended for:

- **Development Team**: Developers, workflow engineers, database architects
- **QA Team**: Test case design and acceptance testing
- **Product Owner**: Scope validation and sign-off
- **Domain Experts**: Methodology review and accuracy validation

### 1.2 Scope

**Product Name**: Nura Intelligence Platform  
**Product Version**: MVP v2.0  
**Product Type**: Intelligence Analysis Platform for Iranian Media

**In Scope for MVP v2.0**:
- Automated ingestion from RSS feeds and Twitter
- AI-powered translation (Farsi/Arabic → English)
- Transparent trust scoring (15-95 scale, 5 components)
- Narrative clustering (semantic similarity)
- Weekly proxy detection (state-controlled sources)
- Framer web interface (feed, item detail, narrative view)
- Real-time webhook updates (n8n → Framer)
- Monitoring and cost guardrails

**Out of Scope for MVP**:
- RAG chat interface (removed from v1.0)
- Public REST API with caching/rate limiting (removed)
- User authentication and personalized feeds
- Mobile applications (iOS/Android)
- Multi-language UI (RTL/Persian)
- Video content analysis
- Real-time push notifications via WebSocket

### 1.3 Definitions, Acronyms, Abbreviations

| Term | Definition |
|------|------------|
| **AOAI** | Azure OpenAI (Microsoft's managed OpenAI service) |
| **Corroboration** | Verification of facts by independent sources |
| **HNSW** | Hierarchical Navigable Small World (vector index algorithm) |
| **LLM** | Large Language Model (e.g., GPT-4) |
| **MVP** | Minimum Viable Product |
| **Narrative** | Semantic cluster of related news items about the same event |
| **pgvector** | PostgreSQL extension for vector similarity search |
| **Provenance** | Attribution and sourcing information for content |
| **Proxy Source** | Media outlet that appears independent but is state-controlled |
| **RAG** | Retrieval-Augmented Generation (LLM + search) |
| **SimHash** | Locality-sensitive hash for near-duplicate detection |
| **Trust Score** | Composite reliability metric (15-95 scale) |
| **Vector Embedding** | Numerical representation of text (3072 dimensions) |

### 1.4 References

| Reference | Description |
|-----------|-------------|
| **IEEE 830-1998** | IEEE Recommended Practice for Software Requirements Specifications |
| **MVP Scope v2.0** | Product scope definition and deliverables |
| **Workflow Architecture v1.0** | n8n workflow implementation guide |
| **AI Engineering Guide v1.0** | Prompts, schemas, cost optimization |
| **Database Schema v1.0** | PostgreSQL table definitions and indexes |

### 1.5 Overview

This SRS is organized into 10 sections:
- **Sections 1-2**: Context and system overview
- **Section 3**: Functional requirements (REQ-xxx-nnn format)
- **Section 4**: Non-functional requirements (performance, security, etc.)
- **Sections 5-7**: System, data, and interface specifications
- **Sections 8-9**: Quality attributes and constraints
- **Section 10**: Appendices (use cases, data dictionary)

---

## 2. Overall Description

### 2.1 Product Perspective

Nura is a **standalone intelligence platform** designed to address information asymmetry in Iranian media coverage. It combines:

- **Automated data ingestion** from 500 RSS feeds and 200 Twitter accounts
- **AI-powered enrichment** for translation and metadata extraction
- **Transparent trust scoring** using a 5-component algorithm
- **Narrative clustering** to group related reporting
- **Proxy detection** to identify state-controlled outlets masquerading as independent media

The system operates autonomously via **n8n workflows**, stores data in **PostgreSQL + pgvector**, and serves a **Framer web interface** for end users.

### 2.2 Product Functions

The system provides the following high-level functions:

1. **Content Collection** (WF1)
   - Poll RSS feeds via Miniflux
   - Poll Twitter accounts via API
   - Deduplicate using URL hash + SimHash
   - Archive raw HTML to Azure Blob Storage

2. **AI Enrichment** (WF2)
   - Translate non-English content to English
   - Extract structured metadata (author, entities, dateline)
   - Generate 3072-dimensional vector embeddings

3. **Trust Assessment** (WF3)
   - Calculate 5-component trust score (0-95 scale)
   - Generate human-readable explanations (template-based)
   - Store breakdown in trust_signals table

4. **Narrative Analysis** (WF4)
   - Cluster semantically similar items
   - Generate neutral titles and summaries
   - Flag propaganda-heavy narratives

5. **Proxy Detection** (WF5)
   - Analyze content overlap with regime media
   - Measure narrative alignment
   - Reclassify suspected proxies automatically

6. **System Monitoring** (WF6)
   - Track daily costs (target: < $1.00/day)
   - Monitor processing backlog
   - Alert on performance degradation

7. **Web Interface** (Framer)
   - Browse narrative feed with trust badges
   - View item details with full breakdown
   - Explore narrative clusters with timelines
   - Receive real-time updates via webhooks

### 2.3 User Characteristics

**Primary Users**:

| User Type | Characteristics | Technical Expertise | Use Cases |
|-----------|----------------|---------------------|-----------|
| **Iranian Diaspora** | Persian/English speakers outside Iran | Low-Medium | Stay informed about Iran events, verify news |
| **Journalists** | Investigating Iranian affairs | Medium-High | Source verification, story research |
| **Researchers** | Academic/think tank analysts | High | Trend analysis, propaganda research |
| **Human Rights Orgs** | NGOs monitoring Iran | Medium | Document abuse, track narratives |

**System Administrators** (Internal):
- Workflow engineers managing n8n
- Database administrators
- Domain experts reviewing proxy detection

### 2.4 Assumptions and Dependencies

**Assumptions**:
- Users have stable internet connection (≥5 Mbps)
- Users access via modern web browsers (Chrome, Firefox, Safari)
- Miniflux instance remains operational for RSS ingestion
- Azure OpenAI maintains <1% downtime
- Twitter API maintains rate limits (100 req/15min per account)

**Dependencies**:
- **External Services**: Miniflux, Twitter API, Azure OpenAI, Azure Blob Storage
- **Technology Stack**: PostgreSQL 16+, pgvector 0.5+, n8n 1.x, Framer
- **Data Sources**: 500 RSS feeds remain active, Twitter accounts not suspended
- **Infrastructure**: Azure subscription with $28/month budget

### 2.5 Constraints

**Budget Constraints**:
- Total monthly cost: ≤ $28/month
- AI costs: ≤ $20/month (translation + embeddings + narratives)
- Infrastructure: ≤ $8/month (PostgreSQL + Blob Storage)

**Time Constraints**:
- MVP delivery: 2 weeks from kickoff
- 6 workflows to be built in 12 working days
- UAT and launch in Week 2

**Technical Constraints**:
- PostgreSQL: Single instance (no replication in MVP)
- n8n: Self-hosted on existing Container App
- Framer: Free tier (1M function executions/month)
- No custom mobile apps (web-only)

**Regulatory Constraints**:
- GDPR compliance not required (no EU users in MVP)
- No PII storage (public content only)
- Transparent methodology (public documentation)

---

## 3. Functional Requirements

This section defines all functional requirements using the format: **REQ-[CATEGORY]-[NNN]**

### 3.1 Data Ingestion (REQ-ING)

#### REQ-ING-001: RSS Feed Polling

**Priority**: CRITICAL  
**Status**: Approved

**Description**: The system SHALL poll RSS feeds via Miniflux API every 15 minutes to retrieve new content.

**Inputs**:
- Miniflux API endpoint: `GET /v1/entries?status=unread&limit=100`
- Authentication: API key in HTTP header

**Processing**:
1. Retrieve unread entries (max 100 per poll)
2. Parse RSS fields: title, url, content, published_at, author
3. Extract source_id from feed_id mapping

**Outputs**:
- New items with `processing_status = 'PENDING'`
- Items stored in `items` table

**Acceptance Criteria**:
- [ ] Polling executes every 15 minutes (±30 seconds tolerance)
- [ ] 100% of entries successfully parsed
- [ ] P95 processing time: < 5 seconds per item
- [ ] Errors logged with source feed ID

**Related Requirements**: REQ-ING-003 (Deduplication)

---

#### REQ-ING-002: Twitter Account Polling

**Priority**: CRITICAL  
**Status**: Approved

**Description**: The system SHALL poll Twitter accounts via Twitter API v2 with priority-based intervals.

**Inputs**:
- Twitter List ID (high-priority sources)
- Twitter API endpoint: `GET /2/lists/{id}/tweets`
- Polling intervals:
  - High-priority accounts: Every 5 minutes
  - Standard accounts: Every 15 minutes

**Processing**:
1. Retrieve tweets with expansions (media, author)
2. Parse tweet fields: text, created_at, author_id, media_urls
3. Store media attachments as separate references

**Outputs**:
- New items with `source_type = 'TWITTER'`
- Media URLs archived to Azure Blob

**Acceptance Criteria**:
- [ ] High-priority accounts polled every 5 minutes
- [ ] Standard accounts polled every 15 minutes
- [ ] Media attachments archived (images, videos)
- [ ] Rate limit handling: 100 req/15min per list
- [ ] 429 errors trigger exponential backoff

**Related Requirements**: REQ-ING-001, REQ-ING-004

---

#### REQ-ING-003: Content Deduplication

**Priority**: CRITICAL  
**Status**: Approved

**Description**: The system SHALL detect and skip duplicate or near-duplicate content using URL hash and SimHash.

**Algorithm**:

```python
def is_duplicate(new_item):
    # Step 1: Exact duplicate check
    url_hash = sha256(new_item.url)
    existing = db.query("SELECT id, sim_hash FROM items WHERE url_hash = ?", url_hash)

    if not existing:
        return False  # New item

    # Step 2: Near-duplicate check (SimHash)
    hamming_distance = count_bit_differences(new_item.sim_hash, existing.sim_hash)
    similarity = 1 - (hamming_distance / 64)

    if similarity >= 0.95:
        return True  # Duplicate
    else:
        # Different enough - mark as reprint
        new_item.original_item_id = existing.id
        new_item.is_reprint = True
        return False
```

**Inputs**:
- `url`: Item URL
- `content`: Full text for SimHash calculation

**Outputs**:
- `url_hash`: SHA-256 hash (32 bytes)
- `sim_hash`: 64-bit locality-sensitive hash
- `is_reprint`: Boolean flag
- `original_item_id`: Reference to original (if reprint)

**Acceptance Criteria**:
- [ ] URL hash collision rate: 0%
- [ ] SimHash detects ≥95% similarity
- [ ] Duplicate rate: < 0.5% of total items
- [ ] Reprints correctly linked to original

**Related Requirements**: REQ-ING-001, REQ-ING-002

---

#### REQ-ING-004: HTML Archival

**Priority**: HIGH  
**Status**: Approved

**Description**: The system SHALL archive raw HTML content to Azure Blob Storage with tiered retention.

**Storage Tiers**:
- **Hot** (0-30 days): Immediate access
- **Cool** (31-90 days): 1-minute retrieval
- **Cold** (90+ days): 1-hour retrieval

**Inputs**:
- `content`: Raw HTML string
- `item_id`: UUID for filename

**Processing**:
1. Upload HTML to `/nura-archive/{item_id}.html`
2. Set `Content-Type: text/html; charset=utf-8`
3. Generate SAS token (1-hour expiry)
4. Store blob URL in `items.archive_url`

**Outputs**:
- `archive_url`: Blob SAS URL

**Acceptance Criteria**:
- [ ] 100% of items archived
- [ ] SAS token valid for 1 hour
- [ ] Lifecycle policy moves to Cool after 30 days
- [ ] Upload failures logged and retried (2 attempts)

**Related Requirements**: REQ-ING-001, REQ-ING-002

---

#### REQ-ING-005: Error Handling and Retry Logic

**Priority**: HIGH  
**Status**: Approved

**Description**: The system SHALL implement retry logic with exponential backoff for transient failures.

**Retry Policy**:

| Error Type | Max Retries | Backoff | Action on Final Failure |
|------------|-------------|---------|------------------------|
| **Network timeout** | 3 | 1s, 2s, 4s | Log error, skip item |
| **API rate limit (429)** | 1 | Wait for `retry-after` | Reduce polling frequency |
| **Database connection** | 3 | 5s, 10s, 20s | Circuit breaker, alert team |
| **Blob upload failure** | 2 | 5s, 10s | Store item with `archive_url = NULL` |

**Circuit Breaker**:
- Open circuit after 5 consecutive failures
- Keep circuit open for 5 minutes
- Half-open: Retry after 5 minutes
- Close circuit on success

**Acceptance Criteria**:
- [ ] Transient errors retried per policy
- [ ] Circuit breaker prevents cascading failures
- [ ] All failures logged with error details
- [ ] Alerts sent for critical errors (email/Slack)

**Related Requirements**: All REQ-ING-xxx

---

### 3.2 AI Enrichment (REQ-AI-ML)

#### REQ-AI-ML-001: Language Detection

**Priority**: MEDIUM  
**Status**: Approved

**Description**: The system SHALL detect content language (Farsi, Arabic, English) using Unicode range analysis.

**Algorithm**:

```python
def detect_language(text):
    farsi_chars = count_chars(text, range=U+0600-U+06FF)
    arabic_chars = count_chars(text, range=U+0600-U+06FF + U+0750-U+077F)

    if farsi_chars > len(text) * 0.3:
        return 'fa'
    elif arabic_chars > len(text) * 0.3:
        return 'ar'
    else:
        return 'en'
```

**Inputs**:
- `body_text`: Raw content

**Outputs**:
- `detected_language`: ISO 639-1 code (fa|ar|en)

**Acceptance Criteria**:
- [ ] Farsi detection accuracy: > 95%
- [ ] Arabic detection accuracy: > 90%
- [ ] English correctly identified as passthrough
- [ ] Mixed-language content defaults to primary language

**Related Requirements**: REQ-AI-ML-002

---

#### REQ-AI-ML-002: Content Translation

**Priority**: CRITICAL  
**Status**: Approved

**Description**: The system SHALL translate Farsi and Arabic content to English using Azure OpenAI gpt-4o-mini.

**Model Configuration**:
- Deployment: `gpt-4o-mini` (alias for gpt-5-nano)
- Temperature: 0.3 (deterministic)
- Max tokens: 2000

**Prompt** (See AI Engineering Guide for full prompt):

```
System: You are a professional news translator. Translate to English while preserving factual accuracy.

User: Translate this {language} article to English:
Title: {title}
Body: {body_text}
```

**Inputs**:
- `body_text`: Original content (Farsi/Arabic)
- `title`: Original title

**Outputs**:
- `body_text_en`: Translated content
- `title_en`: Translated title

**Quality Standards**:
- Named entities preserved with transliteration
- No interpretation or editorialization
- Idioms translated with context
- Dates in ISO 8601 format

**Acceptance Criteria**:
- [ ] 100% of non-English items translated
- [ ] Translation quality validated (manual review 50 samples)
- [ ] No truncation (minimum 50 characters output)
- [ ] Named entities include original script
- [ ] Cost: ≤ $0.002 per item

**Related Requirements**: REQ-AI-ML-004 (combined API call)

---

#### REQ-AI-ML-003: Reserved (Vector Embedding moved to REQ-AI-ML-005)

---

#### REQ-AI-ML-004: Metadata Extraction

**Priority**: HIGH  
**Status**: Approved

**Description**: The system SHALL extract structured metadata from content using Azure OpenAI with JSON schema validation.

**Extracted Fields**:

```json
{
  "author": "string (or 'Anonymous')",
  "dateline": "string (e.g., 'Tehran, Feb 4')",
  "entities": [
    {
      "name": "string",
      "type": "PERSON|ORG|LOC|EVENT",
      "original": "string (non-English script)"
    }
  ],
  "content_type": "news_article|opinion|interview|press_release|analysis|propaganda"
}
```

**Validation** (Pydantic schema in AI Engineering Guide):

```python
class Metadata(BaseModel):
    author: str = "Anonymous"
    dateline: Optional[str] = None
    entities: List[Entity] = Field(max_items=10)
    content_type: Literal['news_article', 'opinion', 'interview', 'press_release', 'analysis', 'propaganda']
```

**Inputs**:
- `body_text_en`: Translated content
- `source_class`: Source classification for context

**Outputs**:
- `metadata`: JSONB field in items table

**Acceptance Criteria**:
- [ ] JSON schema validation: 100% pass rate
- [ ] Entities limited to top 10 most relevant
- [ ] Content type accuracy: > 80%
- [ ] Author field never null (defaults to "Anonymous")
- [ ] Entity extraction F1-score: > 0.80

**Related Requirements**: REQ-AI-ML-002 (combined in single LLM call)

---

#### REQ-AI-ML-005: Vector Embedding Generation

**Priority**: CRITICAL  
**Status**: Approved

**Description**: The system SHALL generate 3072-dimensional vector embeddings using Azure OpenAI text-embedding-3-large model.

**Model Configuration**:
- Deployment: `text-embedding-3-large` (alias for gpt-embedding-text-4)
- Dimensions: 3072 (maximum available)
- Input: `title_en + "\n\n" + body_text_en`

**Input Preparation**:
1. Concatenate translated title and body
2. Truncate to 8191 tokens (model max)
3. No special preprocessing (model handles normalization)

**Outputs**:
- `embedding`: `vector(3072)` stored in PostgreSQL

**Storage**:
- Column type: `vector(3072)` (pgvector extension)
- Index: HNSW with `m=32, ef_construction=128`

**Acceptance Criteria**:
- [ ] 100% of items have embeddings
- [ ] Vector dimensions: exactly 3072
- [ ] pgvector stores without error
- [ ] Cost: ≤ $0.00013 per item
- [ ] Embedding generation time: < 3s P95

**Related Requirements**: REQ-AI-001 (corroboration), REQ-AI-004 (clustering)

---

### 3.3 Trust Scoring (REQ-AI)

#### REQ-AI-001: Trust Score Calculation

**Priority**: CRITICAL  
**Status**: Approved

**Description**: The system SHALL calculate a transparent 5-component trust score on a 15-95 scale for every item.

**Algorithm**:

```python
final_score = clamp(
    base + provenance + corroboration + transparency + modifiers,
    min=15,
    max=95
)
```

**Components** (detailed in sub-requirements):
1. **Base Score** (0-45): Source classification
2. **Provenance** (0-20): Sourcing and attribution
3. **Corroboration** (0-20): Independent verification
4. **Transparency** (0-15): Outlet policies
5. **Modifiers** (-15 to +10): Red/green flags

**Inputs**:
- `item`: Content with metadata
- `source_profile`: Source classification and transparency indicators
- `similar_items`: Vector search results for corroboration

**Outputs**:
- `trust_score`: Integer 15-95
- `trust_level`: Enum HIGH (70-95) | MEDIUM (40-69) | LOW (15-39)
- Breakdown stored in `trust_signals` table

**Acceptance Criteria**:
- [ ] All items have trust_score
- [ ] Score range enforced: 15-95 (no values outside)
- [ ] Trust level correctly mapped
- [ ] Mean Absolute Error: < 15 points vs. human expert ratings
- [ ] Processing time: < 60 seconds P95 per item

**Related Requirements**: REQ-AI-002, REQ-AI-003

---

#### REQ-AI-002: Base Score Assignment

**Priority**: CRITICAL  
**Status**: Approved

**Description**: The system SHALL assign base scores based on 6-tier source classification.

**Classification Tiers**:

| Tier | Source Class | Base Score | Examples |
|------|--------------|-----------|----------|
| **Tier 1** | INTL_WIRE | 40-45 | BBC Persian, VOA Farsi, Radio Farda |
| **Tier 2** | NGO_WATCHDOG | 30-40 | Iran Human Rights, HRANA, Amnesty |
| **Tier 3** | INDIE_MEDIA | 20-35 | IranWire, Telegram channels |
| **Tier 4** | CITIZEN_JOURNALIST | 15-25 | Individual Twitter accounts |
| **Tier 5** | REGIME_MEDIA | 10-20 | IRNA, ISNA, Fars News, Press TV |
| **Tier 6** | PROXY_SUSPECTED | 5-15 | Sources flagged by WF5 |

**Inputs**:
- `source_id`: Foreign key to `source_profiles`

**Outputs**:
- `base_score`: Integer from `source_profiles.base_score`

**Acceptance Criteria**:
- [ ] Base score retrieved from database (not hardcoded)
- [ ] No null values (all sources classified)
- [ ] Proxy reclassification updates base_score to 20

**Related Requirements**: REQ-AI-001, REQ-AI-005

---

#### REQ-AI-003: Trust Score Explanation Generation

**Priority**: HIGH  
**Status**: Approved

**Description**: The system SHALL generate human-readable explanations using template-based approach (NO LLM).

**Template Selection**:
- **HIGH** trust (70-95): Confidence template
- **MEDIUM** trust (40-69): Caution template
- **LOW** trust (15-39): Skepticism template

**Template Variables**:
- `{source}`: Source name
- `{source_class}`: Classification tier
- `{final}`: Final trust score
- `{base}`, `{prov}`, `{corr}`, `{trans}`: Component scores
- `{prov_desc}`, `{corr_desc}`, `{trans_desc}`: Generated descriptions
- `{mod_desc}`: Modifier explanation

**Example Output** (HIGH):

```
BBC Persian receives a HIGH trust score (84/95) based on transparent editorial practices and strong sourcing.

This International Wire outlet has an established reputation (base: 40/45). The article cites Reza Pahlavi as author and provides dateline (London, Feb 4) and includes primary sourcing (provenance: 18/20). Two independent sources corroborate this reporting (corroboration: 14/20). BBC Persian maintains comprehensive transparency policies including correction procedures and funding disclosure (transparency: 15/15).

Red flags such as sensational framing reduce the score (-3 points).

Read with confidence, but always cross-reference major claims.
```

**Inputs**:
- `trust_level`: HIGH|MEDIUM|LOW
- Breakdown components
- Source metadata

**Outputs**:
- `explanation`: Text stored in `trust_signals.explanation`

**Acceptance Criteria**:
- [ ] Explanation generated for 100% of items
- [ ] Natural language quality (UAT with 20 samples)
- [ ] Template variables correctly populated
- [ ] **Cost**: $0.00 (no LLM)
- [ ] Generation time: < 1ms

**Related Requirements**: REQ-AI-001

---

### 3.4 Narrative Clustering (REQ-AI)

#### REQ-AI-004: Semantic Clustering

**Priority**: HIGH  
**Status**: Approved

**Description**: The system SHALL group semantically related items into narratives using vector similarity and entity overlap.

**Clustering Algorithm**:

```python
def find_narrative_match(item):
    # Search 14-day window
    similar_items = vector_search(
        query=item.embedding,
        time_start=item.published_at - 14_days,
        time_end=item.published_at + 14_days,
        similarity_threshold=0.75,
        limit=10
    )

    for similar in similar_items:
        cosine_sim = 1 - cosine_distance(item.embedding, similar.embedding)

        # Strong match: high similarity
        if cosine_sim >= 0.85:
            return similar.narrative_id

        # Moderate match: similarity + entity overlap
        if cosine_sim >= 0.75:
            shared_entities = count_shared_entities(item, similar)
            if shared_entities >= 2:
                return similar.narrative_id

    # No match found
    return None
```

**Inputs**:
- `item.embedding`: 3072-dim vector
- `item.published_at`: Timestamp
- `item.metadata.entities`: Extracted entities

**Outputs**:
- `narrative_id`: UUID (existing or newly created)

**Acceptance Criteria**:
- [ ] Vector search completes in < 100ms P95
- [ ] Strong matches (≥0.85) assigned immediately
- [ ] Moderate matches check entity overlap
- [ ] Clustering quality metrics:
  - Purity: ≥ 0.85
  - Rand Index: ≥ 0.75
- [ ] 14-day window enforced

**Related Requirements**: REQ-AI-ML-005 (embeddings)

---

#### REQ-AI-005: State Proxy Detection

**Priority**: HIGH  
**Status**: Approved

**Description**: The system SHALL detect INDIE_MEDIA and CITIZEN_JOURNALIST sources that are state-controlled proxies using content overlap and narrative alignment analysis.

**ProxyScore Algorithm**:

```python
proxy_score = (
    content_overlap * 0.30 +      # SimHash similarity to REGIME_MEDIA
    narrative_align * 0.30 +      # Shared narratives without contradiction
    amplification * 0.20 +        # MVP: 0 (Phase 2)
    tech_overlap * 0.20           # MVP: 0 (Phase 2)
)
```

**Component 1: Content Overlap** (30%):
- Compare SimHash of source items vs. REGIME_MEDIA items
- 90-day window
- Similarity threshold: ≥90% (Hamming distance ≤6)
- Output: % of items matching regime content

**Component 2: Narrative Alignment** (30%):
- Find narratives shared with REGIME_MEDIA
- Check for contradictions (sentiment divergence ≥0.4)
- Output: % of shared narratives without contradiction

**Component 3: Amplification Network** (20%):
- MVP: Return 0 (not implemented)
- Phase 2: Bot network analysis

**Component 4: Technical Overlap** (20%):
- MVP: Return 0 (not implemented)
- Phase 2: IP/DNS fingerprinting

**Reclassification Thresholds**:
- **ProxyScore ≥ 70**: Automatic reclassification to PROXY_SUSPECTED, base_score = 20
- **ProxyScore 40-69**: Flag for manual review
- **ProxyScore < 40**: No action

**Execution Schedule**:
- Weekly batch job: Every Sunday 00:00 UTC
- Processes all INDIE_MEDIA and CITIZEN_JOURNALIST sources

**Inputs**:
- `source_id`: Source to analyze
- `regime_sources`: List of REGIME_MEDIA source IDs
- 90-day window of items

**Outputs**:
- `proxy_score`: Float 0-100
- `proxy_audits` record with evidence
- LLM-generated explanation for team review

**Acceptance Criteria**:
- [ ] Batch job completes < 30 minutes
- [ ] Precision: ≥ 80% (validated against known proxies)
- [ ] Recall: ≥ 70%
- [ ] All reclassifications logged in audit table
- [ ] Team receives weekly email report
- [ ] **Cost**: ≤ $0.10/month (LLM reports only)

**Related Requirements**: REQ-AI-002 (base score updates)

---

### 3.5 User Interface (REQ-UI)

#### REQ-UI-001: Narrative Feed Dashboard

**Priority**: CRITICAL  
**Status**: Approved

**Description**: The system SHALL display a scrollable feed of narratives sorted by last_updated timestamp.

**Layout**:
- Infinite scroll (load 20 narratives at a time)
- Each narrative card shows:
  - AI-generated title (6-10 words)
  - AI-generated summary (2-3 sentences)
  - Item count (e.g., "12 sources reporting")
  - Trust distribution chart (HIGH/MEDIUM/LOW percentages)
  - Last updated timestamp
  - Propaganda alert banner (if ≥50% regime sources)

**Filters**:
- Minimum trust score slider (0-95)
- Sort: Last updated (default) | Most sources | Highest trust

**Inputs**:
- User selects filters
- Framer calls `/feed` server function

**Outputs**:
- Paginated list of narratives (20 per page)

**Acceptance Criteria**:
- [ ] Page loads in < 2 seconds (First Contentful Paint)
- [ ] Infinite scroll triggers at 80% scroll depth
- [ ] Trust badges visible (GREEN/YELLOW/RED)
- [ ] Propaganda alert displayed prominently
- [ ] Mobile-responsive (breakpoint: 768px)

**Related Requirements**: REQ-INT-001 (Framer function)

---

#### REQ-UI-002: Item Detail Page

**Priority**: HIGH  
**Status**: Approved

**Description**: The system SHALL display full item details with trust breakdown and related narrative.

**Components**:
- **Header**:
  - Title (translated)
  - Source name + logo
  - Trust badge (large, prominent)
  - Publication date
- **Body**:
  - Full translated text
  - Original text (collapsible accordion)
  - Entity tags (clickable)
- **Trust Breakdown Modal**:
  - 5 components with progress bars
  - Human-readable explanation
  - "Learn about our methodology" link
- **Related Narrative Section**:
  - Narrative title and summary
  - Other sources in this narrative (top 5)
  - "View full narrative" button

**Inputs**:
- `item_id` from URL parameter

**Outputs**:
- Rendered item page

**Acceptance Criteria**:
- [ ] Trust badge visible above fold
- [ ] Breakdown modal opens in < 200ms
- [ ] Original text toggle works
- [ ] Entity tags clickable (Phase 2: search)
- [ ] Archive link works (SAS token valid)

**Related Requirements**: REQ-AI-003 (explanation), REQ-UI-003

---

#### REQ-UI-003: Narrative Cluster View

**Priority**: MEDIUM  
**Status**: Approved

**Description**: The system SHALL display all items within a narrative cluster with timeline visualization.

**Components**:
- **Header**:
  - AI-generated title
  - AI-generated summary
  - Propaganda alert (if applicable)
- **Stats**:
  - Item count
  - Trust distribution chart
  - First published / Last updated
- **Timeline**:
  - Horizontal scrollable timeline
  - Items positioned by published_at
  - Color-coded by trust_level
- **Article List**:
  - Sortable: Trust score | Date | Source
  - Filterable: Trust level

**Inputs**:
- `narrative_id` from URL parameter

**Outputs**:
- Rendered narrative page

**Acceptance Criteria**:
- [ ] Timeline renders correctly (no overlap)
- [ ] Sort/filter works client-side (no reload)
- [ ] Trust distribution chart accurate
- [ ] "View source profile" links work

**Related Requirements**: REQ-UI-001, REQ-UI-002

---

#### REQ-UI-004: Methodology Page

**Priority**: MEDIUM  
**Status**: Approved

**Description**: The system SHALL provide public-facing documentation of trust scoring methodology.

**Sections**:
1. **Overview**: Purpose and transparency commitment
2. **Source Classification**: 6-tier taxonomy with examples
3. **Trust Score Formula**: 5 components explained
4. **Corroboration**: How independent verification works
5. **Proxy Detection**: Content overlap and narrative alignment
6. **Limitations**: What the system cannot do
7. **FAQ**: Common questions

**Tone**: Accessible to non-technical users, no jargon

**Acceptance Criteria**:
- [ ] Page accessible without login
- [ ] All 5 components explained with examples
- [ ] Visual diagram of formula
- [ ] Link from every Trust Breakdown modal
- [ ] WCAG 2.1 AA compliant

**Related Requirements**: REQ-AI-001, REQ-AI-005

---

### 3.6 System Integration (REQ-INT)

#### REQ-INT-001: Framer Server Function (Initial Load)

**Priority**: CRITICAL  
**Status**: Approved

**Description**: The system SHALL provide a Framer server function to retrieve paginated narrative feed.

**Endpoint**: `GET /feed` (Framer function, not REST API)

**Query Parameters**:
- `limit`: Integer (default: 20, max: 100)
- `offset`: Integer (default: 0)
- `min_trust`: Integer 0-95 (default: 0)

**SQL Query** (executed in Framer):

```sql
SELECT 
  n.id, n.title, n.summary, n.item_count, 
  n.avg_trust_score, n.trust_distribution, n.last_updated,
  (SELECT json_agg(json_build_object(
    'id', i.id,
    'title', i.title_en,
    'source_name', sp.name,
    'trust_score', i.trust_score,
    'trust_level', i.trust_level,
    'published_at', i.published_at
  ))
  FROM items i
  JOIN source_profiles sp ON i.source_id = sp.id
  WHERE i.narrative_id = n.id
  ORDER BY i.trust_score DESC
  LIMIT 3) as top_items
FROM narratives n
WHERE n.avg_trust_score >= :min_trust
ORDER BY n.last_updated DESC
LIMIT :limit OFFSET :offset
```

**Response Format**:

```json
{
  "narratives": [...],
  "pagination": {
    "total": 150,
    "limit": 20,
    "offset": 0
  }
}
```

**Acceptance Criteria**:
- [ ] Response time: < 500ms P95
- [ ] Cold start: < 2 seconds
- [ ] Pagination works correctly
- [ ] Filters applied accurately
- [ ] **Cost**: $0 (Framer free tier)

**Related Requirements**: REQ-UI-001

---

#### REQ-INT-002: Webhook Delivery (Real-time Updates)

**Priority**: HIGH  
**Status**: Approved

**Description**: The system SHALL deliver real-time updates from n8n workflows to Framer via webhooks.

**Event Types**:

1. **item.created** (WF1):
```json
{
  "event": "item.created",
  "timestamp": "2026-02-04T19:01:00Z",
  "data": {
    "item_id": "uuid",
    "title": "...",
    "source_name": "BBC Persian",
    "published_at": "2026-02-04T18:30:00Z"
  }
}
```

2. **item.scored** (WF3):
```json
{
  "event": "item.scored",
  "timestamp": "2026-02-04T19:02:00Z",
  "data": {
    "item_id": "uuid",
    "trust_score": 84,
    "trust_level": "HIGH",
    "explanation": "..."
  }
}
```

3. **narrative.updated** (WF4):
```json
{
  "event": "narrative.updated",
  "timestamp": "2026-02-04T19:03:00Z",
  "data": {
    "narrative_id": "uuid",
    "title": "...",
    "item_count": 12,
    "avg_trust_score": 67
  }
}
```

**Delivery**:
- HTTP POST to `{{FRAMER_WEBHOOK_URL}}/api/webhook`
- Retry: 1 attempt (non-blocking)
- Timeout: 5 seconds

**Acceptance Criteria**:
- [ ] Webhooks deliver in < 1 second after event
- [ ] Framer UI updates in real-time (no page refresh)
- [ ] Failed deliveries logged (but don't block workflow)
- [ ] Signature validation (optional)

**Related Requirements**: REQ-ING-001, REQ-AI-003, REQ-AI-004

---

### 3.7 Monitoring and Operations (REQ-OPS)

#### REQ-OPS-001: Cost Monitoring

**Priority**: CRITICAL  
**Status**: Approved

**Description**: The system SHALL track daily Azure spending and alert when exceeding $1.00/day.

**Data Sources**:
- Azure Cost Management API
- OpenAI API usage logs (token counts)

**Metrics Tracked**:
- Daily spend (USD)
- Cost per component:
  - Translation (gpt-4o-mini)
  - Embeddings (text-embedding-3-large)
  - Narrative generation (gpt-4o-mini)
  - Proxy reports (gpt-4o-mini)
  - PostgreSQL
  - Blob Storage

**Alert Thresholds**:
- **WARNING**: Daily cost > $0.80 (80% of budget)
- **CRITICAL**: Daily cost > $1.00 (over budget)

**Actions**:
- WARNING: Email notification to team
- CRITICAL: Pause WF1 ingestion for low-priority sources

**Acceptance Criteria**:
- [ ] Cost queried every 6 hours
- [ ] Alert delivered within 15 minutes of threshold breach
- [ ] Dashboard shows cost breakdown by component
- [ ] Monthly projection displayed

**Related Requirements**: REQ-OPS-003 (AI agent)

---

#### REQ-OPS-002: Performance Monitoring

**Priority**: HIGH  
**Status**: Approved

**Description**: The system SHALL monitor query performance and alert on degradation.

**Metrics Tracked** (via pg_stat_statements):
- P95 latency by query type:
  - Vector search (target: < 100ms)
  - Item lookup (target: < 10ms)
  - Feed query (target: < 200ms)
- Processing backlog (PENDING items count)
- Workflow execution times (n8n logs)

**Alert Thresholds**:
- Vector search P95 > 150ms for 10 minutes
- Feed query P95 > 500ms for 10 minutes
- Backlog > 500 items for 30 minutes

**Actions**:
- Email alert to team
- Recommended action: "Run VACUUM ANALYZE on items table"

**Acceptance Criteria**:
- [ ] Metrics exposed in Prometheus
- [ ] Grafana dashboard functional
- [ ] Alerts trigger correctly (tested)
- [ ] P95 histograms accurate

**Related Requirements**: REQ-NFR-001 (performance)

---

#### REQ-OPS-003: AI-Powered Monitoring Agent

**Priority**: MEDIUM  
**Status**: Approved

**Description**: The system SHALL use an AI agent to analyze metrics and recommend actions.

**Agent Architecture**:
- LLM: gpt-4o-mini with function calling
- Tools:
  1. `get_daily_cost()` - Returns current spend
  2. `get_processing_backlog()` - Returns PENDING count
  3. `get_avg_query_time(query_type)` - Returns P95 latency
  4. `get_error_rate()` - Returns % errors in last hour

**Decision Logic**:

```python
if daily_cost > 1.00:
    status = "CRITICAL"
    action = "Pause WF1 ingestion for low-priority sources"
elif backlog > 500:
    status = "WARNING"
    action = "Scale PostgreSQL OR reduce ingestion rate"
elif p95_latency > 750:
    status = "WARNING"
    action = "Run VACUUM ANALYZE, check index health"
elif error_rate > 2:
    status = "WARNING"
    action = "Check logs for recurring errors"
else:
    status = "OK"
```

**Execution**:
- Cron: Every 6 hours
- Outputs JSON report
- Sends email if status != OK

**Acceptance Criteria**:
- [ ] Agent calls all 4 tools
- [ ] Recommendations are actionable
- [ ] Weekly summary report generated
- [ ] **Cost**: $0.002 × 4/day × 30 = $0.24/month

**Related Requirements**: REQ-OPS-001, REQ-OPS-002

---

## 4. Non-Functional Requirements

### 4.1 Performance Requirements (REQ-NFR)

#### REQ-NFR-001: Response Time

**Priority**: HIGH  
**Status**: Approved

| Operation | P95 Target | P99 Target | Measurement Method |
|-----------|-----------|-----------|-------------------|
| **Framer /feed** | < 500ms | < 1000ms | Framer analytics |
| **Item lookup (by ID)** | < 10ms | < 20ms | pg_stat_statements |
| **Vector search** | < 100ms | < 200ms | pg_stat_statements |
| **Trust score calculation** | < 60s | < 120s | n8n execution logs |
| **Narrative clustering** | < 5s | < 10s | n8n execution logs |

**Test Conditions**:
- Database: 100K items, 1K narratives
- Concurrent users: 10
- Network: 50ms latency

**Acceptance Criteria**:
- [ ] All P95 targets met under test conditions
- [ ] No degradation after 7 days continuous operation

---

#### REQ-NFR-002: Throughput

**Priority**: HIGH  
**Status**: Approved

**Targets**:
- Ingestion: 300 items/day sustained
- Peak: 500 items/day for 1 hour (breaking news)
- Enrichment: 10 items/batch, 5-minute interval
- Trust scoring: 1 item/minute

**Acceptance Criteria**:
- [ ] 300 items/day processed without backlog
- [ ] Peak load handled (500 items/hour)
- [ ] No queue buildup after 24 hours

---

#### REQ-NFR-003: Scalability

**Priority**: MEDIUM  
**Status**: Approved

**Current Limits** (MVP):
- Max items: 1M (before partitioning needed)
- Max narratives: 10K
- Max sources: 500 RSS + 200 Twitter
- Concurrent users: 50

**Future Scaling** (Phase 2):
- Partition items table by month
- Add read replicas for queries
- Implement Redis caching layer

**Acceptance Criteria**:
- [ ] System stable at 100K items (1 month data)
- [ ] Query performance acceptable at 500K items (simulation)

---

### 4.2 Security Requirements (REQ-SEC)

#### REQ-SEC-001: Data Protection

**Priority**: HIGH  
**Status**: Approved

**Requirements**:
1. **Secrets Management**:
   - All API keys stored in Azure Key Vault
   - No hardcoded credentials in code/workflows
   - Secrets rotated quarterly

2. **Database Security**:
   - TLS encryption for all connections
   - Least privilege user (`nura_app` with SELECT/INSERT/UPDATE only)
   - No DELETE permissions in application layer

3. **Blob Storage**:
   - SAS tokens with 1-hour expiry
   - No public read access
   - Lifecycle policies enforce retention

**Acceptance Criteria**:
- [ ] No secrets in Git repository
- [ ] Database connections encrypted (verified)
- [ ] SAS tokens expire correctly

---

#### REQ-SEC-002: Access Control

**Priority**: MEDIUM  
**Status**: Approved (MVP: Public access)

**MVP Scope**:
- No user authentication (all content public)
- Read-only access for end users
- Admin access via Azure Portal only

**Phase 2** (Deferred):
- JWT-based authentication
- Role-based access (viewer, analyst, admin)
- Audit log for admin actions

**Acceptance Criteria**:
- [ ] Database has no DROP/TRUNCATE permissions for app user
- [ ] n8n workflows require authentication to modify

---

#### REQ-SEC-003: Input Validation

**Priority**: HIGH  
**Status**: Approved

**Requirements**:
1. **SQL Injection Prevention**:
   - All database queries use parameterized statements
   - No string concatenation for SQL

2. **XSS Prevention**:
   - Framer sanitizes all user-supplied input (future: search)
   - HTML content stored as plain text (no rendering)

3. **API Input Validation**:
   - Framer function validates query params (limit, offset, min_trust)
   - Reject invalid values (e.g., limit > 100)

**Acceptance Criteria**:
- [ ] No SQL injection vulnerabilities (penetration test)
- [ ] XSS test cases pass (OWASP Top 10)

---

### 4.3 Reliability Requirements (REQ-REL)

#### REQ-REL-001: Uptime

**Priority**: HIGH  
**Status**: Approved

**Targets**:
- **System Uptime**: 99.5% (≤43 minutes downtime/month)
- **Component SLAs**:
  - PostgreSQL: 99.9% (Azure SLA)
  - Azure OpenAI: 99.9% (Azure SLA)
  - n8n: 99.0% (self-hosted, best effort)
  - Framer: 99.9% (Framer SLA)

**Downtime Categories**:
- **Planned**: Maintenance windows (Sunday 02:00-04:00 UTC)
- **Unplanned**: Service outages, bugs

**Acceptance Criteria**:
- [ ] Uptime tracked via UptimeRobot
- [ ] 99.5% achieved over 30-day period
- [ ] Incident response time: < 4 hours

---

#### REQ-REL-002: Data Durability

**Priority**: CRITICAL  
**Status**: Approved

**Requirements**:
1. **Database Backups**:
   - Automated daily backups (Azure PostgreSQL)
   - Point-in-time restore: 7 days
   - Backup retention: 30 days

2. **Blob Storage**:
   - Geo-redundant storage (LRS minimum)
   - Soft delete: 7 days

**Recovery Objectives**:
- **RPO** (Recovery Point Objective): 15 minutes
- **RTO** (Recovery Time Objective): 1 hour

**Acceptance Criteria**:
- [ ] Backup restore tested successfully (dry run)
- [ ] RPO/RTO met in disaster recovery test

---

#### REQ-REL-003: Error Recovery

**Priority**: HIGH  
**Status**: Approved

**Strategies**:
1. **Automatic Retry**: Transient errors retried per REQ-ING-005
2. **Circuit Breaker**: Prevents cascading failures
3. **Dead Letter Queue**: Failed items logged for manual review
4. **Graceful Degradation**: System continues with reduced functionality

**Example**: If Azure OpenAI unavailable:
- WF2 (Enrichment): Items remain in PENDING status
- WF1 (Ingestion): Continues to collect and deduplicate
- Alert sent to team

**Acceptance Criteria**:
- [ ] Transient errors recovered automatically
- [ ] Circuit breaker prevents cascading failures
- [ ] System remains operational during partial outage

---

### 4.4 Usability Requirements (REQ-USE)

#### REQ-USE-001: Accessibility

**Priority**: HIGH  
**Status**: Approved

**Standards**: WCAG 2.1 Level AA compliance

**Requirements**:
1. **Keyboard Navigation**: All interactive elements accessible via Tab/Enter
2. **Screen Readers**: ARIA labels for all UI components
3. **Color Contrast**: Minimum 4.5:1 ratio (normal text), 3:1 (large text)
4. **Touch Targets**: Minimum 44×44px (Apple HIG)
5. **Alt Text**: All images have descriptive alt attributes

**Acceptance Criteria**:
- [ ] 0 critical violations (axe DevTools)
- [ ] Keyboard navigation works (manual test)
- [ ] Screen reader test passes (NVDA/VoiceOver)

---

#### REQ-USE-002: Responsiveness

**Priority**: HIGH  
**Status**: Approved

**Breakpoints**:
- **Mobile**: < 768px (vertical layout, bottom sheets)
- **Tablet**: 768px - 1024px (2-column layout)
- **Desktop**: > 1024px (3-column layout)

**Performance**:
- Mobile: First Contentful Paint < 2.5s on 4G
- Desktop: FCP < 1.5s on broadband

**Acceptance Criteria**:
- [ ] All pages render correctly on iPhone 12, iPad, MacBook
- [ ] Touch gestures work (swipe to dismiss modal)
- [ ] Lighthouse mobile score > 85

---

#### REQ-USE-003: Internationalization (Phase 2)

**Priority**: LOW  
**Status**: Deferred

**Future Requirements**:
- RTL support for Persian/Arabic UI
- Locale-aware date formatting
- Currency formatting (if pricing added)

---

### 4.5 Maintainability Requirements (REQ-MAINT)

#### REQ-MAINT-001: Logging

**Priority**: HIGH  
**Status**: Approved

**Log Levels**:
- **ERROR**: Critical failures (database down, API timeout)
- **WARNING**: Recoverable issues (retry succeeded, high cost)
- **INFO**: Normal operations (item ingested, score calculated)
- **DEBUG**: Detailed traces (query execution plans)

**Log Structure** (JSON):

```json
{
  "timestamp": "2026-02-04T19:00:00Z",
  "level": "ERROR",
  "workflow": "WF1",
  "node": "HTTP Request - Miniflux",
  "message": "Connection timeout",
  "details": {
    "url": "https://miniflux.irdecode.com",
    "error": "ETIMEDOUT"
  }
}
```

**Storage**:
- Azure Log Analytics (free tier: 5GB/month)
- Retention: 30 days

**Acceptance Criteria**:
- [ ] All errors logged with stack traces
- [ ] Logs queryable via Kusto (Log Analytics)
- [ ] No sensitive data in logs (credentials masked)

---

#### REQ-MAINT-002: Monitoring Dashboards

**Priority**: HIGH  
**Status**: Approved

**Dashboards** (Grafana):

1. **System Health**:
   - Ingestion rate (items/hour)
   - Processing backlog
   - Error rate by workflow

2. **Performance**:
   - P95/P99 latency histograms
   - Database connection pool usage
   - Query execution times

3. **Cost Tracking**:
   - Daily spend by component
   - Monthly projection
   - Budget utilization %

**Acceptance Criteria**:
- [ ] All dashboards functional
- [ ] Auto-refresh every 30 seconds
- [ ] Accessible to team (no login for MVP)

---

#### REQ-MAINT-003: Documentation

**Priority**: MEDIUM  
**Status**: Approved

**Required Documentation**:

1. **User Documentation**:
   - Methodology page (REQ-UI-004)
   - FAQ
   - 3-minute intro video

2. **Developer Documentation**:
   - Architecture diagram
   - Database schema
   - API specifications (Framer functions)

3. **Operations Documentation**:
   - Runbook (incident response)
   - Deployment guide
   - Backup/restore procedures

**Acceptance Criteria**:
- [ ] All documentation published (GitHub + Framer)
- [ ] Runbook tested during disaster recovery drill

---

## 5. System Requirements

### 5.1 Hardware Requirements

**Development Environment**:
- MacBook Pro M1 (16GB RAM) - sufficient

**Production Environment** (Azure):

| Component | Specification | Justification |
|-----------|--------------|---------------|
| **PostgreSQL** | Standard_B1ms (1 vCore, 2 GB RAM) | Handles 100K items, HNSW indexing |
| **n8n** | Existing Container App (0.5 vCore, 1 GB) | Lightweight workflows |
| **Blob Storage** | 32 GB (Hot/Cool tiers) | HTML archival |
| **Network** | Standard egress | No CDN needed |

---

### 5.2 Software Requirements

**Backend**:
- PostgreSQL 16+ with pgvector 0.5+
- n8n 1.x
- Azure OpenAI API (gpt-4o-mini, text-embedding-3-large)

**Frontend**:
- Framer (latest version)
- Modern browsers: Chrome 100+, Firefox 100+, Safari 15+

**Development Tools**:
- Alembic (database migrations)
- Git (version control)
- VSCode (IDE)

---

### 5.3 Network Requirements

**Bandwidth**:
- Ingestion: ~10 Mbps sustained (RSS/Twitter polling)
- User traffic: ~50 Mbps peak (50 concurrent users)

**Latency**:
- Azure OpenAI API: < 500ms P95 (US East)
- PostgreSQL: < 10ms (same region)

---

## 6. Data Requirements

### 6.1 Data Models

**Primary Tables** (see Database Schema v1.0 for full DDL):

1. **source_profiles**: Media outlets (500 rows)
2. **items**: News content (100K+ rows, growing)
3. **narratives**: Semantic clusters (1K+ rows)
4. **trust_signals**: Trust score breakdowns (1:1 with items)
5. **proxy_audits**: Reclassification history (append-only)

---

### 6.2 Data Volume Estimates

**Month 1**:
- Items: 9,000 (300/day × 30)
- Narratives: ~300 (avg 30 items/narrative)
- Trust signals: 9,000 (1:1)

**Month 6** (projected):
- Items: 54,000
- Narratives: ~1,800
- Trust signals: 54,000

**Storage**:
- PostgreSQL: ~5 GB (items + embeddings)
- Blob Storage: ~32 GB (HTML archive)

---

### 6.3 Data Retention

| Data Type | Retention Policy |
|-----------|------------------|
| **Items (database)** | 180 days (6 months) then archive |
| **HTML (Blob Hot)** | 30 days |
| **HTML (Blob Cool)** | 31-90 days |
| **HTML (Blob Cold)** | 90-180 days |
| **Logs** | 30 days |
| **Backups** | 30 days |
| **Audit logs** | Indefinite (compliance) |

---

## 7. Interface Requirements

### 7.1 User Interfaces

**Web Interface** (Framer):
- Feed Dashboard (REQ-UI-001)
- Item Detail Page (REQ-UI-002)
- Narrative Cluster View (REQ-UI-003)
- Methodology Page (REQ-UI-004)

**Admin Interface** (n8n):
- Workflow canvas (visual editor)
- Execution logs
- Credential management

---

### 7.2 External Interfaces

**APIs Consumed**:

| API | Purpose | Authentication | Rate Limit |
|-----|---------|---------------|------------|
| **Miniflux API** | RSS feed retrieval | API key | No limit |
| **Twitter API v2** | Tweet retrieval | OAuth 2.0 | 100 req/15min |
| **Azure OpenAI** | Translation, embeddings, narratives | API key | 60K TPM |
| **Azure Cost API** | Spending data | Service principal | 100 req/hour |
| **Azure Blob API** | HTML archival | Connection string | No limit |

**Webhooks Delivered**:
- Framer: `POST /api/webhook` (REQ-INT-002)

---

### 7.3 Database Interface

**Connection String** (PostgreSQL):
```
postgresql://nura_app:{{password}}@irdecode-prod-psql.postgres.database.azure.com:5432/nura_db?sslmode=require
```

**Access**:
- Application: Read/write (SELECT, INSERT, UPDATE)
- Admin: Full access (via Azure Portal)

---

## 8. Quality Attributes

### 8.1 Accuracy

**Trust Score Accuracy**:
- Mean Absolute Error: < 15 points vs. human expert ratings
- Validated on 200-item test set

**Translation Quality**:
- Manual review of 50 samples
- No factual errors
- Entities preserved correctly

**Clustering Quality**:
- Purity: ≥ 0.85
- Rand Index: ≥ 0.75
- Validated on 100-item test set

---

### 8.2 Transparency

**Methodology**:
- Complete algorithm documentation (public)
- No black-box scoring
- All 5 components explained

**Data Sources**:
- Source list published (500 RSS, 200 Twitter)
- Classification criteria documented
- Proxy detection logic explained

---

### 8.3 Cost Efficiency

**Monthly Budget**: $28/month

**Cost Optimization**:
- Template-based explanations: Saves $18/month vs. LLM
- Batch processing: 10 items/call
- Embedding caching: No recomputation

**Acceptance Criteria**:
- [ ] Monthly cost < $30 (including buffer)
- [ ] Daily alerts if cost > $1.00

---

## 9. Constraints

### 9.1 Technical Constraints

- **Database**: PostgreSQL only (no NoSQL)
- **Hosting**: Azure only (no multi-cloud)
- **LLM**: Azure OpenAI only (no self-hosted)
- **Frontend**: Framer only (no React/Vue)

### 9.2 Business Constraints

- **Budget**: $28/month hard limit
- **Timeline**: 2 weeks to MVP launch
- **Team**: Solo developer + contractors
- **Language**: English UI only (MVP)

### 9.3 Regulatory Constraints

- **Content**: Public sources only (no hacking/leaks)
- **PII**: No personal data storage
- **Compliance**: No GDPR requirements (no EU users)

---

## 10. Appendices

### 10.1 Use Cases

#### Use Case 1: Browse Narratives

**Actor**: End user  
**Goal**: Find trustworthy reporting on Iran events

**Preconditions**: User visits Framer dashboard

**Main Flow**:
1. User lands on feed dashboard
2. System displays 20 narratives sorted by last_updated
3. User sees trust badges (GREEN/YELLOW/RED)
4. User clicks narrative card
5. System displays narrative cluster view with timeline
6. User clicks item from list
7. System displays item detail with trust breakdown
8. User clicks "Why this score?" to open modal
9. System shows 5-component breakdown with explanation

**Postconditions**: User understands trust score rationale

**Alternative Flows**:
- 3a. User applies minimum trust filter (e.g., ≥70)
- 5a. User sees propaganda alert banner

---

#### Use Case 2: Verify Breaking News

**Actor**: Journalist  
**Goal**: Verify a claim seen on social media

**Preconditions**: Journalist has URL or claim text

**Main Flow**:
1. Journalist opens Nura dashboard
2. Searches narratives for keywords (Phase 2: search)
3. Finds relevant narrative cluster
4. Reviews trust distribution (e.g., 3 HIGH, 5 MEDIUM, 2 LOW)
5. Reads items from independent sources (BBC, VOA)
6. Notes that LOW trust items are from REGIME_MEDIA
7. Cross-references with own sources

**Postconditions**: Journalist has corroboration data

---

#### Use Case 3: Investigate Proxy Source

**Actor**: Domain expert (internal)  
**Goal**: Validate proxy detection results

**Preconditions**: Weekly proxy report received via email

**Main Flow**:
1. Expert receives email: "2 sources flagged for manual review"
2. Expert opens admin dashboard (Phase 2)
3. Reviews proxy_audits table:
   - ContentOverlap: 87%
   - NarrativeAlign: 92%
4. Expert reads LLM-generated explanation
5. Expert manually checks source website:
   - Funding disclosure: None
   - Ownership: Unclear
   - Coverage patterns: Mirrors IRNA
6. Expert confirms reclassification to PROXY_SUSPECTED
7. System updates base_score to 20

**Postconditions**: Source correctly classified

---

### 10.2 Data Dictionary

#### Items Table

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `id` | UUID | Primary key | `550e8400-e29b-41d4-a716-446655440000` |
| `url` | TEXT | Original URL | `https://bbc.com/persian/...` |
| `url_hash` | CHAR(64) | SHA-256 hash of URL | `a1b2c3...` |
| `sim_hash` | CHAR(64) | 64-bit SimHash | `101010...` |
| `title` | TEXT | Original title | `گزارش جدید از تهران` |
| `title_en` | TEXT | Translated title | `New Report from Tehran` |
| `body_text` | TEXT | Original content | `...` |
| `body_text_en` | TEXT | Translated content | `...` |
| `source_id` | UUID | Foreign key to source_profiles | `...` |
| `published_at` | TIMESTAMPTZ | Publication timestamp | `2026-02-04 18:30:00+00` |
| `metadata` | JSONB | Extracted metadata | `{"author": "...", "entities": [...]}` |
| `embedding` | VECTOR(3072) | Text embedding | `[0.123, -0.456, ...]` |
| `trust_score` | INTEGER | Trust score 15-95 | `84` |
| `trust_level` | ENUM | HIGH, MEDIUM, LOW | `HIGH` |
| `narrative_id` | UUID | Foreign key to narratives | `...` |
| `processing_status` | ENUM | PENDING, ENRICHED, SCORED, CLUSTERED | `CLUSTERED` |
| `archive_url` | TEXT | Blob Storage SAS URL | `https://irdecodeprodst.blob.core.windows.net/...` |
| `created_at` | TIMESTAMPTZ | Row creation time | `2026-02-04 18:31:00+00` |
| `updated_at` | TIMESTAMPTZ | Last update time | `2026-02-04 18:35:00+00` |

---

### 10.3 Glossary

**Agent**: AI system with decision-making capability via function calling (e.g., monitoring agent)

**Chain**: Sequential LLM workflow without branching logic (e.g., translation → metadata extraction)

**Corroboration**: Verification of facts by independent sources (not affiliated with original outlet)

**Embedding**: Numerical vector representation of text capturing semantic meaning (3072 dimensions)

**Farsi**: Persian language (ISO 639-1: fa)

**HNSW**: Hierarchical Navigable Small World graph algorithm for approximate nearest neighbor search

**LLM**: Large Language Model (e.g., GPT-4, Claude)

**Narrative**: Cluster of related news items reporting the same event/story

**pgvector**: PostgreSQL extension enabling vector similarity search

**Provenance**: Attribution and sourcing information (author, dateline, citations)

**Proxy Source**: Outlet appearing independent but state-controlled

**RAG**: Retrieval-Augmented Generation (LLM grounded in search results) - Not in MVP

**SimHash**: Locality-sensitive hashing algorithm for near-duplicate detection

**Trust Score**: Composite reliability metric (15-95 scale) with 5 components

---

## Document Approval

| Role | Name | Signature | Date | Status |
|------|------|-----------|------|--------|
| **Product Owner** | [User] | | 2026-02-04 | ✅ Approved |
| **System Architect** | Amir | ✓ | 2026-02-04 | ✅ Approved |
| **AI Engineer** | Navid | ✓ | 2026-02-04 | ✅ Approved |
| **Database Architect** | Reyhaneh | ✓ | 2026-02-04 | ✅ Approved |
| **Domain Expert** | Dr. Kaveh | | Pending | 🕐 Review |
| **QA Lead** | | | Pending | 🕐 Review |

---

**End of Document**

**Document Control**:
- **Version**: 2.0
- **Status**: Approved for Implementation
- **Last Updated**: Wednesday, February 04, 2026, 7:25 PM NZDT
- **File**: `docs/srs-v2.0.md`
- **Total Pages**: ~95 pages
- **Format**: Markdown (IEEE 830 compliant)
