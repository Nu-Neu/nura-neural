-- =============================================================================
-- Nura - PostgreSQL Schema
-- Version: 2.1
-- Date: January 31, 2026
-- 
-- Deployment Model: DB-PER-TENANT (one database per tenant)
-- Each tenant gets their own:
--   - Database (e.g., tenant1_nura)
--   - Azure AI Search index
--   - Blob storage container
-- 
-- Design Principles:
-- 1. Tenant isolation for security and customization
-- 2. Proper normalization with strategic denormalization for performance
-- 3. Audit trails for all AI evaluations (historical tracking)
-- 4. Entity extraction and relationship modeling
-- 5. Embedding sync tracking for Azure AI Search
-- 6. Extensible tagging/categorization system
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";      -- Text search/similarity
CREATE EXTENSION IF NOT EXISTS "btree_gin";    -- Composite GIN indexes

-- =============================================================================
-- ENUM TYPES
-- =============================================================================

-- Source types
CREATE TYPE source_type AS ENUM (
    'rss_feed',
    'twitter_account',
    'twitter_keyword',
    'twitter_list',
    'newsletter',
    'telegram_channel',
    'youtube_channel',
    'manual'
);

-- Credibility classification
CREATE TYPE credibility_tier AS ENUM (
    'propaganda',       -- Known state/regime propaganda
    'state_affiliated', -- State-linked but not pure propaganda
    'partisan',         -- Strong political bias but not state
    'unverified',       -- Unknown credibility
    'credible',         -- Established credible sources
    'official'          -- Official government/institutional
);

-- Content types
CREATE TYPE content_type AS ENUM (
    'article',
    'tweet',
    'thread',
    'newsletter_issue',
    'video_transcript',
    'telegram_post'
);

-- Languages (extensible via table, but enum for core)
CREATE TYPE language_code AS ENUM (
    'fa',       -- Farsi/Persian
    'ar',       -- Arabic
    'en',       -- English
    'he',       -- Hebrew
    'tr',       -- Turkish
    'other'
);

CREATE TYPE text_direction AS ENUM ('rtl', 'ltr');

-- Processing statuses
CREATE TYPE processing_status AS ENUM (
    'pending',
    'queued',
    'processing',
    'completed',
    'failed',
    'skipped',
    'needs_review'
);

-- Claim types
CREATE TYPE claim_type AS ENUM (
    'factual',          -- Verifiable fact claim
    'predictive',       -- Future prediction
    'causal',           -- Cause-effect claim
    'quantitative',     -- Numerical claim
    'attribution',      -- Quote/statement attribution
    'narrative',        -- Broader framing
    'opinion'           -- Editorial stance
);

-- Verification outcomes
CREATE TYPE verification_status AS ENUM (
    'unverified',
    'verified_true',
    'verified_false',
    'mostly_true',
    'mostly_false',
    'misleading',
    'out_of_context',
    'disputed',
    'unverifiable',
    'satire'
);

-- Stance classification
CREATE TYPE stance AS ENUM (
    'pro_regime',
    'anti_regime',
    'pro_western',
    'anti_western',
    'neutral',
    'mixed',
    'unknown'
);

-- Plausibility bands
CREATE TYPE plausibility_band AS ENUM (
    'highly_unlikely',
    'unlikely',
    'uncertain',
    'plausible',
    'highly_plausible',
    'confirmed'
);

-- Entity types
CREATE TYPE entity_type AS ENUM (
    'person',
    'organization',
    'government_body',
    'media_outlet',
    'political_party',
    'military_unit',
    'location',
    'event'
);

-- Relationship types between entities
CREATE TYPE entity_relationship_type AS ENUM (
    'affiliated_with',
    'employed_by',
    'leads',
    'member_of',
    'opposes',
    'supports',
    'located_in',
    'subsidiary_of',
    'formerly'
);

-- Podcast status
CREATE TYPE podcast_status AS ENUM (
    'scheduled',
    'generating_script',
    'script_review',
    'generating_audio',
    'published',
    'failed',
    'cancelled'
);

-- Embedding sync status
CREATE TYPE sync_status AS ENUM (
    'pending',
    'synced',
    'failed',
    'deleted'
);

-- =============================================================================
-- CORE TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TOPICS / TAGS (Hierarchical categorization)
-- -----------------------------------------------------------------------------
CREATE TABLE topics (
    topic_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id           UUID REFERENCES topics(topic_id) ON DELETE SET NULL,
    
    slug                VARCHAR(100) UNIQUE NOT NULL,   -- 'iran-nuclear', 'us-iran-relations'
    name                VARCHAR(255) NOT NULL,          -- English
    name_fa             VARCHAR(255),                   -- Farsi
    name_ar             VARCHAR(255),                   -- Arabic
    description         TEXT,
    
    -- For keyword matching during auto-tagging
    keywords            TEXT[],                         -- ['nuclear', 'enrichment', 'IAEA']
    keywords_fa         TEXT[],
    keywords_ar         TEXT[],
    
    is_active           BOOLEAN DEFAULT true,
    sort_order          INTEGER DEFAULT 0,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_topics_parent ON topics(parent_id);
CREATE INDEX idx_topics_slug ON topics(slug);
CREATE INDEX idx_topics_keywords ON topics USING gin(keywords);

-- -----------------------------------------------------------------------------
-- ENTITIES (People, organizations, etc.)
-- -----------------------------------------------------------------------------
CREATE TABLE entities (
    entity_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    entity_type         entity_type NOT NULL,
    
    -- Names
    name                VARCHAR(500) NOT NULL,          -- Primary English name
    name_fa             VARCHAR(500),                   -- Farsi name
    name_ar             VARCHAR(500),                   -- Arabic name
    aliases             TEXT[],                         -- Alternative names/spellings
    
    -- Identifiers
    wikidata_id         VARCHAR(50),                    -- Q-number for linking
    twitter_handle      VARCHAR(100),
    
    -- Metadata
    country             VARCHAR(3),                     -- ISO country code
    description         TEXT,
    description_fa      TEXT,
    
    -- For people
    title               VARCHAR(255),                   -- 'Supreme Leader', 'Foreign Minister'
    
    -- For organizations
    org_type            VARCHAR(100),                   -- 'news_agency', 'government', 'ngo'
    parent_entity_id    UUID REFERENCES entities(entity_id),
    
    -- Classification
    stance              stance,
    credibility_tier    credibility_tier,
    
    -- Profile data (OSINT)
    profile             JSONB DEFAULT '{}'::jsonb,
    /*
        profile example:
        {
            "birth_date": "1939-04-19",
            "position_history": [...],
            "social_followers": {...},
            "notable_statements": [...]
        }
    */
    
    is_active           BOOLEAN DEFAULT true,
    last_updated_at     TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_entities_type ON entities(entity_type);
CREATE INDEX idx_entities_name_trgm ON entities USING gin(name gin_trgm_ops);
CREATE INDEX idx_entities_aliases ON entities USING gin(aliases);
CREATE INDEX idx_entities_wikidata ON entities(wikidata_id) WHERE wikidata_id IS NOT NULL;
CREATE INDEX idx_entities_twitter ON entities(twitter_handle) WHERE twitter_handle IS NOT NULL;

-- -----------------------------------------------------------------------------
-- ENTITY RELATIONSHIPS
-- -----------------------------------------------------------------------------
CREATE TABLE entity_relationships (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    from_entity_id      UUID NOT NULL REFERENCES entities(entity_id) ON DELETE CASCADE,
    to_entity_id        UUID NOT NULL REFERENCES entities(entity_id) ON DELETE CASCADE,
    relationship_type   entity_relationship_type NOT NULL,
    
    -- Temporal bounds (many relationships change over time)
    valid_from          DATE,
    valid_to            DATE,
    is_current          BOOLEAN DEFAULT true,
    
    confidence          FLOAT DEFAULT 1.0,
    source_url          TEXT,                           -- Evidence source
    notes               TEXT,
    
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(from_entity_id, to_entity_id, relationship_type, valid_from)
);

CREATE INDEX idx_entity_rel_from ON entity_relationships(from_entity_id);
CREATE INDEX idx_entity_rel_to ON entity_relationships(to_entity_id);
CREATE INDEX idx_entity_rel_current ON entity_relationships(is_current) WHERE is_current = true;

-- -----------------------------------------------------------------------------
-- SOURCES
-- -----------------------------------------------------------------------------
CREATE TABLE sources (
    source_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identity
    source_type         source_type NOT NULL,
    identifier          VARCHAR(500) NOT NULL,          -- domain, @username, keyword
    
    -- Display
    name                VARCHAR(255) NOT NULL,          -- English
    name_original       VARCHAR(255),                   -- Original language
    logo_url            TEXT,
    
    -- Linked entity (if this source is an organization)
    entity_id           UUID REFERENCES entities(entity_id),
    
    -- Location & Language
    country             VARCHAR(3),
    primary_language    language_code DEFAULT 'en',
    languages           language_code[] DEFAULT '{en}',
    
    description         TEXT,
    
    -- Classification (denormalized from entity for quick access)
    credibility_tier    credibility_tier DEFAULT 'unverified',
    
    -- Configuration
    is_active           BOOLEAN DEFAULT true,
    poll_interval_mins  INTEGER DEFAULT 15,
    priority            INTEGER DEFAULT 5,              -- 1=highest, 10=lowest
    
    config              JSONB DEFAULT '{}'::jsonb,
    /*
        config examples:
        RSS: {"feed_url": "https://...", "full_text_selector": "article.body"}
        Twitter: {"user_id": "123456", "include_replies": false, "include_retweets": false}
    */
    
    -- Timestamps
    last_polled_at      TIMESTAMPTZ,
    last_successful_at  TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(source_type, identifier)
);

CREATE INDEX idx_sources_type ON sources(source_type);
CREATE INDEX idx_sources_active ON sources(is_active, priority) WHERE is_active = true;
CREATE INDEX idx_sources_entity ON sources(entity_id) WHERE entity_id IS NOT NULL;
CREATE INDEX idx_sources_tier ON sources(credibility_tier);

-- -----------------------------------------------------------------------------
-- SOURCE IMTT EVALUATIONS (Historical tracking)
-- -----------------------------------------------------------------------------
CREATE TABLE source_evaluations (
    evaluation_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id           UUID NOT NULL REFERENCES sources(source_id) ON DELETE CASCADE,
    
    -- IMTT Scores (0.0 - 1.0)
    independence        FLOAT CHECK (independence >= 0 AND independence <= 1),
    methodology         FLOAT CHECK (methodology >= 0 AND methodology <= 1),
    transparency        FLOAT CHECK (transparency >= 0 AND transparency <= 1),
    triangulation       FLOAT CHECK (triangulation >= 0 AND triangulation <= 1),
    overall_score       FLOAT CHECK (overall_score >= 0 AND overall_score <= 1),
    
    -- Derived tier (can override source's default)
    recommended_tier    credibility_tier,
    
    -- Evidence
    reasoning           TEXT,
    evidence_urls       TEXT[],
    sample_content_ids  UUID[],                         -- Content that informed this evaluation
    
    -- Metadata
    model_used          VARCHAR(100),                   -- 'gpt-4o', 'manual'
    evaluated_by        VARCHAR(100),                   -- 'agent1', 'editor:john'
    is_current          BOOLEAN DEFAULT true,
    
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_source_eval_source ON source_evaluations(source_id);
CREATE INDEX idx_source_eval_current ON source_evaluations(source_id, is_current) WHERE is_current = true;

-- Ensure only one current evaluation per source
CREATE UNIQUE INDEX idx_source_eval_unique_current 
    ON source_evaluations(source_id) WHERE is_current = true;

-- -----------------------------------------------------------------------------
-- CONTENT
-- -----------------------------------------------------------------------------
CREATE TABLE content (
    content_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id           UUID REFERENCES sources(source_id) ON DELETE SET NULL,
    
    -- Type & Identity
    content_type        content_type NOT NULL,
    external_id         VARCHAR(500),                   -- Tweet ID, URL hash, etc.
    url                 TEXT,
    
    -- Canonical URL after redirects
    canonical_url       TEXT,
    
    -- Content
    title               TEXT,
    title_en            TEXT,
    
    -- Body text
    content_text        TEXT,                           -- Original language
    content_text_en     TEXT,                           -- English (translation or original)
    content_summary     TEXT,                           -- AI-generated summary (English)
    
    -- Storage references
    raw_html_url        TEXT,                           -- Blob URL for raw HTML
    extracted_text_url  TEXT,                           -- Blob URL for clean text
    
    -- Language
    language            language_code DEFAULT 'en',
    detected_language   VARCHAR(10),                    -- More specific: 'fa-IR', 'ar-EG'
    text_direction      text_direction DEFAULT 'ltr',
    
    -- Authorship
    author_name         VARCHAR(255),
    author_handle       VARCHAR(255),                   -- Twitter handle, byline
    author_entity_id    UUID REFERENCES entities(entity_id),
    
    -- Timestamps
    published_at        TIMESTAMPTZ,
    
    -- Metrics (denormalized for quick access, updated periodically)
    word_count          INTEGER,
    
    -- Twitter-specific
    twitter_metrics     JSONB,
    /*
        {
            "likes": 1500,
            "retweets": 300,
            "replies": 45,
            "quotes": 20,
            "views": 50000,
            "fetched_at": "2026-01-31T12:00:00Z"
        }
    */
    reply_to_id         VARCHAR(100),
    thread_id           VARCHAR(100),
    is_retweet          BOOLEAN DEFAULT false,
    
    -- Processing status
    ingest_status       processing_status DEFAULT 'pending',
    analysis_status     processing_status DEFAULT 'pending',
    
    -- Flags
    is_duplicate        BOOLEAN DEFAULT false,
    duplicate_of_id     UUID REFERENCES content(content_id),
    is_hidden           BOOLEAN DEFAULT false,          -- Editor-suppressed
    hide_reason         TEXT,
    
    -- Timestamps
    ingested_at         TIMESTAMPTZ DEFAULT NOW(),
    analyzed_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(content_type, external_id)
);

-- Partitioning hint: Consider partitioning by ingested_at for large scale
-- CREATE TABLE content (...) PARTITION BY RANGE (ingested_at);

CREATE INDEX idx_content_source ON content(source_id);
CREATE INDEX idx_content_type ON content(content_type);
CREATE INDEX idx_content_language ON content(language);
CREATE INDEX idx_content_ingest_status ON content(ingest_status) WHERE ingest_status = 'pending';
CREATE INDEX idx_content_analysis_status ON content(analysis_status) WHERE analysis_status = 'pending';
CREATE INDEX idx_content_published ON content(published_at DESC);
CREATE INDEX idx_content_ingested ON content(ingested_at DESC);
CREATE INDEX idx_content_author_entity ON content(author_entity_id) WHERE author_entity_id IS NOT NULL;
CREATE INDEX idx_content_hidden ON content(is_hidden) WHERE is_hidden = false;

-- Full-text search
CREATE INDEX idx_content_title_trgm ON content USING gin(title gin_trgm_ops);
CREATE INDEX idx_content_text_trgm ON content USING gin(content_text gin_trgm_ops);

-- -----------------------------------------------------------------------------
-- CONTENT EVALUATIONS (Historical tracking of AI evaluations)
-- -----------------------------------------------------------------------------
CREATE TABLE content_evaluations (
    evaluation_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_id          UUID NOT NULL REFERENCES content(content_id) ON DELETE CASCADE,
    
    -- Stance & Bias
    stance              stance,
    stance_confidence   FLOAT,
    bias_indicators     TEXT[],                         -- ['loaded_language', 'false_balance']
    
    -- Propaganda Assessment
    propaganda_risk     FLOAT CHECK (propaganda_risk >= 0 AND propaganda_risk <= 1),
    propaganda_techniques TEXT[],                       -- ['appeal_to_fear', 'bandwagon']
    
    -- Factuality
    plausibility        plausibility_band,
    factuality_score    FLOAT,                          -- 0-1 overall factuality
    
    -- Virality/Reach
    virality_score      FLOAT,                          -- Normalized 0-1
    
    -- Generated Content
    summary_en          TEXT,                           -- English summary
    explanation         TEXT,                           -- Why this rating
    key_claims          TEXT[],                         -- Quick claim extraction
    
    -- Metadata
    model_used          VARCHAR(100),
    prompt_version      VARCHAR(50),                    -- Track prompt iterations
    tokens_used         INTEGER,
    latency_ms          INTEGER,
    evaluated_by        VARCHAR(100),                   -- 'agent1', 'editor:john'
    
    is_current          BOOLEAN DEFAULT true,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_content_eval_content ON content_evaluations(content_id);
CREATE INDEX idx_content_eval_current ON content_evaluations(content_id, is_current) WHERE is_current = true;
CREATE INDEX idx_content_eval_stance ON content_evaluations(stance) WHERE is_current = true;
CREATE INDEX idx_content_eval_propaganda ON content_evaluations(propaganda_risk) WHERE is_current = true;

CREATE UNIQUE INDEX idx_content_eval_unique_current 
    ON content_evaluations(content_id) WHERE is_current = true;

-- -----------------------------------------------------------------------------
-- CONTENT TOPICS (Many-to-many)
-- -----------------------------------------------------------------------------
CREATE TABLE content_topics (
    content_id          UUID NOT NULL REFERENCES content(content_id) ON DELETE CASCADE,
    topic_id            UUID NOT NULL REFERENCES topics(topic_id) ON DELETE CASCADE,
    
    confidence          FLOAT DEFAULT 1.0,
    assigned_by         VARCHAR(100),                   -- 'auto', 'editor:john'
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (content_id, topic_id)
);

CREATE INDEX idx_content_topics_topic ON content_topics(topic_id);

-- -----------------------------------------------------------------------------
-- CONTENT ENTITIES (Entities mentioned in content)
-- -----------------------------------------------------------------------------
CREATE TABLE content_entities (
    content_id          UUID NOT NULL REFERENCES content(content_id) ON DELETE CASCADE,
    entity_id           UUID NOT NULL REFERENCES entities(entity_id) ON DELETE CASCADE,
    
    mention_type        VARCHAR(50) DEFAULT 'mentioned', -- 'mentioned', 'quoted', 'about', 'authored'
    mention_count       INTEGER DEFAULT 1,
    sentiment           VARCHAR(20),                     -- 'positive', 'negative', 'neutral'
    
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (content_id, entity_id, mention_type)
);

CREATE INDEX idx_content_entities_entity ON content_entities(entity_id);

-- -----------------------------------------------------------------------------
-- CLAIMS
-- -----------------------------------------------------------------------------
CREATE TABLE claims (
    claim_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_id          UUID NOT NULL REFERENCES content(content_id) ON DELETE CASCADE,
    
    -- Claim text
    claim_text          TEXT NOT NULL,
    claim_text_en       TEXT,
    language            language_code DEFAULT 'en',
    
    -- Classification
    claim_type          claim_type DEFAULT 'factual',
    
    -- Verification
    verification_status verification_status DEFAULT 'unverified',
    confidence          FLOAT,
    
    -- Subject (what/who the claim is about)
    subject_entity_id   UUID REFERENCES entities(entity_id),
    subject_text        VARCHAR(500),                   -- If no entity match
    
    -- Temporal context
    claim_date          DATE,                           -- When the claimed event occurred/will occur
    
    -- Extracted context
    context             TEXT,                           -- Surrounding context
    
    -- Processing
    extraction_model    VARCHAR(100),
    
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_claims_content ON claims(content_id);
CREATE INDEX idx_claims_type ON claims(claim_type);
CREATE INDEX idx_claims_verification ON claims(verification_status);
CREATE INDEX idx_claims_subject_entity ON claims(subject_entity_id) WHERE subject_entity_id IS NOT NULL;
CREATE INDEX idx_claims_text_trgm ON claims USING gin(claim_text gin_trgm_ops);

-- -----------------------------------------------------------------------------
-- CLAIM VERIFICATIONS (Historical tracking)
-- -----------------------------------------------------------------------------
CREATE TABLE claim_verifications (
    verification_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    claim_id            UUID NOT NULL REFERENCES claims(claim_id) ON DELETE CASCADE,
    
    status              verification_status NOT NULL,
    confidence          FLOAT,
    
    -- Evidence
    reasoning           TEXT,
    evidence            JSONB DEFAULT '[]'::jsonb,
    /*
        [
            {
                "type": "document",
                "source": "IAEA Report 2025",
                "url": "https://...",
                "excerpt": "...",
                "supports_claim": false
            }
        ]
    */
    
    -- Counter-evidence (conflicting sources)
    counter_evidence    JSONB DEFAULT '[]'::jsonb,
    
    -- Metadata
    model_used          VARCHAR(100),
    verified_by         VARCHAR(100),
    is_current          BOOLEAN DEFAULT true,
    
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_claim_verif_claim ON claim_verifications(claim_id);
CREATE INDEX idx_claim_verif_current ON claim_verifications(claim_id, is_current) WHERE is_current = true;

CREATE UNIQUE INDEX idx_claim_verif_unique_current 
    ON claim_verifications(claim_id) WHERE is_current = true;

-- -----------------------------------------------------------------------------
-- NARRATIVES
-- -----------------------------------------------------------------------------
CREATE TABLE narratives (
    narrative_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Labels
    label               VARCHAR(500) NOT NULL,
    label_fa            VARCHAR(500),
    label_ar            VARCHAR(500),
    
    description         TEXT,
    description_fa      TEXT,
    
    -- Cluster info (denormalized for performance)
    content_count       INTEGER DEFAULT 0,
    claim_count         INTEGER DEFAULT 0,
    source_count        INTEGER DEFAULT 0,              -- Unique sources
    languages           language_code[] DEFAULT '{}',
    
    -- Aggregate evaluation (computed from content)
    dominant_stance     stance DEFAULT 'unknown',
    avg_propaganda_risk FLOAT,
    consensus_plausibility plausibility_band,
    
    -- Key entities involved
    primary_entities    UUID[],                         -- Top entity IDs
    
    -- Timeline
    first_seen_at       TIMESTAMPTZ,
    last_activity_at    TIMESTAMPTZ,
    peak_activity_at    TIMESTAMPTZ,
    
    -- Status
    is_active           BOOLEAN DEFAULT true,           -- Still developing
    is_featured         BOOLEAN DEFAULT false,          -- Editor-promoted
    is_hidden           BOOLEAN DEFAULT false,
    
    -- Related narratives
    parent_narrative_id UUID REFERENCES narratives(narrative_id),
    merged_into_id      UUID REFERENCES narratives(narrative_id),
    
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_narratives_active ON narratives(is_active, last_activity_at DESC) WHERE is_active = true;
CREATE INDEX idx_narratives_featured ON narratives(is_featured, last_activity_at DESC) WHERE is_featured = true;
CREATE INDEX idx_narratives_hidden ON narratives(is_hidden) WHERE is_hidden = false;
CREATE INDEX idx_narratives_label_trgm ON narratives USING gin(label gin_trgm_ops);

-- -----------------------------------------------------------------------------
-- NARRATIVE TOPICS
-- -----------------------------------------------------------------------------
CREATE TABLE narrative_topics (
    narrative_id        UUID NOT NULL REFERENCES narratives(narrative_id) ON DELETE CASCADE,
    topic_id            UUID NOT NULL REFERENCES topics(topic_id) ON DELETE CASCADE,
    relevance           FLOAT DEFAULT 1.0,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (narrative_id, topic_id)
);

CREATE INDEX idx_narrative_topics_topic ON narrative_topics(topic_id);

-- -----------------------------------------------------------------------------
-- NARRATIVE TIMELINE (Detailed timeline entries)
-- -----------------------------------------------------------------------------
CREATE TABLE narrative_timeline (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    narrative_id        UUID NOT NULL REFERENCES narratives(narrative_id) ON DELETE CASCADE,
    
    event_date          DATE NOT NULL,
    event_hour          INTEGER,                        -- 0-23 for hourly granularity
    
    content_count       INTEGER DEFAULT 0,
    claim_count         INTEGER DEFAULT 0,
    
    key_event           TEXT,                           -- Description of what happened
    key_content_ids     UUID[],                         -- Representative content
    
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_narrative_timeline_narrative ON narrative_timeline(narrative_id, event_date DESC);

-- -----------------------------------------------------------------------------
-- CONTENT ↔ NARRATIVE LINKS
-- -----------------------------------------------------------------------------
CREATE TABLE content_narratives (
    content_id          UUID NOT NULL REFERENCES content(content_id) ON DELETE CASCADE,
    narrative_id        UUID NOT NULL REFERENCES narratives(narrative_id) ON DELETE CASCADE,
    
    relevance           FLOAT DEFAULT 1.0 CHECK (relevance >= 0 AND relevance <= 1),
    link_type           VARCHAR(50) DEFAULT 'member',   -- 'member', 'seed', 'reaction', 'counter'
    
    assigned_by         VARCHAR(100),                   -- 'agent2', 'editor:john'
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (content_id, narrative_id)
);

CREATE INDEX idx_content_narratives_narrative ON content_narratives(narrative_id);
CREATE INDEX idx_content_narratives_type ON content_narratives(link_type);

-- -----------------------------------------------------------------------------
-- CLAIM ↔ NARRATIVE LINKS
-- -----------------------------------------------------------------------------
CREATE TABLE claim_narratives (
    claim_id            UUID NOT NULL REFERENCES claims(claim_id) ON DELETE CASCADE,
    narrative_id        UUID NOT NULL REFERENCES narratives(narrative_id) ON DELETE CASCADE,
    
    relevance           FLOAT DEFAULT 1.0,
    is_core_claim       BOOLEAN DEFAULT false,          -- Central to the narrative
    
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (claim_id, narrative_id)
);

CREATE INDEX idx_claim_narratives_narrative ON claim_narratives(narrative_id);

-- -----------------------------------------------------------------------------
-- ARTICLE ↔ TWEET LINKS
-- -----------------------------------------------------------------------------
CREATE TABLE article_tweet_links (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    article_id          UUID NOT NULL REFERENCES content(content_id) ON DELETE CASCADE,
    tweet_id            UUID NOT NULL REFERENCES content(content_id) ON DELETE CASCADE,
    
    link_type           VARCHAR(50) DEFAULT 'reaction',
    /*
        'reaction' - Tweet is reacting to article
        'shares' - Tweet shares/promotes article
        'discusses' - Tweet discusses article topic
        'quotes' - Tweet quotes from article
        'contradicts' - Tweet contradicts article
    */
    
    confidence          FLOAT DEFAULT 1.0,
    detected_by         VARCHAR(100),                   -- 'url_match', 'semantic', 'manual'
    
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(article_id, tweet_id)
);

CREATE INDEX idx_atl_article ON article_tweet_links(article_id);
CREATE INDEX idx_atl_tweet ON article_tweet_links(tweet_id);
CREATE INDEX idx_atl_type ON article_tweet_links(link_type);

-- =============================================================================
-- PODCAST & DELIVERY
-- =============================================================================

CREATE TABLE podcast_episodes (
    episode_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Episode info
    title               VARCHAR(500) NOT NULL,
    description         TEXT,
    episode_number      INTEGER,
    
    -- Date coverage
    coverage_start      TIMESTAMPTZ NOT NULL,
    coverage_end        TIMESTAMPTZ NOT NULL,
    
    -- Content
    script              TEXT,
    script_sections     JSONB,                          -- Structured script with sections
    narratives_covered  UUID[],
    
    -- Audio
    audio_url           TEXT,
    audio_duration_secs INTEGER,
    audio_size_bytes    BIGINT,
    
    -- Status
    status              podcast_status DEFAULT 'scheduled',
    error_message       TEXT,
    retry_count         INTEGER DEFAULT 0,
    
    -- Generation metadata
    script_model        VARCHAR(100),
    tts_provider        VARCHAR(100),                   -- 'azure', 'elevenlabs'
    tts_voice           VARCHAR(100),
    
    -- Publication
    published_at        TIMESTAMPTZ,
    rss_guid            VARCHAR(255) UNIQUE,
    
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_podcast_status ON podcast_episodes(status);
CREATE INDEX idx_podcast_published ON podcast_episodes(published_at DESC) WHERE published_at IS NOT NULL;
CREATE INDEX idx_podcast_coverage ON podcast_episodes(coverage_start, coverage_end);

-- =============================================================================
-- EMBEDDINGS & SEARCH SYNC
-- =============================================================================

CREATE TABLE embeddings_sync (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Target (polymorphic)
    target_type         VARCHAR(50) NOT NULL,           -- 'content', 'claim', 'narrative'
    target_id           UUID NOT NULL,
    
    -- Embedding info
    embedding_model     VARCHAR(100) NOT NULL,          -- 'text-embedding-3-large'
    vector_dimensions   INTEGER,
    
    -- Search service sync
    search_index        VARCHAR(100) NOT NULL,          -- 'nura-content', 'nura-claims'
    search_doc_id       VARCHAR(255),                   -- ID in Azure AI Search
    
    -- Status
    sync_status         sync_status DEFAULT 'pending',
    last_synced_at      TIMESTAMPTZ,
    last_error          TEXT,
    retry_count         INTEGER DEFAULT 0,
    
    -- Version tracking
    content_hash        VARCHAR(64),                    -- Hash of embedded content
    
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(target_type, target_id, search_index)
);

CREATE INDEX idx_embeddings_sync_status ON embeddings_sync(sync_status) WHERE sync_status = 'pending';
CREATE INDEX idx_embeddings_sync_target ON embeddings_sync(target_type, target_id);

-- =============================================================================
-- USER FEEDBACK & INTERACTION
-- =============================================================================

CREATE TABLE user_feedback (
    feedback_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Target (one must be set)
    content_id          UUID REFERENCES content(content_id) ON DELETE CASCADE,
    claim_id            UUID REFERENCES claims(claim_id) ON DELETE CASCADE,
    narrative_id        UUID REFERENCES narratives(narrative_id) ON DELETE CASCADE,
    episode_id          UUID REFERENCES podcast_episodes(episode_id) ON DELETE CASCADE,
    
    -- Feedback
    feedback_type       VARCHAR(50) NOT NULL,           -- 'seems_right', 'seems_off', 'flag', 'helpful'
    feedback_detail     VARCHAR(100),                   -- More specific: 'bias_wrong', 'missing_context'
    comment             TEXT,
    
    -- Context
    session_id          VARCHAR(100),
    user_agent          TEXT,
    ip_hash             VARCHAR(64),                    -- Hashed for privacy
    
    -- Processing
    is_reviewed         BOOLEAN DEFAULT false,
    reviewed_by         VARCHAR(100),
    reviewed_at         TIMESTAMPTZ,
    action_taken        TEXT,
    
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    
    -- At least one target
    CHECK (num_nonnulls(content_id, claim_id, narrative_id, episode_id) = 1)
);

CREATE INDEX idx_feedback_content ON user_feedback(content_id) WHERE content_id IS NOT NULL;
CREATE INDEX idx_feedback_narrative ON user_feedback(narrative_id) WHERE narrative_id IS NOT NULL;
CREATE INDEX idx_feedback_unreviewed ON user_feedback(is_reviewed) WHERE is_reviewed = false;
CREATE INDEX idx_feedback_type ON user_feedback(feedback_type);

-- =============================================================================
-- OPERATIONAL TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- INGESTION LOG
-- -----------------------------------------------------------------------------
CREATE TABLE ingestion_log (
    log_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id           UUID REFERENCES sources(source_id) ON DELETE SET NULL,
    
    run_type            VARCHAR(50) NOT NULL,           -- 'rss_poll', 'twitter_fetch', 'manual'
    
    started_at          TIMESTAMPTZ NOT NULL,
    completed_at        TIMESTAMPTZ,
    duration_ms         INTEGER,
    
    -- Results
    items_fetched       INTEGER DEFAULT 0,
    items_new           INTEGER DEFAULT 0,
    items_updated       INTEGER DEFAULT 0,
    items_duplicate     INTEGER DEFAULT 0,
    items_failed        INTEGER DEFAULT 0,
    
    status              VARCHAR(50) DEFAULT 'running',
    error_message       TEXT,
    error_details       JSONB,
    
    -- n8n tracking
    workflow_execution_id VARCHAR(100),
    
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ingestion_source ON ingestion_log(source_id);
CREATE INDEX idx_ingestion_started ON ingestion_log(started_at DESC);
CREATE INDEX idx_ingestion_status ON ingestion_log(status);
CREATE INDEX idx_ingestion_workflow ON ingestion_log(workflow_execution_id) WHERE workflow_execution_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- ANALYSIS LOG (Track Agent runs)
-- -----------------------------------------------------------------------------
CREATE TABLE analysis_log (
    log_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    agent_name          VARCHAR(50) NOT NULL,           -- 'agent1', 'agent2', 'embedder'
    run_type            VARCHAR(50) NOT NULL,           -- 'batch', 'single', 'scheduled'
    
    started_at          TIMESTAMPTZ NOT NULL,
    completed_at        TIMESTAMPTZ,
    duration_ms         INTEGER,
    
    -- Scope
    items_processed     INTEGER DEFAULT 0,
    items_succeeded     INTEGER DEFAULT 0,
    items_failed        INTEGER DEFAULT 0,
    
    -- Cost tracking
    tokens_used         INTEGER DEFAULT 0,
    estimated_cost_usd  DECIMAL(10, 4),
    
    status              VARCHAR(50) DEFAULT 'running',
    error_message       TEXT,
    
    workflow_execution_id VARCHAR(100),
    
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_analysis_agent ON analysis_log(agent_name);
CREATE INDEX idx_analysis_started ON analysis_log(started_at DESC);
CREATE INDEX idx_analysis_status ON analysis_log(status);

-- -----------------------------------------------------------------------------
-- API KEYS (For widget/API consumers)
-- -----------------------------------------------------------------------------
CREATE TABLE api_keys (
    key_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    name                VARCHAR(255) NOT NULL,
    key_hash            VARCHAR(64) NOT NULL UNIQUE,    -- SHA-256 of actual key
    key_prefix          VARCHAR(10) NOT NULL,           -- First 8 chars for identification
    
    -- Permissions
    scopes              TEXT[] DEFAULT '{read}',        -- 'read', 'write', 'admin'
    allowed_origins     TEXT[],                         -- CORS origins
    rate_limit_per_min  INTEGER DEFAULT 60,
    
    -- Status
    is_active           BOOLEAN DEFAULT true,
    expires_at          TIMESTAMPTZ,
    
    -- Usage
    last_used_at        TIMESTAMPTZ,
    total_requests      BIGINT DEFAULT 0,
    
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_api_keys_prefix ON api_keys(key_prefix);
CREATE INDEX idx_api_keys_active ON api_keys(is_active) WHERE is_active = true;

-- =============================================================================
-- MATERIALIZED VIEWS (For common queries)
-- =============================================================================

-- Daily narrative summary (refresh hourly)
CREATE MATERIALIZED VIEW mv_daily_narratives AS
SELECT 
    n.narrative_id,
    n.label,
    n.description,
    n.content_count,
    n.dominant_stance,
    n.avg_propaganda_risk,
    n.consensus_plausibility,
    n.first_seen_at,
    n.last_activity_at,
    n.is_featured,
    array_agg(DISTINCT t.slug) FILTER (WHERE t.slug IS NOT NULL) as topic_slugs,
    (
        SELECT COUNT(*) 
        FROM content_narratives cn 
        JOIN content c ON cn.content_id = c.content_id 
        WHERE cn.narrative_id = n.narrative_id 
        AND c.ingested_at > NOW() - INTERVAL '24 hours'
    ) as items_last_24h
FROM narratives n
LEFT JOIN narrative_topics nt ON n.narrative_id = nt.narrative_id
LEFT JOIN topics t ON nt.topic_id = t.topic_id
WHERE n.is_active = true 
AND n.is_hidden = false
AND n.last_activity_at > NOW() - INTERVAL '7 days'
GROUP BY n.narrative_id;

CREATE UNIQUE INDEX idx_mv_daily_narratives ON mv_daily_narratives(narrative_id);

-- Source health dashboard
CREATE MATERIALIZED VIEW mv_source_health AS
SELECT 
    s.source_id,
    s.name,
    s.source_type,
    s.credibility_tier,
    s.is_active,
    s.last_polled_at,
    s.last_successful_at,
    COUNT(DISTINCT c.content_id) FILTER (WHERE c.ingested_at > NOW() - INTERVAL '24 hours') as items_24h,
    COUNT(DISTINCT c.content_id) FILTER (WHERE c.ingested_at > NOW() - INTERVAL '7 days') as items_7d,
    MAX(c.ingested_at) as last_content_at,
    (
        SELECT status 
        FROM ingestion_log il 
        WHERE il.source_id = s.source_id 
        ORDER BY started_at DESC 
        LIMIT 1
    ) as last_run_status
FROM sources s
LEFT JOIN content c ON s.source_id = c.source_id
WHERE s.is_active = true
GROUP BY s.source_id;

CREATE UNIQUE INDEX idx_mv_source_health ON mv_source_health(source_id);

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN 
        SELECT table_name 
        FROM information_schema.columns 
        WHERE column_name = 'updated_at' 
        AND table_schema = 'public'
    LOOP
        EXECUTE format('
            DROP TRIGGER IF EXISTS trg_updated_at ON %I;
            CREATE TRIGGER trg_updated_at 
            BEFORE UPDATE ON %I 
            FOR EACH ROW 
            EXECUTE FUNCTION update_updated_at();
        ', t, t);
    END LOOP;
END $$;

-- Update narrative counts when content links change
CREATE OR REPLACE FUNCTION update_narrative_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        UPDATE narratives SET
            content_count = (SELECT COUNT(*) FROM content_narratives WHERE narrative_id = NEW.narrative_id),
            last_activity_at = NOW(),
            updated_at = NOW()
        WHERE narrative_id = NEW.narrative_id;
    END IF;
    
    IF TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN
        UPDATE narratives SET
            content_count = (SELECT COUNT(*) FROM content_narratives WHERE narrative_id = OLD.narrative_id),
            updated_at = NOW()
        WHERE narrative_id = OLD.narrative_id;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_narrative_counts
AFTER INSERT OR UPDATE OR DELETE ON content_narratives
FOR EACH ROW EXECUTE FUNCTION update_narrative_counts();

-- Mark old evaluations as not current when new one inserted
CREATE OR REPLACE FUNCTION set_evaluation_not_current()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_current = true THEN
        -- For content_evaluations
        IF TG_TABLE_NAME = 'content_evaluations' THEN
            UPDATE content_evaluations 
            SET is_current = false 
            WHERE content_id = NEW.content_id 
            AND evaluation_id != NEW.evaluation_id 
            AND is_current = true;
        -- For source_evaluations
        ELSIF TG_TABLE_NAME = 'source_evaluations' THEN
            UPDATE source_evaluations 
            SET is_current = false 
            WHERE source_id = NEW.source_id 
            AND evaluation_id != NEW.evaluation_id 
            AND is_current = true;
        -- For claim_verifications
        ELSIF TG_TABLE_NAME = 'claim_verifications' THEN
            UPDATE claim_verifications 
            SET is_current = false 
            WHERE claim_id = NEW.claim_id 
            AND verification_id != NEW.verification_id 
            AND is_current = true;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_content_eval_current
BEFORE INSERT ON content_evaluations
FOR EACH ROW EXECUTE FUNCTION set_evaluation_not_current();

CREATE TRIGGER trg_source_eval_current
BEFORE INSERT ON source_evaluations
FOR EACH ROW EXECUTE FUNCTION set_evaluation_not_current();

CREATE TRIGGER trg_claim_verif_current
BEFORE INSERT ON claim_verifications
FOR EACH ROW EXECUTE FUNCTION set_evaluation_not_current();

-- =============================================================================
-- REFRESH MATERIALIZED VIEWS (Call periodically via n8n or cron)
-- =============================================================================

CREATE OR REPLACE FUNCTION refresh_materialized_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_narratives;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_source_health;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- GRANTS (Adjust as needed)
-- =============================================================================

-- Example: Application role
-- CREATE ROLE nura_app LOGIN PASSWORD 'xxx';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO nura_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO nura_app;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO nura_app;

-- Example: Read-only role for analytics
-- CREATE ROLE nura_readonly LOGIN PASSWORD 'xxx';
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO nura_readonly;
-- GRANT SELECT ON ALL MATERIALIZED VIEWS IN SCHEMA public TO nura_readonly;
