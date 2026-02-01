SET search_path = public;

CREATE OR REPLACE FUNCTION get_pending_content(p_limit INTEGER DEFAULT 100)
RETURNS TABLE(
    content_id UUID,
    source_id UUID,
    title TEXT,
    content_text TEXT,
    language language_code,
    text_direction text_direction,
    url TEXT,
    published_at TIMESTAMPTZ,
    ingest_status processing_status,
    analysis_status processing_status,
    ingested_at TIMESTAMPTZ,
    source_identifier VARCHAR(500),
    source_name TEXT,
    source_country VARCHAR(3),
    source_tier credibility_tier,
    source_last_evaluated TIMESTAMPTZ
) LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_limit INTEGER := GREATEST(COALESCE(p_limit, 100), 1);
BEGIN
    RETURN QUERY
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
        s.identifier,
        s.name,
        s.country,
        s.credibility_tier,
        se_last.evaluated_at
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
    WHERE c.analysis_status = 'pending'
    ORDER BY c.ingested_at ASC
    LIMIT v_limit;
END;
$$;

CREATE OR REPLACE FUNCTION check_duplicate(p_hash VARCHAR)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE AS $$
DECLARE
    has_content_hash BOOLEAN;
    sql TEXT;
    duplicate_found BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'content'
          AND column_name = 'content_hash'
    ) INTO has_content_hash;

    IF has_content_hash THEN
        sql := 'SELECT EXISTS (
                   SELECT 1 FROM content
                   WHERE content_hash = $1 OR external_id = $1 OR url = $1
                )';
    ELSE
        sql := 'SELECT EXISTS (
                   SELECT 1 FROM content
                   WHERE external_id = $1 OR url = $1
                )';
    END IF;

    EXECUTE sql INTO duplicate_found USING p_hash;
    RETURN duplicate_found;
END;
$$;

CREATE OR REPLACE FUNCTION get_unclustered_claims(p_hours INTEGER DEFAULT 24)
RETURNS TABLE(
    claim_id UUID,
    content_id UUID,
    claim_text TEXT,
    claim_text_en TEXT,
    language language_code,
    claim_type claim_type,
    confidence FLOAT,
    subject_text VARCHAR(500),
    source_id UUID,
    source_tier credibility_tier,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
) LANGUAGE plpgsql STABLE AS $$
DECLARE
    window_interval INTERVAL := make_interval(hours => GREATEST(COALESCE(p_hours, 24), 1));
BEGIN
    RETURN QUERY
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
        s.credibility_tier,
        c.published_at,
        cl.created_at
    FROM claims cl
    JOIN content c ON cl.content_id = c.content_id
    LEFT JOIN sources s ON c.source_id = s.source_id
    WHERE cl.created_at >= NOW() - window_interval
      AND cl.claim_text_en IS NOT NULL
      AND char_length(cl.claim_text_en) > 20
      AND NOT EXISTS (
          SELECT 1 FROM claim_narratives cn
          WHERE cn.claim_id = cl.claim_id
      )
    ORDER BY cl.created_at DESC;
END;
$$;