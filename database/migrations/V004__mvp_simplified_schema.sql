-- =============================================================================
-- Nura Neural - MVP Migration
-- Version: V004
-- Date: February 2, 2026
-- 
-- Purpose: Apply simplified MVP schema based on Technical Decision Meeting
-- Changes:
--   - Removed: claims, claim_verifications, claim_narratives tables
--   - Simplified: 4 core tables (source_profiles, items, narratives, trust_signals)
--   - Added: Trust scoring breakdown fields per Master Functional Specification
-- =============================================================================

-- Note: This is a FRESH schema deployment, not a migration from V2/V3
-- If migrating from existing complex schema, run DROP statements first (see below)

-- =============================================================================
-- CLEANUP: Drop old schema if exists (USE WITH CAUTION)
-- =============================================================================

-- Uncomment these lines if migrating from old complex schema:
/*
DROP TABLE IF EXISTS claim_narratives CASCADE;
DROP TABLE IF EXISTS claim_verifications CASCADE;
DROP TABLE IF EXISTS claims CASCADE;
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
DROP TABLE IF EXISTS article_tweet_links CASCADE;
DROP TABLE IF EXISTS podcast_episodes CASCADE;
DROP TABLE IF EXISTS embeddings_sync CASCADE;
DROP TABLE IF EXISTS user_feedback CASCADE;
DROP TABLE IF EXISTS ingestion_log CASCADE;
DROP TABLE IF EXISTS analysis_log CASCADE;
DROP TABLE IF EXISTS api_keys CASCADE;

DROP MATERIALIZED VIEW IF EXISTS mv_daily_narratives CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_source_health CASCADE;

DROP TYPE IF EXISTS source_type CASCADE;
DROP TYPE IF EXISTS credibility_tier CASCADE;
DROP TYPE IF EXISTS content_type CASCADE;
DROP TYPE IF EXISTS language_code CASCADE;
DROP TYPE IF EXISTS text_direction CASCADE;
DROP TYPE IF EXISTS processing_status CASCADE;
DROP TYPE IF EXISTS claim_type CASCADE;
DROP TYPE IF EXISTS verification_status CASCADE;
DROP TYPE IF EXISTS stance CASCADE;
DROP TYPE IF EXISTS plausibility_band CASCADE;
DROP TYPE IF EXISTS entity_type CASCADE;
DROP TYPE IF EXISTS entity_relationship_type CASCADE;
DROP TYPE IF EXISTS podcast_status CASCADE;
DROP TYPE IF EXISTS sync_status CASCADE;
*/

-- =============================================================================
-- Now apply the MVP schema from schema_mvp.sql
-- =============================================================================

\echo 'Applying Nura Neural MVP Schema v3.0...'
\i schema_mvp.sql
\echo 'MVP Schema applied successfully!'

-- =============================================================================
-- Verify Installation
-- =============================================================================

SELECT 'Tables created:' as info;
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;

SELECT 'Enum types created:' as info;
SELECT typname FROM pg_type 
WHERE typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
AND typtype = 'e'
ORDER BY typname;
