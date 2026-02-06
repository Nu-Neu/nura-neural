-- V013__wf02_schema_additions.sql
-- WF02 Embedding, RAG Cache & Clustering schema additions
-- Feature: 004-wf02-embedding-clustering
-- Date: 2026-02-06

-- ============================================================================
-- 1. Add columns to content_items table
-- ============================================================================

-- Add novelty_score column for delta detection results
ALTER TABLE content_items 
ADD COLUMN IF NOT EXISTS novelty_score NUMERIC(3,2);

COMMENT ON COLUMN content_items.novelty_score IS 'Delta detection result: 0.00 = complete duplicate, 1.00 = entirely novel. Threshold for significant novelty: >= 0.20';

-- ============================================================================
-- 2. Add columns to clusters table
-- ============================================================================

-- Add needs_reanalysis flag for re-trigger conditions
ALTER TABLE clusters 
ADD COLUMN IF NOT EXISTS needs_reanalysis BOOLEAN DEFAULT false;

COMMENT ON COLUMN clusters.needs_reanalysis IS 'Set to true when Tier 1 source joins or volume spikes >50%. Consumed by WF03 analysis workflow.';

-- Add last_updated_at for velocity calculations
ALTER TABLE clusters 
ADD COLUMN IF NOT EXISTS last_updated_at TIMESTAMPTZ DEFAULT NOW();

COMMENT ON COLUMN clusters.last_updated_at IS 'Timestamp of last item addition, used for hourly velocity calculation in re-trigger logic.';

-- ============================================================================
-- 3. Create narrative_groups table
-- ============================================================================

CREATE TABLE IF NOT EXISTS narrative_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_cluster_id UUID NOT NULL REFERENCES clusters(id) ON DELETE CASCADE,
    grouping_rationale TEXT NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_cluster_display_order UNIQUE (parent_cluster_id, display_order)
);

COMMENT ON TABLE narrative_groups IS 'Organizes clusters for narrative view display (US-B5). Created by WF02.';
COMMENT ON COLUMN narrative_groups.grouping_rationale IS 'AI-generated explanation for why items are grouped together.';
COMMENT ON COLUMN narrative_groups.display_order IS 'Sort order for UI rendering within the parent cluster view.';

-- Index for efficient cluster lookup
CREATE INDEX IF NOT EXISTS idx_narrative_groups_cluster 
ON narrative_groups (parent_cluster_id);

-- ============================================================================
-- 4. Create HNSW index for knowledge_base.embedding_vector
-- ============================================================================

-- Check if index already exists before creating
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'idx_knowledge_base_embedding_hnsw'
    ) THEN
        CREATE INDEX idx_knowledge_base_embedding_hnsw
        ON knowledge_base USING hnsw (embedding_vector vector_cosine_ops)
        WITH (m = 16, ef_construction = 64);
        
        RAISE NOTICE 'Created HNSW index on knowledge_base.embedding_vector';
    ELSE
        RAISE NOTICE 'Index idx_knowledge_base_embedding_hnsw already exists';
    END IF;
END $$;

COMMENT ON INDEX idx_knowledge_base_embedding_hnsw IS 'HNSW index for RAG cache similarity lookup at >= 0.92 threshold. Tuned for ~10k entries.';

-- ============================================================================
-- 5. Create partial index for clusters.needs_reanalysis
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_clusters_needs_reanalysis
ON clusters (needs_reanalysis)
WHERE needs_reanalysis = true;

COMMENT ON INDEX idx_clusters_needs_reanalysis IS 'Partial index for WF03 to efficiently find clusters needing re-analysis.';

-- ============================================================================
-- 6. Create partial index for clusters.expires_at
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_clusters_expires_at_active
ON clusters (expires_at)
WHERE expires_at > NOW();

COMMENT ON INDEX idx_clusters_expires_at_active IS 'Partial index for efficient lookup of active (non-expired) clusters in WF02 cluster matching.';

-- ============================================================================
-- 7. Add valid state values for WF02 transitions
-- ============================================================================

-- Update the state check constraint if it exists, or add new valid states
-- WF02 states: ready_for_embedding, embedding_generated, clustered, rag_cache_hit, embedding_failed

DO $$
BEGIN
    -- Check if constraint exists and drop it
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'content_items_state_check'
    ) THEN
        ALTER TABLE content_items DROP CONSTRAINT content_items_state_check;
    END IF;
    
    -- Add new constraint with all valid WF02 states
    ALTER TABLE content_items 
    ADD CONSTRAINT content_items_state_check 
    CHECK (state IN (
        'pending',
        'ingested', 
        'translated',
        'ready_for_embedding',
        'embedding_generated',
        'clustered',
        'rag_cache_hit',
        'embedding_failed',
        'analyzed',
        'published',
        'archived'
    ));
    
    RAISE NOTICE 'Updated content_items state check constraint with WF02 states';
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Could not update state constraint: %', SQLERRM;
END $$;

-- ============================================================================
-- 8. Helper function for representative item scoring
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_representative_score(
    p_source_tier INTEGER,
    p_content_length INTEGER,
    p_engagement_count INTEGER DEFAULT 0
) RETURNS NUMERIC AS $$
DECLARE
    v_credibility_score NUMERIC;
    v_completeness_score NUMERIC;
    v_engagement_score NUMERIC;
BEGIN
    -- Source credibility (50% weight): Tier 1 = 1.0, Tier 2 = 0.7, Tier 3 = 0.4
    v_credibility_score := CASE p_source_tier
        WHEN 1 THEN 1.0
        WHEN 2 THEN 0.7
        WHEN 3 THEN 0.4
        ELSE 0.3
    END;
    
    -- Content completeness (30% weight): normalized by length (max 10000 chars)
    v_completeness_score := LEAST(p_content_length::NUMERIC / 10000.0, 1.0);
    
    -- Engagement (20% weight): normalized (max 100000)
    v_engagement_score := LEAST(p_engagement_count::NUMERIC / 100000.0, 1.0);
    
    -- Weighted combination
    RETURN ROUND(
        (v_credibility_score * 0.50) + 
        (v_completeness_score * 0.30) + 
        (v_engagement_score * 0.20), 
        4
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calculate_representative_score IS 'Calculates weighted score for selecting cluster representative item. Used by WF02 US-B6.';

-- ============================================================================
-- Verification queries (run manually after migration)
-- ============================================================================

-- SELECT column_name FROM information_schema.columns 
-- WHERE table_name = 'content_items' AND column_name = 'novelty_score';

-- SELECT column_name FROM information_schema.columns 
-- WHERE table_name = 'clusters' AND column_name IN ('needs_reanalysis', 'last_updated_at');

-- SELECT indexname FROM pg_indexes 
-- WHERE indexname IN ('idx_knowledge_base_embedding_hnsw', 'idx_clusters_needs_reanalysis', 'idx_clusters_expires_at_active');

-- SELECT table_name FROM information_schema.tables WHERE table_name = 'narrative_groups';

-- SELECT proname FROM pg_proc WHERE proname = 'calculate_representative_score';
