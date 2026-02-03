---
doc_type: requirements
version: 2.4
last_updated: 2026-02-03
owner: Product Team
status: approved
---

# Software Requirements Specification (SRS) - Nura Platform

## Document Control

| Field | Value |
|-------|-------|
| **Version** | 2.4 Final |
| **Date** | February 3, 2026 |
| **Owner** | Product Team |
| **Reviewed by** | Navid (AI Engineer), Amir (Software Architect), Reyhaneh (Database Specialist), Mani (UX Lead) |
| **Status** | Approved for Implementation |
| **Traceability** | [Ref: HLD v1.1], [Ref: ENG-SPEC v3.1], [Ref: DESIGN v1.0] |

### Version History

| Version | Date | Contributors | Changes |
|---------|------|--------------|---------|
| 2.0 | Feb 1, 2026 | Product Team | Initial MVP requirements |
| 2.1 | Feb 2, 2026 | Navid, Amir | Added trust scoring requirements |
| 2.2 | Feb 2, 2026 | Product, Engineering | Narrative clustering requirements |
| 2.3 | Feb 3, 2026 | Product, Navid, Amir, Reyhaneh | Final Docs-as-Code format with traceability |
| 2.4 | Feb 3, 2026 | Product, UX, Engineering | Added UX requirements, refined API specs, enhanced testing scenarios |

---

## 1. Introduction

### 1.1 Purpose

This Software Requirements Specification (SRS) defines the functional and non-functional requirements for the **Nura Intelligence Platform MVP**. It serves as the contractual agreement between the Product Team and the Engineering Team.

### 1.2 Scope

**In Scope (MVP - Phase 1):**
- Data ingestion from RSS feeds and Twitter/X
- AI-powered Trust Scoring (deterministic algorithm)
- Narrative Clustering (grouping related articles)
- Public API Gateway for frontend consumption
- Framer-based web UI (English only)
- PostgreSQL database with pgvector for semantic search
- UX components: Trust Badge, Trust Breakdown Modal, Narrative Cluster View

**Out of Scope (Phase 2):**
- User authentication and personalized feeds
- Mobile applications (iOS/Android)
- Paid API tiers and rate limiting
- RTL/Persian UI localization
- Real-time push notifications
- Advanced analytics dashboard

### 1.3 Definitions & Acronyms

| Term | Definition |
|------|------------|
| **Trust Score** | Numerical value (15-95) indicating credibility of a news item |
| **Narrative** | Cluster of related news items covering the same story/event |
| **Source Class** | Categorical classification of media outlets (Regime, NGO, Wire, etc.) |
| **Proxy Detection** | Algorithm to identify state-affiliated sources masquerading as independent |
| **SimHash** | Content hashing algorithm for near-duplicate detection |
| **pgvector** | PostgreSQL extension for vector similarity search |
| **HNSW** | Hierarchical Navigable Small World graph for ANN search |
| **Trust Badge** | Visual component displaying trust score (green/yellow/red) |
| **Breakdown Modal** | Interactive UI explaining trust score components |

---

## 2. Functional Requirements

### 2.1 Module: Data Ingestion Layer (Layer 1)

#### REQ-ING-001: RSS Feed Ingestion

**User Story:**
As a **System Administrator**, I want the platform to automatically fetch news from configured RSS feeds every 15 minutes so that the database contains the latest articles.

**Acceptance Criteria:**
1. n8n workflow executes on a 15-minute schedule (cron: `*/15`)
2. Workflow processes the Source Bible (500 RSS URLs stored in `source_profiles` table)
3. Each fetched item is checked for duplicates using `url_hash` (SHA-256)
4. If duplicate detected, item is skipped and logged with reason `DUPLICATE_URL`
5. Raw HTML snapshot is stored in Azure Blob Storage (Hot Tier) with path: `raw/{source_id}/{date}/{url_hash}.html`
6. Metadata (Title, Body, Author, Publish Date) is extracted using GPT-4o-mini API
7. Extracted data is inserted into `items` table with status `PENDING_ANALYSIS`

**Performance Requirements:**
- Processing time per item: ≤5 seconds (P95)
- Batch size: 50 items per workflow run
- Error rate: <2% (network failures excluded)

[Ref: REQ-ING-001]

---

#### REQ-ING-002: Twitter/X Data Ingestion

**User Story:**
As a **System Administrator**, I want the platform to monitor specific Twitter accounts and hashtags so that citizen journalism and real-time updates are captured.

**Acceptance Criteria:**
1. Twitter API v2 integration via n8n (OAuth 2.0 authentication)
2. Monitor 200 accounts listed in Source Bible (verified citizen journalists, activists)
3. Monitor hashtags: `#IranProtests`, `#MahsaAmini`, `#OpIran` (configurable)
4. Polling interval: Every 5 minutes for high-priority accounts, 15 minutes for others
5. Tweets are deduplicated using `tweet_id` (primary key)
6. Media attachments (images/videos) are downloaded to Azure Blob Storage
7. Tweet metadata extracted: `author_handle`, `verified_status`, `retweet_count`, `like_count`, `timestamp`

**Edge Cases:**
- **Handle deleted tweets:** Mark as status `DELETED`, do not purge from DB
- **Handle suspended accounts:** Log warning, disable monitoring for 24 hours

[Ref: REQ-ING-002]

---

#### REQ-ING-003: Content Deduplication

**User Story:**
As a **Data Engineer**, I want the system to detect and filter duplicate articles so that storage costs are minimized and analysis quality is maintained.

**Acceptance Criteria:**
1. **URL Deduplication:** Calculate SHA-256 hash of canonical URL (remove UTM params, trailing slashes)
2. **Content Deduplication:** Calculate SimHash of `title + body_text` (1024-bit signature)
3. If SimHash similarity ≥95% with existing item in last 24 hours, mark as `REPRINT`
4. Reprints are linked to original item via `original_item_id` (FK to `items.id`)
5. Reprints do NOT trigger Trust Scoring (inherit score from original)
6. Deduplication logic runs **before** GPT-4o-mini extraction to save API costs

**Performance:**
- Deduplication check: ≤50ms per item (using indexed `url_hash` and `content_hash`)

[Ref: REQ-ING-003]

---

#### REQ-ING-004: Language Filtering

**User Story:**
As a **Cost Controller**, I want the system to discard articles not in supported languages so that API costs are not wasted on irrelevant content.

**Acceptance Criteria:**
1. Language detection using `langdetect` library (Python) or GPT-4o-mini (if metadata extraction already triggered)
2. Supported languages: English (EN), Persian (FA), Arabic (AR)
3. Items NOT in supported languages are marked with status `LANGUAGE_MISMATCH`
4. Discarded items are logged with detected language code (ISO 639-1)
5. Discarded items are NOT stored in `items` table (pre-insert filter)

**Exception:**
- If `source_class = INTL_WIRE` (Reuters, AP, AFP), allow all languages for future expansion

[Ref: REQ-ING-004]

---

### 2.2 Module: AI Reasoning Layer (Layer 2)

#### REQ-AI-001: Trust Score Calculation

**User Story:**
As an **Analyst**, I want every news item to have a Trust Score (15-95) so that I can quickly assess credibility without reading full articles.

**Acceptance Criteria:**
1. Trust Score is calculated using **deterministic formula** (see [ENG-SPEC v3.1, Section 4])
2. Formula components:
   - **Base Contribution (0-45 points):** Based on `source_profiles.base_score`
   - **Provenance (0-20 points):** URL validity, timestamp, author byline, dateline, media
   - **Corroboration (0-20 points):** Independent sources confirming same claim
   - **Transparency (0-15 points):** Editorial disclosure, corrections policy
   - **Modifiers (-15 to +10 points):** Red flags (anonymous sourcing), Green flags (primary documents)
3. Final Score is clamped between 15 and 95 (no exceptions)
4. Calculation latency: ≤60 seconds per item (including vector search for corroboration)
5. Result is stored in `trust_signals` table with fields:
   - `final_score` (INT)
   - `trust_level` (ENUM: HIGH, MEDIUM, LOW)
   - `breakdown_json` (JSONB with component scores)
   - `explanation` (TEXT, human-readable summary)

**Score Range → Trust Level → UI Badge Color:**

| Score Range | Trust Level | Badge Color |
|-------------|-------------|-------------|
| 70-95 | HIGH | Green |
| 40-69 | MEDIUM | Yellow/Amber |
| 15-39 | LOW | Red |

[Ref: REQ-AI-001] [See: ENG-301 to ENG-306 for detailed formula]

---

#### REQ-AI-002: Narrative Clustering

**User Story:**
As a **User**, I want related articles about the same event to be grouped together so that I don't see duplicate headlines and can follow story development.

**Acceptance Criteria:**
1. Clustering uses **pgvector** for semantic similarity (cosine distance on 1536-dim embeddings)
2. Clustering window: 14 days (configurable per topic type—see [ENG-402])
3. Match condition:
   - **Cosine Similarity ≥0.85** OR
   - **Cosine Similarity ≥0.75 AND Entity Overlap ≥2** (shared PERSON/ORG/EVENT entities)
4. Items with same `MainEventID` entity are always merged (even if opposing stances)
5. New narratives trigger GPT-4o-mini (o3-mini preferred) to generate summary title
6. Narrative title format: `[MainEvent]: [KeyDevelopment]` (e.g., "Zahedan Protests: Death Toll Rises to 96")
7. Batch clustering runs every 15 minutes (synchronized with ingestion workflow)

**Performance:**
- Vector search: ≤200ms per query (HNSW index on `items.embedding`)
- Clustering latency: ≤5 seconds per new item

[Ref: REQ-AI-002] [See: ENG-401, ENG-402]

---

#### REQ-AI-003: Proxy Detection

**User Story:**
As a **Trust & Safety Officer**, I want the system to identify state-affiliated outlets masquerading as independent sources so that they cannot artificially boost trust scores through fake corroboration.

**Acceptance Criteria:**
1. Weekly batch job calculates **ProxyScore (0-100)** for all sources using formula:
   ```
   ProxyScore = 0.3×ContentOverlap + 0.3×NarrativeAlign + 0.2×AmplificationNet + 0.2×TechOverlap
   ```
2. Component calculations:
   - **ContentOverlap:** % of articles with cosine similarity ≥0.90 to known regime sources
   - **NarrativeAlign:** % of narratives where source never contradicts regime framing
   - **AmplificationNet:** Social media boost from known regime bot networks (7,500 accounts)
   - **TechOverlap:** Shared hosting/IP infrastructure with regime sites
3. Threshold-based actions:

| ProxyScore | Label | Action |
|------------|-------|--------|
| ≥70 | **State Proxy** | Reclassify `source_class = REGIME_MEDIA` OR apply -10 penalty to base score |
| 40-69 | **Grey Zone** | Flag "State Affiliated" warning, require human audit before corroboration |
| <40 | **Independent** | No penalty |

4. **Critical Constraint:** Sources flagged as "State Proxy" CANNOT corroborate other regime sources
5. All reclassifications are logged in `audit_log` table with reason and approver

[Ref: REQ-AI-003] [See: ENG-202]

---

#### REQ-AI-004: Statement of Record Handling

**User Story:**
As a **Fact-Checker**, I want the system to distinguish between a VIP's opinion statement and factual claims so that political figures cannot artificially boost unverified claims.

**Acceptance Criteria:**
1. When `source_class = KEY_FIGURE` (e.g., Trump, Pezeshkian, Pahlavi):
   - **Detect "Statement of Record"** (e.g., "I will...", "We plan...", "I condemn...")
   - Flag as `is_official_statement = TRUE`
   - Trust Score = Authenticity Score (high if verified speaker via official channel)
2. **Detect "Factual Claim"** (e.g., "500 killed", "They attacked us")
   - Mark as `UNVERIFIED_CLAIM`
   - Require at least 1 independent corroboration (NGO, Wire, etc.)
   - If no corroboration found, score remains **LOW** (≤40)
3. VIP status does NOT boost truth score of factual claims—only independent confirmation increases score

**Example:**
- Trump tweets: *"I convinced Iran to cancel 800 executions"*
  - **Statement:** "I convinced..." → `is_official_statement = TRUE`, High Authenticity
  - **Claim:** "800 executions cancelled" → Requires corroboration from Iran Human Rights, Amnesty
  - If no corroboration → Score = 40 (base) + 10 (provenance) + 0 (corroboration) = 50 (MEDIUM), flagged "Unverified"

[Ref: REQ-AI-004] [See: ENG-201]

---

### 2.3 Module: Product API Layer (Layer 3 & 4)

#### REQ-API-001: Public Feed Endpoint

**User Story:**
As a **Frontend Developer**, I want a feed endpoint that returns narratives with nested items so that I can display the latest news on the homepage.

**Acceptance Criteria:**
1. **Endpoint:** `GET /api/v1/feed`
2. **Query Parameters:**
   - `limit` (INT, default 20, max 100)
   - `offset` (INT, default 0, for pagination)
   - `language` (ENUM: EN, FA, AR, default EN)
   - `min_trust_score` (INT, default 40, range 15-95)
3. **Response Schema:**
```json
{
  "narratives": [
    {
      "narrative_id": "uuid",
      "title": "Zahedan Protests: Death Toll Rises to 96",
      "summary": "Generated by GPT-4o-mini...",
      "created_at": "2026-02-03T10:00:00Z",
      "last_updated": "2026-02-03T11:00:00Z",
      "item_count": 12,
      "avg_trust_score": 72,
      "top_items": [
        {
          "item_id": "uuid",
          "title": "HRANA Reports 96 Deaths in Zahedan",
          "source_name": "Human Rights Activists News Agency",
          "source_logo_url": "https://...",
          "publish_date": "2026-02-03T09:30:00Z",
          "trust_score": 85,
          "trust_level": "HIGH",
          "url": "https://..."
        }
      ]
    }
  ],
  "pagination": {
    "total": 150,
    "limit": 20,
    "offset": 0,
    "has_next": true
  }
}
```
4. **Performance:** Response time ≤500ms (P95)
5. **Caching:** Redis cache with 2-minute TTL

[Ref: REQ-API-001]

---

#### REQ-API-002: Item Detail Endpoint

**User Story:**
As a **User**, I want to click on a news item and see the full article with trust score breakdown so that I understand why the score is high or low.

**Acceptance Criteria:**
1. **Endpoint:** `GET /api/v1/items/{item_id}`
2. **Response Schema:**
```json
{
  "item_id": "uuid",
  "title": "...",
  "body_text": "Full article content...",
  "source": {
    "name": "HRANA",
    "logo_url": "https://...",
    "source_class": "NGO_WATCHDOG",
    "base_score": 90
  },
  "metadata": {
    "author": "Jane Doe",
    "publish_date": "2026-02-03T09:30:00Z",
    "url": "https://...",
    "entities": [
      {"type": "PERSON", "name": "Mahsa Amini"},
      {"type": "EVENT", "name": "Zahedan Protests"}
    ]
  },
  "trust_signal": {
    "final_score": 85,
    "trust_level": "HIGH",
    "badges": ["VERIFIED_SOURCE", "CORROBORATED"],
    "breakdown": {
      "base": 40,
      "provenance": 20,
      "corroboration": 18,
      "transparency": 12,
      "modifiers": -5
    },
    "explanation": "High credibility due to NGO source, multiple confirmations, and transparent sourcing.",
    "warnings": ["Minor: Anonymous 'residents' quoted"]
  },
  "narrative": {
    "narrative_id": "uuid",
    "title": "Zahedan Protests: Death Toll Rises to 96"
  }
}
```
3. **Performance:** Response time ≤300ms (P95)

[Ref: REQ-API-002]

---

#### REQ-UI-001: Trust Score Visualization

**User Story:**
As a **User**, I want to click on the Trust Badge to see a breakdown of how the score was calculated so that I understand the platform's methodology.

**Acceptance Criteria:**
1. **Trust Badge** displays color-coded score:
   - **Green (70-95):** High Trust
   - **Yellow (40-69):** Medium Trust
   - **Red (15-39):** Low Trust
2. Clicking badge opens a **modal/drawer** with:
   - **Bar Chart:** 4 horizontal bars showing Base, Provenance, Corroboration, Transparency contributions
   - **Warnings/Flags:** Red alerts (e.g., "Anonymous sourcing detected")
   - **Green Flags:** (e.g., "Primary documents linked")
3. Modal includes "Learn More" link to methodology page explaining scoring system

**Design Reference:**
- Figma mockup attached in separate doc
- Component library: `TrustBadge.tsx`, `TrustModal.tsx`

[Ref: REQ-UI-001] [See: DESIGN-001, DESIGN-002]

---

#### REQ-UI-002: Source Profile Page

**User Story:**
As a **User**, I want to click on a source name and see its profile, base score, and recent articles so that I can assess the outlet's general credibility.

**Acceptance Criteria:**
1. **Route:** `/sources/{source_slug}`
2. **Page Content:**
   - Source logo and name
   - `source_class` label (e.g., "NGO Watchdog")
   - `base_score` (0-100) with color coding
   - Ownership disclosure (if available)
   - Recent 20 articles from this source (with trust scores)
3. **Performance:** Page load ≤1 second (P95)

[Ref: REQ-UI-002]

---

#### REQ-UI-003: Narrative Cluster View

**User Story:**
As a **User**, I want to see all articles about a specific event grouped together with a timeline view so that I can follow the story's evolution.

**Acceptance Criteria:**
1. **Route:** `/narratives/{narrative_id}`
2. **Page Components:**
   - **Narrative Header:** Title, last updated timestamp, item count
   - **AI-Generated Summary:** 2-3 sentence overview
   - **Trust Distribution:** Pie chart showing % of HIGH/MEDIUM/LOW trust articles
   - **Article List:** Sorted by trust score (default) or chronological
   - **Timeline View:** Visual timeline showing when each article was published
   - **Propaganda Alert:** Red warning if regime sources show suspicious patterns
3. **Filtering:**
   - Sort by: Trust Score, Date, Source
   - Filter by: Trust Level (All, High, Medium, Low)
4. **Performance:** Page load ≤1.5 seconds (P95)

[Ref: REQ-UI-003] [See: DESIGN-003]

---

### 2.4 Module: Database & Storage Layer (Layer 0)

#### REQ-DB-001: PostgreSQL Schema

**User Story:**
As a **Database Administrator**, I want a normalized schema with vector indexing so that queries are fast and data integrity is maintained.

**Acceptance Criteria:**
1. PostgreSQL 16 with **pgvector** extension enabled
2. Core tables:
   - `source_profiles` (500 sources with `base_score`, `source_class`, `ownership_cluster`)
   - `items` (news articles with `embedding` vector[1536])
   - `trust_signals` (trust scores with `breakdown_json`)
   - `narratives` (clustered stories)
   - `audit_log` (change tracking)
3. Indexes:
   - **HNSW index** on `items.embedding` (HNSW with m=16, ef_construction=64)
   - B-tree indexes on `items.publish_date`, `items.source_id`, `items.narrative_id`
   - GIN index on `items.metadata` (JSONB)
4. Constraints:
   - `trust_score` CHECK (15 ≤ `final_score` ≤ 95)
   - `source_class` ENUM (strict taxonomy, no ad-hoc strings)

[Ref: REQ-DB-001]

---

#### REQ-DB-002: Azure Blob Storage

**User Story:**
As a **Cost Manager**, I want raw HTML snapshots stored in cheap blob storage so that database size stays manageable.

**Acceptance Criteria:**
1. Storage account: `nura_storage_acct`
   - **Hot Tier:** 0-30 days
   - **Cool Tier:** 31-90 days
   - **Archive Tier:** >90 days
2. Container structure:
   - `raw/{source_id}/{YYYY-MM-DD}/{url_hash}.html`
   - `media/{item_id}/{filename}.jpg|png|mp4`
3. Retention policy: Auto-delete after 1 year (configurable)
4. Access: SAS tokens with 1-hour expiry for frontend retrieval

[Ref: REQ-DB-002]

---

## 3. Non-Functional Requirements

### 3.1 Performance

| Metric | Target | Measurement |
|--------|--------|-------------|
| API Response Time (P95) | ≤500ms | `/feed` endpoint |
| Trust Score Calculation | ≤60s per item | From ingestion to `trust_signals` insert |
| Vector Search Latency | ≤200ms | pgvector ANN query (top 50 results) |
| Clustering Batch Time | ≤5 min | Processing 500 new items |
| Database Query Time (P95) | ≤100ms | Simple SELECT queries |

[Ref: REQ-NFR-001]

---

### 3.2 Scalability

| Dimension | MVP Target | Phase 2 Target |
|-----------|------------|----------------|
| Items Ingested/Day | 5,000 | 50,000 |
| API Requests/Minute | 100 | 1,000 |
| Concurrent Users | 500 | 10,000 |
| Database Size | 100 GB | 1 TB |
| Vector Index Size | 10M items | 100M items |

[Ref: REQ-NFR-002]

---

### 3.3 Security

| Requirement | Implementation |
|-------------|----------------|
| API Authentication | Public endpoints (no auth for MVP); Phase 2: API keys + JWT |
| Database Encryption | Transparent Data Encryption (TDE) enabled |
| Blob Storage Encryption | AES-256 at rest, HTTPS in transit |
| Input Validation | Sanitize all user inputs (prevent SQL injection, XSS) |
| Rate Limiting | 100 req/min per IP (Cloudflare) |

[Ref: REQ-NFR-003]

---

### 3.4 Reliability

| Metric | Target |
|--------|--------|
| Uptime | 99.5% (MVP), 99.9% (Phase 2) |
| Data Loss (RPO) | ≤15 minutes (DB backups every 15 min) |
| Recovery Time (RTO) | ≤1 hour (automated failover) |
| Error Rate | <0.5% (excluding network failures) |

[Ref: REQ-NFR-004]

---

### 3.5 Maintainability

| Requirement | Implementation |
|-------------|----------------|
| Code Documentation | Inline comments ("why", not "what"); README at repo root |
| API Documentation | Auto-generated OpenAPI (Swagger) spec at `/api/docs` |
| Logging | Structured JSON logs (Winston/Bunyan), sent to Azure Log Analytics |
| Monitoring | Prometheus + Grafana dashboards (latency, error rate, queue depth) |
| Alerting | PagerDuty integration for critical failures (DB down, API 5xx >1%) |

[Ref: REQ-NFR-005]

---

### 3.6 Usability (UX Requirements)

| Requirement | Implementation |
|-------------|----------------|
| Mobile Responsiveness | All UI components optimized for mobile (70% of users on smartphone) |
| Accessibility | WCAG 2.1 Level AA compliance (color contrast, keyboard navigation, screen reader support) |
| Load Time | First Contentful Paint (FCP) ≤1.5s on 4G connection |
| Trust Badge Visibility | Badge must be visible within viewport without scrolling (System 1 thinking) |
| Explanation Clarity | Trust Breakdown Modal uses plain language, not technical jargon |
| Error Messaging | User-friendly error messages (e.g., "Oops! Something went wrong" instead of error codes) |

[Ref: REQ-NFR-006]

---

## 4. Constraints & Assumptions

### 4.1 Technical Constraints

- **Database:** PostgreSQL 16 (pgvector dependency)
- **Hosting:** Azure East US (latency optimized for US/EU users)
- **LLM Provider:** OpenAI API (GPT-4o-mini, o3-mini)
- **Frontend:** Framer (no-code constraint; Phase 2 may migrate to Next.js)

### 4.2 Assumptions

- **Source Bible Stability:** List of 500 sources is maintained manually (reviewed monthly)
- **API Cost:** GPT-4o-mini pricing remains stable at $0.15/$0.60 per 1M tokens (in/out)
- **Vector Embedding Model:** OpenAI `text-embedding-3-small` (1536 dimensions, $0.02/1M tokens)
- **User Base:** Initially English-speaking analysts, journalists, researchers (Persian UI in Phase 2)

---

## 5. Dependencies & Risks

### 5.1 External Dependencies

| Dependency | Criticality | Mitigation |
|------------|-------------|------------|
| OpenAI API | **Critical** | Fallback to local LLM (LLaMA 3) if quota exceeded |
| Twitter API | **High** | Cache tweets locally; scraping fallback if API restricted |
| Azure Cloud | **Critical** | Multi-region failover plan (West Europe backup) |
| RSS Feeds | **Medium** | Monitor uptime; alert if >10% sources down |

---

### 5.2 Risk Register

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| OpenAI Rate Limit | Medium | High | Implement request queue; upgrade to Tier 5 |
| Vector Index Performance Degradation | Low | High | Monitor query latency; re-index monthly |
| Source Reclassification Errors | Medium | Medium | Human review for Proxy Score 40-70 range |
| Narrative Fragmentation | High | Medium | Tune clustering thresholds weekly |
| Database Storage Growth | High | Low | Archival policy (Cool/Archive tiers) |

---

## 6. Acceptance Testing

### 6.1 End-to-End Test Scenarios

**Scenario 1: Ingest → Score → Cluster → Display**
1. Add new RSS article URL to test source
2. Verify item appears in `items` table within 15 minutes
3. Verify `trust_signals` record created with `final_score` in 15-95 range
4. Verify `breakdown_json` contains all 4 components (base, provenance, corroboration, transparency)
5. Verify item assigned to existing or new `narrative_id`
6. Verify narrative appears in `/feed` endpoint response
7. Verify Trust Badge displays correct color on Framer UI

**Pass Criteria:** All steps complete without errors in <2 minutes

---

**Scenario 2: Proxy Detection**
1. Add known regime proxy source (e.g., Tasnim reprint network)
2. Run weekly proxy detection batch job
3. Verify `ProxyScore ≥70` calculated
4. Verify source reclassified to `source_class = REGIME_MEDIA`
5. Verify -10 penalty applied to `base_score`
6. Verify source cannot corroborate another regime source (query test)

**Pass Criteria:** ProxyScore accurate (manual audit), reclassification logged in `audit_log`

---

**Scenario 3: Statement of Record**
1. Ingest tweet from Trump: *"I will visit Tehran next month"*
2. Verify `is_official_statement = TRUE`
3. Verify `trust_level = STATEMENT_RECORD`
4. Ingest tweet from Trump: *"500 protesters were killed"*
5. Verify `is_official_statement = FALSE`
6. Verify `trust_level = MEDIUM` (no corroboration found)
7. Add corroboration from HRANA
8. Verify trust score increases to `HIGH`

**Pass Criteria:** VIP statements handled correctly; factual claims require corroboration

---

**Scenario 4: UX - Trust Badge Interaction**
1. Navigate to `/feed` on mobile device (iPhone 13)
2. Verify Trust Badge is visible without scrolling
3. Tap badge to open Trust Breakdown Modal
4. Verify modal displays:
   - 4 horizontal bars (Base, Provenance, Corroboration, Transparency)
   - Warnings section (if any)
   - "Learn More" link
5. Tap "Learn More" → Verify methodology page loads
6. Close modal → Verify UI returns to feed without errors

**Pass Criteria:** All interactions complete within 3 seconds; no UI glitches

---

**Scenario 5: UX - Narrative Cluster View**
1. Navigate to `/narratives/{zahedan-protests-id}`
2. Verify page loads in <1.5 seconds
3. Verify components present:
   - Narrative title and summary
   - Trust distribution pie chart
   - Article list (sorted by trust score)
   - Timeline view (visual timeline)
4. Filter by "High Trust" → Verify only HIGH trust articles shown
5. Sort by "Date" → Verify chronological ordering

**Pass Criteria:** All interactions complete smoothly; data matches API response

---

## 7. Sign-off & Approval

This SRS has been reviewed and approved by:

| Role | Name | Signature | Date |
|------|------|-----------|------|
| **Product Owner** | [Your Name] | _________________ | Feb 3, 2026 |
| **AI Engineer** | Navid | Reviewed | Feb 3, 2026 |
| **Software Architect** | Amir | Reviewed | Feb 3, 2026 |
| **Database Specialist** | Reyhaneh | Reviewed | Feb 3, 2026 |
| **UX Lead** | Mani | Reviewed | Feb 3, 2026 |

**Document Status:** FINAL — Ready for Development

---

## Appendix A: Traceability Matrix

| SRS Requirement | Engineering Spec Section |
|-----------------|--------------------------|
| REQ-ING-001 | ENG-501 (Feed Triage) |
| REQ-ING-003 | ENG-501 (Deduplication) |
| REQ-AI-001 | ENG-301 to ENG-306 (Trust Scoring) |
| REQ-AI-002 | ENG-401, ENG-402 (Narrative Clustering) |
| REQ-AI-003 | ENG-202 (Proxy Detection) |
| REQ-AI-004 | ENG-201 (Statement of Record) |
| REQ-API-001 | ENG-602 (API Response Schema) |
| REQ-UI-001 | DESIGN-001, DESIGN-002 (Trust Badge & Modal) |
| REQ-UI-003 | DESIGN-003 (Narrative Cluster View) |

---

## Appendix B: Related Documents

- **HLD v1.1** — High-Level Design (Architecture, Tech Stack, Data Flow)
- **ENG-SPEC v3.1** — Engineering Specification (Formulas, Algorithms, Database Schema)
- **DESIGN v1.0** — UX Design System (Trust Badge, Breakdown Modal, Narrative View)
- **UX Strategy v1.0** — Design System, Personas, Interaction Patterns
- **Source Bible** — Master list of 500 sources with classifications

---

**Last Updated:** Tuesday, February 3, 2026, 3:03 PM NZDT  
**Approval Status:** FINAL — Ready for Implementation

---

*This SRS is the contractual agreement between Product and Engineering. All features must trace back to a **REQ-XXX** identifier. Questions? Escalate to Product Owner or Engineering Lead.*
