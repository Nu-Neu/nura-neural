-- =============================================================================
-- Nura Neural - Additional Tables for Monitoring & Proxy Detection
-- Version: V006
-- Date: February 4, 2026
-- 
-- Purpose: Add tables required by WF5 (Proxy Detection) and WF6 (Monitoring)
-- These tables were identified as missing from V005 MVP schema
-- =============================================================================

-- =============================================================================
-- TABLE: proxy_audits
-- Purpose: Track proxy detection analysis results (REQ-AI-005)
-- Used by: WF5_Proxy_Detection (weekly batch job)
-- =============================================================================

CREATE TABLE proxy_audits (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id               UUID NOT NULL REFERENCES source_profiles(id) ON DELETE CASCADE,
    
    -- ProxyScore Components
    proxy_score             FLOAT NOT NULL CHECK (proxy_score >= 0 AND proxy_score <= 1),
    content_overlap_score   FLOAT NOT NULL CHECK (content_overlap_score >= 0 AND content_overlap_score <= 1),
    narrative_align_score   FLOAT NOT NULL CHECK (narrative_align_score >= 0 AND narrative_align_score <= 1),
    amplification_score     FLOAT DEFAULT 0 CHECK (amplification_score >= 0 AND amplification_score <= 1),  -- Phase 2
    tech_overlap_score      FLOAT DEFAULT 0 CHECK (tech_overlap_score >= 0 AND tech_overlap_score <= 1),    -- Phase 2
    
    -- Evidence & Results
    evidence                JSONB DEFAULT '{}'::jsonb,
    action_taken            VARCHAR(50) NOT NULL CHECK (action_taken IN ('reclassified', 'flagged_review', 'none')),
    previous_base_score     INTEGER,
    new_base_score          INTEGER,
    
    -- LLM-generated explanation for team review
    explanation             TEXT,
    
    -- Metadata
    analysis_window_days    INTEGER DEFAULT 90,
    items_analyzed          INTEGER DEFAULT 0,
    regime_items_compared   INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_proxy_audits_source ON proxy_audits(source_id);
CREATE INDEX idx_proxy_audits_created ON proxy_audits(created_at DESC);
CREATE INDEX idx_proxy_audits_action ON proxy_audits(action_taken) WHERE action_taken != 'none';
CREATE INDEX idx_proxy_audits_score ON proxy_audits(proxy_score DESC) WHERE proxy_score >= 0.4;

COMMENT ON TABLE proxy_audits IS 'Weekly proxy detection audit results (REQ-AI-005)';
COMMENT ON COLUMN proxy_audits.proxy_score IS 'Composite score: 0.30*content + 0.30*narrative + 0.20*amplification + 0.20*tech';
COMMENT ON COLUMN proxy_audits.action_taken IS 'reclassified (>=70), flagged_review (40-69), none (<40)';

-- =============================================================================
-- TABLE: monitoring_logs
-- Purpose: Track daily cost and performance metrics (REQ-OPS-001, REQ-OPS-002)
-- Used by: WF6_Monitoring (daily + every 6 hours)
-- =============================================================================

CREATE TABLE monitoring_logs (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    log_date                DATE NOT NULL,
    log_hour                INTEGER CHECK (log_hour >= 0 AND log_hour <= 23),
    
    -- Cost Metrics (USD)
    daily_cost_usd          DECIMAL(10,4) DEFAULT 0,
    translation_cost        DECIMAL(10,4) DEFAULT 0,
    embedding_cost          DECIMAL(10,4) DEFAULT 0,
    narrative_cost          DECIMAL(10,4) DEFAULT 0,
    storage_cost            DECIMAL(10,4) DEFAULT 0,
    
    -- Token Usage
    translation_tokens      INTEGER DEFAULT 0,
    embedding_tokens        INTEGER DEFAULT 0,
    narrative_tokens        INTEGER DEFAULT 0,
    
    -- Processing Metrics
    items_ingested          INTEGER DEFAULT 0,
    items_enriched          INTEGER DEFAULT 0,
    items_scored            INTEGER DEFAULT 0,
    items_clustered         INTEGER DEFAULT 0,
    items_pending           INTEGER DEFAULT 0,
    items_failed            INTEGER DEFAULT 0,
    
    -- Performance Metrics
    avg_ingestion_ms        INTEGER,
    avg_enrichment_ms       INTEGER,
    avg_scoring_ms          INTEGER,
    avg_vector_search_ms    INTEGER,
    p95_vector_search_ms    INTEGER,
    
    -- Error Tracking
    error_count             INTEGER DEFAULT 0,
    error_details           JSONB DEFAULT '[]'::jsonb,
    
    -- Alerts
    alert_triggered         BOOLEAN DEFAULT false,
    alert_type              VARCHAR(50),  -- 'WARNING', 'CRITICAL', 'BACKLOG', 'ERROR_RATE'
    alert_action            VARCHAR(100), -- 'notify', 'pause_ingestion', etc.
    
    -- Timestamps
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    
    -- Unique constraint for date+hour combination
    UNIQUE (log_date, log_hour)
);

CREATE INDEX idx_monitoring_logs_date ON monitoring_logs(log_date DESC);
CREATE INDEX idx_monitoring_logs_alerts ON monitoring_logs(alert_triggered) WHERE alert_triggered = true;
CREATE INDEX idx_monitoring_logs_cost ON monitoring_logs(daily_cost_usd DESC) WHERE daily_cost_usd > 0;

COMMENT ON TABLE monitoring_logs IS 'Cost and performance monitoring (REQ-OPS-001, REQ-OPS-002)';
COMMENT ON COLUMN monitoring_logs.log_hour IS 'NULL for daily summary, 0-23 for hourly snapshots';
COMMENT ON COLUMN monitoring_logs.alert_type IS 'WARNING (>$0.80), CRITICAL (>$1.00), BACKLOG (>500), ERROR_RATE (>5%)';

-- =============================================================================
-- TABLE: workflow_state (workflow_health)
-- Purpose: Track workflow health state for circuit breaker pattern (REQ-ING-005)
-- Used by: WF1_Ingestion error handling
-- =============================================================================

CREATE TABLE workflow_state (
    workflow_name           VARCHAR(100) PRIMARY KEY,
    
    -- Circuit Breaker State
    circuit_state           VARCHAR(20) DEFAULT 'closed' CHECK (circuit_state IN ('closed', 'open', 'half-open')),
    consecutive_failures    INTEGER DEFAULT 0,
    last_failure_at         TIMESTAMPTZ,
    circuit_opened_at       TIMESTAMPTZ,
    
    -- Execution Tracking
    last_execution_at       TIMESTAMPTZ,
    last_success_at         TIMESTAMPTZ,
    total_executions        INTEGER DEFAULT 0,
    total_failures          INTEGER DEFAULT 0,
    
    -- Rate Limiting (for Twitter API)
    rate_limit_remaining    INTEGER,
    rate_limit_reset_at     TIMESTAMPTZ,
    
    -- Timestamps
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE workflow_state IS 'Workflow health state for circuit breaker pattern and rate limiting';
COMMENT ON COLUMN workflow_state.circuit_state IS 'closed=healthy, open=unhealthy (5 failures), half-open=recovering';

-- Insert initial state for all workflows
INSERT INTO workflow_state (workflow_name) VALUES
    ('WF1_Ingestion_RSS'),
    ('WF1_Ingestion_Twitter'),
    ('WF2_Enrichment'),
    ('WF3_Trust_Scoring'),
    ('WF4_Narrative_Clustering'),
    ('WF5_Proxy_Detection'),
    ('WF6_Monitoring');

-- =============================================================================
-- FUNCTION: update_workflow_state
-- Purpose: Helper function for updating workflow state
-- =============================================================================

CREATE OR REPLACE FUNCTION update_workflow_state()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_workflow_state_updated
    BEFORE UPDATE ON workflow_state
    FOR EACH ROW
    EXECUTE FUNCTION update_workflow_state();

-- =============================================================================
-- FUNCTION: check_workflow_health
-- Purpose: Check if workflow is healthy and can proceed
-- Returns: true if execution should proceed, false if circuit is open
-- =============================================================================

CREATE OR REPLACE FUNCTION check_workflow_health(p_workflow_name VARCHAR(100))
RETURNS BOOLEAN AS $$
DECLARE
    v_state workflow_state%ROWTYPE;
BEGIN
    SELECT * INTO v_state FROM workflow_state WHERE workflow_name = p_workflow_name;
    
    IF NOT FOUND THEN
        RETURN true; -- No state = allow execution
    END IF;
    
    -- If circuit is open, check if 5 minutes have passed
    IF v_state.circuit_state = 'open' THEN
        IF v_state.circuit_opened_at + interval '5 minutes' < NOW() THEN
            -- Move to half-open state
            UPDATE workflow_state 
            SET circuit_state = 'half-open', updated_at = NOW()
            WHERE workflow_name = p_workflow_name;
            RETURN true;
        ELSE
            RETURN false; -- Still in cooldown
        END IF;
    END IF;
    
    RETURN true; -- Circuit is closed or half-open
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- FUNCTION: record_workflow_failure
-- Purpose: Record a failure and potentially open the circuit
-- =============================================================================

CREATE OR REPLACE FUNCTION record_workflow_failure(p_workflow_name VARCHAR(100), p_error TEXT DEFAULT NULL)
RETURNS VOID AS $$
DECLARE
    v_failures INTEGER;
BEGIN
    UPDATE workflow_state SET
        consecutive_failures = consecutive_failures + 1,
        total_failures = total_failures + 1,
        last_failure_at = NOW(),
        updated_at = NOW()
    WHERE workflow_name = p_workflow_name
    RETURNING consecutive_failures INTO v_failures;
    
    -- Open circuit after 5 consecutive failures
    IF v_failures >= 5 THEN
        UPDATE workflow_state SET
            circuit_state = 'open',
            circuit_opened_at = NOW()
        WHERE workflow_name = p_workflow_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- FUNCTION: record_workflow_success
-- Purpose: Record a successful execution and close circuit if needed
-- =============================================================================

CREATE OR REPLACE FUNCTION record_workflow_success(p_workflow_name VARCHAR(100))
RETURNS VOID AS $$
BEGIN
    UPDATE workflow_state SET
        consecutive_failures = 0,
        circuit_state = 'closed',
        last_execution_at = NOW(),
        last_success_at = NOW(),
        total_executions = total_executions + 1,
        updated_at = NOW()
    WHERE workflow_name = p_workflow_name;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Verification
-- =============================================================================

SELECT 'V006 Migration Complete - Monitoring Tables Created' as status;

SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('proxy_audits', 'monitoring_logs', 'workflow_state')
ORDER BY table_name;
