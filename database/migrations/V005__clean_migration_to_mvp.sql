-- =============================================================================
-- Nura Neural - Clean Migration to MVP v2.0
-- Version: V006
-- Date: February 4, 2026
-- 
-- Purpose: Clean migration from V002/V003 schema to V004 MVP schema
-- This handles conflicts with existing types/tables from previous migrations
-- =============================================================================

-- =============================================================================
-- STEP 1: Drop old tables that conflict with MVP schema
-- =============================================================================

\echo 'Dropping old schema elements...'

-- Drop old tables (cascade to remove dependencies)
DROP TABLE IF EXISTS content_narratives CASCADE;
DROP TABLE IF EXISTS content_entities CASCADE;
DROP TABLE IF EXISTS content_topics CASCADE;
DROP TABLE IF EXISTS content_evaluations CASCADE;
DROP TABLE IF EXISTS content CASCADE;
DROP TABLE IF EXISTS source_evaluations CASCADE;
DROP TABLE IF EXISTS sources CASCADE;
DROP TABLE IF EXISTS entity_relationships CASCADE;
DROP TABLE IF EXISTS entities CASCADE;
DROP TABLE IF EXISTS narrative_timeline CASCADE;
DROP TABLE IF EXISTS narrative_topics CASCADE;
DROP TABLE IF EXISTS narratives CASCADE;
DROP TABLE IF EXISTS topics CASCADE;
DROP TABLE IF EXISTS ingestion_log CASCADE;
DROP TABLE IF EXISTS analysis_log CASCADE;
DROP TABLE IF EXISTS embedding_sync CASCADE;
DROP TABLE IF EXISTS user_feedback CASCADE;
DROP TABLE IF EXISTS api_keys CASCADE;

-- Drop materialized views if they exist
DROP MATERIALIZED VIEW IF EXISTS mv_daily_narratives CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_source_health CASCADE;

-- Drop old types (must be after tables that use them)
DROP TYPE IF EXISTS content_type CASCADE;
DROP TYPE IF EXISTS language_code CASCADE;
DROP TYPE IF EXISTS processing_status CASCADE;
DROP TYPE IF EXISTS source_type CASCADE;
DROP TYPE IF EXISTS credibility_tier CASCADE;
DROP TYPE IF EXISTS text_direction CASCADE;
DROP TYPE IF EXISTS claim_type CASCADE;
DROP TYPE IF EXISTS verification_status CASCADE;
DROP TYPE IF EXISTS stance CASCADE;
DROP TYPE IF EXISTS plausibility_band CASCADE;
DROP TYPE IF EXISTS entity_type CASCADE;
DROP TYPE IF EXISTS entity_relationship_type CASCADE;
DROP TYPE IF EXISTS podcast_status CASCADE;
DROP TYPE IF EXISTS sync_status CASCADE;
DROP TYPE IF EXISTS trust_level CASCADE;
DROP TYPE IF EXISTS narrative_topic_type CASCADE;

\echo 'Old schema cleaned.'

-- =============================================================================
-- STEP 2: Enable required extensions (idempotent)
-- =============================================================================

\echo 'Enabling extensions...'

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";          -- pgvector for embeddings
CREATE EXTENSION IF NOT EXISTS "pg_trgm";         -- Text search/similarity

\echo 'Extensions enabled.'

-- =============================================================================
-- STEP 3: Create new ENUMs for MVP v2.0
-- =============================================================================

\echo 'Creating MVP v2.0 ENUMs...'

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

\echo 'ENUMs created.'

-- =============================================================================
-- STEP 4: Apply MVP schema (4 core tables)
-- =============================================================================

\echo 'Creating MVP v2.0 tables...'

-- Note: We're not using \i here because we need inline SQL for cloud shell
-- Instead, we'll include the essential table definitions directly

-- TABLE 1: SOURCE_PROFILES
CREATE TABLE source_profiles (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identity
    name                VARCHAR(255) NOT NULL,
    name_fa             VARCHAR(255),
    identifier          VARCHAR(500) NOT NULL UNIQUE,
    
    -- Classification (6-Layer Spectrum)
    source_class        source_class NOT NULL,
    source_subclass     source_subclass NOT NULL,
    base_score          INTEGER NOT NULL CHECK (base_score >= 15 AND base_score <= 100),
    
    -- Transparency Audit
    transparency_audit  JSONB DEFAULT '{}'::jsonb,
    transparency_score  INTEGER DEFAULT 0 CHECK (transparency_score >= 0 AND transparency_score <= 15),
    
    -- Context Statement
    context_statement   TEXT,
    context_statement_fa TEXT,
    
    -- Proxy Detection
    proxy_score         FLOAT DEFAULT 0.0 CHECK (proxy_score >= 0 AND proxy_score <= 1),
    is_state_proxy      BOOLEAN DEFAULT false,
    ownership_cluster   VARCHAR(100),
    
    -- Feed Configuration
    feed_url            TEXT,
    feed_type           content_type DEFAULT 'rss_article',
    poll_interval_mins  INTEGER DEFAULT 15,
    is_active           BOOLEAN DEFAULT true,
    
    -- Historical Performance
    historical_accuracy FLOAT,
    last_audit_at       TIMESTAMPTZ,
    
    -- Timestamps
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_source_profiles_class ON source_profiles(source_class);
CREATE INDEX idx_source_profiles_active ON source_profiles(is_active) WHERE is_active = true;
CREATE INDEX idx_source_profiles_cluster ON source_profiles(ownership_cluster) WHERE ownership_cluster IS NOT NULL;

-- TABLE 2: NARRATIVES
CREATE TABLE narratives (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- AI-Generated Content
    title               TEXT NOT NULL,
    title_fa            TEXT,
    summary             TEXT NOT NULL,
    summary_fa          TEXT,
    
    -- Metadata
    topic_type          narrative_topic_type DEFAULT 'BREAKING',
    first_seen_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_updated        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_featured         BOOLEAN DEFAULT false,
    
    -- Metrics
    item_count          INTEGER DEFAULT 0,
    trust_distribution  JSONB DEFAULT '{}'::jsonb,
    propaganda_ratio    FLOAT DEFAULT 0.0,
    
    -- Timestamps
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_narratives_updated ON narratives(last_updated DESC);
CREATE INDEX idx_narratives_featured ON narratives(is_featured) WHERE is_featured = true;
CREATE INDEX idx_narratives_topic ON narratives(topic_type);
CREATE INDEX idx_narratives_first_seen ON narratives(first_seen_at DESC);

-- TABLE 3: ITEMS
CREATE TABLE items (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Source
    source_id           UUID NOT NULL REFERENCES source_profiles(id) ON DELETE CASCADE,
    narrative_id        UUID REFERENCES narratives(id) ON DELETE SET NULL,
    
    -- Identity
    url                 TEXT NOT NULL,
    url_hash            VARCHAR(64) NOT NULL UNIQUE,
    content_hash        VARCHAR(64),
    
    -- Content (Original)
    title               TEXT NOT NULL,
    content             TEXT,
    content_html        TEXT,
    excerpt             TEXT,
    author              VARCHAR(255),
    
    -- Metadata
    content_type        content_type DEFAULT 'rss_article',
    original_language   language_code DEFAULT 'fa',
    published_at        TIMESTAMPTZ NOT NULL,
    ingested_at         TIMESTAMPTZ DEFAULT NOW(),
    
    -- AI Enrichment
    title_en            TEXT,
    content_en          TEXT,
    metadata            JSONB DEFAULT '{}'::jsonb,
    embedding           vector(3072),
    
    -- Trust Score
    trust_score         INTEGER CHECK (trust_score >= 15 AND trust_score <= 95),
    trust_level         trust_level,
    
    -- Processing
    status              processing_status DEFAULT 'pending',
    error_message       TEXT,
    
    -- Archival
    blob_path           TEXT,
    
    -- Timestamps
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_items_source ON items(source_id);
CREATE INDEX idx_items_narrative ON items(narrative_id);
CREATE INDEX idx_items_url_hash ON items(url_hash);
CREATE INDEX idx_items_published ON items(published_at DESC);
CREATE INDEX idx_items_ingested ON items(ingested_at DESC);
CREATE INDEX idx_items_status ON items(status) WHERE status != 'completed';
CREATE INDEX idx_items_trust_score ON items(trust_score DESC) WHERE trust_score IS NOT NULL;
CREATE INDEX idx_items_trust_level ON items(trust_level);
CREATE INDEX idx_items_embedding ON items USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- TABLE 4: TRUST_SIGNALS
CREATE TABLE trust_signals (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id             UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    
    -- Breakdown (5 Components)
    source_score        INTEGER NOT NULL,
    content_score       INTEGER NOT NULL,
    corroboration_score INTEGER NOT NULL,
    freshness_penalty   INTEGER NOT NULL,
    consistency_score   INTEGER NOT NULL,
    
    -- Total
    total_score         INTEGER NOT NULL CHECK (total_score >= 15 AND total_score <= 95),
    
    -- Explanation
    explanation         TEXT NOT NULL,
    
    -- Calculation Metadata
    calculated_at       TIMESTAMPTZ DEFAULT NOW(),
    model_version       VARCHAR(50) DEFAULT 'mvp_v1.0'
);

CREATE INDEX idx_trust_signals_item ON trust_signals(item_id);
CREATE INDEX idx_trust_signals_total ON trust_signals(total_score DESC);
CREATE INDEX idx_trust_signals_calculated ON trust_signals(calculated_at DESC);

\echo 'Tables created.'

-- =============================================================================
-- STEP 5: Create helper functions
-- =============================================================================

\echo 'Creating helper functions...'

-- Trigger function for updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to source_profiles
CREATE TRIGGER trg_source_profiles_updated
    BEFORE UPDATE ON source_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Apply trigger to items
CREATE TRIGGER trg_items_updated
    BEFORE UPDATE ON items
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

\echo 'Helper functions created.'

-- =============================================================================
-- STEP 6: Verification
-- =============================================================================

\echo 'Verifying installation...'

SELECT 'MVP v2.0 Schema Applied Successfully!' as status;

SELECT 'Tables created:' as info;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;

SELECT 'ENUMs created:' as info;
SELECT typname as enum_name
FROM pg_type
WHERE typcategory = 'E' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
ORDER BY typname;

\echo 'Migration V006 complete!'
