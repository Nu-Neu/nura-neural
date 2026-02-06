-- =============================================================================
-- Migration: V010 - HNSW Index Tuning
-- Feature: 003-db-foundation-schema (US2)
-- Date: 2026-02-06
--
-- Purpose:
--   Drop and recreate HNSW vector indexes with proper tuning parameters.
--   Optimized for 100K+ vectors with balanced recall/performance.
--
-- Parameters:
--   m = 16: Maximum connections per layer (balanced for our scale)
--   ef_construction = 64: Dynamic candidate list size during construction
--
-- Prerequisites:
--   - V008__core_schema_prereqs.sql applied
--   - pgvector extension installed
--   - content_items and knowledge_base tables exist
--
-- Notes:
--   - Uses CONCURRENTLY for non-blocking operations
--   - Requires flyway:executeInTransaction=false
--   - Idempotent via IF EXISTS clauses
-- =============================================================================

-- T008: Flyway directive for CONCURRENT operations (cannot run in transaction)
-- flyway:executeInTransaction=false

-- =============================================================================
-- T009: HNSW Index on content_items
-- =============================================================================

-- Drop existing untuned index
DROP INDEX CONCURRENTLY IF EXISTS idx_content_items_embedding_hnsw;

-- Recreate with tuning parameters
CREATE INDEX CONCURRENTLY idx_content_items_embedding_hnsw
  ON content_items
  USING hnsw (embedding_vector vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

COMMENT ON INDEX idx_content_items_embedding_hnsw IS 
  'HNSW index for content_items embeddings. Tuned: m=16, ef_construction=64. Created by V010.';

-- =============================================================================
-- T010: HNSW Index on knowledge_base
-- =============================================================================

-- Drop existing untuned index
DROP INDEX CONCURRENTLY IF EXISTS idx_knowledge_base_embedding_hnsw;

-- Recreate with tuning parameters
CREATE INDEX CONCURRENTLY idx_knowledge_base_embedding_hnsw
  ON knowledge_base
  USING hnsw (embedding_vector vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

COMMENT ON INDEX idx_knowledge_base_embedding_hnsw IS 
  'HNSW index for knowledge_base embeddings. Tuned: m=16, ef_construction=64. Created by V010.';

-- =============================================================================
-- Validation: Verify indexes created with correct parameters
-- =============================================================================

DO $$
DECLARE
  ci_opts TEXT;
  kb_opts TEXT;
BEGIN
  -- Check content_items index
  SELECT array_to_string(c.reloptions, ',') INTO ci_opts
  FROM pg_class c
  WHERE c.relname = 'idx_content_items_embedding_hnsw';
  
  IF ci_opts IS NULL THEN
    RAISE EXCEPTION 'idx_content_items_embedding_hnsw was not created';
  END IF;
  
  IF ci_opts NOT LIKE '%m=16%' OR ci_opts NOT LIKE '%ef_construction=64%' THEN
    RAISE EXCEPTION 'idx_content_items_embedding_hnsw missing tuning params: %', ci_opts;
  END IF;
  
  RAISE NOTICE 'idx_content_items_embedding_hnsw verified: %', ci_opts;
  
  -- Check knowledge_base index
  SELECT array_to_string(c.reloptions, ',') INTO kb_opts
  FROM pg_class c
  WHERE c.relname = 'idx_knowledge_base_embedding_hnsw';
  
  IF kb_opts IS NULL THEN
    RAISE EXCEPTION 'idx_knowledge_base_embedding_hnsw was not created';
  END IF;
  
  IF kb_opts NOT LIKE '%m=16%' OR kb_opts NOT LIKE '%ef_construction=64%' THEN
    RAISE EXCEPTION 'idx_knowledge_base_embedding_hnsw missing tuning params: %', kb_opts;
  END IF;
  
  RAISE NOTICE 'idx_knowledge_base_embedding_hnsw verified: %', kb_opts;
  
  RAISE NOTICE 'V010 migration validated successfully';
END $$;
