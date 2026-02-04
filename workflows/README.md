# Nura Neural Workflows

This directory contains n8n workflow definitions that implement the core business logic for the Nura Intelligence Platform MVP v2.0.

## Workflow-First Architecture

The Nura platform follows a **workflow-first** design where all business logic is orchestrated by n8n running in Azure Container Apps. The workflows defined here implement the complete data pipeline from ingestion to presentation.

## Workflows Overview

### WF1: Content Ingestion Pipeline (`WF1_Ingestion.json`)
- **Purpose**: Automated content collection from RSS feeds (via Miniflux) and Twitter API v2
- **Schedule**: Every 30 minutes
- **Requirements**: REQ-ING-001, REQ-ING-002, REQ-ING-003, REQ-ING-004
- **Key Functions**:
  - Poll Miniflux for unread RSS items
  - Poll Twitter API for recent tweets from monitored accounts
  - Deduplicate using URL hash + SimHash (Hamming distance ≤6)
  - Archive raw HTML to Azure Blob Storage (`nura-content` container)
  - Insert new items to PostgreSQL with `status=PENDING`
- **Cost**: $0.00/day (no LLM calls)

### WF2: AI Enrichment Pipeline (`WF2_Enrichment.json`)
- **Purpose**: AI-powered translation, metadata extraction, and vector embedding generation
- **Trigger**: Database trigger when `items.status = PENDING`
- **Requirements**: REQ-AI-ML-002, REQ-AI-ML-003, REQ-AI-ML-005
- **Key Functions**:
  - Translate Farsi/Arabic content to English using GPT-4o
  - Extract structured metadata (author, entities, dateline, sentiment)
  - Generate 3072-dimensional embeddings using `text-embedding-3-small`
  - Update item record with enriched data, set `status=ENRICHED`
- **Cost**: ~$0.60/day (60k tokens @ $0.01/1k)

### WF3: Trust Scoring Pipeline (`WF3_Trust_Scoring.json`)
- **Purpose**: Calculate transparent 5-component trust scores (0-95 scale)
- **Trigger**: Database trigger when `items.status = ENRICHED`
- **Requirements**: REQ-AI-001, REQ-AI-002, REQ-AI-003
- **Key Functions**:
  - **Component 1**: Source Credibility (lookup `base_score` from `source_profiles`)
  - **Component 2**: Content Quality (analyze byline, dateline, citations)
  - **Component 3**: Corroboration (vector search for similar HIGH trust items)
  - **Component 4**: Freshness (age penalty: 0-5 days = 0, >10 days = -10)
  - **Component 5**: Consistency (check contradictions with HIGH trust sources)
  - Generate template-based explanations (no LLM)
  - Store breakdown in `trust_signals` table
- **Cost**: $0.00/day (no LLM calls)

### WF4: Narrative Clustering Pipeline (`WF4_Narrative_Clustering.json`)
- **Purpose**: Group semantically related items into narratives
- **Trigger**: Database trigger when `items.trust_score` is set
- **Requirements**: REQ-AI-004, REQ-AI-ML-006, REQ-AI-ML-007
- **Key Functions**:
  - Vector search within 14-day window (cosine similarity ≥ 0.75)
  - Strong match (≥0.85): Immediate assignment to existing narrative
  - Moderate match (≥0.75): Check for ≥2 shared entities
  - Create new narrative if no match found
  - Generate AI title (6-10 words) and summary (2-3 sentences) using GPT-4
  - Update `narratives` table with metadata
- **Cost**: ~$0.30/day (LLM for titles/summaries)

### WF5: State Proxy Detection (`WF5_Proxy_Detection.json`)
- **Purpose**: Identify INDIE_MEDIA/CITIZEN_JOURNALIST sources that are state-controlled
- **Schedule**: Weekly batch job (Sunday 00:00 UTC)
- **Requirements**: REQ-AI-005
- **Key Functions**:
  - **Component 1** (30%): Content Overlap (SimHash similarity ≥90% with REGIME_MEDIA)
  - **Component 2** (30%): Narrative Alignment (shared narratives without contradiction)
  - **Component 3** (20%): Amplification Network (MVP: 0, Phase 2 only)
  - **Component 4** (20%): Technical Overlap (MVP: 0, Phase 2 only)
  - Calculate ProxyScore (0-100)
  - Auto-reclassify if ProxyScore ≥ 70 (set `type=PROXY_SUSPECTED`, `base_score=20`)
  - Generate LLM explanation for team review
  - Log to `proxy_audits` table
  - Send weekly email report
- **Cost**: ~$0.10/month (LLM for explanations only)

### WF6: System Monitoring & Cost Control (`WF6_Monitoring.json`)
- **Purpose**: Monitor system health, costs, and performance
- **Schedule**: Daily (00:00 UTC)
- **Requirements**: REQ-NF-001, REQ-NF-002
- **Key Functions**:
  - Track daily Azure OpenAI spend (target: < $1.00/day)
  - Monitor processing backlog (target: < 100 `PENDING` items)
  - Calculate error rates (target: < 5%)
  - Send CRITICAL alerts if thresholds exceeded:
    - Daily spend > $1.00
    - Backlog > 500 items
    - Error rate > 5%
  - Emergency action: Pause WF1 ingestion if backlog > 1000 items
  - Log metrics to database
- **Cost**: $0.00/day (monitoring only)

## Deployment

Workflows are deployed to the `irdecode-prod-n8n` Azure Container App using the import script:

```powershell
.\scripts\import-n8n-workflows.ps1
```

**Prerequisites**:
- Active PIM access to `irdecode-prod-rg` resource group (verify with `.\scripts\check-azure-access.ps1`)
- n8n API credentials stored in Azure Key Vault (`irdecode-prod-kv`)

## Credentials

Workflow credentials (API keys, database connection strings) are managed separately in `CREDENTIALS.json` and deployed using:

```powershell
.\scripts\import-n8n-credentials.ps1
```

**Never commit `CREDENTIALS.json`** to version control. The file contains:
- PostgreSQL connection string
- Azure OpenAI API key
- Azure Blob Storage SAS token
- Miniflux API key
- Twitter API credentials

## Development Notes

1. **Workflow IDs**: The JSON files use placeholder node positions and connections. When imported into n8n, the platform assigns unique IDs and establishes connections based on node names.

2. **Testing**: Use the n8n web UI to test individual workflows before activating them in production. Mock data can be injected using the `test-workflow-mock.ps1` script.

3. **Monitoring**: All workflows log execution details to n8n's internal database. Use the n8n UI or query the database directly to debug issues.

4. **Cost Optimization**: The workflows are designed to minimize LLM API calls:
   - WF1 (Ingestion): No LLM
   - WF2 (Enrichment): Batched translation/metadata extraction
   - WF3 (Trust Scoring): Template-based explanations (no LLM)
   - WF4 (Narrative Clustering): LLM only for new narrative titles/summaries
   - WF5 (Proxy Detection): LLM only for team reports (weekly)
   - WF6 (Monitoring): No LLM

5. **Error Handling**: Each workflow implements retry logic with exponential backoff. Failed executions are logged to n8n's error queue for manual review.

## References

- [Nura SRS MVP v2.0](../docs/nura_srs_mvp_v2.0.md)
- [n8n Documentation](https://docs.n8n.io/)
- [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/)
