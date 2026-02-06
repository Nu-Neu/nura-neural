-- Quick verification query for Core Schema (V008)
-- Run in psql or Cloud Shell after applying migrations

\echo 'Checking Core Schema (V008) Status...'

-- Check key ENUMs
SELECT 'ENUMs Status:' as check_type;
SELECT typname as enum_name
FROM pg_type
WHERE typcategory = 'E'
  AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND typname IN (
    'source_type',
    'source_official_capacity',
    'source_platform',
    'source_audit_status',
    'source_ownership_type',
    'language_code',
    'content_nature',
    'content_type',
    'content_processing_status',
    'cluster_trust_badge',
    'cluster_narrative_pattern',
    'analysis_type',
    'analysis_tone',
    'knowledge_fact_type',
    'knowledge_verification_source',
    'knowledge_created_by'
  )
ORDER BY typname;

-- Check core tables
SELECT 'Tables Status:' as check_type;
SELECT table_name,
       (SELECT COUNT(*) FROM information_schema.columns WHERE columns.table_name = tables.table_name) as column_count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
  AND table_name IN ('sources', 'content_items', 'clusters', 'content_analysis', 'knowledge_base')
ORDER BY table_name;

-- Check extensions
SELECT 'Extensions Status:' as check_type;
SELECT extname as extension_name, extversion as version
FROM pg_extension
WHERE extname IN ('uuid-ossp', 'vector', 'pg_trgm', 'btree_gin')
ORDER BY extname;

\echo 'Verification Complete!'
