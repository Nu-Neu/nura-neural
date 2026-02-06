-- =============================================================================
-- Nura - Core Schema Prerequisites (Sources + Core Entities)
-- Version: V008
-- Date: 2026-02-06
--
-- Purpose:
--   Establish the foundational tables/enums required across all epics.
--   Implements US-C1 (Source Registry) and creates core entities needed for
--   ingestion, clustering, analysis, and RAG.
--
-- Notes:
--   - SQL-only (Flyway-compatible). No psql meta-commands.
--   - Append-only migration; do not edit once applied.
-- =============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- =============================================================================
-- ENUMS
-- =============================================================================

-- Source registry
CREATE TYPE source_type AS ENUM ('NEWS_ORG', 'INDIVIDUAL', 'GOVERNMENT_ORG', 'THINK_TANK', 'NGO');
CREATE TYPE source_official_capacity AS ENUM ('NONE', 'HEAD_OF_STATE', 'SPOKESPERSON', 'OFFICIAL', 'JOURNALIST');
CREATE TYPE source_platform AS ENUM ('RSS', 'TWITTER', 'TELEGRAM', 'WEB', 'YOUTUBE');
CREATE TYPE source_audit_status AS ENUM ('PENDING', 'AUDITED', 'REQUIRES_UPDATE');
CREATE TYPE source_ownership_type AS ENUM ('STATE_CONTROLLED', 'INDEPENDENT', 'PRIVATE', 'NGO', 'UNKNOWN');

-- Shared
CREATE TYPE language_code AS ENUM ('fa', 'ar', 'en', 'tr', 'other');

-- Content
CREATE TYPE content_nature AS ENUM ('FACTUAL', 'INTERPRETIVE', 'MIXED', 'UNKNOWN');
CREATE TYPE content_type AS ENUM ('BREAKING_NEWS', 'ARTICLE', 'OPINION', 'STATEMENT', 'THREAD', 'VIDEO', 'IMAGE');
CREATE TYPE content_processing_status AS ENUM ('PENDING', 'TRANSLATED', 'EMBEDDED', 'CLUSTERED', 'ANALYZED', 'FINALIZED');

-- Clusters
CREATE TYPE cluster_trust_badge AS ENUM ('HIGH_TRUST', 'MEDIUM_TRUST', 'LOW_TRUST', 'PROPAGANDA_ALERT');
CREATE TYPE cluster_narrative_pattern AS ENUM ('ORGANIC', 'COORDINATED_PROPAGANDA', 'DISPUTED');

-- Analysis
CREATE TYPE analysis_type AS ENUM ('FACT_CHECK', 'ARGUMENT_ANALYSIS', 'PROPAGANDA_DETECTION');
CREATE TYPE analysis_tone AS ENUM ('NEUTRAL', 'INFLAMMATORY', 'PARTISAN', 'FEARMONGERING');

-- Knowledge base
CREATE TYPE knowledge_fact_type AS ENUM ('HISTORICAL_FACT', 'NARRATIVE_PATTERN', 'VERIFIED_CLAIM', 'PROPAGANDA_TECHNIQUE');
CREATE TYPE knowledge_verification_source AS ENUM ('EXPERT', 'PERPLEXITY_PRO', 'HISTORICAL', 'ACADEMIC', 'AMNESTY', 'UN');
CREATE TYPE knowledge_created_by AS ENUM ('AI', 'EXPERT', 'PERPLEXITY');

-- =============================================================================
-- HELPERS
-- =============================================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- TABLE: sources (US-C1: Source Registry)
-- =============================================================================

CREATE TABLE sources (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  name                  VARCHAR(500) NOT NULL,
  name_fa               VARCHAR(500),

  source_type           source_type NOT NULL,
  official_capacity     source_official_capacity NOT NULL DEFAULT 'NONE',

  platform              source_platform NOT NULL,
  platform_identifier   TEXT NOT NULL,

  default_language      language_code NOT NULL DEFAULT 'fa',

  tier                  SMALLINT NOT NULL DEFAULT 3 CHECK (tier BETWEEN 1 AND 3),

  baseline_trust_score  INTEGER NOT NULL DEFAULT 0 CHECK (baseline_trust_score BETWEEN 0 AND 100),
  imtt_scores           JSONB NOT NULL DEFAULT '{}'::jsonb,

  audit_status          source_audit_status NOT NULL DEFAULT 'PENDING',
  last_audit_at         TIMESTAMPTZ,

  ownership_type        source_ownership_type NOT NULL DEFAULT 'UNKNOWN',
  affiliation           TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  funding_sources       TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],

  metadata              JSONB NOT NULL DEFAULT '{}'::jsonb,

  is_active             BOOLEAN NOT NULL DEFAULT true,

  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_sources_platform_identifier UNIQUE (platform, platform_identifier)
);

CREATE INDEX idx_sources_type ON sources(source_type);
CREATE INDEX idx_sources_tier ON sources(tier);
CREATE INDEX idx_sources_baseline_trust_score ON sources(baseline_trust_score);
CREATE INDEX idx_sources_audit_status ON sources(audit_status);
CREATE INDEX idx_sources_ownership_type ON sources(ownership_type);

CREATE INDEX idx_sources_name_trgm ON sources USING gin (name gin_trgm_ops);
CREATE INDEX idx_sources_name_fa_trgm ON sources USING gin (name_fa gin_trgm_ops);
CREATE INDEX idx_sources_affiliation_gin ON sources USING gin (affiliation);

CREATE TRIGGER trg_sources_set_updated_at
  BEFORE UPDATE ON sources
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- TABLE: clusters
-- =============================================================================

CREATE TABLE clusters (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  title_en              VARCHAR(200) NOT NULL,
  summary_en            VARCHAR(280) NOT NULL,

  trust_badge           cluster_trust_badge NOT NULL,
  final_trust_score     INTEGER NOT NULL CHECK (final_trust_score BETWEEN 0 AND 100),
  content_quality_score INTEGER CHECK (content_quality_score BETWEEN 0 AND 100),
  source_weighted_score INTEGER CHECK (source_weighted_score BETWEEN 0 AND 100),

  narrative_pattern     cluster_narrative_pattern NOT NULL DEFAULT 'ORGANIC',
  is_breaking           BOOLEAN NOT NULL DEFAULT false,

  representative_item_id UUID,
  total_items_count     INTEGER NOT NULL DEFAULT 0 CHECK (total_items_count >= 0),

  impact_metrics        JSONB NOT NULL DEFAULT '{}'::jsonb,

  deep_research_triggered BOOLEAN NOT NULL DEFAULT false,
  deep_research_result  JSONB,

  first_seen_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at            TIMESTAMPTZ
);

CREATE INDEX idx_clusters_last_updated ON clusters(last_updated_at DESC);
CREATE INDEX idx_clusters_first_seen ON clusters(first_seen_at DESC);
CREATE INDEX idx_clusters_expires_at ON clusters(expires_at);
CREATE INDEX idx_clusters_trust_badge ON clusters(trust_badge);
CREATE INDEX idx_clusters_narrative_pattern ON clusters(narrative_pattern);
CREATE INDEX idx_clusters_is_breaking ON clusters(is_breaking) WHERE is_breaking = true;
CREATE INDEX idx_clusters_final_trust_score ON clusters(final_trust_score DESC);

-- =============================================================================
-- TABLE: content_items
-- =============================================================================

CREATE TABLE content_items (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  source_id             UUID NOT NULL REFERENCES sources(id) ON DELETE RESTRICT,
  external_id           TEXT NOT NULL,

  content_nature         content_nature NOT NULL DEFAULT 'UNKNOWN',
  content_type           content_type NOT NULL DEFAULT 'ARTICLE',

  original_language      language_code NOT NULL DEFAULT 'fa',
  original_title         VARCHAR(500),
  original_text          TEXT,

  translated_title_en    VARCHAR(500),
  translated_text_en     TEXT,
  translation_model      TEXT,

  embedding_vector       vector(1536),
  embedding_model        TEXT,

  cluster_id             UUID,
  parent_id              UUID,

  platform_metadata      JSONB NOT NULL DEFAULT '{}'::jsonb,

  processing_status      content_processing_status NOT NULL DEFAULT 'PENDING',

  published_at           TIMESTAMPTZ,
  ingested_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at           TIMESTAMPTZ,

  CONSTRAINT uq_content_items_source_external UNIQUE (source_id, external_id)
);

ALTER TABLE content_items
  ADD CONSTRAINT fk_content_items_cluster
  FOREIGN KEY (cluster_id) REFERENCES clusters(id) ON DELETE SET NULL;

ALTER TABLE content_items
  ADD CONSTRAINT fk_content_items_parent
  FOREIGN KEY (parent_id) REFERENCES content_items(id) ON DELETE SET NULL;

CREATE INDEX idx_content_items_source ON content_items(source_id);
CREATE INDEX idx_content_items_cluster ON content_items(cluster_id);
CREATE INDEX idx_content_items_parent ON content_items(parent_id) WHERE parent_id IS NOT NULL;

CREATE INDEX idx_content_items_status ON content_items(processing_status);
CREATE INDEX idx_content_items_nature ON content_items(content_nature);
CREATE INDEX idx_content_items_published_at ON content_items(published_at DESC);
CREATE INDEX idx_content_items_ingested_at ON content_items(ingested_at DESC);

-- Vector index for similarity search (pgvector)
CREATE INDEX idx_content_items_embedding_hnsw
  ON content_items
  USING hnsw (embedding_vector vector_cosine_ops);

-- Now that content_items exists, finalize the representative_item FK
ALTER TABLE clusters
  ADD CONSTRAINT fk_clusters_representative_item
  FOREIGN KEY (representative_item_id) REFERENCES content_items(id) ON DELETE SET NULL;

-- =============================================================================
-- TABLE: content_analysis
-- =============================================================================

CREATE TABLE content_analysis (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  content_item_id       UUID NOT NULL REFERENCES content_items(id) ON DELETE CASCADE,
  cluster_id            UUID REFERENCES clusters(id) ON DELETE SET NULL,

  analysis_type         analysis_type NOT NULL,

  propaganda_detected   BOOLEAN NOT NULL DEFAULT false,
  detected_techniques   TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  logical_fallacies     TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  tone                  analysis_tone NOT NULL DEFAULT 'NEUTRAL',

  penalty_breakdown     JSONB NOT NULL DEFAULT '[]'::jsonb,

  content_quality_score INTEGER CHECK (content_quality_score BETWEEN 0 AND 100),
  total_penalty_applied INTEGER CHECK (total_penalty_applied >= 0),

  verdict_en            TEXT,
  verdict_fa            TEXT,
  confidence_score      NUMERIC(4,3) CHECK (confidence_score BETWEEN 0 AND 1),

  ai_model_used         TEXT,
  prompt_version        TEXT,
  analyzed_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  inherited_from        UUID REFERENCES content_analysis(id) ON DELETE SET NULL,
  reuse_count           INTEGER NOT NULL DEFAULT 0 CHECK (reuse_count >= 0)
);

CREATE INDEX idx_content_analysis_item ON content_analysis(content_item_id);
CREATE INDEX idx_content_analysis_cluster ON content_analysis(cluster_id);
CREATE INDEX idx_content_analysis_type ON content_analysis(analysis_type);
CREATE INDEX idx_content_analysis_propaganda ON content_analysis(propaganda_detected) WHERE propaganda_detected = true;
CREATE INDEX idx_content_analysis_quality_score ON content_analysis(content_quality_score DESC);

-- =============================================================================
-- TABLE: knowledge_base
-- =============================================================================

CREATE TABLE knowledge_base (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  fact_type             knowledge_fact_type NOT NULL,

  text_content          TEXT NOT NULL,
  text_content_fa       TEXT,

  embedding_vector      vector(1536) NOT NULL,

  verification_source   knowledge_verification_source,
  confidence_level      NUMERIC(4,3) CHECK (confidence_level BETWEEN 0 AND 1),

  related_entities      TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  related_clusters      UUID[] NOT NULL DEFAULT ARRAY[]::UUID[],

  invalidated           BOOLEAN NOT NULL DEFAULT false,

  created_by            knowledge_created_by NOT NULL DEFAULT 'AI',
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  reference_count       INTEGER NOT NULL DEFAULT 0 CHECK (reference_count >= 0),
  last_referenced_at    TIMESTAMPTZ
);

CREATE INDEX idx_knowledge_base_fact_type ON knowledge_base(fact_type);
CREATE INDEX idx_knowledge_base_confidence ON knowledge_base(confidence_level DESC);
CREATE INDEX idx_knowledge_base_invalidated ON knowledge_base(invalidated) WHERE invalidated = true;
CREATE INDEX idx_knowledge_base_related_entities_gin ON knowledge_base USING gin (related_entities);

CREATE INDEX idx_knowledge_base_embedding_hnsw
  ON knowledge_base
  USING hnsw (embedding_vector vector_cosine_ops);
