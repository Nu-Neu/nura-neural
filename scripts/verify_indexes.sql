-- =============================================================================
-- Index Verification Script
-- Feature: 003-db-foundation-schema (US3)
-- Purpose: Verify all supporting indexes exist and are used by query plans
-- =============================================================================

-- T011: Index verification - list all indexes on core tables

\echo 'Checking indexes on content_items...'
SELECT 
  indexname,
  indexdef,
  pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
FROM pg_indexes 
WHERE tablename = 'content_items'
ORDER BY indexname;

\echo 'Checking indexes on knowledge_base...'
SELECT 
  indexname,
  indexdef,
  pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
FROM pg_indexes 
WHERE tablename = 'knowledge_base'
ORDER BY indexname;

\echo 'Checking indexes on clusters...'
SELECT 
  indexname,
  indexdef,
  pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
FROM pg_indexes 
WHERE tablename = 'clusters'
ORDER BY indexname;

\echo 'Checking indexes on sources...'
SELECT 
  indexname,
  indexdef,
  pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
FROM pg_indexes 
WHERE tablename = 'sources'
ORDER BY indexname;

-- Verify expected indexes exist
DO $$
DECLARE
  expected_indexes TEXT[] := ARRAY[
    -- content_items indexes
    'idx_content_items_status',
    'idx_content_items_source',
    'idx_content_items_cluster',
    'idx_content_items_published_at',
    'idx_content_items_embedding_hnsw',
    -- knowledge_base indexes
    'idx_knowledge_base_fact_type',
    'idx_knowledge_base_confidence',
    'idx_knowledge_base_embedding_hnsw',
    -- clusters indexes
    'idx_clusters_trust_badge',
    'idx_clusters_final_trust_score',
    'idx_clusters_is_breaking',
    -- sources indexes
    'idx_sources_type',
    'idx_sources_tier',
    'idx_sources_name_trgm'
  ];
  idx TEXT;
  missing_indexes TEXT[] := ARRAY[]::TEXT[];
BEGIN
  FOREACH idx IN ARRAY expected_indexes LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = idx) THEN
      missing_indexes := array_append(missing_indexes, idx);
    END IF;
  END LOOP;
  
  IF array_length(missing_indexes, 1) > 0 THEN
    RAISE WARNING 'Missing indexes: %', array_to_string(missing_indexes, ', ');
  ELSE
    RAISE NOTICE 'All expected indexes present';
  END IF;
END $$;

-- =============================================================================
-- T012: EXPLAIN ANALYZE tests for key query patterns
-- =============================================================================

\echo ''
\echo '=== Query Pattern Tests ==='
\echo ''

-- Test 1: Status filter (should use idx_content_items_status)
\echo 'Test 1: Status filter query plan...'
EXPLAIN (COSTS OFF, FORMAT TEXT)
SELECT id, original_title 
FROM content_items 
WHERE processing_status = 'PENDING'
LIMIT 100;

-- Test 2: Trust badge filter (should use idx_clusters_trust_badge)
\echo 'Test 2: Trust badge filter query plan...'
EXPLAIN (COSTS OFF, FORMAT TEXT)
SELECT id, title_en 
FROM clusters 
WHERE trust_badge = 'HIGH_TRUST'
ORDER BY final_trust_score DESC
LIMIT 50;

-- Test 3: Trigram search (should use idx_sources_name_trgm)
\echo 'Test 3: Trigram similarity query plan...'
EXPLAIN (COSTS OFF, FORMAT TEXT)
SELECT id, name 
FROM sources 
WHERE name % 'news'
LIMIT 20;

-- Test 4: Date range scan (should use idx_content_items_published_at)
\echo 'Test 4: Date range query plan...'
EXPLAIN (COSTS OFF, FORMAT TEXT)
SELECT id, published_at 
FROM content_items 
WHERE published_at >= NOW() - INTERVAL '7 days'
ORDER BY published_at DESC
LIMIT 100;

-- Test 5: Vector k-NN (should use HNSW index after V010)
\echo 'Test 5: Vector k-NN query plan (requires embedding data)...'
EXPLAIN (COSTS OFF, FORMAT TEXT)
SELECT id 
FROM content_items 
WHERE embedding_vector IS NOT NULL
ORDER BY embedding_vector <=> (
  SELECT embedding_vector FROM content_items WHERE embedding_vector IS NOT NULL LIMIT 1
)
LIMIT 50;

\echo ''
\echo 'Index verification complete'
