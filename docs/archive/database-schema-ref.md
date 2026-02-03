---
doc_type: database_schema
version: 1.0
last_updated: 2026-02-03
owner: Nura Development Team
status: approved
related_docs: 
  - srs-nura-v2.4.md
  - hld-nura-v2.0.md
  - design-trust-narrative-system-v1.0.md
---

-- ============================================================================
-- Nura News Intelligence Platform - Database Schema v1.0 (MVP)
-- ============================================================================
-- Description: PostgreSQL schema for AI-driven news analysis platform
-- Target Environment: Azure PostgreSQL Flexible Server
-- Extensions Required: pgvector, uuid-ossp
-- 
-- Design Decisions:
-- - Vector dimensions reduced to 512 (from 1536) for cost optimization
-- - Partitioning deferred to Phase 2 (see Backlog Issue #TBD)
-- - JSONB indexing uses jsonb_path_ops for performance
-- - Partial index on processing_status for n8n workflow efficiency
--
-- Contributors: Reyhaneh (DB), Navid (AI), Amir (Architecture), Saman (Automation)
-- ============================================================================

-- ============================================================================
-- EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- For text search (future use)

-- ============================================================================
-- TABLE: sources
-- ============================================================================
-- Purpose: Registry of news sources (RSS feeds, Telegram channels, etc.)
-- Notes: trust_baseline is the initial credibility score (0-100)
-- ============================================================================
CREATE TABLE sources (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    base_url TEXT NOT NULL UNIQUE,
    trust_baseline INT DEFAULT 50 CHECK (trust_baseline >= 0 AND trust_baseline <= 100),
    source_type TEXT DEFAULT 'rss' CHECK (source_type IN ('rss', 'telegram', 'twitter', 'manual')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- TABLE: articles
-- ============================================================================
-- Purpose: Core table for news articles and analysis results
-- Notes: 
--   - url_hash ensures idempotency (prevents duplicate ingestion)
--   - embedding uses 512 dimensions (text-embedding-3-small optimized)
--   - ai_metadata stores: sentiment, entities, propaganda_techniques, summary
--   - processing_status tracks n8n workflow state
-- Future: Will be partitioned by published_at in Phase 2
-- ============================================================================
CREATE TABLE articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    url_hash TEXT NOT NULL UNIQUE, 
    source_id INT REFERENCES sources(id) ON DELETE SET NULL,

    -- Content fields
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    original_url TEXT,
    published_at TIMESTAMPTZ NOT NULL,

    -- AI Analysis outputs
    ai_metadata JSONB DEFAULT '{}', 
    trust_score FLOAT CHECK (trust_score >= 0 AND trust_score <= 100),
    embedding VECTOR(512), 

    -- Workflow management
    processing_status TEXT DEFAULT 'pending' CHECK (processing_status IN ('pending', 'processed', 'failed', 'skipped')),
    error_log TEXT, -- For failed processing debugging

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES: articles
-- ============================================================================

-- Vector similarity search (HNSW for speed)
-- Parameters: m=16 (connections per layer), ef_construction=64 (build quality)
CREATE INDEX idx_articles_embedding ON articles 
    USING hnsw (embedding vector_cosine_ops) 
    WITH (m = 16, ef_construction = 64);

-- JSONB metadata search (optimized with jsonb_path_ops)
CREATE INDEX idx_articles_metadata ON articles 
    USING GIN (ai_metadata jsonb_path_ops);

-- Trust score + date filtering (for UI queries)
CREATE INDEX idx_articles_trust_date ON articles 
    (trust_score DESC, published_at DESC);

-- Partial index for n8n workflow (only pending items)
CREATE INDEX idx_articles_pending ON articles(processing_status) 
    WHERE processing_status = 'pending';

-- Full-text search on title (optional, for keyword search)
CREATE INDEX idx_articles_title_trgm ON articles 
    USING gin (title gin_trgm_ops);

-- ============================================================================
-- TABLE: narratives
-- ============================================================================
-- Purpose: Clustered narratives (groups of similar articles)
-- Notes: embedding is the centroid vector of all articles in this narrative
-- ============================================================================
CREATE TABLE narratives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    summary TEXT,
    embedding VECTOR(512), -- Centroid of article embeddings

    -- Metadata
    first_seen_at TIMESTAMPTZ DEFAULT NOW(),
    last_updated_at TIMESTAMPTZ DEFAULT NOW(),
    article_count INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true -- For archiving old narratives
);

-- Vector search on narratives
CREATE INDEX idx_narratives_embedding ON narratives 
    USING hnsw (embedding vector_cosine_ops) 
    WITH (m = 16, ef_construction = 64);

-- ============================================================================
-- TABLE: article_narratives (Many-to-Many)
-- ============================================================================
-- Purpose: Maps articles to narratives with similarity scores
-- Notes: similarity_score is cosine similarity (0-1)
-- ============================================================================
CREATE TABLE article_narratives (
    article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
    narrative_id UUID REFERENCES narratives(id) ON DELETE CASCADE,
    similarity_score FLOAT CHECK (similarity_score >= 0 AND similarity_score <= 1),
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (article_id, narrative_id)
);

-- Index for finding articles by narrative
CREATE INDEX idx_article_narratives_narrative ON article_narratives(narrative_id);

-- ============================================================================
-- TABLE: users (Future - Auth system)
-- ============================================================================
-- Purpose: User accounts for personalized feeds
-- Status: Placeholder for Phase 2
-- ============================================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-update timestamp on articles
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_articles_updated_at 
    BEFORE UPDATE ON articles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sources_updated_at 
    BEFORE UPDATE ON sources
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-update narrative article count
CREATE OR REPLACE FUNCTION update_narrative_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE narratives 
        SET article_count = article_count + 1,
            last_updated_at = NOW()
        WHERE id = NEW.narrative_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE narratives 
        SET article_count = article_count - 1,
            last_updated_at = NOW()
        WHERE id = OLD.narrative_id;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_narrative_count_trigger
    AFTER INSERT OR DELETE ON article_narratives
    FOR EACH ROW EXECUTE FUNCTION update_narrative_count();

-- ============================================================================
-- SEED DATA (Optional - for testing)
-- ============================================================================

-- Sample sources
INSERT INTO sources (name, base_url, trust_baseline, source_type) VALUES
    ('IRNA (Official)', 'https://www.irna.ir/rss', 30, 'rss'),
    ('Fars News', 'https://www.farsnews.ir/rss', 25, 'rss'),
    ('BBC Persian', 'https://www.bbc.com/persian/rss', 75, 'rss'),
    ('Iran International', 'https://www.iranintl.com/rss', 70, 'rss');

-- ============================================================================
-- MAINTENANCE QUERIES (for DBA reference)
-- ============================================================================

-- Check table sizes
-- SELECT 
--     schemaname,
--     tablename,
--     pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
-- FROM pg_tables 
-- WHERE schemaname = 'public'
-- ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Check index usage
-- SELECT 
--     schemaname,
--     tablename,
--     indexname,
--     idx_scan,
--     pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
-- FROM pg_stat_user_indexes
-- ORDER BY idx_scan ASC;

-- Find pending articles (for n8n debugging)
-- SELECT id, title, created_at, processing_status, error_log
-- FROM articles
-- WHERE processing_status = 'pending'
-- ORDER BY created_at DESC
-- LIMIT 100;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
