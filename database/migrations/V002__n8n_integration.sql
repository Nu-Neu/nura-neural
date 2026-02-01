SET search_path = public;

-- Ensure workflow execution tracking exists
ALTER TABLE ingestion_log
    ADD COLUMN IF NOT EXISTS workflow_execution_id VARCHAR(100);

ALTER TABLE analysis_log
    ADD COLUMN IF NOT EXISTS workflow_execution_id VARCHAR(100);

-- Indexes supporting n8n hot paths
CREATE INDEX IF NOT EXISTS idx_content_external_id ON content(external_id);
CREATE INDEX IF NOT EXISTS idx_content_url ON content(url);
CREATE INDEX IF NOT EXISTS idx_content_analysis_pending
    ON content(analysis_status, ingested_at)
    WHERE analysis_status = 'pending';
CREATE INDEX IF NOT EXISTS idx_claims_created_en
    ON claims(created_at DESC)
    WHERE claim_text_en IS NOT NULL;

-- Optimized query surfaces
CREATE OR REPLACE VIEW vw_pending_content_for_analysis AS
SELECT
    c.content_id,
    c.source_id,
    c.title,
    c.content_text,
    c.language,
    c.text_direction,
    c.url,
    c.published_at,
    c.ingest_status,
    c.analysis_status,
    c.ingested_at,
    s.identifier AS source_identifier,
    s.name AS source_name,
    s.country AS source_country,
    s.credibility_tier AS source_tier,
    se_last.evaluated_at AS source_last_evaluated
FROM content c
LEFT JOIN sources s ON c.source_id = s.source_id
LEFT JOIN LATERAL (
    SELECT se.evaluated_at
    FROM source_evaluations se
    WHERE se.source_id = s.source_id
      AND se.is_current = true
    ORDER BY se.evaluated_at DESC
    LIMIT 1
) se_last ON true
WHERE c.analysis_status = 'pending';

CREATE OR REPLACE VIEW vw_unclustered_claims AS
SELECT
    cl.claim_id,
    cl.content_id,
    cl.claim_text,
    cl.claim_text_en,
    cl.language,
    cl.claim_type,
    cl.confidence,
    cl.subject_text,
    c.source_id,
    s.credibility_tier AS source_tier,
    c.published_at,
    cl.created_at
FROM claims cl
JOIN content c ON cl.content_id = c.content_id
LEFT JOIN sources s ON c.source_id = s.source_id
LEFT JOIN claim_narratives cn ON cl.claim_id = cn.claim_id
WHERE cn.claim_id IS NULL
  AND cl.claim_text_en IS NOT NULL
  AND char_length(cl.claim_text_en) > 20;

CREATE OR REPLACE VIEW vw_content_duplicate_lookup AS
SELECT
    content_id,
    source_id,
    content_type,
    external_id,
    url,
    canonical_url,
    ingest_status,
    analysis_status,
    is_duplicate,
    duplicate_of_id,
    ingested_at
FROM content;