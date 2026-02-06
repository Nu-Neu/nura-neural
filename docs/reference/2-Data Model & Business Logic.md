<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# NURA Platform - Data Model \& Business Logic Specification

## Version 2.0 - Final Master Document

**Document Type:** Technical Specification
**Date:** February 5, 2026, 7:44 PM NZDT
**Status:** 🟢 Final Approved for Implementation
**Owner:** Nura Architecture Team
**Scope:** Complete data model, algorithms, and business logic for MVP

***

## Document Control

| Version | Date | Author | Changes |
| :-- | :-- | :-- | :-- |
| 1.0 | Feb 5, 2026 13:31 | Amir (Architect) | Initial domain model |
| 1.5 | Feb 5, 2026 13:42 | Team | Added LLM penalty logic |
| 2.0 | Feb 5, 2026 19:44 | Team | Complete consolidated version |


***

## Table of Contents

1. [Domain Model - Complete Entity Definitions](#1-domain-model)
2. [Entity Relationships](#2-entity-relationships)
3. [Core Business Logic - Algorithms](#3-core-business-logic)
4. [Scoring Algorithms - Mathematical Formulas](#4-scoring-algorithms)
5. [n8n Workflow Logic](#5-n8n-workflow-logic)
6. [Operational Logic \& Rules](#6-operational-logic)
7. [Data Flow Processes](#7-data-flow-processes)
8. [References \& Sources](#8-references)

***

## 1. Domain Model

### 1.1 Entity: Source

**Purpose:** Represents any content producer (news agency, individual, organization).

**Critical Requirement:** All sources must have a `baseline_trust_score` calculated using IMTT framework before any content from them is analyzed.

**Schema:**

```json
{
  "id": "uuid (primary key)",
  "name": "string (display name)",
  "name_fa": "string (Farsi name, nullable)",
  "source_type": "enum (NEWS_ORG | INDIVIDUAL | GOVERNMENT_ORG | THINK_TANK | NGO)",
  "official_capacity": "enum (NONE | HEAD_OF_STATE | SPOKESPERSON | OFFICIAL | JOURNALIST)",
  "platform": "enum (RSS | TWITTER | TELEGRAM | WEB | YOUTUBE)",
  "platform_identifier": "string (RSS URL, Twitter handle, etc.)",
  
  "default_language": "string (ISO 639-1: 'fa', 'ar', 'en', 'tr')",
  
  "baseline_trust_score": "number (0-100, calculated from IMTT)",
  "imtt_scores": {
    "integrity": "number (0-25)",
    "methodology": "number (0-25)",
    "transparency": "number (0-25)",
    "trustworthiness": "number (0-25)"
  },
  
  "audit_status": "enum (PENDING | AUDITED | REQUIRES_UPDATE)",
  "last_audit_at": "timestamp",
  
  "ownership_type": "enum (STATE_CONTROLLED | INDEPENDENT | PRIVATE | NGO | UNKNOWN)",
  "affiliation": "array<string> (e.g., ['IRGC', 'Regime'], ['Independent'], etc.)",
  "funding_sources": "array<string> (e.g., ['Iranian Government', 'Donations'])",
  
  "metadata": {
    "domain": "string (website domain)",
    "domain_authority": "number (0-100, from SEO tools)",
    "wikipedia_url": "string (nullable)",
    "founded_year": "number (nullable)"
  },
  
  "is_active": "boolean",
  "created_at": "timestamp",
  "updated_at": "timestamp"
}
```

**Indexes:**

- Primary: `id`
- Unique: `platform` + `platform_identifier`
- Secondary: `source_type`, `baseline_trust_score`
- Full-text: `name`, `name_fa`

**Example:**

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "HRANA",
  "name_fa": "سازمان حقوق بشر فعالان",
  "source_type": "NGO",
  "platform": "RSS",
  "platform_identifier": "https://www.en-hrana.org/feed",
  "default_language": "en",
  "baseline_trust_score": 90,
  "imtt_scores": {
    "integrity": 23,
    "methodology": 20,
    "transparency": 24,
    "trustworthiness": 23
  },
  "audit_status": "AUDITED",
  "ownership_type": "NGO",
  "affiliation": ["Independent", "Human Rights"]
}
```

**Business Rules:**

1. If `audit_status = PENDING`, content can be ingested but will receive a "Unverified Source" warning.
2. If `baseline_trust_score < 30` AND `affiliation` contains "Regime", automatically flag content for propaganda detection.
3. Sources with `is_active = false` are archived but historical data is retained.

***

### 1.2 Entity: ContentItem

**Purpose:** The atomic unit of content. Stores both original and translated text.

**Critical Design Decision:** ALL content is translated to English for processing, regardless of original language. This enables:

- Consistent embedding generation
- Better clustering accuracy
- Unified AI analysis

**Schema:**

```json
{
  "id": "uuid (primary key)",
  "source_id": "uuid (FK → Source.id)",
  "external_id": "string (unique ID from platform, e.g., tweet ID)",
  
  "content_nature": "enum (FACTUAL | INTERPRETIVE | MIXED | UNKNOWN)",
  "content_type": "enum (BREAKING_NEWS | ARTICLE | OPINION | STATEMENT | THREAD | VIDEO | IMAGE)",
  
  "original_language": "string (auto-detected, ISO 639-1)",
  "original_title": "string (nullable, max 500 chars)",
  "original_text": "text (full raw content)",
  
  "translated_title_en": "string (max 500 chars)",
  "translated_text_en": "text (for AI processing)",
  "translation_model": "string (e.g., 'gpt-5-nano', nullable if original is English)",
  
  "embedding_vector": "vector (1536 dimensions, pgvector type)",
  "embedding_model": "string (e.g., 'text-embedding-3-small')",
  
  "cluster_id": "uuid (FK → Cluster.id, nullable initially)",
  "parent_id": "uuid (FK → ContentItem.id, for threads/replies, nullable)",
  
  "platform_metadata": {
    "url": "string",
    "author_handle": "string",
    "author_name": "string",
    "likes": "number",
    "shares": "number",
    "views": "number",
    "engagement_rate": "number (calculated)",
    "is_retweet": "boolean",
    "is_quote": "boolean",
    "media_attachments": "array<string> (URLs)"
  },
  
  "processing_status": "enum (PENDING | TRANSLATED | EMBEDDED | CLUSTERED | ANALYZED | FINALIZED)",
  
  "published_at": "timestamp",
  "ingested_at": "timestamp",
  "processed_at": "timestamp (nullable)"
}
```

**Indexes:**

- Primary: `id`
- Unique: `source_id` + `external_id`
- Foreign Keys: `source_id`, `cluster_id`, `parent_id`
- Vector Index: `embedding_vector` (HNSW for fast similarity search)
- Time-range: `published_at`, `ingested_at`
- Filter: `processing_status`, `content_nature`

**Example:**

```json
{
  "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "source_id": "550e8400-e29b-41d4-a716-446655440000",
  "external_id": "hrana-2026-02-05-001",
  "content_nature": "FACTUAL",
  "content_type": "BREAKING_NEWS",
  "original_language": "en",
  "original_title": "HRANA Reports 96 Deaths in Zahedan Protests",
  "original_text": "Human Rights Activists News Agency (HRANA) documented at least 96 deaths during protests in Zahedan on January 10, 2026...",
  "translated_title_en": "HRANA Reports 96 Deaths in Zahedan Protests",
  "translated_text_en": "Human Rights Activists News Agency (HRANA) documented at least 96 deaths during protests in Zahedan on January 10, 2026...",
  "embedding_vector": "[0.023, -0.015, 0.041, ...]",
  "cluster_id": "a3c9e679-0000-40de-944b-e07fc1f90ae7",
  "published_at": "2026-01-25T14:30:00Z",
  "ingested_at": "2026-01-25T14:35:12Z",
  "processing_status": "ANALYZED"
}
```

**Business Rules:**

1. If `original_language ≠ 'en'`, `translated_text_en` is REQUIRED before clustering.
2. If `processing_status = PENDING` for > 5 minutes, trigger alert (stuck in pipeline).
3. `embedding_vector` must be generated from `translated_text_en`, not `original_text`.
4. If `parent_id` is set, this is part of a thread → lower priority for individual analysis.

***

### 1.3 Entity: Cluster

**Purpose:** Represents a unified narrative composed of multiple similar ContentItems from various sources.

**Key Concept:** A Cluster is the "story" (e.g., "Zahedan Protests Death Toll"), not individual articles about it.

**Schema:**

```json
{
  "id": "uuid (primary key)",
  
  "title_en": "string (AI-synthesized, max 200 chars)",
  "summary_en": "string (one-sentence context, max 280 chars)",
  
  "trust_badge": "enum (HIGH_TRUST | MEDIUM_TRUST | LOW_TRUST | PROPAGANDA_ALERT)",
  "final_trust_score": "number (0-100)",
  "content_quality_score": "number (0-100)",
  "source_weighted_score": "number (0-100, weighted avg of all sources in cluster)",
  
  "narrative_pattern": "enum (ORGANIC | COORDINATED_PROPAGANDA | DISPUTED)",
  "is_breaking": "boolean",
  
  "representative_item_id": "uuid (FK → ContentItem.id)",
  "total_items_count": "number",
  
  "impact_metrics": {
    "total_engagement": "number (sum of all items' engagement)",
    "unique_sources": "number",
    "geographic_spread": "array<string> (countries where sources are based)",
    "velocity": "number (items per hour)"
  },
  
  "deep_research_triggered": "boolean",
  "deep_research_result": "json (nullable, from Perplexity Pro)",
  
  "first_seen_at": "timestamp",
  "last_updated_at": "timestamp",
  "expires_at": "timestamp (14 days after first_seen_at)"
}
```

**Indexes:**

- Primary: `id`
- Foreign Key: `representative_item_id`
- Filter: `trust_badge`, `narrative_pattern`, `is_breaking`
- Score-range: `final_trust_score`
- Time-range: `first_seen_at`, `last_updated_at`, `expires_at`

**Example:**

```json
{
  "id": "a3c9e679-0000-40de-944b-e07fc1f90ae7",
  "title_en": "Zahedan Protests: Death Toll Disputed (96-22,490)",
  "summary_en": "Multiple sources report deaths from January 10 protests, with figures ranging from regime's 3,117 to HRANA's 22,490.",
  "trust_badge": "MEDIUM_TRUST",
  "final_trust_score": 65,
  "narrative_pattern": "DISPUTED",
  "representative_item_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "total_items_count": 47,
  "impact_metrics": {
    "total_engagement": 125000,
    "unique_sources": 12,
    "velocity": 3.2
  },
  "first_seen_at": "2026-01-25T14:30:00Z",
  "last_updated_at": "2026-01-26T08:15:00Z"
}
```

**Business Rules:**

1. A Cluster must have at least 1 ContentItem.
2. `representative_item_id` must point to the item with highest `source.baseline_trust_score` in the cluster.
3. If `expires_at` is reached, cluster is archived but data retained.
4. `trust_badge` is recalculated every time a new item is added to the cluster.

***

### 1.4 Entity: ContentAnalysis

**Purpose:** Stores AI-generated analysis results. Separated from ContentItem for data normalization.

**Key Decision:** Analysis is stored per ContentItem initially, but inherited by similar items via RAG.

**Schema:**

```json
{
  "id": "uuid (primary key)",
  "content_item_id": "uuid (FK → ContentItem.id)",
  "cluster_id": "uuid (FK → Cluster.id, nullable)",
  
  "analysis_type": "enum (FACT_CHECK | ARGUMENT_ANALYSIS | PROPAGANDA_DETECTION)",
  
  "propaganda_detected": "boolean",
  "detected_techniques": "array<string> (e.g., ['Loaded_Language', 'Dehumanization'])",
  "logical_fallacies": "array<string> (e.g., ['Strawman', 'False_Dilemma'])",
  "tone": "enum (NEUTRAL | INFLAMMATORY | PARTISAN | FEARMONGERING)",
  
  "penalty_breakdown": [
    {
      "issue_type": "enum (PROPAGANDA | FALLACY | TONE | SOURCING)",
      "specific_technique": "string",
      "evidence": "string (exact quote from text)",
      "penalty_amount": "number",
      "explanation_en": "string",
      "explanation_fa": "string (nullable)"
    }
  ],
  
  "content_quality_score": "number (80 - sum of penalties)",
  "total_penalty_applied": "number (sum of all penalty_amount)",
  
  "verdict_en": "text (detailed explanation)",
  "verdict_fa": "text (Farsi translation, nullable)",
  "confidence_score": "number (0-1)",
  
  "ai_model_used": "string (e.g., 'gpt-5-nano-20260101')",
  "prompt_version": "string (for A/B testing prompts)",
  "analyzed_at": "timestamp",
  
  "inherited_from": "uuid (FK → ContentAnalysis.id, nullable, if using RAG)",
  "reuse_count": "number (how many times this analysis was inherited)"
}
```

**Indexes:**

- Primary: `id`
- Foreign Keys: `content_item_id`, `cluster_id`, `inherited_from`
- Filter: `analysis_type`, `propaganda_detected`
- Score-range: `content_quality_score`, `confidence_score`

**Example:**

```json
{
  "id": "b4d9f679-1234-40de-944b-e07fc1f90ae7",
  "content_item_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "analysis_type": "FACT_CHECK",
  "propaganda_detected": false,
  "detected_techniques": [],
  "tone": "NEUTRAL",
  "penalty_breakdown": [
    {
      "issue_type": "SOURCING",
      "specific_technique": "Anonymous_Sources",
      "evidence": "Sources within the regime confirmed",
      "penalty_amount": 9,
      "explanation_en": "Uses unverifiable anonymous sources for critical death toll claim"
    }
  ],
  "content_quality_score": 71,
  "total_penalty_applied": 9,
  "verdict_en": "Credible report with minor sourcing concerns",
  "confidence_score": 0.85,
  "ai_model_used": "gpt-5-nano-20260101",
  "analyzed_at": "2026-01-25T14:40:00Z"
}
```

**Business Rules:**

1. If `inherited_from` is set, no new AI analysis was performed (cost savings).
2. `content_quality_score` cannot exceed 80 (base score).
3. If `confidence_score < 0.7`, flag for human review.
4. Analysis older than 30 days should be re-run if content is still active.

***

### 1.5 Entity: KnowledgeBase

**Purpose:** Stores verified facts and historical propaganda patterns for RAG (Retrieval-Augmented Generation).

**Key Innovation:** This is NURA's "memory" - prevents re-analyzing the same propaganda tactics repeatedly.

**Schema:**

```json
{
  "id": "uuid (primary key)",
  
  "fact_type": "enum (HISTORICAL_FACT | NARRATIVE_PATTERN | VERIFIED_CLAIM | PROPAGANDA_TECHNIQUE)",
  
  "text_content": "text (verified knowledge, max 2000 chars)",
  "text_content_fa": "text (Farsi version, nullable)",
  
  "embedding_vector": "vector (1536 dimensions)",
  
  "verification_source": "enum (EXPERT | PERPLEXITY_PRO | HISTORICAL | ACADEMIC | AMNESTY | UN)",
  "confidence_level": "number (0-1)",
  
  "related_entities": "array<string> (people, orgs, events, e.g., ['Mahsa Amini', 'IRGC', '2022 Protests'])",
  "related_clusters": "array<uuid> (Cluster IDs where this was used)",
  
  "metadata": {
    "date_range": "string (e.g., '2022-09-16 to 2023-01-20')",
    "geographic_scope": "string (e.g., 'Iran, Tehran')",
    "citation": "string (academic source or URL)",
    "pattern_confidence": "number (for NARRATIVE_PATTERN type)"
  },
  
  "reference_count": "number (how many times used in RAG)",
  "last_referenced_at": "timestamp",
  "created_at": "timestamp",
  "created_by": "enum (AI | EXPERT | PERPLEXITY)"
}
```

**Indexes:**

- Primary: `id`
- Vector: `embedding_vector` (HNSW index)
- Filter: `fact_type`, `verification_source`, `confidence_level`
- Full-text: `text_content`, `related_entities`
- Array: `related_entities` (GIN index for fast lookup)

**Example:**

```json
{
  "id": "c5e9f679-5678-40de-944b-e07fc1f90ae7",
  "fact_type": "PROPAGANDA_TECHNIQUE",
  "text_content": "Regime sources consistently underreport protest deaths by 85-90%. Historical pattern: 2019 (reported 225, actual 1,500), 2022 (reported 83, actual 551).",
  "embedding_vector": "[0.012, -0.034, 0.056, ...]",
  "verification_source": "HISTORICAL",
  "confidence_level": 0.95,
  "related_entities": ["IRGC", "Tasnim", "Fars News", "State TV"],
  "metadata": {
    "pattern_confidence": 0.91,
    "citation": "Amnesty International Reports 2019, 2022"
  },
  "reference_count": 23,
  "created_at": "2026-01-15T10:00:00Z",
  "created_by": "EXPERT"
}
```

**Business Rules:**

1. Only entries with `confidence_level ≥ 0.8` are used for RAG.
2. If `reference_count` exceeds 100, consider promoting to "Core Fact" (faster lookup).
3. Entries older than 2 years should be reviewed for relevance.
4. `PROPAGANDA_TECHNIQUE` type requires `pattern_confidence ≥ 0.85`.

***

## 2. Entity Relationships

### 2.1 Relationship Diagram

```
Source (1) ────────────────── (N) ContentItem
   │                               │
   │                               ├─── (1) ContentAnalysis
   │                               │
   │                               └─── (N) Cluster
   │                                       │
   └───────────────────────────────────────┴─── (1) Representative ContentItem

ContentItem (parent) ────── (children) ContentItem
   (for Twitter threads and reply chains)

KnowledgeBase ←────── (RAG reference) ────────→ ContentAnalysis
   (similarity search during analysis)

Cluster ←────── (enrichment) ────────→ KnowledgeBase.related_clusters[]
```


### 2.2 Detailed Relationships

#### Source → ContentItem (1:N)

**Type:** One-to-Many
**Description:** One source produces many content items.
**Cascade:** No delete cascade (preserve historical data for forensics).
**Constraint:** `source_id` must reference an active source OR have warning flag.

#### ContentItem → Cluster (N:1)

**Type:** Many-to-One
**Description:** Multiple similar items belong to one cluster.
**Cascade:** No delete (items can exist without cluster temporarily).
**Constraint:** Items can be clustered only if `processing_status = EMBEDDED`.

#### ContentItem → ContentAnalysis (1:N)

**Type:** One-to-Many
**Description:** One item can have multiple analyses (fact-check, propaganda check).
**Cascade:** DELETE CASCADE (analysis meaningless without content).
**Constraint:** At least one analysis per item before `processing_status = ANALYZED`.

#### Cluster → Representative ContentItem (1:1)

**Type:** One-to-One (from Cluster perspective)
**Description:** Each cluster designates one item as representative.
**Selection Logic:** See Algorithm 3.6 (Representative Selection).
**Constraint:** Representative must have highest combined score (source + completeness).

#### ContentItem → ContentItem (Parent-Child)

**Type:** Self-referential One-to-Many
**Description:** For Twitter threads and reply chains.
**Cascade:** No delete (preserve orphaned items).
**Depth Limit:** 10 levels (prevent infinite loops).
**Constraint:** `parent_id` must reference older item (`published_at` comparison).

#### ContentAnalysis → ContentAnalysis (Inheritance)

**Type:** Self-referential Many-to-One
**Description:** When RAG finds similar content, new analysis inherits from old.
**Field:** `inherited_from` points to original analysis.
**Constraint:** Inherited analysis must have `confidence_score ≥ 0.8`.

#### KnowledgeBase → Cluster (N:M)

**Type:** Many-to-Many (via array field)
**Description:** Knowledge base entries reference clusters where they were used.
**Field:** `KnowledgeBase.related_clusters[]`
**Update:** Append cluster ID when used in RAG.

***

## 3. Core Business Logic

### 3.1 Universal Translation Pipeline

**Function Name:** `IngestAndTranslate`
**Input:** Raw feed item (any language)
**Output:** ContentItem with both original and translated text

**Algorithm:**

```
FUNCTION IngestAndTranslate(rawFeed):
  
  // Step 1: Normalize to standard schema
  item = NEW ContentItem()
  item.id = GenerateUUID()
  item.source_id = LookupSource(rawFeed.platform, rawFeed.source_identifier)
  item.external_id = rawFeed.id
  item.original_text = rawFeed.text
  item.original_title = rawFeed.title
  item.published_at = rawFeed.published_at
  item.ingested_at = CurrentTimestamp()
  item.processing_status = 'PENDING'
  
  // Step 2: Detect language
  detectedLang = DetectLanguage(item.original_text)
  item.original_language = detectedLang
  
  // Step 3: Translate if non-English
  IF detectedLang ≠ 'en' THEN
    translationResult = CallAI({
      model: 'gpt-5-nano',
      task: 'translate',
      parameters: {
        text: item.original_text,
        from: detectedLang,
        to: 'en',
        context: 'political_news',
        preserve_terms: ['IRGC', 'Sepah', 'Basij', 'Mahsa Amini', 'Zahedan', 'Evin']
      }
    })
    
    item.translated_text_en = translationResult.text
    item.translated_title_en = CallAI({
      model: 'gpt-5-nano',
      task: 'translate',
      parameters: {
        text: item.original_title,
        from: detectedLang,
        to: 'en'
      }
    }).text
    item.translation_model = 'gpt-5-nano'
  ELSE
    // Already English
    item.translated_text_en = item.original_text
    item.translated_title_en = item.original_title
    item.translation_model = NULL
  END IF
  
  item.processing_status = 'TRANSLATED'
  
  // Step 4: Save to database
  Database.ContentItems.Insert(item)
  
  RETURN item.id

END FUNCTION
```

**Cost:** ~\$0.001 per translation (GPT-5-nano pricing)
**Latency:** <2 seconds per item

**Business Rules:**

1. Translation preserves political terminology (no transliteration of key terms).
2. If translation fails 3 times, mark item as `processing_status = FAILED` and alert.
3. If `original_language` detection confidence < 0.7, default to source's `default_language`.

***

### 3.2 Smart Clustering with RAG (Trust Inheritance)

**Function Name:** `ClusterAndVerify`
**Input:** Translated ContentItem
**Output:** ContentItem assigned to Cluster (new or existing)

**Critical Innovation:** This algorithm saves 92% of AI analysis costs by reusing previous analyses.

**Algorithm:**

```
FUNCTION ClusterAndVerify(contentItem):
  
  // Step 1: Generate embedding from English text
  embeddingResult = CallAI({
    model: 'text-embedding-3-small',
    input: contentItem.translated_text_en
  })
  
  contentItem.embedding_vector = embeddingResult.vector
  contentItem.embedding_model = 'text-embedding-3-small'
  contentItem.processing_status = 'EMBEDDED'
  Database.ContentItems.Update(contentItem)
  
  // Step 2: RAG Check - Search historical patterns in Knowledge Base
  historicalMatches = VectorDB.Search({
    collection: 'knowledge_base',
    vector: contentItem.embedding_vector,
    limit: 3,
    threshold: 0.92,
    filter: {
      fact_type: ['NARRATIVE_PATTERN', 'VERIFIED_CLAIM'],
      confidence_level: { gte: 0.8 }
    }
  })
  
  IF historicalMatches.Count > 0 AND historicalMatches[^0].similarity >= 0.92 THEN
    // This narrative has been seen before - HIGH CONFIDENCE MATCH
    Log('RAG_HIT', contentItem.id, historicalMatches[^0].id)
    
    // Find the cluster associated with this pattern
    relatedClusterIds = historicalMatches[^0].related_clusters
    IF relatedClusterIds.Count > 0 THEN
      targetCluster = Database.Clusters.GetById(relatedClusterIds[^0])
      
      // Add item to existing cluster
      contentItem.cluster_id = targetCluster.id
      contentItem.processing_status = 'CLUSTERED'
      
      // Inherit analysis from representative item
      representativeAnalysis = Database.ContentAnalysis.GetByContentId(
        targetCluster.representative_item_id
      )
      
      newAnalysis = CloneAnalysis(representativeAnalysis)
      newAnalysis.id = GenerateUUID()
      newAnalysis.content_item_id = contentItem.id
      newAnalysis.inherited_from = representativeAnalysis.id
      newAnalysis.analyzed_at = CurrentTimestamp()
      Database.ContentAnalysis.Insert(newAnalysis)
      
      // Update cluster metrics
      targetCluster.total_items_count += 1
      targetCluster.last_updated_at = CurrentTimestamp()
      Database.Clusters.Update(targetCluster)
      
      // Update knowledge base usage stats
      historicalMatches[^0].reference_count += 1
      historicalMatches[^0].last_referenced_at = CurrentTimestamp()
      Database.KnowledgeBase.Update(historicalMatches[^0])
      
      contentItem.processing_status = 'ANALYZED'
      Database.ContentItems.Update(contentItem)
      
      RETURN {
        status: 'INHERITED',
        cluster_id: targetCluster.id,
        cost_saved: '$0.05'  // Typical analysis cost
      }
    END IF
  END IF
  
  // Step 3: Search in active clusters (NEW ANALYSIS PATH)
  activeClusterMatches = VectorDB.Search({
    collection: 'clusters',
    vector: contentItem.embedding_vector,
    limit: 1,
    threshold: 0.85,
    filter: {
      expires_at: { gt: CurrentTimestamp() }
    }
  })
  
  IF activeClusterMatches.Count > 0 AND activeClusterMatches[^0].similarity >= 0.85 THEN
    // Similar to existing cluster but not exact match
    targetCluster = activeClusterMatches[^0]
    
    contentItem.cluster_id = targetCluster.id
    contentItem.processing_status = 'CLUSTERED'
    Database.ContentItems.Update(contentItem)
    
    // Check if this adds new information (Delta Detection)
    deltaResult = DetectDelta(contentItem, targetCluster)
    
    IF deltaResult.hasNewInfo THEN
      // Analyze only the new information
      RETURN {
        status: 'ADDED_TO_CLUSTER_WITH_DELTA',
        cluster_id: targetCluster.id,
        delta_text: deltaResult.deltaText,
        requires_analysis: true
      }
    ELSE
      // Pure duplicate - inherit existing analysis
      representativeAnalysis = Database.ContentAnalysis.GetByContentId(
        targetCluster.representative_item_id
      )
      newAnalysis = CloneAnalysis(representativeAnalysis)
      newAnalysis.content_item_id = contentItem.id
      newAnalysis.inherited_from = representativeAnalysis.id
      Database.ContentAnalysis.Insert(newAnalysis)
      
      contentItem.processing_status = 'ANALYZED'
      Database.ContentItems.Update(contentItem)
      
      RETURN {
        status: 'DUPLICATE_INHERITED',
        cluster_id: targetCluster.id
      }
    END IF
  ELSE
    // No match - create new cluster
    newCluster = CreateNewCluster(contentItem)
    
    contentItem.cluster_id = newCluster.id
    contentItem.processing_status = 'CLUSTERED'
    Database.ContentItems.Update(contentItem)
    
    RETURN {
      status: 'NEW_CLUSTER_CREATED',
      cluster_id: newCluster.id,
      requires_analysis: true
    }
  END IF

END FUNCTION
```

**Thresholds (Confirmed):**

- **Knowledge Base Match:** ≥0.92 similarity → Inherit analysis (FAST PATH, \$0 cost)
- **Active Cluster Match:** ≥0.85 similarity → Add to cluster (MAY inherit or analyze delta)
- **No Match:** <0.85 similarity → Create new cluster (FULL ANALYSIS, ~\$0.05 cost)

**Performance:**

- Cache Hit Rate Target: >90%
- Average Latency: 0.05s (cache hit), 5s (new analysis)
- Cost Savings: ~\$180/day with 4,000 items

***

### 3.3 Differentiated Analysis Routing

**Function Name:** `AnalyzeReliability`
**Input:** Cluster with at least one ContentItem
**Output:** Cluster with trust scores assigned

**Key Decision:** Different content types require different analysis methods.

**Algorithm:**

```
FUNCTION AnalyzeReliability(cluster):
  
  representativeItem = Database.ContentItems.GetById(cluster.representative_item_id)
  
  // Step 1: Classify content nature
  classificationResult = CallAI({
    model: 'gpt-5-nano',
    task: 'classify',
    prompt: PROMPT_CLASSIFY_CONTENT_NATURE,
    parameters: {
      text: representativeItem.translated_text_en,
      options: ['FACTUAL', 'INTERPRETIVE', 'MIXED']
    }
  })
  
  representativeItem.content_nature = classificationResult.classification
  Database.ContentItems.Update(representativeItem)
  
  // Step 2: Route to appropriate analysis pipeline
  IF classificationResult.classification == 'FACTUAL' THEN
    // Fact-checking pipeline
    analysisResult = FactCheckPipeline(representativeItem)
  ELSE
    // Argument analysis + propaganda detection pipeline
    analysisResult = ArgumentAnalysisPipeline(representativeItem)
  END IF
  
  // Save analysis
  contentAnalysis = NEW ContentAnalysis()
  contentAnalysis.id = GenerateUUID()
  contentAnalysis.content_item_id = representativeItem.id
  contentAnalysis.cluster_id = cluster.id
  contentAnalysis.analysis_type = analysisResult.type
  contentAnalysis.propaganda_detected = analysisResult.propaganda_detected
  contentAnalysis.detected_techniques = analysisResult.techniques
  contentAnalysis.logical_fallacies = analysisResult.fallacies
  contentAnalysis.tone = analysisResult.tone
  contentAnalysis.penalty_breakdown = analysisResult.penalties
  contentAnalysis.content_quality_score = analysisResult.content_score
  contentAnalysis.total_penalty_applied = analysisResult.total_penalty
  contentAnalysis.verdict_en = analysisResult.verdict
  contentAnalysis.confidence_score = analysisResult.confidence
  contentAnalysis.ai_model_used = analysisResult.model
  contentAnalysis.analyzed_at = CurrentTimestamp()
  Database.ContentAnalysis.Insert(contentAnalysis)
  
  // Step 3: Calculate final trust score using formula
  source = Database.Sources.GetById(representativeItem.source_id)
  
  // Calculate source-weighted score for entire cluster
  allItems = Database.ContentItems.GetByClusterId(cluster.id)
  sourceScores = []
  FOR EACH item IN allItems DO
    itemSource = Database.Sources.GetById(item.source_id)
    sourceScores.Add(itemSource.baseline_trust_score)
  END FOR
  sourceWeightedScore = Average(sourceScores)
  
  // Apply formula: (Source × 0.4) + (Content × 0.6) - Propaganda Penalty
  finalScore = (sourceWeightedScore × 0.4) + 
               (contentAnalysis.content_quality_score × 0.6) -
               (contentAnalysis.propaganda_detected ? 10 : 0)
  
  // Clamp to 0-100 range
  finalScore = Max(0, Min(100, finalScore))
  
  cluster.final_trust_score = Round(finalScore, 0)
  cluster.content_quality_score = contentAnalysis.content_quality_score
  cluster.source_weighted_score = sourceWeightedScore
  
  // Step 4: Assign trust badge based on thresholds
  IF finalScore >= 70 THEN
    cluster.trust_badge = 'HIGH_TRUST'
  ELSE IF finalScore >= 40 THEN
    cluster.trust_badge = 'MEDIUM_TRUST'
  ELSE
    cluster.trust_badge = 'LOW_TRUST'
  END IF
  
  // Step 5: Override for propaganda alert
  IF contentAnalysis.propaganda_detected AND sourceWeightedScore < 30 THEN
    cluster.trust_badge = 'PROPAGANDA_ALERT'
  END IF
  
  // Step 6: Check if coordinated behavior detected
  coordinationResult = DetectCoordinatedBehavior(cluster)
  IF coordinationResult.isCoordinated THEN
    cluster.narrative_pattern = 'COORDINATED_PROPAGANDA'
    cluster.trust_badge = 'PROPAGANDA_ALERT'  // Override
  END IF
  
  Database.Clusters.Update(cluster)
  
  RETURN cluster

END FUNCTION
```


***

### 3.4 Delta Detection Algorithm

**Function Name:** `DetectDelta`
**Purpose:** Identify new information in similar content to avoid redundant analysis.
**Input:** New ContentItem, Existing Cluster
**Output:** Delta result with novel sentences

**Algorithm:**

```
FUNCTION DetectDelta(newItem, existingCluster):
  
  // Step 1: Extract sentences from both texts
  newSentences = SplitIntoSentences(newItem.translated_text_en)
  
  representativeItem = Database.ContentItems.GetById(
    existingCluster.representative_item_id
  )
  existingSentences = SplitIntoSentences(representativeItem.translated_text_en)
  
  // Step 2: Compare sentence-by-sentence using embeddings
  novelSentences = []
  
  FOR EACH sentence IN newSentences DO
    IF Length(sentence) < 10 THEN
      CONTINUE  // Skip very short sentences
    END IF
    
    sentenceEmbedding = CallAI({
      model: 'text-embedding-3-small',
      input: sentence
    }).vector
    
    maxSimilarity = 0
    
    FOR EACH existingSentence IN existingSentences DO
      existingEmbedding = CallAI({
        model: 'text-embedding-3-small',
        input: existingSentence
      }).vector
      
      similarity = CosineSimilarity(sentenceEmbedding, existingEmbedding)
      
      IF similarity > maxSimilarity THEN
        maxSimilarity = similarity
      END IF
    END FOR
    
    // If similarity < 80%, it's novel information
    IF maxSimilarity < 0.80 THEN
      novelSentences.Add({
        text: sentence,
        max_similarity: maxSimilarity
      })
    END IF
  END FOR
  
  // Step 3: Decision
  IF novelSentences.Count > 0 THEN
    deltaText = Join(novelSentences.Select(s => s.text), ' ')
    noveltyScore = novelSentences.Count / newSentences.Count
    
    RETURN {
      hasNewInfo: true,
      deltaText: deltaText,
      novelSentenceCount: novelSentences.Count,
      noveltyScore: noveltyScore,
      recommendation: noveltyScore > 0.3 ? 'FULL_ANALYSIS' : 'DELTA_ONLY'
    }
  ELSE
    RETURN {
      hasNewInfo: false,
      useExistingAnalysis: true,
      recommendation: 'INHERIT'
    }
  END IF

END FUNCTION
```

**Example:**

```
Existing: "96 people died in Zahedan protests"
New:      "96 people died in Zahedan protests, including 12 children"

Delta Result:
{
  hasNewInfo: true,
  deltaText: "including 12 children",
  novelSentenceCount: 1,
  noveltyScore: 0.2,
  recommendation: "DELTA_ONLY"
}

Action: Only analyze the claim "12 children" instead of entire text
```


***

### 3.5 Representative Item Selection

**Function Name:** `SelectRepresentativeItem`
**Purpose:** Choose the best ContentItem to represent a Cluster.
**Input:** Cluster with multiple items
**Output:** Updated cluster with `representative_item_id` set

**Algorithm:**

```
FUNCTION SelectRepresentativeItem(cluster):
  
  items = Database.ContentItems.GetByClusterId(cluster.id)
  
  IF items.Count == 1 THEN
    cluster.representative_item_id = items[^0].id
    RETURN cluster
  END IF
  
  // Score each item using multi-factor formula
  scoredItems = []
  
  FOR EACH item IN items DO
    source = Database.Sources.GetById(item.source_id)
    
    score = 0
    
    // Factor 1: Source credibility (50% weight)
    sourceScore = source.baseline_trust_score × 0.5
    score += sourceScore
    
    // Factor 2: Content completeness (30% weight)
    completenessScore = 0
    
    // Length bonus (max 10 points)
    textLength = Length(item.translated_text_en)
    lengthBonus = Min(10, (textLength / 1000) × 10)
    completenessScore += lengthBonus
    
    // Has title bonus
    IF item.translated_title_en IS NOT NULL THEN
      completenessScore += 10
    END IF
    
    // Has URL bonus
    IF item.platform_metadata.url IS NOT NULL THEN
      completenessScore += 10
    END IF
    
    // Cap at 30
    completenessScore = Min(completenessScore, 30)
    score += completenessScore
    
    // Factor 3: Engagement (20% weight)
    totalEngagement = item.platform_metadata.likes + 
                      item.platform_metadata.shares + 
                      item.platform_metadata.views
    
    IF totalEngagement > 0 THEN
      engagementScore = Log10(totalEngagement + 1) × 2
      engagementScore = Min(engagementScore, 20)
      score += engagementScore
    END IF
    
    scoredItems.Add({
      item: item,
      score: score,
      breakdown: {
        source: sourceScore,
        completeness: completenessScore,
        engagement: engagementScore
      }
    })
  END FOR
  
  // Select highest scoring item
  scoredItems = OrderByDescending(scoredItems, s => s.score)
  winner = scoredItems[^0]
  
  cluster.representative_item_id = winner.item.id
  Database.Clusters.Update(cluster)
  
  Log('REPRESENTATIVE_SELECTED', {
    cluster_id: cluster.id,
    item_id: winner.item.id,
    score: winner.score,
    breakdown: winner.breakdown
  })
  
  RETURN cluster

END FUNCTION
```

**Example Scoring:**

```
Cluster: "Zahedan Protests Death Toll"

Item A (HRANA article):
  - Source: 90 × 0.5 = 45
  - Completeness: 10 (length) + 10 (title) + 10 (URL) = 30
  - Engagement: log10(5000) × 2 = 7.4
  - Total: 82.4 ✅ WINNER

Item B (NYT article):
  - Source: 85 × 0.5 = 42.5
  - Completeness: 8 + 10 + 10 = 28
  - Engagement: log10(12000) × 2 = 8.2
  - Total: 78.7

Item C (Twitter):
  - Source: 50 × 0.5 = 25
  - Completeness: 3 + 0 + 10 = 13
  - Engagement: log10(50000) × 2 = 9.4
  - Total: 47.4
```


***

### 3.6 Coordinated Behavior Detection

**Function Name:** `DetectCoordinatedBehavior`
**Purpose:** Identify bot networks and orchestrated propaganda campaigns.
**Input:** Cluster with multiple items
**Output:** Coordination report

**Algorithm:**

```
FUNCTION DetectCoordinatedBehavior(cluster):
  
  items = Database.ContentItems.GetByClusterId(cluster.id)
  
  IF items.Count < 5 THEN
    // Too few items to detect coordination
    RETURN { isCoordinated: false, reason: 'insufficient_data' }
  END IF
  
  // Metric 1: Text Similarity Score
  similarities = []
  FOR i = 0 TO items.Count - 2 DO
    FOR j = i + 1 TO items.Count - 1 DO
      sim = CosineSimilarity(items[i].embedding_vector, items[j].embedding_vector)
      similarities.Add(sim)
    END FOR
  END FOR
  avgSimilarity = Average(similarities)
  
  // Metric 2: Time Window (how fast did this spread?)
  timestamps = items.Select(i => i.published_at).OrderBy()
  firstPost = timestamps[^0]
  lastPost = timestamps[timestamps.Count - 1]
  timeWindow = lastPost - firstPost
  timeWindowMinutes = timeWindow.TotalMinutes
  
  // Metric 3: Suspicious Sources Ratio
  suspiciousSources = 0
  FOR EACH item IN items DO
    source = Database.Sources.GetById(item.source_id)
    IF source.baseline_trust_score < 30 THEN
      suspiciousSources += 1
    END IF
  END FOR
  suspiciousRatio = suspiciousSources / items.Count
  
  // Metric 4: Account Creation Patterns (for Twitter)
  twitterItems = items.Where(i => i.source.platform == 'TWITTER')
  IF twitterItems.Count >= 5 THEN
    creationDates = twitterItems.Select(i => i.platform_metadata.account_created_at)
    creationWindow = Max(creationDates) - Min(creationDates)
    
    IF creationWindow.TotalDays < 30 AND twitterItems.Count > 10 THEN
      // Many accounts created within same month - suspicious
      suspiciousAccountPattern = true
    END IF
  END IF
  
  // Decision Logic
  confidence = 0
  reasons = []
  
  IF avgSimilarity > 0.90 THEN
    confidence += 0.35
    reasons.Add('Text similarity > 90%: ' + Round(avgSimilarity × 100, 1) + '%')
  END IF
  
  IF timeWindowMinutes < 10 AND items.Count > 20 THEN
    confidence += 0.30
    reasons.Add('Rapid propagation: ' + items.Count + ' items in ' + Round(timeWindowMinutes, 1) + ' minutes')
  END IF
  
  IF suspiciousRatio > 0.5 THEN
    confidence += 0.25
    reasons.Add('Suspicious sources: ' + Round(suspiciousRatio × 100, 0) + '%')
  END IF
  
  IF suspiciousAccountPattern THEN
    confidence += 0.10
    reasons.Add('Suspicious account creation pattern detected')
  END IF
  
  IF confidence >= 0.70 THEN
    RETURN {
      isCoordinated: true,
      confidence: confidence,
      reasons: reasons,
      metrics: {
        avgSimilarity: avgSimilarity,
        timeWindowMinutes: timeWindowMinutes,
        suspiciousRatio: suspiciousRatio
      },
      recommendation: 'FLAG_AS_PROPAGANDA'
    }
  ELSE
    RETURN {
      isCoordinated: false,
      confidence: confidence,
      reasons: ['Below coordination threshold']
    }
  END IF

END FUNCTION
```

**Thresholds:**

- **Text Similarity:** >90% (almost identical wording)
- **Time Window:** <10 minutes for >20 items (impossibly fast organic spread)
- **Suspicious Sources:** >50% from low-trust sources
- **Overall Confidence:** ≥70% to flag

***

## 4. Scoring Algorithms

### 4.1 Final Trust Score Formula

**Mathematical Expression:**

$$
\text{Final Trust Score} = (\text{Source Baseline} \times 0.4) + (\text{Content Quality} \times 0.6) - \text{Propaganda Penalty}
$$

Where:

- **Source Baseline:** 0-100 (from IMTT framework)
- **Content Quality:** 0-100 (penalty-based scoring, starts at 80)
- **Propaganda Penalty:** 0-10 (additional deduction for severe cases)

**Justification:**

- Content (60%) weighted higher because content quality varies even within trusted sources
- Source (40%) significant because historical track record matters
- Propaganda penalty as final override for extreme manipulation

**Clamping:** Final score is clamped to  range

**Reference:** design-trust-narrative-system-v1.0.md, Section 2.2 + University of Washington (2021) Research

***

### 4.2 Source Baseline Score (IMTT Framework)

**Framework:** Integrity, Methodology, Transparency, Trustworthiness


| Pillar | Weight | Criteria | Measurement |
| :-- | :-- | :-- | :-- |
| **Integrity** | 25/100 | Factual accuracy history, No plagiarism, Correction policy, Retraction transparency | Binary checks + historical audit |
| **Methodology** | 25/100 | Source citations, Research transparency, Structural consistency, Editorial standards | Weighted scoring based on presence |
| **Transparency** | 25/100 | Ownership disclosure, Funding sources disclosed, Author identification, Editorial policies accessible | Deduction for missing information |
| **Trustworthiness** | 25/100 | Peer endorsements, Audience trust surveys, Domain authority (Moz/Ahrefs), Wikipedia recognition | Aggregate scoring |

**Calculation Method:**

```
FUNCTION CalculateIMTTScore(source):
  
  // Integrity (0-25)
  integrity = 25  // Start with perfect score
  
  IF HasPlagiarismHistory(source) THEN
    integrity -= 10
  END IF
  
  factualAccuracy = GetHistoricalAccuracy(source)  // 0-1 scale
  integrity -= (1 - factualAccuracy) × 15
  
  IF NOT HasCorrectionPolicy(source) THEN
    integrity -= 5
  END IF
  
  // Methodology (0-25)
  methodology = 0
  
  citationRate = GetAverageCitationRate(source)  // 0-1 scale
  methodology += citationRate × 15
  
  IF HasEditorialStandards(source) THEN
    methodology += 5
  END IF
  
  structuralConsistency = EvaluateStructure(source)  // 0-1 scale
  methodology += structuralConsistency × 5
  
  // Transparency (0-25)
  transparency = 25  // Start with perfect score
  
  IF NOT OwnershipDisclosed(source) THEN
    transparency -= 10
  END IF
  
  IF NOT FundingDisclosed(source) THEN
    transparency -= 10
  END IF
  
  IF NOT HasNamedAuthors(source) THEN
    transparency -= 5
  END IF
  
  // Trustworthiness (0-25)
  trustworthiness = 0
  
  domainAuthority = GetDomainAuthority(source)  // 0-100 scale
  trustworthiness += (domainAuthority / 100) × 10
  
  peerEndorsements = CountPeerEndorsements(source)
  trustworthiness += Min(peerEndorsements × 2, 10)
  
  IF HasWikipediaPage(source) THEN
    trustworthiness += 5
  END IF
  
  // Sum all pillars
  baselineScore = integrity + methodology + transparency + trustworthiness
  
  RETURN baselineScore

END FUNCTION
```

**Example Calculations:**

**HRANA (Human Rights NGO):**

```
Integrity:       23/25  (Strong track record, 2 minor errors in 5 years)
Methodology:     20/25  (Good citations, sometimes anonymous sources)
Transparency:    24/25  (Clear ownership, funding disclosed, minor editorial gaps)
Trustworthiness: 23/25  (Recognized internationally, Wikipedia page, high DA)
────────────────
Total:           90/100
```

**Tasnim (IRGC Media):**

```
Integrity:       8/25   (85% historical underreporting pattern)
Methodology:     10/25  (Some citations, but selective and biased)
Transparency:    5/25   (Ownership disclosed but funding opaque)
Trustworthiness: 5/25   (Known state affiliation, low independent endorsement)
────────────────
Total:           28/100
```

**Reference:** IMTT_Inspired_Source_Scoring_Framework.md

***

### 4.3 Content Quality Score (LLM-Powered Penalty System)

**Base Score:** 80/100

**Deduction Table:**


| Issue Category | Specific Technique | Penalty | Detection Method | Evidence Required |
| :-- | :-- | :-- | :-- | :-- |
| **Heavy Propaganda** | Dehumanization | -15 | LLM pattern match | Quote: "savage rioters", "animals" |
|  | Fear-Mongering | -15 | LLM sentiment + lexicon | Quote: "imminent collapse", "chaos" |
|  | Loaded Language | -15 | LLM context analysis | Quote: "terrorists" (for protesters) |
| **Logical Fallacy** | Strawman | -10 | LLM argument structure | Misrepresenting opponent |
|  | False Dilemma | -10 | LLM logic analysis | "Either X or total destruction" |
|  | Ad Hominem | -10 | LLM entity + sentiment | Attacking person vs. argument |
| **Tone** | Inflammatory/Partisan | -10 | LLM sentiment analysis | Excessive emotional language |
| **Sourcing** | No credible citation | -15 | LLM fact extraction | Critical claim without source |
|  | Anonymous sources (critical claim) | -9 | LLM source identification | "Sources say" for death toll |

**LLM Implementation:**

**System Prompt for Content Scoring:**

```markdown
# ROLE
You are an expert media analyst specializing in propaganda detection for content related to Iran.

# TASK
Analyze the provided content and calculate a Content Quality Score using a penalty-based system.

# SCORING FRAMEWORK

## Base Score
- Start with: 80/100

## Deductions
Apply penalties for each detected issue:

1. **Heavy Propaganda Techniques** (-15 each):
   - Dehumanization: Describing people as "savage", "animals", "vermin"
   - Fear-Mongering: "Imminent collapse", "chaos", "destruction"
   - Loaded Language: "Terrorists" (for protesters), "martyrs" (for security forces)

2. **Logical Fallacies** (-10 each):
   - Strawman: Misrepresenting opponent's position
   - False Dilemma: Presenting only two extreme options
   - Ad Hominem: Attacking person instead of argument

3. **Tone Issues** (-10):
   - Inflammatory or highly partisan language
   - Excessive emotional manipulation

4. **Sourcing Problems**:
   - No credible source for critical claim: -15
   - Anonymous sources for critical claim: -9

## OUTPUT FORMAT (JSON)
```json
{
  "content_quality_score": <number 0-100>,
  "base_score": 80,
  "total_penalty": <number>,
  "detected_issues": [
    {
      "issue_type": "PROPAGANDA | FALLACY | TONE | SOURCING",
      "specific_technique": "string",
      "evidence": "exact quote from text",
      "penalty": <number>,
      "explanation": "why this is problematic"
    }
  ],
  "final_verdict": "brief summary in English (max 100 words)"
}
```


# CONTENT TO ANALYZE

{content_text}

```

**Example Analysis:**

**Input Text:**
```

"The brutal regime's savage forces attacked peaceful protesters.
Anonymous sources confirm that foreign agents were arrested.
These Western-backed terrorists want to destroy Iran."

```

**LLM Output:**
```json
{
  "content_quality_score": 31,
  "base_score": 80,
  "total_penalty": 49,
  "detected_issues": [
    {
      "issue_type": "PROPAGANDA",
      "specific_technique": "Dehumanization",
      "evidence": "savage forces",
      "penalty": 15,
      "explanation": "Describes security forces as 'savage' to strip humanity"
    },
    {
      "issue_type": "PROPAGANDA",
      "specific_technique": "Loaded_Language",
      "evidence": "terrorists",
      "penalty": 15,
      "explanation": "Labels protesters as 'terrorists' to delegitimize dissent"
    },
    {
      "issue_type": "FALLACY",
      "specific_technique": "False_Dilemma",
      "evidence": "Western-backed terrorists want to destroy Iran",
      "penalty": 10,
      "explanation": "Frames all dissent as foreign conspiracy, ignoring legitimate grievances"
    },
    {
      "issue_type": "SOURCING",
      "specific_technique": "Anonymous_Sources",
      "evidence": "Anonymous sources confirm",
      "penalty": 9,
      "explanation": "Uses unverifiable anonymous sources for critical claim about arrests"
    }
  ],
  "final_verdict": "This content heavily employs propaganda techniques including dehumanization and loaded language. It relies on anonymous sources and presents a false dilemma. Content Quality Score: 31/100."
}
```

**Algorithm:**

```
FUNCTION CalculateContentQualityScore(contentItem):
  
  prompt = BuildPrompt(SYSTEM_PROMPT_CONTENT_SCORING, {
    content_text: contentItem.translated_text_en
  })
  
  result = CallAI({
    model: 'gpt-5-nano',
    prompt: prompt,
    temperature: 0,  // Deterministic output
    response_format: { type: "json_object" }
  })
  
  // Validation: Ensure score is reasonable
  IF result.content_quality_score < 0 OR result.content_quality_score > 80 THEN
    Log('INVALID_SCORE', result)
    // Retry once
    result = CallAI(...)
  END IF
  
  // Safety override: If source is regime + score too high, cap it
  source = Database.Sources.GetById(contentItem.source_id)
  IF source.baseline_trust_score < 30 AND result.content_quality_score > 60 THEN
    result.content_quality_score = 60
    result.detected_issues.Add({
      issue_type: 'OVERRIDE',
      explanation: 'Score capped due to historically unreliable source'
    })
  END IF
  
  RETURN result

END FUNCTION
```


***

### 4.4 Trust Badge Classification

| Final Score Range | Badge | Color | Label (EN) | Label (FA) | User Guidance |
| :-- | :-- | :-- | :-- | :-- | :-- |
| 70-95 | HIGH_TRUST | 🟢 Green | High Trust | قابل اعتماد | "Verified by credible sources" |
| 40-69 | MEDIUM_TRUST | 🟡 Yellow | Medium Trust | نیاز به تایید | "Verify independently before sharing" |
| 15-39 | LOW_TRUST | 🔴 Red | Low Trust | غیرقابل اعتماد | "High risk of propaganda or error" |
| <15 OR Propaganda Flag | PROPAGANDA_ALERT | 🚫 Black | Propaganda Alert | هشدار پروپاگاندا | "Coordinated disinformation detected" |

**Override Rules:**

```
FUNCTION AssignTrustBadge(cluster):
  
  score = cluster.final_trust_score
  
  // Base classification
  IF score >= 70 THEN
    badge = 'HIGH_TRUST'
  ELSE IF score >= 40 THEN
    badge = 'MEDIUM_TRUST'
  ELSE
    badge = 'LOW_TRUST'
  END IF
  
  // Override Rule 1: Propaganda detected + low source score
  representativeAnalysis = Database.ContentAnalysis.GetByClusterId(cluster.id)[^0]
  sourceScore = cluster.source_weighted_score
  
  IF representativeAnalysis.propaganda_detected AND sourceScore < 30 THEN
    badge = 'PROPAGANDA_ALERT'
  END IF
  
  // Override Rule 2: Coordinated behavior pattern
  IF cluster.narrative_pattern == 'COORDINATED_PROPAGANDA' THEN
    badge = 'PROPAGANDA_ALERT'
  END IF
  
  // Override Rule 3: Deep research downgrade
  IF cluster.deep_research_triggered AND 
     cluster.deep_research_result.verified_score < 30 THEN
    badge = 'PROPAGANDA_ALERT'
  END IF
  
  cluster.trust_badge = badge
  Database.Clusters.Update(cluster)
  
  RETURN badge

END FUNCTION
```

**Reference:** design-trust-narrative-system-v1.0.md, RESEARCH-003 (Credly Badge Standards)

***

## 5. n8n Workflow Logic

### 5.1 Master Workflow Architecture

**Critical Note:** n8n orchestrates the entire pipeline as a series of connected workflows.

**Workflow Overview:**

```
┌─────────────────────────────────────────────────────────────┐
│  WORKFLOW 1: Ingestion & Translation                        │
│  Trigger: Cron (every 5 minutes) + Webhook                  │
│  ─────────────────────────────────────────────────────────  │
│  [RSS Poller] → [Normalize] → [Detect Lang]                │
│       ↓                                                      │
│  [Twitter API] → [Deduplicate] → [Translate if needed]     │
│       ↓                                                      │
│  [PostgreSQL Insert: ContentItem]                           │
└─────────────────────────────────────────────────────────────┘
         │
         ↓ (triggers via PostgreSQL trigger or n8n watch)
┌─────────────────────────────────────────────────────────────┐
│  WORKFLOW 2: Embedding & Clustering                         │
│  Trigger: New ContentItem with status='TRANSLATED'          │
│  ─────────────────────────────────────────────────────────  │
│  [Generate Embedding: OpenAI API]                           │
│       ↓                                                      │
│  [Vector Search: pgvector]                                  │
│       ├─ (similarity ≥ 0.92) → [Inherit Analysis]          │
│       ├─ (similarity ≥ 0.85) → [Add to Cluster]            │
│       └─ (similarity < 0.85) → [Create New Cluster]        │
│       ↓                                                      │
│  [PostgreSQL Update: cluster_id, status='CLUSTERED']       │
└─────────────────────────────────────────────────────────────┘
         │
         ↓ (triggers if new cluster or requires_analysis=true)
┌─────────────────────────────────────────────────────────────┐
│  WORKFLOW 3: AI Analysis                                    │
│  Trigger: Cluster with requires_analysis=true               │
│  ─────────────────────────────────────────────────────────  │
│  [Classify Content Nature: GPT-5-nano]                     │
│       ├─ FACTUAL → [Fact Check Pipeline]                   │
│       └─ INTERPRETIVE → [Propaganda Detection Pipeline]    │
│       ↓                                                      │
│  [Calculate Trust Score: Formula]                           │
│       ↓                                                      │
│  [Assign Badge]                                             │
│       ↓                                                      │
│  [PostgreSQL Insert: ContentAnalysis]                       │
│  [PostgreSQL Update: Cluster trust scores]                  │
└─────────────────────────────────────────────────────────────┘
         │
         ↓ (conditional trigger for high-impact items)
┌─────────────────────────────────────────────────────────────┐
│  WORKFLOW 4: Deep Research (Optional)                       │
│  Trigger: High impact + disputed                            │
│  ─────────────────────────────────────────────────────────  │
│  [Gatekeeper Check: Should trigger?]                        │
│       ↓ (YES)                                               │
│  [Perplexity Pro API Call]                                  │
│       ↓                                                      │
│  [Update Trust Score with verified data]                    │
│       ↓                                                      │
│  [Add to Knowledge Base]                                    │
│       ↓                                                      │
│  [PostgreSQL Update: deep_research_result]                  │
└─────────────────────────────────────────────────────────────┘
         │
         ↓ (final output)
┌─────────────────────────────────────────────────────────────┐
│  WORKFLOW 5: API Serving & UI Update                        │
│  Trigger: Cluster finalized                                 │
│  ─────────────────────────────────────────────────────────  │
│  [Generate JSON for API]                                    │
│       ↓                                                      │
│  [Push to Framer Webhook]                                   │
│       ↓                                                      │
│  [Index in Azure AI Search for fast retrieval]             │
└─────────────────────────────────────────────────────────────┘
```


***

### 5.2 Workflow 1: Ingestion \& Translation (n8n JSON Spec)

**Trigger:** Cron schedule (every 5 minutes) + Webhook for manual triggers

**Node Structure:**

```json
{
  "name": "Ingestion_Translation_Workflow",
  "nodes": [
    {
      "name": "Schedule Trigger",
      "type": "n8n-nodes-base.cron",
      "parameters": {
        "rule": {
          "interval": [{ "field": "minutes", "minutesInterval": 5 }]
        }
      }
    },
    {
      "name": "Fetch RSS Feeds",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "method": "GET",
        "url": "={{ $env.MINIFLUX_API }}/v1/entries?status=unread&limit=100",
        "authentication": "genericCredentialType",
        "genericAuthType": "httpHeaderAuth",
        "options": {
          "timeout": 10000
        }
      }
    },
    {
      "name": "Fetch Twitter",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "method": "GET",
        "url": "={{ $env.TWITTER_API }}/tweets/recent?accounts={{ $env.TWITTER_ACCOUNTS }}",
        "options": {
          "timeout": 10000
        }
      }
    },
    {
      "name": "Merge Feeds",
      "type": "n8n-nodes-base.merge",
      "parameters": {
        "mode": "combine",
        "combinationMode": "mergeByPosition"
      }
    },
    {
      "name": "Normalize Schema",
      "type": "n8n-nodes-base.code",
      "parameters": {
        "language": "javaScript",
        "jsCode": "// Normalize to standard ContentItem schema\nconst items = $input.all();\nconst normalized = [];\n\nfor (const item of items) {\n  const platform = item.json.source?.includes('twitter') ? 'TWITTER' : 'RSS';\n  \n  normalized.push({\n    json: {\n      external_id: item.json.id,\n      source_identifier: item.json.feed_url || item.json.author_id,\n      platform: platform,\n      original_title: item.json.title,\n      original_text: item.json.content || item.json.text,\n      published_at: item.json.published_at,\n      platform_metadata: {\n        url: item.json.url,\n        author_handle: item.json.author,\n        likes: item.json.likes || 0,\n        shares: item.json.retweets || 0\n      }\n    }\n  });\n}\n\nreturn normalized;"
      }
    },
    {
      "name": "Detect Language",
      "type": "n8n-nodes-base.code",
      "parameters": {
        "language": "javaScript",
        "jsCode": "// Simple language detection (placeholder - use proper library in production)\nconst items = $input.all();\n\nfor (const item of items) {\n  const text = item.json.original_text;\n  \n  // Persian detection: Check for Persian unicode ranges\n  const persianRegex = /[\\u0600-\\u06FF]/;\n  \n  if (persianRegex.test(text)) {\n    item.json.original_language = 'fa';\n    item.json.needs_translation = true;\n  } else {\n    item.json.original_language = 'en';\n    item.json.needs_translation = false;\n  }\n}\n\nreturn items;"
      }
    },
    {
      "name": "Route: Needs Translation?",
      "type": "n8n-nodes-base.if",
      "parameters": {
        "conditions": {
          "boolean": [{\n            "value1": "={{ $json.needs_translation }}",\n            "value2": true\n          }]
        }
      }
    },
    {
      "name": "Translate to English",
      "type": "n8n-nodes-base.openAi",
      "parameters": {
        "resource": "text",
        "operation": "message",
        "model": "gpt-5-nano",
        "messages": {
          "values": [
            {
              "role": "system",
              "content": "Translate the following Persian text to English. Preserve political terminology (IRGC, Sepah, Basij, etc.). Context: Iranian political news."
            },
            {
              "role": "user",
              "content": "={{ $json.original_text }}"
            }
          ]
        }
      }
    },
    {
      "name": "Set Translated Text",
      "type": "n8n-nodes-base.set",
      "parameters": {
        "values": {
          "string": [
            {
              "name": "translated_text_en",
              "value": "={{ $json.choices[^0].message.content }}"
            },
            {
              "name": "translation_model",
              "value": "gpt-5-nano"
            }
          ]
        }
      }
    },
    {
      "name": "Lookup Source",
      "type": "n8n-nodes-base.postgres",
      "parameters": {
        "operation": "executeQuery",
        "query": "SELECT id, baseline_trust_score FROM sources WHERE platform = '{{ $json.platform }}' AND platform_identifier = '{{ $json.source_identifier }}' LIMIT 1"
      }
    },
    {
      "name": "Insert ContentItem",
      "type": "n8n-nodes-base.postgres",
      "parameters": {
        "operation": "insert",
        "table": "content_items",
        "columns": "source_id, external_id, original_language, original_title, original_text, translated_title_en, translated_text_en, translation_model, published_at, ingested_at, processing_status, platform_metadata",
        "options": {
          "queryReplacement": "id, source_id"
        }
      }
    }
  ],
  "connections": {
    "Schedule Trigger": {
      "main": [[{ "node": "Fetch RSS Feeds" }, { "node": "Fetch Twitter" }]]
    },
    "Fetch RSS Feeds": {
      "main": [[{ "node": "Merge Feeds" }]]
    },
    "Fetch Twitter": {
      "main": [[{ "node": "Merge Feeds" }]]
    },
    "Merge Feeds": {
      "main": [[{ "node": "Normalize Schema" }]]
    },
    "Normalize Schema": {
      "main": [[{ "node": "Detect Language" }]]
    },
    "Detect Language": {
      "main": [[{ "node": "Route: Needs Translation?" }]]
    },
    "Route: Needs Translation?": {
      "main": [
        [{ "node": "Translate to English" }],  // true branch
        [{ "node": "Lookup Source" }]  // false branch (already English)
      ]
    },
    "Translate to English": {
      "main": [[{ "node": "Set Translated Text" }]]
    },
    "Set Translated Text": {
      "main": [[{ "node": "Lookup Source" }]]
    },
    "Lookup Source": {
      "main": [[{ "node": "Insert ContentItem" }]]
    }
  }
}
```


***

### 5.3 Workflow 2: Clustering (Simplified Logic)

**Trigger:** PostgreSQL trigger when new item has `processing_status = 'TRANSLATED'`

**Key Nodes:**

1. **Generate Embedding** (OpenAI API)
2. **Vector Search** (PostgreSQL pgvector custom query)
3. **Decision Router** (IF node with 3 branches)
4. **Inherit Analysis** (Copy from existing)
5. **Add to Cluster** (Update cluster_id)
6. **Create New Cluster** (Insert new cluster)

**Pseudo-n8n Structure:**

```
[PostgreSQL Trigger: New Translated Item]
  ↓
[HTTP Request: OpenAI Embedding API]
  ↓
[Set: Store embedding_vector]
  ↓
[PostgreSQL: Vector Search in Knowledge Base (≥0.92)]
  ↓
[IF: Has Historical Match?]
  ├─ YES → [Inherit Analysis from KB]
  └─ NO → [PostgreSQL: Vector Search in Clusters (≥0.85)]
            ↓
           [IF: Has Cluster Match?]
             ├─ YES → [Add to Existing Cluster] → [Check Delta]
             └─ NO → [Create New Cluster] → [Trigger Analysis Workflow]
```


***

### 5.4 Workflow 3: Analysis (LLM Scoring)

**Trigger:** New cluster with `requires_analysis = true`

**Key Nodes:**

1. **Fetch Cluster Data** (PostgreSQL)
2. **Classify Content Nature** (OpenAI GPT-5-nano)
3. **Router: Factual vs Interpretive**
4. **Propaganda Detection** (OpenAI GPT-5-nano with scoring prompt)
5. **Calculate Final Score** (Code node with formula)
6. **Assign Badge** (Code node with thresholds)
7. **Insert Analysis** (PostgreSQL)
8. **Update Cluster** (PostgreSQL)

***

### 5.5 Workflow 4: Gatekeeper \& Deep Research

**Trigger:** Cluster updated with `trust_badge = 'MEDIUM_TRUST'` AND `total_items_count > 50`

**Key Logic:**

```
[Fetch Cluster]
  ↓
[Code: Gatekeeper Check]
  IF (impact > 5000 AND (source_score > 70 AND content_score < 50)):
    ↓
    [HTTP Request: Perplexity Pro API]
      ↓
    [Parse Verification Result]
      ↓
    [Update Final Score]
      ↓
    [Insert into Knowledge Base]
  ELSE:
    [Skip - Budget Conservation]
```


***

## 6. Operational Logic

### 6.1 Gatekeeper Logic for Deep Research

**Purpose:** Conserve Perplexity Pro budget (\$5,000 must last until June 2026).

**Daily Budget:** \$5/day = ~50 Perplexity calls/day (at \$0.10/call)

**Algorithm:**

```
FUNCTION ShouldTriggerDeepResearch(cluster):
  
  // Condition 1: High Impact
  isHighImpact = (
    cluster.total_items_count > 50 OR
    cluster.impact_metrics.total_engagement > 5000 OR
    cluster.impact_metrics.unique_sources > 10 OR
    cluster.is_breaking == true
  )
  
  // Condition 2: Contradiction (Source vs Content)
  hasContradiction = (
    cluster.content_quality_score < 50 AND
    cluster.source_weighted_score > 70
  )
  
  // Condition 3: Coordinated Pattern
  isCoordinated = (
    cluster.narrative_pattern == 'COORDINATED_PROPAGANDA'
  )
  
  // Condition 4: Disputed with medium score
  isDisputed = (
    cluster.trust_badge == 'MEDIUM_TRUST' AND
    cluster.impact_metrics.geographic_spread.length > 3
  )
  
  // Condition 5: Budget check
  todayCount = Database.Clusters.Count({
    deep_research_triggered: true,
    last_updated_at: { gte: StartOfToday() }
  })
  
  withinBudget = todayCount < 50
  
  // Final decision: High impact AND disputed/coordinated AND within budget
  RETURN withinBudget AND isHighImpact AND (
    hasContradiction OR isCoordinated OR isDisputed
  )

END FUNCTION
```

**Deep Research Execution:**

```
FUNCTION ExecuteDeepResearch(cluster):
  
  IF NOT ShouldTriggerDeepResearch(cluster) THEN
    RETURN { triggered: false, reason: 'Did not meet criteria' }
  END IF
  
  // Call Perplexity Pro
  representativeItem = Database.ContentItems.GetById(
    cluster.representative_item_id
  )
  
  deepResearchResult = CallPerplexityPro({
    query: cluster.title_en,
    focus: 'fact_verification',
    sources: GetTrustedWhitelist(),  // Pre-approved domains
    depth: 'comprehensive',
    related_phrases: ExtractKeyEntities(representativeItem.translated_text_en)
  })
  
  // Update cluster with verified information
  cluster.deep_research_triggered = true
  cluster.deep_research_result = deepResearchResult
  
  // Recalculate trust score with verification
  IF deepResearchResult.verification_status == 'VERIFIED' THEN
    cluster.final_trust_score = Max(cluster.final_trust_score, 75)
  ELSE IF deepResearchResult.verification_status == 'FALSE' THEN
    cluster.final_trust_score = Min(cluster.final_trust_score, 25)
    cluster.trust_badge = 'PROPAGANDA_ALERT'
  END IF
  
  Database.Clusters.Update(cluster)
  
  // Add to Knowledge Base for future RAG
  kbEntry = NEW KnowledgeBase()
  kbEntry.id = GenerateUUID()
  kbEntry.fact_type = 'VERIFIED_CLAIM'
  kbEntry.text_content = deepResearchResult.verdict
  kbEntry.embedding_vector = representativeItem.embedding_vector
  kbEntry.verification_source = 'PERPLEXITY_PRO'
  kbEntry.confidence_level = 0.95
  kbEntry.related_clusters = [cluster.id]
  kbEntry.metadata = {
    citation: deepResearchResult.sources.Join(', ')
  }
  kbEntry.created_at = CurrentTimestamp()
  kbEntry.created_by = 'PERPLEXITY'
  Database.KnowledgeBase.Insert(kbEntry)
  
  Log('DEEP_RESEARCH_COMPLETED', {
    cluster_id: cluster.id,
    cost: '$0.10',
    result: deepResearchResult.verification_status
  })
  
  RETURN { triggered: true, result: deepResearchResult }

END FUNCTION
```

**Trusted Whitelist (For Perplexity Pro):**

```
[
  "amnesty.org",
  "hrw.org",
  "en-hrana.org",
  "iranintl.com",
  "bbc.com/persian",
  "nytimes.com",
  "reuters.com",
  "apnews.com"
]
```

**Exclusion List (Sources Perplexity should NOT use):**

```
[
  "tasnimnews.com",
  "farsnews.ir",
  "presstv.ir",
  "isna.ir",
  "mehrnews.com"
]
```


***

### 6.2 Cache Invalidation \& Cleanup

**Purpose:** Prevent database bloat and ensure data freshness.

**Rules:**

```
// Rule 1: Expire old clusters
SCHEDULE DAILY_CLEANUP (runs at 02:00 UTC):
  
  // Find clusters older than 14 days
  expiredClusters = Database.Clusters.FindAll({
    expires_at: { lte: CurrentTimestamp() }
  })
  
  FOR EACH cluster IN expiredClusters DO
    // Archive to cold storage (S3/Azure Blob)
    ArchiveCluster(cluster)
    
    // Delete from active database
    Database.Clusters.Delete(cluster.id)
    
    // Keep ContentItems but mark as archived
    Database.ContentItems.UpdateAll({
      cluster_id: cluster.id
    }, {
      processing_status: 'ARCHIVED'
    })
  END FOR
  
  Log('CLEANUP_COMPLETED', {
    clusters_archived: expiredClusters.Count
  })

END SCHEDULE

// Rule 2: Refresh stale analyses
SCHEDULE WEEKLY_REFRESH (runs on Sunday):
  
  // Find clusters that are still active but analysis is old
  staleCluster = Database.Clusters.FindAll({
    last_updated_at: { lte: CurrentTimestamp() - Days(30) },
    expires_at: { gt: CurrentTimestamp() }
  })
  
  FOR EACH cluster IN staleClusters DO
    // Re-analyze with latest model
    TriggerAnalysisWorkflow(cluster.id)
  END FOR

END SCHEDULE

// Rule 3: Vacuum embeddings no longer in use
SCHEDULE MONTHLY_VACUUM:
  
  // Remove embeddings for archived items
  Database.ExecuteQuery("
    DELETE FROM content_items
    WHERE processing_status = 'ARCHIVED'
    AND ingested_at < NOW() - INTERVAL '90 days'
  ")
  
  // Rebuild vector index for performance
  Database.ExecuteQuery("
    REINDEX INDEX embedding_vector_idx
  ")

END SCHEDULE
```


***

## 7. Data Flow Processes

### 7.1 Complete End-to-End Flow

**From RSS/Twitter to User UI:**

```
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 1: INGESTION (Latency Target: <30s)                       │
├─────────────────────────────────────────────────────────────────┤
│ 1. Fetch from Source (RSS/Twitter)                              │
│ 2. Normalize to standard schema                                 │
│ 3. Detect language (0.1s)                                       │
│ 4. Translate if not English (2s per GPT-5-nano call)           │
│ 5. Lookup Source in database                                    │
│ 6. Insert ContentItem (processing_status='TRANSLATED')          │
└─────────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 2: CLUSTERING (Latency Target: <5s)                       │
├─────────────────────────────────────────────────────────────────┤
│ 7. Generate embedding (1s per OpenAI call)                      │
│ 8. Vector search in Knowledge Base (0.05s)                      │
│    ├─ IF similarity ≥ 0.92:                                    │
│    │    → FAST PATH: Inherit analysis (cost: $0)               │
│    │    → Update cluster stats                                  │
│    │    → END (total latency: ~1s)                             │
│    └─ IF similarity < 0.92:                                    │
│       → Continue to step 9                                      │
│ 9. Vector search in active Clusters (0.05s)                     │
│    ├─ IF similarity ≥ 0.85:                                    │
│    │    → Add to existing cluster                              │
│    │    → Check for delta (2s)                                 │
│    │       ├─ IF no new info: Inherit analysis                │
│    │       └─ IF new info: Continue to analysis               │
│    └─ IF similarity < 0.85:                                    │
│       → Create new cluster                                      │
│       → Trigger analysis                                        │
└─────────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 3: ANALYSIS (Latency Target: <10s)                        │
├─────────────────────────────────────────────────────────────────┤
│ 10. Select representative item (0.1s)                           │
│ 11. Classify content nature (3s GPT-5-nano)                     │
│ 12. Route to pipeline:                                          │
│     ├─ FACTUAL → Fact-checking (5s GPT-5-nano)                │
│     └─ INTERPRETIVE → Propaganda detection (5s GPT-5-nano)    │
│ 13. Calculate trust score (0.01s formula)                       │
│ 14. Assign trust badge (0.01s logic)                           │
│ 15. Insert ContentAnalysis record                               │
│ 16. Update Cluster with scores                                  │
└─────────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 4: DEEP RESEARCH (Optional, High-Impact Only)             │
├─────────────────────────────────────────────────────────────────┤
│ 17. Gatekeeper check (0.01s)                                    │
│     IF (High impact + Disputed + Budget available):             │
│        → Call Perplexity Pro (60-120s)                         │
│        → Update trust score                                     │
│        → Add to Knowledge Base                                  │
│     ELSE:                                                        │
│        → Skip (cost savings)                                    │
└─────────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 5: OUTPUT (Latency Target: <1s)                           │
├─────────────────────────────────────────────────────────────────┤
│ 18. Generate JSON for API                                       │
│ 19. Push to Framer via Webhook                                  │
│ 20. Index in Azure AI Search                                    │
│ 21. User sees News Card with Trust Badge                        │
└─────────────────────────────────────────────────────────────────┘
```


***

### 7.2 Performance Metrics \& Targets

| Metric | Fast Path (Cache Hit) | Full Analysis Path | Target |
| :-- | :-- | :-- | :-- |
| **Total Latency** | ~1 minute | ~5 minutes | <5 min |
| **Ingestion** | 30s | 30s | <30s |
| **Clustering** | 1s | 5s | <5s |
| **Analysis** | 0.05s (inherited) | 10s | <10s |
| **Deep Research** | N/A | 120s | <2 min |
| **API Response** | 0.5s | 0.5s | <1s |

**Cost Per Item:**

- Fast Path (Cache Hit): **\$0.001** (embedding only)
- Full Analysis: **\$0.055** (embedding + GPT-5-nano)
- Deep Research: **\$0.155** (Full + Perplexity Pro)

**Expected Distribution (with 4,000 items/day):**

- Cache Hit (90%): 3,600 items × \$0.001 = **\$3.60/day**
- Full Analysis (9.5%): 380 items × \$0.055 = **\$20.90/day**
- Deep Research (0.5%): 20 items × \$0.155 = **\$3.10/day**

**Total Daily Cost:** ~\$27.60/day
**Monthly Cost:** ~\$828/month (
<span style="display:none">[^1][^2][^3]</span>

<div align="center">⁂</div>

[^1]: Product Definition.md

[^2]: 0-Vision.md

[^3]: 1-Requirments.md

