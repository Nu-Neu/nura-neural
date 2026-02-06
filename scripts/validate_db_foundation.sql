-- =============================================================================
-- Database Foundation Validation Script
-- Feature: 003-db-foundation-schema
-- Purpose: Comprehensive validation of all database foundation requirements
-- =============================================================================

\echo '==================================================================='
\echo 'Database Foundation Schema Validation'
\echo '==================================================================='
\echo ''

-- =============================================================================
-- Section 1: PostgreSQL Version Check
-- =============================================================================

\echo 'Section 1: PostgreSQL Version'
\echo '------------------------------'

SELECT version();

DO $$
DECLARE
  v_version TEXT;
  v_major INT;
BEGIN
  SELECT split_part(version(), ' ', 2) INTO v_version;
  v_major := split_part(v_version, '.', 1)::INT;
  
  IF v_major >= 16 THEN
    RAISE NOTICE '✓ PostgreSQL %s (required: 16+)', v_version;
  ELSE
    RAISE EXCEPTION '✗ PostgreSQL % is below required 16.x', v_version;
  END IF;
END $$;

-- =============================================================================
-- Section 2: Extension Verification (US1)
-- =============================================================================

\echo ''
\echo 'Section 2: Extensions (US1)'
\echo '----------------------------'

SELECT extname, extversion 
FROM pg_extension 
WHERE extname IN ('uuid-ossp', 'vector', 'pg_trgm', 'btree_gin')
ORDER BY extname;

DO $$
DECLARE
  ext_count INT;
  vector_ver TEXT;
  vector_major INT;
  vector_minor INT;
BEGIN
  SELECT COUNT(*) INTO ext_count
  FROM pg_extension 
  WHERE extname IN ('uuid-ossp', 'vector', 'pg_trgm', 'btree_gin');
  
  IF ext_count < 4 THEN
    RAISE EXCEPTION '✗ Missing extensions (expected 4, found %)', ext_count;
  END IF;
  
  SELECT extversion INTO vector_ver FROM pg_extension WHERE extname = 'vector';
  vector_major := split_part(vector_ver, '.', 1)::INT;
  vector_minor := split_part(vector_ver, '.', 2)::INT;
  
  IF vector_major = 0 AND vector_minor < 5 THEN
    RAISE EXCEPTION '✗ pgvector % is below required 0.5+', vector_ver;
  END IF;
  
  RAISE NOTICE '✓ All 4 extensions installed';
  RAISE NOTICE '✓ pgvector version % (required: 0.5+)', vector_ver;
END $$;

-- =============================================================================
-- Section 3: Core Tables Verification
-- =============================================================================

\echo ''
\echo 'Section 3: Core Tables'
\echo '-----------------------'

SELECT 
  table_name,
  pg_size_pretty(pg_total_relation_size(table_name::regclass)) AS total_size,
  (SELECT COUNT(*) FROM information_schema.columns c WHERE c.table_name = t.table_name) AS column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
  AND table_name IN ('content_items', 'knowledge_base', 'clusters', 'sources', 'content_analysis')
ORDER BY table_name;

DO $$
DECLARE
  core_tables TEXT[] := ARRAY['content_items', 'knowledge_base', 'clusters', 'sources'];
  tbl TEXT;
  missing TEXT[] := ARRAY[]::TEXT[];
BEGIN
  FOREACH tbl IN ARRAY core_tables LOOP
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = tbl) THEN
      missing := array_append(missing, tbl);
    END IF;
  END LOOP;
  
  IF array_length(missing, 1) > 0 THEN
    RAISE EXCEPTION '✗ Missing tables: %', array_to_string(missing, ', ');
  END IF;
  
  RAISE NOTICE '✓ All core tables exist';
END $$;

-- =============================================================================
-- Section 4: HNSW Index Verification (US2)
-- =============================================================================

\echo ''
\echo 'Section 4: HNSW Indexes (US2)'
\echo '------------------------------'

SELECT 
  c.relname AS index_name,
  array_to_string(c.reloptions, ', ') AS options,
  pg_size_pretty(pg_relation_size(c.oid)) AS size
FROM pg_class c
JOIN pg_index i ON c.oid = i.indexrelid
JOIN pg_am am ON c.relam = am.oid
WHERE c.relname LIKE '%_embedding_hnsw'
  AND am.amname = 'hnsw'
ORDER BY c.relname;

DO $$
DECLARE
  ci_opts TEXT;
  kb_opts TEXT;
BEGIN
  -- Check content_items HNSW index
  SELECT array_to_string(c.reloptions, ',') INTO ci_opts
  FROM pg_class c
  WHERE c.relname = 'idx_content_items_embedding_hnsw';
  
  IF ci_opts IS NULL THEN
    RAISE EXCEPTION '✗ idx_content_items_embedding_hnsw not found';
  ELSIF ci_opts NOT LIKE '%m=16%' OR ci_opts NOT LIKE '%ef_construction=64%' THEN
    RAISE WARNING '! idx_content_items_embedding_hnsw has non-optimal params: %', ci_opts;
  ELSE
    RAISE NOTICE '✓ idx_content_items_embedding_hnsw: m=16, ef_construction=64';
  END IF;
  
  -- Check knowledge_base HNSW index
  SELECT array_to_string(c.reloptions, ',') INTO kb_opts
  FROM pg_class c
  WHERE c.relname = 'idx_knowledge_base_embedding_hnsw';
  
  IF kb_opts IS NULL THEN
    RAISE EXCEPTION '✗ idx_knowledge_base_embedding_hnsw not found';
  ELSIF kb_opts NOT LIKE '%m=16%' OR kb_opts NOT LIKE '%ef_construction=64%' THEN
    RAISE WARNING '! idx_knowledge_base_embedding_hnsw has non-optimal params: %', kb_opts;
  ELSE
    RAISE NOTICE '✓ idx_knowledge_base_embedding_hnsw: m=16, ef_construction=64';
  END IF;
END $$;

-- =============================================================================
-- Section 5: Supporting Indexes Verification (US3)
-- =============================================================================

\echo ''
\echo 'Section 5: Supporting Indexes (US3)'
\echo '-------------------------------------'

SELECT 
  tablename,
  COUNT(*) AS index_count
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('content_items', 'knowledge_base', 'clusters', 'sources')
GROUP BY tablename
ORDER BY tablename;

-- Show key indexes
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
    'idx_content_items_status',
    'idx_content_items_published_at',
    'idx_clusters_trust_badge',
    'idx_sources_name_trgm'
  )
ORDER BY indexname;

-- =============================================================================
-- Section 6: Partition Infrastructure Verification (US4)
-- =============================================================================

\echo ''
\echo 'Section 6: Partition Infrastructure (US4)'
\echo '------------------------------------------'

SELECT 
  proname AS function_name,
  pg_get_function_arguments(oid) AS arguments,
  pg_get_function_result(oid) AS return_type
FROM pg_proc
WHERE proname IN ('create_weekly_partitions', 'check_partition_coverage')
ORDER BY proname;

-- Test partition creation function (dry run)
\echo 'Testing create_weekly_partitions() dry run...'
SELECT * FROM create_weekly_partitions('content_items', 4);

-- Check view exists
SELECT viewname, definition
FROM pg_views
WHERE viewname = 'v_partition_status';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'create_weekly_partitions') THEN
    RAISE NOTICE '✓ create_weekly_partitions function exists';
  ELSE
    RAISE WARNING '! create_weekly_partitions function missing';
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_partition_coverage') THEN
    RAISE NOTICE '✓ check_partition_coverage function exists';
  ELSE
    RAISE WARNING '! check_partition_coverage function missing';
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_views WHERE viewname = 'v_partition_status') THEN
    RAISE NOTICE '✓ v_partition_status view exists';
  ELSE
    RAISE WARNING '! v_partition_status view missing';
  END IF;
END $$;

-- =============================================================================
-- Section 7: Flyway Migration History
-- =============================================================================

\echo ''
\echo 'Section 7: Migration History'
\echo '-----------------------------'

SELECT 
  version,
  description,
  success,
  installed_on
FROM flyway_schema_history
WHERE version ~ '^[0-9]+$'
ORDER BY installed_rank;

-- =============================================================================
-- Summary
-- =============================================================================

\echo ''
\echo '==================================================================='
\echo 'VALIDATION COMPLETE'
\echo '==================================================================='
