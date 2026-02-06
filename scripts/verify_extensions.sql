-- =============================================================================
-- Extension Verification Script
-- Feature: 003-db-foundation-schema (US1)
-- Purpose: Verify all required PostgreSQL extensions are installed and functional
-- =============================================================================

-- T005: Extension verification query
\echo 'Checking installed extensions...'

SELECT extname, extversion 
FROM pg_extension 
WHERE extname IN ('uuid-ossp', 'vector', 'pg_trgm', 'btree_gin')
ORDER BY extname;

-- Verify extension count
DO $$
DECLARE
  ext_count INT;
BEGIN
  SELECT COUNT(*) INTO ext_count
  FROM pg_extension 
  WHERE extname IN ('uuid-ossp', 'vector', 'pg_trgm', 'btree_gin');
  
  IF ext_count < 4 THEN
    RAISE EXCEPTION 'Expected 4 extensions, found %', ext_count;
  END IF;
  RAISE NOTICE 'All 4 required extensions installed';
END $$;

-- T006: Vector functionality test (1536-dimension embedding)
\echo 'Testing vector operations...'

-- Create temporary table for vector test
CREATE TEMP TABLE _vector_test (
  id SERIAL PRIMARY KEY,
  embedding vector(1536)
);

-- Generate a test 1536-dimension vector (zeros with markers)
INSERT INTO _vector_test (embedding)
SELECT (
  '[' || 
  string_agg(
    CASE 
      WHEN i = 1 THEN '0.1'
      WHEN i = 768 THEN '0.5'
      WHEN i = 1536 THEN '0.9'
      ELSE '0.0'
    END, ','
  ) ||
  ']'
)::vector(1536)
FROM generate_series(1, 1536) AS i;

-- Verify insert succeeded
DO $$
DECLARE
  v_count INT;
  v_dims INT;
BEGIN
  SELECT COUNT(*), vector_dims(embedding) INTO v_count, v_dims
  FROM _vector_test;
  
  IF v_count != 1 THEN
    RAISE EXCEPTION 'Vector insert failed';
  END IF;
  
  IF v_dims != 1536 THEN
    RAISE EXCEPTION 'Expected 1536 dimensions, got %', v_dims;
  END IF;
  
  RAISE NOTICE 'Vector insert test passed: 1536 dimensions';
END $$;

-- Test cosine distance operation
SELECT 
  id,
  vector_dims(embedding) AS dimensions,
  embedding <=> embedding AS self_distance,
  1 - (embedding <=> embedding) AS self_similarity
FROM _vector_test;

-- Test k-NN query pattern (will use seq scan on temp table, but validates syntax)
EXPLAIN (COSTS OFF)
SELECT id 
FROM _vector_test 
ORDER BY embedding <=> (SELECT embedding FROM _vector_test WHERE id = 1)
LIMIT 5;

-- Cleanup
DROP TABLE _vector_test;

\echo 'Extension verification complete - ALL TESTS PASSED'
