-- Quick verification query for MVP v2.0 schema
-- Run this in Cloud Shell to verify migration success

\echo 'Checking MVP v2.0 Schema Status...'

-- Check ENUMs
SELECT 'ENUMs Status:' as check_type;
SELECT typname as enum_name
FROM pg_type
WHERE typcategory = 'E' 
  AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND typname IN ('source_class', 'source_subclass', 'content_type', 'language_code', 'trust_level', 'processing_status', 'narrative_topic_type')
ORDER BY typname;

-- Check Tables
SELECT 'Tables Status:' as check_type;
SELECT table_name, 
       (SELECT COUNT(*) FROM information_schema.columns WHERE columns.table_name = tables.table_name) as column_count
FROM information_schema.tables
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE'
  AND table_name IN ('source_profiles', 'narratives', 'items', 'trust_signals')
ORDER BY table_name;

-- Check Extensions
SELECT 'Extensions Status:' as check_type;
SELECT extname as extension_name, extversion as version
FROM pg_extension
WHERE extname IN ('uuid-ossp', 'vector', 'pg_trgm')
ORDER BY extname;

-- Check Indexes on items table (should include vector index)
SELECT 'Items Table Indexes:' as check_type;
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'items'
ORDER BY indexname;

\echo 'Verification Complete!'
\echo 'Expected Results:'
\echo '  • 7 ENUMs (source_class, source_subclass, content_type, language_code, trust_level, processing_status, narrative_topic_type)'
\echo '  • 4 Tables (source_profiles, narratives, items, trust_signals)'
\echo '  • 3 Extensions (uuid-ossp, vector, pg_trgm)'
\echo '  • items table should have vector index (idx_items_embedding)'
