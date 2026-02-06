-- =============================================================================
-- Nura - WF01 Content Items State Support
-- Version: V009
-- Date: 2026-02-06
--
-- Purpose:
--   Add state machine support for WF01 Ingestion & Translation workflow.
--   - Add TRANSLATING and INGESTED states to content_processing_status enum
--   - Add needs_translation flag for retry queue
--   - Add indexes for WF01 critical path queries
--
-- Notes:
--   - SQL-only (Flyway-compatible). No psql meta-commands.
--   - Append-only migration; do not edit once applied.
-- =============================================================================

-- =============================================================================
-- ENUM UPDATES
-- =============================================================================

-- Add TRANSLATING state (WF01 in-progress translation)
ALTER TYPE content_processing_status ADD VALUE IF NOT EXISTS 'TRANSLATING' AFTER 'PENDING';

-- Add INGESTED state (WF01 complete, ready for WF02 embedding)
ALTER TYPE content_processing_status ADD VALUE IF NOT EXISTS 'INGESTED' AFTER 'TRANSLATING';

-- =============================================================================
-- COLUMN ADDITIONS
-- =============================================================================

-- Add needs_translation flag for retry queue
-- Items that failed translation are flagged for later retry
ALTER TABLE content_items
  ADD COLUMN IF NOT EXISTS needs_translation BOOLEAN NOT NULL DEFAULT false;

-- =============================================================================
-- INDEXES FOR WF01 CRITICAL PATH
-- =============================================================================

-- Deduplication lookup (WF01 critical path)
-- Used by Node 4 (PostgreSQL Dedupe Check) to filter already-processed items
CREATE INDEX IF NOT EXISTS idx_content_items_external_id 
  ON content_items(external_id);

-- Processing queue lookup (for retry)
-- Used to find items that need translation retry
CREATE INDEX IF NOT EXISTS idx_content_items_needs_translation 
  ON content_items(needs_translation) 
  WHERE needs_translation = true;

-- Processing status + ingested_at for WF01 monitoring queries
-- Used to track items processed in recent time windows
CREATE INDEX IF NOT EXISTS idx_content_items_status_ingested
  ON content_items(processing_status, ingested_at DESC);

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON COLUMN content_items.needs_translation IS 
  'Flag for WF01 retry queue. Set to true when translation fails after max retries.';
