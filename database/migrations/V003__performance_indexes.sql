SET search_path = public;

-- Partial indexes for status-driven polling
CREATE INDEX IF NOT EXISTS idx_content_ingest_pending_partial
    ON content(ingested_at DESC, source_id)
    WHERE ingest_status IN ('pending', 'processing');

CREATE INDEX IF NOT EXISTS idx_content_analysis_review_partial
    ON content(ingested_at DESC)
    WHERE analysis_status IN ('failed', 'needs_review');

CREATE INDEX IF NOT EXISTS idx_content_analysis_active_partial
    ON content(source_id, ingested_at DESC)
    WHERE analysis_status IN ('pending', 'processing');

CREATE INDEX IF NOT EXISTS idx_embeddings_sync_pending_partial
    ON embeddings_sync(target_type, target_id)
    WHERE sync_status = 'pending';

CREATE INDEX IF NOT EXISTS idx_analysis_log_status_partial
    ON analysis_log(agent_name, started_at DESC)
    WHERE status IN ('running', 'failed');

-- JSONB / array-heavy columns
CREATE INDEX IF NOT EXISTS idx_sources_config_gin
    ON sources USING gin(config jsonb_path_ops);

CREATE INDEX IF NOT EXISTS idx_ingestion_log_error_details_gin
    ON ingestion_log USING gin(error_details);

CREATE INDEX IF NOT EXISTS idx_claim_verifications_evidence_gin
    ON claim_verifications USING gin(evidence);

CREATE INDEX IF NOT EXISTS idx_claim_verifications_counter_evidence_gin
    ON claim_verifications USING gin(counter_evidence);