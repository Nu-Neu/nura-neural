-- =============================================================================
-- Migration: V012 - Partition Infrastructure
-- Feature: 003-db-foundation-schema (US4)
-- Date: 2026-02-06
--
-- Purpose:
--   Create partition management functions and monitoring view for future
--   weekly partitioning of content_items table.
--
-- Notes:
--   - This migration does NOT convert existing tables to partitioned
--   - Creates infrastructure for when partitioning is enabled (separate feature)
--   - Functions safely check if table is partitioned before operating
--   - ISO week format: YYYY_wWW (e.g., 2026_w06)
-- =============================================================================

-- =============================================================================
-- T014: Partition Creation Function
-- =============================================================================

CREATE OR REPLACE FUNCTION create_weekly_partitions(
  p_table_name TEXT DEFAULT 'content_items',
  p_weeks_ahead INT DEFAULT 8
)
RETURNS TABLE(
  partition_name TEXT,
  week_start DATE,
  week_end DATE,
  created BOOLEAN
) AS $$
DECLARE
  w_start DATE;
  w_end DATE;
  p_name TEXT;
  already_exists BOOLEAN;
  is_partitioned BOOLEAN;
BEGIN
  -- Check if parent table exists and is partitioned
  SELECT EXISTS (
    SELECT 1 FROM pg_partitioned_table pt
    JOIN pg_class c ON pt.partrelid = c.oid
    WHERE c.relname = p_table_name
  ) INTO is_partitioned;
  
  FOR i IN 0..p_weeks_ahead LOOP
    -- Calculate ISO week boundaries (Monday start)
    w_start := date_trunc('week', CURRENT_DATE + (i * INTERVAL '1 week'))::DATE;
    w_end := (w_start + INTERVAL '1 week')::DATE;
    
    -- Generate partition name: tablename_YYYY_wWW
    p_name := p_table_name || '_' || to_char(w_start, 'YYYY_"w"IW');
    
    -- Check if partition already exists
    SELECT EXISTS (
      SELECT 1 FROM pg_class WHERE relname = p_name
    ) INTO already_exists;
    
    -- Create partition only if parent is partitioned and partition doesn't exist
    IF is_partitioned AND NOT already_exists THEN
      EXECUTE format(
        'CREATE TABLE %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
        p_name, p_table_name, w_start, w_end
      );
      already_exists := FALSE;  -- Mark as newly created
    ELSE
      -- If already exists, keep the flag true
      -- If parent not partitioned, skip creation
      NULL;
    END IF;
    
    -- Return planned partition info (whether created or planned)
    partition_name := p_name;
    week_start := w_start;
    week_end := w_end;
    created := is_partitioned AND NOT already_exists;
    RETURN NEXT;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION create_weekly_partitions(TEXT, INT) IS 
  'Creates weekly partitions for a date-partitioned table. Safe to call if table is not yet partitioned. Call via n8n workflow or cron.';

-- =============================================================================
-- T015: Partition Coverage Check Function
-- =============================================================================

CREATE OR REPLACE FUNCTION check_partition_coverage(p_table_name TEXT DEFAULT 'content_items')
RETURNS TABLE(
  partition_name TEXT,
  range_start TIMESTAMPTZ,
  range_end TIMESTAMPTZ,
  row_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    child.relname::TEXT AS partition_name,
    (regexp_match(
      pg_get_expr(child.relpartbound, child.oid), 
      'FOR VALUES FROM \(''(.+)''\) TO'
    ))[1]::TIMESTAMPTZ AS range_start,
    (regexp_match(
      pg_get_expr(child.relpartbound, child.oid), 
      'TO \(''(.+)''\)'
    ))[1]::TIMESTAMPTZ AS range_end,
    COALESCE(
      (SELECT reltuples::BIGINT FROM pg_class WHERE relname = child.relname),
      0
    ) AS row_count
  FROM pg_inherits
  JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
  JOIN pg_class child ON pg_inherits.inhrelid = child.oid
  WHERE parent.relname = p_table_name
  ORDER BY range_start;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION check_partition_coverage(TEXT) IS 
  'Returns partition coverage and estimated row counts for monitoring. Returns empty if table is not partitioned.';

-- =============================================================================
-- T016: Partition Status View
-- =============================================================================

CREATE OR REPLACE VIEW v_partition_status AS
SELECT 
  c.relname AS partition_name,
  pg_get_expr(c.relpartbound, c.oid) AS bounds,
  pg_relation_size(c.oid) AS size_bytes,
  pg_size_pretty(pg_relation_size(c.oid)) AS size_pretty,
  COALESCE(s.n_live_tup, 0) AS row_estimate,
  COALESCE(s.n_dead_tup, 0) AS dead_tuples,
  COALESCE(s.last_vacuum, '-infinity'::timestamptz) AS last_vacuum,
  COALESCE(s.last_analyze, '-infinity'::timestamptz) AS last_analyze
FROM pg_class p
JOIN pg_inherits i ON p.oid = i.inhparent
JOIN pg_class c ON i.inhrelid = c.oid
LEFT JOIN pg_stat_user_tables s ON s.relname = c.relname
WHERE p.relname = 'content_items'
ORDER BY c.relname;

COMMENT ON VIEW v_partition_status IS 
  'Dashboard view for content_items partition monitoring. Shows size, row counts, and maintenance stats.';

-- =============================================================================
-- Validation: Verify functions and view created
-- =============================================================================

DO $$
BEGIN
  -- Verify create_weekly_partitions exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'create_weekly_partitions'
  ) THEN
    RAISE EXCEPTION 'create_weekly_partitions function not created';
  END IF;
  RAISE NOTICE 'create_weekly_partitions function: OK';
  
  -- Verify check_partition_coverage exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'check_partition_coverage'
  ) THEN
    RAISE EXCEPTION 'check_partition_coverage function not created';
  END IF;
  RAISE NOTICE 'check_partition_coverage function: OK';
  
  -- Verify v_partition_status view exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_views WHERE viewname = 'v_partition_status'
  ) THEN
    RAISE EXCEPTION 'v_partition_status view not created';
  END IF;
  RAISE NOTICE 'v_partition_status view: OK';
  
  RAISE NOTICE 'V012 migration validated successfully';
END $$;

-- =============================================================================
-- Test: Dry run of partition creation (will show planned partitions)
-- =============================================================================

-- Uncomment to test:
-- SELECT * FROM create_weekly_partitions('content_items', 8);
