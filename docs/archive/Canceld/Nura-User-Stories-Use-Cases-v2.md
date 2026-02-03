# Nura Platform - User Stories & Use Cases Documentation

**Version:** 2.0 (MVP - Activist Edition)  
**Document Type:** Product Requirements - User Stories & Use Cases  
**Date:** February 3, 2026  
**Status:** ✅ Approved by Product Owner  
**Scope:** MVP Launch (4-week timeline)  
**Language:** English UI for international audience

---

## 📋 Document Control

| Version | Date | Author | Changes |
|:--------|:-----|:-------|:--------|
| 1.0 | Feb 2, 2026 | Business Analyst | Initial SRS with 4-layer architecture |
| 2.0 | Feb 3, 2026 | Product Team | Strategic pivot: Global Observer + Diaspora Activist focus, Admin UI removed from MVP |

---

## 🎯 Executive Summary

This document contains all **User Stories** and **Use Cases** for the Nura Platform MVP, designed based on the new strategy focusing on:

1. **Global Observers** (international journalists, researchers) - seeking truth beyond propaganda
2. **Diaspora Activists** (Iranian advocates abroad) - amplifying people's voices on social media

### Key Changes from v1.0:
- ❌ **Removed:** Admin UI panel from MVP scope
- ✅ **Added:** Smart Share tools for X/Instagram
- ✅ **Added:** Context Generation instead of traditional Fact-Checking
- ✅ **Added:** Community Trust scoring for diaspora accounts
- ✅ **Added:** Silence Detection (censorship monitoring)

---

## 👥 Primary Personas

### Persona 1: Sarah (Global Observer)
- **Role:** Western journalist covering Middle East
- **Pain Point:** "I can't tell which Iranian news sources are credible. State media looks professional but spreads disinformation."
- **Goal:** Quickly assess news credibility and understand the political context
- **Tech Literacy:** High
- **Primary Device:** Desktop

### Persona 2: Reza (Diaspora Activist)
- **Role:** Iranian human rights advocate on Twitter/X
- **Pain Point:** "I want to share verified news, but creating fact-based posts takes hours. By then, propaganda has already spread."
- **Goal:** Rapidly share credible information with ready-made content
- **Tech Literacy:** Medium-High
- **Primary Device:** Mobile (70%) + Desktop (30%)

---

## 📊 User Stories (Epic Level)

### Epic 1: Global Observer - News Verification

#### US-01: View Trust Score
```
As a global news consumer
I want to see a clear trust score (15-95) next to each news item
So that I can quickly assess credibility without reading full articles
```

**Acceptance Criteria:**
- [ ] Trust score displayed as colored badge (Green/Yellow/Red)
- [ ] Badge includes tooltip showing source classification
- [ ] Score ranges: <40 Red | 40-70 Yellow | >70 Green
- [ ] Badge visible on feed cards and detail pages

**Priority:** P0 (Critical)  
**Story Points:** 3  
**Dependencies:** UC-R1 (Trust Scoring Engine)

---

#### US-02: Understand Context
```
As a foreign observer unfamiliar with Iranian politics
I want to read a short "Context Box" in English explaining why this news matters
So that I don't fall for propaganda framing
```

**Acceptance Criteria:**
- [ ] Every item has 2-3 paragraph Context section in English
- [ ] Context includes: historical background, source bias, relation to current events
- [ ] Uses controlled glossary (e.g., "protester" not "rioter")
- [ ] AI-generated but editorially reviewed for sensitive topics

**Priority:** P0 (Critical)  
**Story Points:** 5  
**Dependencies:** UC-R6 (Context Generation), Controlled Vocabulary Module

---

#### US-03: Source Transparency Profile
```
As a journalist fact-checking claims
I want to click on a source name and see its full transparency profile
So that I know who owns it and their track record
```

**Acceptance Criteria:**
- [ ] Clicking source name opens Modal/Slide-over
- [ ] Profile shows: Ownership, Source Class, Historical Accuracy, Proxy Warning (if applicable)
- [ ] Links to external documentation (UN reports, research papers)
- [ ] "Last Updated" timestamp for profile data

**Priority:** P1 (High)  
**Story Points:** 5  
**Dependencies:** UC-D3 (Source Profile Sync)

---

### Epic 2: Diaspora Activist - Content Amplification

#### US-04: Browse Narratives (Not Individual Items)
```
As a diaspora activist tracking multiple stories
I want to see news grouped into "Narratives" (events/stories)
So that I don't waste time reading 20 duplicate articles about the same protest
```

**Acceptance Criteria:**
- [ ] Home page displays Narrative Cards (not individual Item Cards)
- [ ] Each card shows: Title, Source Count, Date Range, Trend Score
- [ ] Clicking card expands to timeline of all related items
- [ ] Items sorted by trust score within narrative

**Priority:** P0 (Critical)  
**Story Points:** 8  
**Dependencies:** UC-R5 (Narrative Clustering)

---

#### US-05: Smart Share for Social Media
```
As an activist wanting to amplify verified news
I want to click "Share to X/Instagram" and get ready-made content
So that I can post credible information quickly without creating from scratch
```

**Acceptance Criteria:**
- [ ] "Share" button with X and Instagram icons
- [ ] **For X:** Generates 3-tweet thread:
  - Tweet 1: Headline + link
  - Tweet 2: Context + trending hashtags
  - Tweet 3: Evidence links
- [ ] **For Instagram:** Generates 9:16 story image with headline + trust score
- [ ] Auto-copy text to clipboard
- [ ] Download image as PNG

**Priority:** P0 (Critical)  
**Story Points:** 8  
**Dependencies:** UC-A7 (Image Generator Service)

---

#### US-06: Access Evidence Bank
```
As an activist debating online
I want to quickly access all supporting documents (PDFs, videos, reports) for a narrative
So that I can back up my claims with credible sources
```

**Acceptance Criteria:**
- [ ] Narrative detail page has "Evidence" section
- [ ] Direct links to: NGO reports, verified videos, official statements
- [ ] "Copy All Links" button for quick reference gathering
- [ ] Evidence items tagged by type (Document, Video, Official Statement)

**Priority:** P1 (High)  
**Story Points:** 3  
**Dependencies:** Manual curation initially, automated in Phase 2

---

## 🔧 Use Cases (Technical Detail)

### Layer 1: Data Ingestion

#### UC-D1: Ingest RSS/Web Articles

**ID:** UC-D1  
**Actor:** System (Automated Worker)  
**Trigger:** Cron job every 15 minutes  
**Preconditions:** Source Bible loaded in `source_profiles` table

**Main Flow:**
1. System reads RSS URL list from database
2. For each URL, downloads XML content
3. Extracts metadata using GPT-4o-mini:
   - Title, Body, Author, Publish Date, Language
4. Computes content hash for deduplication
5. If hash unique, inserts new record into `items` table
6. Archives raw HTML to Blob Storage

**Postconditions:** New item ready for Reasoning Layer processing

**Exception Flows:**
- **E1:** RSS feed unreachable → Log error + Retry after 1 hour
- **E2:** Content spam (length < 100 chars) → Discard
- **E3:** Language not FA/EN/AR → Flag for manual review

**Technical Specifications:**
- Model: `gpt-4o-mini` (cheapest for extraction)
- Max processing time: 30 seconds per item
- Batch size: 50 items per run
- Reference: [Meeting Minutes Strategic.docx]

**Data Contract:**
```json
{
  "item_id": "uuid",
  "source_id": "uuid",
  "title": "string",
  "body_text": "string",
  "author": "string|null",
  "publish_date": "datetime",
  "url": "string",
  "language": "enum[FA,EN,AR]",
  "platform": "enum[WEB,X,TELEGRAM]"
}
```

---

#### UC-D2: Ingest Social Media (Twitter/X)

**ID:** UC-D2  
**Actor:** System  
**Trigger:** Webhook (real-time) OR Polling every 5 minutes  
**Preconditions:** Whitelist of trusted diaspora accounts exists

**Main Flow:**
1. System fetches new posts from Twitter API
2. Filters posts that meet criteria:
   - From Whitelist accounts OR
   - Contains monitored hashtags (#MahsaAmini, #IranProtests)
3. Stores raw JSON to Blob Storage
4. Sets `platform = "X"`
5. Links to account via `source_id` (from `source_profiles`)

**Postconditions:** Post ready for Trust Scoring

**Exception Flow:**
- **E1:** Account not in Whitelist → Check Community Trust Score
- **E2:** Community Trust < 50 → Flag for Manual Review
- **E3:** API rate limit → Queue for delayed processing

**Technical Specifications:**
- API: TwitterAPI.io (per [Strategic Meeting])
- Rate limit: 500 requests/15min
- Storage: Azure Blob (JSON format)

**New Logic (v2.0):**
- **Community Trust Scoring:** If account lacks "organizational transparency" (no website, no staff list) but is verified by community, receives `+10` bonus in trust calculation

---

### Layer 2: AI Reasoning

#### UC-R1: Calculate Trust Score (Updated for v2.0)

**ID:** UC-R1  
**Actor:** Trust Scoring Engine  
**Trigger:** New item enters processing queue  
**Preconditions:** Item has valid `source_id`

**Main Flow:**

**Step 1: Base Score (0-45 points)**
- Read `base_score` from `source_profiles` based on Source Class
- Example: 
  - REGIME_MEDIA: 35
  - MAINSTREAM_DIASPORA: 75
  - NGO_WATCHDOG: 90

**Step 2: Provenance Score (max 20 points)**
- Valid URL: +6
- Precise timestamp: +5
- Named author: +4
- Dateline (location): +3
- Original media (image/video): +2

**Step 3: Corroboration Score (max 20 points)**
- Vector search for similar items (Cosine Similarity > 0.85)
- Count independent sources (filter: different Ownership Cluster)
- Scoring:
  - 0 matches: 0
  - 1 match: +8
  - 2 matches: +14
  - 3+ matches: +20

**Step 4: Transparency Score (max 15 points)**
- Source level (0-9): About page (+3), Corrections policy (+2), Staff list (+2), Contact info (+2)
- Item level (0-6): Named author (+2), Primary source links (+1), Methodology (+1)

**Step 5: Community Trust Bonus (NEW in v2.0)**
- If source in Whitelist: +10
- Compensates for lack of organizational transparency

**Step 6: Modifiers**
- Anonymous sourcing: -8
- Unverified numbers: -10
- Primary document link: +6

**Step 7: Final Calculation**
```python
final_score = CLAMP(15, 95, base + provenance + corroboration + transparency + community_bonus + modifiers)
```

**Postconditions:** Item has `final_score` and `trust_level` in `trust_signals` table

**Technical Notes:**
- Formula source: [Master Functional Specification]
- **Breaking change:** Community Trust replaces blanket penalty for non-institutional sources

---

#### UC-R5: Cluster into Narratives

**ID:** UC-R5  
**Actor:** Narrative Clustering Engine (o3-mini)  
**Trigger:** Batch job every 15 minutes  
**Preconditions:** At least 10 new items in queue

**Main Flow:**

1. **Candidate Retrieval:**
   - For each new item, perform Vector Search (14-day window)
   - Retrieve top 50 similar items

2. **Similarity Gating:**
   - Calculate Cosine Similarity
   - Calculate Entity Overlap (shared PERSON/ORG/EVENT entities)
   - **Match condition:**
     - (Cosine Similarity > 0.85) OR
     - (Cosine Similarity > 0.75 AND Entity Overlap ≥ 2)

3. **Stance Check:**
   - If Match Condition met:
     - Check `main_event_id`
     - If identical → **Merge to existing Narrative**
   - **Note:** Even opposing stances merge (e.g., "protest was peaceful" vs "protest was violent" = same event)

4. **Create or Update:**
   - **If no match:** Create new Narrative
     - Generate title with o3-mini
     - Generate summary with GPT-4o
     - Calculate Trend Score (source count × recency factor)
   - **If match:** Update existing
     - Increment item count
     - Update `last_seen` timestamp
     - Recalculate Trend Score

**Postconditions:** All items linked to a `narrative_id`

**Technical Specifications:**
- Model: o3-mini for clustering decisions (high reasoning)
- Model: GPT-4o for narrative summaries (quality writing)
- Vector DB: Azure AI Search with pgvector
- Reference: [HLD Architecture Document]

---

#### UC-R6: Generate Context (Refactored from Debunking)

**ID:** UC-R6  
**Actor:** Context Generation Service (GPT-4o)  
**Trigger:** New narrative created OR narrative becomes trending  
**Preconditions:** Narrative has ≥3 items from different sources

**Main Flow:**

1. **Input Preparation:**
   - Collect all items in narrative
   - Extract: headlines, source classes, key entities, timestamps

2. **Prompt Engineering:**
   - System prompt: "You are an impartial analyst explaining Iranian news to international audiences. Use controlled vocabulary. Distinguish regime narratives from independent reporting without political bias."
   - Context: Source distribution (X regime, Y independent, Z international)

3. **Content Generation:**
   - **Paragraph 1:** What happened (factual summary)
   - **Paragraph 2:** Why it matters (historical context, political significance)
   - **Paragraph 3:** Source bias analysis (which narratives exist, who promotes them)

4. **Controlled Vocabulary Check:**
   - Replace: "rioter" → "protester"
   - Replace: "terrorist" → "armed group" (unless in direct quote)
   - Flag sensitive terms for editorial review

5. **Storage:**
   - Save to `narratives.context_text`
   - Flag `needs_editorial_review = true` if sensitive

**Postconditions:** Narrative has English context for US-02

**Technical Specifications:**
- Model: GPT-4o (highest quality)
- Max length: 500 words
- Language: English only
- Controlled glossary: Maintained in `controlled_vocabulary` table

**Example Output:**
```
What happened: On January 15, 2026, protests erupted in Zahedan following Friday prayers, 
with demonstrators demanding justice for detainees. State media (IRNA, Tasnim) reported 
"disturbances" while independent accounts (1500tasvir, NetBlocks) documented security 
forces using live ammunition.

Why it matters: This continues the pattern of post-prayer protests in Zahedan that began 
after the September 2022 Bloody Friday incident. The city has become a focal point of 
Sunni-majority Baluch resistance to central government policies.

Source analysis: Regime outlets frame events as "foreign-backed riots" while diaspora media 
and human rights organizations characterize them as legitimate grievances over discrimination 
and police brutality.
```

---

#### UC-R8: Silence Detection (NEW in v2.0)

**ID:** UC-R8  
**Actor:** Censorship Detection Module  
**Trigger:** Daily batch job (12:00 AM UTC)  
**Preconditions:** Access to Twitter Trending API

**Main Flow:**

1. **Trending Topic Retrieval:**
   - Fetch Top 20 trending topics in Persian Twitter
   - Filter: Iran-related hashtags/keywords

2. **State Media Coverage Check:**
   - For each trending topic:
     - Search `items` where `source_class = REGIME_MEDIA`
     - Time window: Last 24 hours
     - Count matching items

3. **Gap Detection:**
   - If item count < 2:
     - Create `narrative_gap` record
     - Data: `{topic, twitter_volume, state_media_coverage: 0}`
     - Flag: "Potential Censorship"

4. **Alert Generation:**
   - Send notification to editorial team
   - Generate UI banner: "⚠️ This topic is trending on social media but ignored by state outlets"

5. **False Positive Filtering:**
   - Ignore if topic category = Sports OR Entertainment
   - Keyword blacklist: Celebrity names, sports events

**Postconditions:** Users aware of coordinated silence

**Exception Flow:**
- **E1:** Twitter API unavailable → Skip run, log incident
- **E2:** Trending topic in non-Persian language → Ignore

**Technical Specifications:**
- Twitter Trends API: Geographic filter for Iran
- Threshold: >10,000 tweets in 24h = "trending"
- Storage: New table `narrative_gaps`

**UI Integration:**
- Banner appears on homepage when gap detected
- Links to Twitter search for topic
- Shows last state media mention (if any)

---

### Layer 3: Application/Product

#### UC-A2: View Item Details with Smart Share

**ID:** UC-A2  
**Actor:** Diaspora Activist  
**Trigger:** User clicks on news item  
**Preconditions:** Item has complete trust scoring

**Main Flow:**

1. **Display Content:**
   - Full article text
   - Featured image (if available)
   - Source logo and name

2. **Trust Breakdown Section:**
   - **Base Score:** Bar chart showing source class score
   - **Provenance:** Checklist (✓ URL, ✓ Timestamp, ✗ Anonymous author)
   - **Corroboration:** List of confirming sources (clickable links)
   - **Transparency:** Link to source "About" page

3. **Context Box:**
   - English paragraph (from UC-R6)
   - Expandable "Read More" if >300 words

4. **Smart Share Buttons:**

   **A. "Tweet This" Button:**
   - Generates 3-tweet thread:
     ```
     Tweet 1: [Headline] [Trust Badge Emoji] 🔗 [Short Link]
     
     Tweet 2: Context: [2-sentence summary] #IranProtests #HumanRights
     
     Tweet 3: Verified by: [Source 1], [Source 2] 📎 Evidence: [Link]
     ```
   - Copies to clipboard
   - Opens Twitter composer (optional)

   **B. "Instagram Story" Button:**
   - Triggers UC-A7 (Image Generation)
   - Downloads 1080×1920 PNG
   - Overlays: Headline, Trust Score, QR code, Nura logo

5. **Evidence Links:**
   - Collapsible section showing related documents
   - Copy button for each link

**Postconditions:** User has ready-made content for social sharing

**UI/UX Specifications:**
- Mobile-first design (70% of users on mobile)
- Share buttons sticky on scroll (always accessible)
- Dark mode support
- RTL text support for Persian content

**Technical Stack:**
- Frontend: Framer (per project requirements)
- API endpoint: `GET /item/{id}/share-kit`

---

#### UC-A7: Generate Instagram Story Image (NEW)

**ID:** UC-A7  
**Actor:** Smart Share Service  
**Trigger:** User clicks "Share to Instagram"  
**Preconditions:** Item has title and trust score

**Main Flow:**

1. **Canvas Creation:**
   - Dimensions: 1080×1920 (Instagram Story format)
   - Background: White-to-blue gradient (Nura brand colors)

2. **Layout Elements:**
   - **Header:** Nura logo (top 200px)
   - **Body (700px):**
     - Headline in bold (max 3 lines, auto-truncate)
     - Trust score as colored circular badge
     - Source name in small text
   - **Footer (200px):**
     - QR code linking to full article
     - Text: "Scan for full story"

3. **Typography:**
   - Headline: Sans-serif, 72pt, bold
   - Trust score: 120pt, white text on colored circle
   - Footer text: 32pt

4. **Color Coding:**
   - Trust >70: Green gradient
   - Trust 40-70: Orange gradient  
   - Trust <40: Red gradient

5. **Rendering:**
   - Server-side image generation
   - Output: PNG format
   - Filename: `nura-story-{item_id}.png`

6. **Delivery:**
   - Auto-download to user device
   - Cache for 24 hours

**Postconditions:** User has Instagram-ready image

**Technical Implementation:**
```python
# Pseudocode
def generate_story_image(item_id):
    item = fetch_item(item_id)
    canvas = create_canvas(1080, 1920)
    
    # Background
    canvas.gradient(top_color="#FFFFFF", bottom_color="#4A90E2")
    
    # Logo
    canvas.add_image("nura-logo.png", x=540, y=100, width=300)
    
    # Headline
    canvas.add_text(
        text=item.title,
        x=100, y=400,
        font="Arial Bold", size=72,
        max_lines=3
    )
    
    # Trust badge
    color = get_badge_color(item.trust_score)
    canvas.add_circle(x=540, y=900, radius=150, fill=color)
    canvas.add_text(str(item.trust_score), x=540, y=900, size=120, color="white")
    
    # QR Code
    qr = generate_qr(f"https://nura.ai/item/{item_id}")
    canvas.add_image(qr, x=440, y=1600, width=200)
    
    return canvas.export_png()
```

**Technical Stack:**
- Python + Pillow OR Playwright (screenshot approach)
- Font: Open Sans (license-free)
- Hosting: Azure Blob Storage (CDN cached)

---

### Layer 4: Governance (Minimal for MVP)

#### UC-G1: Manage Source Bible (Backend Only)

**ID:** UC-G1  
**Actor:** Technical Lead (Manual process)  
**Trigger:** Need to add new source  
**Preconditions:** Access to Git repository

**Main Flow:**

1. **Open Configuration File:**
   - File: `config/sources.csv`
   - Format:
   ```csv
   source_name,url,source_class,base_score,transparency_score,context_statement
   ```

2. **Add New Entry:**
   ```csv
   "BBC Persian","https://bbc.com/persian/rss","MAINSTREAM_DIASPORA",75,8,"UK state-funded, editorially independent"
   ```

3. **Validation:**
   - Check URL accessibility
   - Verify RSS format
   - Ensure source_class is valid enum

4. **Deployment:**
   - Git commit with message: "Add source: BBC Persian"
   - Push to main branch
   - Ingestion service auto-reloads (hot reload from CSV)

5. **Verification:**
   - Monitor logs for successful ingestion
   - Check `source_profiles` table for new entry

**Postconditions:** New source begins ingestion within 15 minutes

**Note for MVP:**
- No admin UI built
- All changes via Git (Configuration as Code)
- Post-MVP: Build admin panel as UC-G7

**Change Log Format:**
```
Date: 2026-02-05
Action: ADD_SOURCE
Source: BBC Persian
Rationale: Major diaspora broadcaster
Approved by: Editorial Lead
```

---

#### UC-G2: Fairness & Controlled Vocabulary Enforcement

**ID:** UC-G2  
**Actor:** Content Quality System (Automated + Manual Review)  
**Trigger:** Context generation (UC-R6) OR Manual editorial review  
**Preconditions:** Controlled vocabulary database loaded

**Main Flow:**

1. **Vocabulary Check:**
   - Scan generated text for flagged terms
   - Terms database:
   ```json
   {
     "rioter": {"replace": "protester", "severity": "high"},
     "terrorist": {"replace": "armed group", "severity": "medium", "exception": "direct_quote"},
     "separatist": {"replace": "autonomy advocate", "severity": "low"}
   }
   ```

2. **Automated Replacement:**
   - For severity=high: Auto-replace
   - For severity=medium: Replace unless in quote marks
   - For severity=low: Flag for editorial review

3. **Quote Detection:**
   - If term appears in `"..."` or `«...»`:
     - Keep original
     - Add footnote: "Translation of regime terminology"

4. **Bias Check:**
   - Scan for loaded language patterns:
     - "Regime claims X but..." → Acceptable
     - "The regime lies about X" → Flag (too editorial)

5. **Editorial Queue:**
   - Sensitive narratives flagged to `editorial_review_queue`
   - Manual approval required before publishing

**Postconditions:** All public-facing text follows fairness guidelines

**Technical Implementation:**
- Rule engine: Python + spaCy for context detection
- Database: `controlled_vocabulary` table
- Review queue: Airtable integration (temporary for MVP)

**Example Transformation:**
```
BEFORE: "Rioters clashed with security forces in Tehran, according to state media."

AFTER: "Protesters clashed with security forces in Tehran, according to regime media outlets. 
Independent sources characterized the demonstrations as peaceful until security forces deployed 
tear gas."
```

---

## 📊 Priority Matrix

| User Story / Use Case | Priority | Sprint Assignment | Dependencies | Estimated Effort |
|:---------------------|:---------|:------------------|:-------------|:----------------|
| US-01 (Trust Score) | P0 | Sprint 1 | UC-R1 | 3 days |
| US-02 (Context) | P0 | Sprint 2 | UC-R6, Vocabulary DB | 5 days |
| US-04 (Narratives) | P0 | Sprint 2 | UC-R5 | 8 days |
| US-05 (Smart Share) | P0 | Sprint 3 | UC-A7 | 8 days |
| US-03 (Source Profile) | P1 | Sprint 3 | UC-D3 | 5 days |
| US-06 (Evidence Bank) | P1 | Sprint 4 | Manual curation | 3 days |
| UC-R8 (Silence Detection) | P2 | Post-MVP | Twitter API setup | 5 days |

**Sprint Timeline:**
- Sprint 1 (Week 1): Infrastructure + Ingestion + Basic Scoring
- Sprint 2 (Week 2): Narratives + Context Generation
- Sprint 3 (Week 3): Smart Share + UI Polish
- Sprint 4 (Week 4): Testing + Beta Launch

---

## ✅ Definition of Done (DoD)

For each User Story to be considered "Done":

### Code Quality
- [ ] Code written and unit tested (>80% coverage)
- [ ] Peer review completed
- [ ] No P0/P1 bugs

### Documentation
- [ ] API documentation updated (OpenAPI spec)
- [ ] README updated with setup instructions
- [ ] Inline code comments for complex logic

### Testing
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Manual QA by Product Owner
- [ ] Tested with native Farsi speaker (for Context)

### Deployment
- [ ] Deployed to staging environment
- [ ] Performance verified (<2s page load)
- [ ] Mobile responsiveness checked

### Sign-off
- [ ] Demo to Product Owner
- [ ] Product Owner approval obtained
- [ ] Moved to "Done" column in project board

---

## 🚨 Out of Scope (Post-MVP Features)

The following are **NOT** included in MVP and deferred to Phase 2:

1. **Admin UI Panel** (manual backend management for MVP)
2. **Multi-language UI** (English only for MVP; add Farsi later)
3. **User accounts/authentication** (public access only)
4. **Email notifications** for trending narratives
5. **Browser extension** for in-situ fact-checking
6. **Automated fact-checking** of numerical claims (manual for MVP)
7. **Video analysis** (text-only for MVP)
8. **Telegram channel monitoring** (Twitter/X only for MVP)

---

## 📚 References

1. [Meeting Minutes Strategic.docx] - Strategic decisions and architecture
2. [Master Functional Specification: Source Evaluation.md] - Trust scoring formulas
3. [HLD Document] - System architecture and data flows
4. [SRS v1.0] - Original use case foundation

---

## 📝 Approval Signatures

| Role | Name | Signature | Date |
|:-----|:-----|:----------|:-----|
| Product Owner | [Pending] | ✅ Approved | Feb 3, 2026 |
| Business Analyst | Kaveh | ✅ Prepared | Feb 3, 2026 |
| Media Specialist | Sara | ✅ Reviewed | Feb 3, 2026 |
| UX Specialist | Mani | ✅ Reviewed | Feb 3, 2026 |
| Web Designer | Farzad | ✅ Reviewed | Feb 3, 2026 |

---

**Document Status:** ✅ Final - Ready for Development Sprint Planning

**Next Steps:**
1. Technical Lead prepares database schema (SQL DDL)
2. Backend team begins Sprint 1: UC-D1, UC-D2, UC-R1
3. Frontend team begins Framer mockups for US-01, US-04
4. Editorial team prepares Source Bible CSV and Controlled Vocabulary

---

*This document is the single source of truth for Nura MVP requirements. Any changes must be approved by Product Owner and documented in version history.*