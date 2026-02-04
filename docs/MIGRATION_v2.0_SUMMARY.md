# Migration to MVP v2.0 - Summary

**Date**: 2026-02-04  
**Status**: Infrastructure Cleanup Complete, Workflows Scaffolded

## Changes Made

### 1. Removed Deprecated Services ✅

**Deleted**:
- `services/text-extractor/` - Flask service for text extraction using readability
  - **Reason**: MVP v2.0 uses Azure OpenAI (GPT-4o) for metadata extraction and translation instead of dedicated microservices

**Infrastructure Updates**:
- Removed `rsshub` container app from [infrastructure/main.tf](infrastructure/main.tf)
  - **Reason**: SRS REQ-ING-002 mandates Twitter API v2 for direct polling, not RSS bridging
- Removed commented-out `smry` container app definition
  - **Reason**: Never deployed, superseded by LLM-based extraction

**Outputs Cleanup**:
- Removed `rsshub_internal_url` and `smry_internal_url` from [infrastructure/outputs.tf](infrastructure/outputs.tf)

### 2. Added Azure OpenAI Validation ✅

**Infrastructure Changes**:
- Added `data.azurerm_cognitive_account.openai` to [infrastructure/main.tf](infrastructure/main.tf) to validate existence of `irdecode-prod-openai` resource
- Added `existing_openai_account` variable to [infrastructure/variables.tf](infrastructure/variables.tf) (default: `irdecode-prod-openai`)
- Added OpenAI endpoint outputs to [infrastructure/outputs.tf](infrastructure/outputs.tf):
  - `openai_endpoint`: Azure OpenAI endpoint URL
  - `openai_account_name`: Account name for reference

**Purpose**: Ensures Terraform deployment fails early if the required Azure OpenAI resource doesn't exist, preventing silent failures during workflow execution.

### 3. Scaffolded Core Workflows ✅

Created `workflows/` directory with 6 workflow JSON files:

| Workflow | File | Purpose | Schedule | Cost/Day |
|----------|------|---------|----------|----------|
| **WF1** | `WF1_Ingestion.json` | RSS + Twitter ingestion, deduplication | Every 30 min | $0.00 |
| **WF2** | `WF2_Enrichment.json` | Translation, metadata, embeddings | DB trigger | $0.60 |
| **WF3** | `WF3_Trust_Scoring.json` | 5-component trust scores | DB trigger | $0.00 |
| **WF4** | `WF4_Narrative_Clustering.json` | Semantic clustering + AI titles | DB trigger | $0.30 |
| **WF5** | `WF5_Proxy_Detection.json` | State proxy detection | Weekly | $0.003 |
| **WF6** | `WF6_Monitoring.json` | Cost & performance monitoring | Daily | $0.00 |

**Total Target Cost**: ~$0.90/day ($27/month) - within $28/month budget

Each workflow file includes:
- Node structure with placeholders for n8n import
- Inline comments mapping to SRS requirements
- Metadata describing purpose, triggers, and cost targets

Created [workflows/README.md](workflows/README.md) with:
- Architecture overview
- Detailed workflow descriptions
- Deployment instructions
- Cost optimization notes
- Development guidelines

## Next Steps

### Phase 1: Infrastructure Deployment (CRITICAL)

1. **Verify Azure Access**:
   ```powershell
   .\scripts\check-azure-access.ps1
   ```
   - Ensure PIM access is active for `irdecode-prod-rg`
   - Activate roles if needed

2. **Validate Azure OpenAI Resource**:
   ```powershell
   az cognitiveservices account show --name irdecode-prod-openai --resource-group irdecode-prod-rg
   ```
   - If the resource doesn't exist, either:
     - Create it using Azure Portal/CLI
     - Or update `existing_openai_account` variable in `terraform.tfvars`

3. **Deploy Terraform Changes**:
   ```powershell
   cd infrastructure
   .\deploy.ps1
   ```
   - This will:
     - Remove `rsshub` container app
     - Validate OpenAI resource existence
     - Apply updated configuration

### Phase 2: Workflow Implementation (HIGH PRIORITY)

The scaffolded workflow files are **placeholders only**. They define the structure but lack actual n8n node configurations. To complete the workflows:

1. **Import Scaffolds to n8n**:
   ```powershell
   .\scripts\import-n8n-workflows.ps1
   ```

2. **Configure Each Workflow in n8n UI**:
   - Open `https://<n8n-url>` (get URL from Key Vault or deployment outputs)
   - For each workflow:
     - Configure HTTP Request nodes with proper endpoints
     - Set up PostgreSQL nodes with connection credentials
     - Configure Azure OpenAI nodes with API keys
     - Test with mock data using `.\scripts\test-workflow-mock.ps1`

3. **Priority Order**:
   - **WF1 (Ingestion)**: CRITICAL - Must be working to feed data into system
   - **WF2 (Enrichment)**: HIGH - Blocks trust scoring and clustering
   - **WF3 (Trust Scoring)**: HIGH - Core feature
   - **WF4 (Narrative Clustering)**: MEDIUM - Can initially run without AI titles/summaries
   - **WF6 (Monitoring)**: MEDIUM - Important for cost control
   - **WF5 (Proxy Detection)**: LOW - Can be added post-launch

### Phase 3: Database Validation

1. **Apply Latest Migration**:
   ```powershell
   .\scripts\db_migrate.ps1
   ```
   - Ensure `V004__mvp_simplified_schema.sql` is applied
   - Validates 4-table schema (Source Profiles, Items, Narratives, Trust Signals)

2. **Smoke Test**:
   ```powershell
   .\scripts\db_smokecheck.ps1
   ```

### Phase 4: Credentials & Secrets

1. **Deploy Credentials**:
   ```powershell
   .\scripts\import-n8n-credentials.ps1
   ```
   - Ensure `CREDENTIALS.json` is populated (never commit to repo!)

2. **Validate Key Vault Secrets**:
   - `miniflux-api-key`
   - `nura-search-api-key`
   - `nura-twitterapi-io-key`
   - Azure OpenAI API key

## Validation Checklist

Before considering migration complete:

- [ ] Infrastructure deployed successfully (no Terraform errors)
- [ ] Azure OpenAI resource validated
- [ ] `rsshub` and `smry` containers removed from Azure
- [ ] All 6 workflows imported to n8n
- [ ] WF1 (Ingestion) tested with mock data
- [ ] WF2 (Enrichment) tested with mock item
- [ ] WF3 (Trust Scoring) calculates scores correctly
- [ ] Database schema matches SRS v2.0 (4 tables)
- [ ] Credentials deployed to n8n
- [ ] Daily cost monitoring active (WF6)

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Azure OpenAI resource doesn't exist | Terraform deployment fails | Validate manually before `terraform apply` |
| Workflow nodes not properly configured | System non-functional | Use n8n UI to configure and test each workflow |
| Twitter API rate limits exceeded | Ingestion paused | WF6 monitoring will alert; reduce poll frequency |
| Daily costs exceed $1.00 | Budget overrun | WF6 auto-pauses WF1 ingestion; email alert sent |
| Missing credentials | Workflows fail to execute | Run `import-n8n-credentials.ps1` before activation |

## Cost Breakdown (Target vs Actual)

| Component | Target/Day | Notes |
|-----------|-----------|-------|
| WF1 (Ingestion) | $0.00 | No LLM calls |
| WF2 (Enrichment) | $0.60 | 60k tokens @ $0.01/1k |
| WF3 (Trust Scoring) | $0.00 | Template-based |
| WF4 (Clustering) | $0.30 | LLM for titles/summaries |
| WF5 (Proxy Detection) | $0.003 | Weekly, LLM for reports |
| WF6 (Monitoring) | $0.00 | No LLM |
| **Total** | **$0.90/day** | **$27/month** (budget: $28) |

## References

- [SRS MVP v2.0](docs/nura_srs_mvp_v2.0.md)
- [Workflows README](workflows/README.md)
- [Infrastructure README](infrastructure/Readme.md)
- [Database Migrations](database/migrations/README.md)
