-- =============================================================================
-- Nura Neural - MVP Database Schema
-- Version: 3.0 (Simplified for MVP)
-- Date: February 2, 2026
-- 
-- Based on Technical Decision Meeting Minutes:
-- - 4 Core Tables: source_profiles, items, narratives, trust_signals
-- - Removed: claims entity (narratives serve this purpose via AI summaries)
-- - Narrative-First Architecture
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";          -- pgvector for embeddings
CREATE EXTENSION IF NOT EXISTS "pg_trgm";         -- Text search/similarity

-- =============================================================================
-- ENUM TYPES (Aligned with Master Functional Specification)
-- =============================================================================

-- Source Classification: The 6-Layer Spectrum
CREATE TYPE source_class AS ENUM (
    'REGIME_MEDIA',         -- IRNA, Fars, Tasnim (35-40)
    'GREY_TABLOID',         -- Anonymous Telegram, clickbait (20-30)
    'ACTIVIST_CITIZEN',     -- 1500tasvir, emerging accounts (50-65)
    'MAINSTREAM_DIASPORA',  -- BBC Persian, Iran Intl (70-80)
    'NGO_WATCHDOG',         -- HRANA, Amnesty, NetBlocks (85-95)
    'INTL_WIRE',            -- Reuters, AP, NYT (90-100)
    'KEY_FIGURE'            -- Heads of state, opposition leaders (60 fixed)
);

-- Source Subclass (detailed classification)
CREATE TYPE source_subclass AS ENUM (
    -- REGIME_MEDIA
    'STATE_NEWS_AGENCY',
    'IRGC_AFFILIATED',
    'STATE_INTERNATIONAL',
    -- GREY_TABLOID
    'ANONYMOUS_TELEGRAM',
    'CLICKBAIT_DIASPORA',
    -- ACTIVIST_CITIZEN
    'CITIZEN_VERIFIED',
    'CITIZEN_EMERGING',
    -- MAINSTREAM_DIASPORA
    'INTL_BROADCASTER',
    'INDEPENDENT_PERSIAN',
    -- NGO_WATCHDOG
    'HUMAN_RIGHTS_INTL',
    'TECH_MONITOR',
    -- INTL_WIRE
    'GLOBAL_WIRE',
    -- KEY_FIGURE
    'HEAD_OF_STATE',
    'OPPOSITION_LEADER'
);

-- Content/Source types
CREATE TYPE content_type AS ENUM (
    'rss_article',
    'tweet',
    'telegram_post',
    'manual_entry'
);

-- Languages (core supported)
CREATE TYPE language_code AS ENUM ('fa', 'en', 'ar');

-- Trust levels (for UI badges)
CREATE TYPE trust_level AS ENUM (
    'VERIFIED',      -- 80-95: Green
    'RELIABLE',      -- 65-79: Light Green
    'CHECK_SOURCES', -- 50-64: Yellow
    'UNVERIFIED',    -- 35-49: Orange
    'CAUTION'        -- 15-34: Red
);

-- Processing status
CREATE TYPE processing_status AS ENUM (
    'pending',
    'processing',
    'completed',
    'failed'
);

-- Narrative topic type (affects clustering window)
CREATE TYPE narrative_topic_type AS ENUM (
    'BREAKING',      -- 72 hours window
    'PROTEST',       -- 7 days window
    'POLICY'         -- 14 days window
);

-- =============================================================================
-- TABLE 1: SOURCE_PROFILES
-- Master list of sources with classification and scoring
-- =============================================================================

CREATE TABLE source_profiles (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identity
    name                VARCHAR(255) NOT NULL,
    name_fa             VARCHAR(255),                   -- Farsi name
    identifier          VARCHAR(500) NOT NULL UNIQUE,   -- domain, @handle, or channel ID
    
    -- Classification (6-Layer Spectrum)
    source_class        source_class NOT NULL,
    source_subclass     source_subclass NOT NULL,
    base_score          INTEGER NOT NULL CHECK (base_score >= 15 AND base_score <= 100),
    
    -- Transparency Audit (JSONB for flexibility)
    transparency_audit  JSONB DEFAULT '{}'::jsonb,
    /*
        {
            "ownership_page": true,        -- +3 points
            "corrections_policy": false,   -- +2 points
            "staff_list": true,            -- +2 points
            "contact_info": true,          -- +2 points
            "total_score": 7               -- Max 9
        }
    */
    transparency_score  INTEGER DEFAULT 0 CHECK (transparency_score >= 0 AND transparency_score <= 15),
    
    -- Context Statement (for UI/explanation)
    context_statement   TEXT,                           -- English
    context_statement_fa TEXT,                          -- Farsi
    
    -- Proxy Detection
    proxy_score         FLOAT DEFAULT 0.0 CHECK (proxy_score >= 0 AND proxy_score <= 1),
    is_state_proxy      BOOLEAN DEFAULT false,
    ownership_cluster   VARCHAR(100),                   -- e.g., 'IRGC', 'BBC_GROUP'
    
    -- Feed Configuration
    feed_url            TEXT,                           -- RSS feed URL
    feed_type           content_type DEFAULT 'rss_article',
    poll_interval_mins  INTEGER DEFAULT 15,
    is_active           BOOLEAN DEFAULT true,
    
    -- Historical Performance
    historical_accuracy FLOAT,                          -- 0-1 scale
    last_audit_at       TIMESTAMPTZ,
    
    -- Timestamps
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_source_profiles_class ON source_profiles(source_class);
CREATE INDEX idx_source_profiles_active ON source_profiles(is_active) WHERE is_active = true;
CREATE INDEX idx_source_profiles_cluster ON source_profiles(ownership_cluster) WHERE ownership_cluster IS NOT NULL;

-- =============================================================================
-- TABLE 2: NARRATIVES
-- Story clusters with AI-generated summaries (Narrative-First Architecture)
-- =============================================================================

CREATE TABLE narratives (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Display
    title               VARCHAR(500) NOT NULL,
    title_fa            VARCHAR(500),
    
    -- AI-Generated Content
    ai_summary          TEXT,                           -- English summary from o3-mini + GPT-4o
    ai_summary_fa       TEXT,                           -- Persian polished version (GPT-4o)
    
    -- Key Facts (structured extraction)
    key_facts           JSONB DEFAULT '[]'::jsonb,
    /*
        [
            {"fact": "3 killed in protest", "verified": false, "sources": 2},
            {"fact": "Police used tear gas", "verified": true, "sources": 5}
        ]
    */
    
    -- Classification
    topic_type          narrative_topic_type DEFAULT 'BREAKING',
    primary_language    language_code DEFAULT 'fa',
    
    -- Aggregated Metrics
    item_count          INTEGER DEFAULT 0,
    source_count        INTEGER DEFAULT 0,              -- Unique sources
    trend_score         FLOAT DEFAULT 0.0,              -- Virality/importance metric
    
    -- Trust Distribution (aggregated from items)
    avg_trust_score     FLOAT,
    min_trust_score     FLOAT,
    max_trust_score     FLOAT,
    
    -- Entities (for clustering)
    entities            JSONB DEFAULT '[]'::jsonb,
    /*
        [
            {"type": "PERSON", "name": "Khamenei", "name_fa": "خامنه‌ای"},
            {"type": "LOCATION", "name": "Zahedan", "name_fa": "زاهدان"},
            {"type": "EVENT", "name": "Friday Protest"}
        ]
    */
    
    -- Time Bounds
    first_seen_at       TIMESTAMPTZ,
    last_seen_at        TIMESTAMPTZ,
    cluster_window_end  TIMESTAMPTZ,                    -- When clustering stops accepting new items
    
    -- Status
    is_active           BOOLEAN DEFAULT true,
    is_featured         BOOLEAN DEFAULT false,          -- Editor-promoted
    
    -- Manual Debunk (for viral rumors not in RSS)
    is_manual_debunk    BOOLEAN DEFAULT false,
    debunk_verdict      VARCHAR(100),                   -- 'FALSE', 'MISLEADING', 'OUT_OF_CONTEXT'
    debunk_explanation  TEXT,
    
    -- Timestamps
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_narratives_active ON narratives(is_active, last_seen_at DESC) WHERE is_active = true;
CREATE INDEX idx_narratives_featured ON narratives(is_featured) WHERE is_featured = true;
CREATE INDEX idx_narratives_topic ON narratives(topic_type);
CREATE INDEX idx_narratives_trend ON narratives(trend_score DESC);

-- =============================================================================
-- TABLE 3: ITEMS
-- Raw news articles with embeddings and narrative assignment
-- =============================================================================

CREATE TABLE items (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Source Link
    source_id           UUID NOT NULL REFERENCES source_profiles(id) ON DELETE SET NULL,
    
    -- Narrative Assignment (Many-to-One)
    narrative_id        UUID REFERENCES narratives(id) ON DELETE SET NULL,
    
    -- Identity
    external_id         VARCHAR(500),                   -- Tweet ID, RSS GUID, etc.
    url                 TEXT NOT NULL,
    url_hash            VARCHAR(64) NOT NULL,           -- SHA-256 for deduplication
    content_hash        VARCHAR(64),                    -- SimHash for near-duplicate detection
    
    -- Content
    title               TEXT,
    title_en            TEXT,                           -- English translation
    body                TEXT,                           -- Original language
    body_en             TEXT,                           -- English translation
    summary             VARCHAR(500),                   -- AI-generated summary (GPT-4o-mini)
    
    -- Metadata (extracted by GPT-4o-mini)
    author              VARCHAR(255),
    publish_date        TIMESTAMPTZ,
    language            language_code DEFAULT 'fa',
    content_type        content_type DEFAULT 'rss_article',
    
    -- Entities (for narrative clustering)
    entities            JSONB DEFAULT '[]'::jsonb,
    /*
        [
            {"type": "PERSON", "name": "Raisi"},
            {"type": "ORG", "name": "IRGC"}
        ]
    */
    
    -- Embedding (pgvector - 3072 dimensions for text-embedding-3-large)
    embedding           vector(3072),
    
    -- Storage References
    raw_html_url        TEXT,                           -- Azure Blob URL
    
    -- Processing Status
    ingest_status       processing_status DEFAULT 'pending',
    analysis_status     processing_status DEFAULT 'pending',
    
    -- Flags
    is_duplicate        BOOLEAN DEFAULT false,
    is_breaking         BOOLEAN DEFAULT false,          -- <6 hours old, no corroboration penalty
    is_official_statement BOOLEAN DEFAULT false,        -- VIP "Statement of Record"
    
    -- Timestamps
    ingested_at         TIMESTAMPTZ DEFAULT NOW(),
    analyzed_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(url_hash)
);

CREATE INDEX idx_items_source ON items(source_id);
CREATE INDEX idx_items_narrative ON items(narrative_id) WHERE narrative_id IS NOT NULL;
CREATE INDEX idx_items_url_hash ON items(url_hash);
CREATE INDEX idx_items_content_hash ON items(content_hash) WHERE content_hash IS NOT NULL;
CREATE INDEX idx_items_ingest_pending ON items(ingest_status) WHERE ingest_status = 'pending';
CREATE INDEX idx_items_analysis_pending ON items(analysis_status) WHERE analysis_status = 'pending';
CREATE INDEX idx_items_ingested ON items(ingested_at DESC);
CREATE INDEX idx_items_published ON items(publish_date DESC) WHERE publish_date IS NOT NULL;
CREATE INDEX idx_items_language ON items(language);

-- Vector similarity search index (HNSW for ANN)
CREATE INDEX idx_items_embedding ON items USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- =============================================================================
-- TABLE 4: TRUST_SIGNALS
-- Detailed scoring breakdown per item (One-to-One with items)
-- =============================================================================

CREATE TABLE trust_signals (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Item Link (One-to-One)
    item_id             UUID NOT NULL UNIQUE REFERENCES items(id) ON DELETE CASCADE,
    
    -- Final Score & Level
    final_score         INTEGER NOT NULL CHECK (final_score >= 15 AND final_score <= 95),
    trust_level         trust_level NOT NULL,
    
    -- Score Breakdown (per Master Functional Specification)
    base_contribution   INTEGER CHECK (base_contribution >= 0 AND base_contribution <= 45),
    /*
        Formula: ROUND(0.45 × source_profiles.base_score)
        Range: 9 to 45 points
    */
    
    provenance_score    INTEGER CHECK (provenance_score >= 0 AND provenance_score <= 20),
    /*
        URL Valid: +6
        Timestamp: +5
        Author: +4
        Dateline: +3
        Media: +2
    */
    provenance_breakdown JSONB DEFAULT '{}'::jsonb,
    /*
        {
            "url_valid": true,      -- +6
            "has_timestamp": true,  -- +5
            "has_author": false,    -- +4
            "has_dateline": true,   -- +3
            "has_media": false      -- +2
        }
    */
    
    corroboration_score INTEGER CHECK (corroboration_score >= 0 AND corroboration_score <= 20),
    /*
        0 matches: 0 pts
        1 match: +8 pts
        2 matches: +14 pts
        3 matches: +18 pts
        4+ matches: +20 pts
    */
    corroboration_count INTEGER DEFAULT 0,
    corroboration_sources UUID[],                       -- IDs of corroborating items
    ownership_cluster_blocked BOOLEAN DEFAULT false,    -- True if all matches from same cluster
    
    transparency_score  INTEGER CHECK (transparency_score >= 0 AND transparency_score <= 15),
    /*
        Source level (0-9) + Item level (0-6)
    */
    
    modifiers           INTEGER DEFAULT 0,
    /*
        Anonymous Sourcing: -8
        Unverified Numbers: -10
        Primary Doc: +6
        Correction: +5
    */
    modifier_flags      JSONB DEFAULT '[]'::jsonb,
    /*
        ["ANONYMOUS_SOURCING", "UNVERIFIED_NUMBERS"]
    */
    
    -- Badges (for UI)
    badges              TEXT[] DEFAULT '{}',
    /*
        ['VERIFIED_SOURCE', 'CORROBORATED', 'BREAKING', 'OFFICIAL_STATEMENT']
    */
    
    -- Warnings (for UI)
    warnings            TEXT[] DEFAULT '{}',
    /*
        ['REGIME_PROXY', 'ANONYMOUS_SOURCE', 'UNVERIFIED_NUMBERS']
    */
    
    -- Human-Readable Explanation (generated by GPT-4o-mini)
    explanation         TEXT,
    explanation_fa      TEXT,
    
    -- Metadata
    model_used          VARCHAR(100),                   -- 'o3-mini', 'gpt-4o-mini'
    scored_at           TIMESTAMPTZ DEFAULT NOW(),
    
    -- Timestamps
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_trust_signals_item ON trust_signals(item_id);
CREATE INDEX idx_trust_signals_score ON trust_signals(final_score DESC);
CREATE INDEX idx_trust_signals_level ON trust_signals(trust_level);

-- =============================================================================
-- OPERATIONAL TABLES (Supporting the 4 core tables)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- INGESTION LOG (Track feed polling runs)
-- -----------------------------------------------------------------------------
CREATE TABLE ingestion_log (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id           UUID REFERENCES source_profiles(id) ON DELETE SET NULL,
    
    run_type            VARCHAR(50) NOT NULL,           -- 'rss_poll', 'twitter_fetch', 'manual'
    workflow_execution_id VARCHAR(100),                 -- n8n execution ID
    
    started_at          TIMESTAMPTZ NOT NULL,
    completed_at        TIMESTAMPTZ,
    duration_ms         INTEGER,
    
    -- Results
    items_fetched       INTEGER DEFAULT 0,
    items_new           INTEGER DEFAULT 0,
    items_duplicate     INTEGER DEFAULT 0,
    items_failed        INTEGER DEFAULT 0,
    
    status              VARCHAR(50) DEFAULT 'running',
    error_message       TEXT,
    
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ingestion_log_source ON ingestion_log(source_id);
CREATE INDEX idx_ingestion_log_started ON ingestion_log(started_at DESC);

-- -----------------------------------------------------------------------------
-- ANALYSIS LOG (Track AI processing runs)
-- -----------------------------------------------------------------------------
CREATE TABLE analysis_log (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    agent_name          VARCHAR(50) NOT NULL,           -- 'ingestion', 'scoring', 'clustering', 'summarization'
    run_type            VARCHAR(50) NOT NULL,           -- 'batch', 'single', 'scheduled'
    workflow_execution_id VARCHAR(100),
    
    started_at          TIMESTAMPTZ NOT NULL,
    completed_at        TIMESTAMPTZ,
    duration_ms         INTEGER,
    
    -- Scope
    items_processed     INTEGER DEFAULT 0,
    items_succeeded     INTEGER DEFAULT 0,
    items_failed        INTEGER DEFAULT 0,
    
    -- Cost Tracking
    tokens_used         INTEGER DEFAULT 0,
    estimated_cost_usd  DECIMAL(10, 4),
    model_used          VARCHAR(100),
    
    status              VARCHAR(50) DEFAULT 'running',
    error_message       TEXT,
    
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_analysis_log_agent ON analysis_log(agent_name);
CREATE INDEX idx_analysis_log_started ON analysis_log(started_at DESC);

-- -----------------------------------------------------------------------------
-- EMBEDDING SYNC (Track Azure AI Search synchronization)
-- -----------------------------------------------------------------------------
CREATE TABLE embedding_sync (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    item_id             UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    search_index        VARCHAR(100) NOT NULL DEFAULT 'nura-content',
    search_doc_id       VARCHAR(255),
    
    sync_status         VARCHAR(20) DEFAULT 'pending', -- 'pending', 'synced', 'failed'
    last_synced_at      TIMESTAMPTZ,
    last_error          TEXT,
    retry_count         INTEGER DEFAULT 0,
    
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(item_id, search_index)
);

CREATE INDEX idx_embedding_sync_pending ON embedding_sync(sync_status) WHERE sync_status = 'pending';

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER trg_source_profiles_updated_at
    BEFORE UPDATE ON source_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_narratives_updated_at
    BEFORE UPDATE ON narratives
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_items_updated_at
    BEFORE UPDATE ON items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_trust_signals_updated_at
    BEFORE UPDATE ON trust_signals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Update narrative counts when items are linked/unlinked
CREATE OR REPLACE FUNCTION update_narrative_counts()
RETURNS TRIGGER AS $$
BEGIN
    -- Update old narrative if changed
    IF TG_OP = 'UPDATE' AND OLD.narrative_id IS DISTINCT FROM NEW.narrative_id THEN
        IF OLD.narrative_id IS NOT NULL THEN
            UPDATE narratives SET
                item_count = (SELECT COUNT(*) FROM items WHERE narrative_id = OLD.narrative_id),
                source_count = (SELECT COUNT(DISTINCT source_id) FROM items WHERE narrative_id = OLD.narrative_id),
                last_seen_at = (SELECT MAX(ingested_at) FROM items WHERE narrative_id = OLD.narrative_id),
                updated_at = NOW()
            WHERE id = OLD.narrative_id;
        END IF;
    END IF;
    
    -- Update new narrative
    IF NEW.narrative_id IS NOT NULL THEN
        UPDATE narratives SET
            item_count = (SELECT COUNT(*) FROM items WHERE narrative_id = NEW.narrative_id),
            source_count = (SELECT COUNT(DISTINCT source_id) FROM items WHERE narrative_id = NEW.narrative_id),
            first_seen_at = COALESCE(first_seen_at, NEW.ingested_at),
            last_seen_at = GREATEST(last_seen_at, NEW.ingested_at),
            updated_at = NOW()
        WHERE id = NEW.narrative_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_items_narrative_counts
    AFTER INSERT OR UPDATE OF narrative_id ON items
    FOR EACH ROW EXECUTE FUNCTION update_narrative_counts();

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Calculate trust level from score
CREATE OR REPLACE FUNCTION get_trust_level(score INTEGER)
RETURNS trust_level AS $$
BEGIN
    RETURN CASE
        WHEN score >= 80 THEN 'VERIFIED'::trust_level
        WHEN score >= 65 THEN 'RELIABLE'::trust_level
        WHEN score >= 50 THEN 'CHECK_SOURCES'::trust_level
        WHEN score >= 35 THEN 'UNVERIFIED'::trust_level
        ELSE 'CAUTION'::trust_level
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calculate cluster window end based on topic type
CREATE OR REPLACE FUNCTION get_cluster_window_end(topic narrative_topic_type, first_seen TIMESTAMPTZ)
RETURNS TIMESTAMPTZ AS $$
BEGIN
    RETURN CASE topic
        WHEN 'BREAKING' THEN first_seen + INTERVAL '72 hours'
        WHEN 'PROTEST' THEN first_seen + INTERVAL '7 days'
        WHEN 'POLICY' THEN first_seen + INTERVAL '14 days'
        ELSE first_seen + INTERVAL '72 hours'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =============================================================================
-- VIEWS (For common queries)
-- =============================================================================

-- Active narratives with trust distribution
CREATE VIEW v_active_narratives AS
SELECT 
    n.id,
    n.title,
    n.title_fa,
    n.ai_summary,
    n.topic_type,
    n.item_count,
    n.source_count,
    n.trend_score,
    n.first_seen_at,
    n.last_seen_at,
    n.is_featured,
    ROUND(AVG(ts.final_score))::INTEGER as avg_trust_score,
    MIN(ts.final_score) as min_trust_score,
    MAX(ts.final_score) as max_trust_score,
    COUNT(CASE WHEN ts.trust_level = 'VERIFIED' THEN 1 END) as verified_count,
    COUNT(CASE WHEN ts.trust_level = 'CAUTION' THEN 1 END) as caution_count
FROM narratives n
LEFT JOIN items i ON i.narrative_id = n.id
LEFT JOIN trust_signals ts ON ts.item_id = i.id
WHERE n.is_active = true
GROUP BY n.id;

-- Source health dashboard
CREATE VIEW v_source_health AS
SELECT 
    sp.id,
    sp.name,
    sp.source_class,
    sp.base_score,
    sp.is_active,
    COUNT(i.id) FILTER (WHERE i.ingested_at > NOW() - INTERVAL '24 hours') as items_24h,
    COUNT(i.id) FILTER (WHERE i.ingested_at > NOW() - INTERVAL '7 days') as items_7d,
    MAX(i.ingested_at) as last_item_at,
    (
        SELECT status FROM ingestion_log il 
        WHERE il.source_id = sp.id 
        ORDER BY started_at DESC LIMIT 1
    ) as last_run_status
FROM source_profiles sp
LEFT JOIN items i ON i.source_id = sp.id
GROUP BY sp.id;

-- =============================================================================
-- SAMPLE DATA: Source Classification Constants
-- =============================================================================

-- These should be inserted via the Source Bible import script
COMMENT ON TABLE source_profiles IS 
'Source classification based on 6-Layer Spectrum:
- REGIME_MEDIA (35-40): IRNA, Fars, Tasnim
- GREY_TABLOID (20-30): Anonymous Telegram, clickbait
- ACTIVIST_CITIZEN (50-65): 1500tasvir, Vahid Online
- MAINSTREAM_DIASPORA (70-80): BBC Persian, Iran Intl
- NGO_WATCHDOG (85-95): HRANA, Amnesty, NetBlocks
- INTL_WIRE (90-100): Reuters, AP, NYT
- KEY_FIGURE (60 fixed): Heads of state, opposition leaders';

-- =============================================================================
-- END OF MVP SCHEMA
-- =============================================================================
