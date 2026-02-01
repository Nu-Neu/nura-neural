# n8n Configuration Guide

Step-by-step guide to configure n8n for Nura Neural.

---

## Table of Contents

1. [Access n8n UI](#1-access-n8n-ui)
2. [Create Credentials](#2-create-credentials)
3. [Import Workflows](#3-import-workflows)
4. [Activate Workflows](#4-activate-workflows)
5. [Verify Everything Works](#5-verify-everything-works)

---

## 1. Access n8n UI

### Production URL

```
https://api.irdecode.com
```

### First-Time Login

1. Navigate to `https://api.irdecode.com` in your browser
2. Create an owner account if this is first access
3. Log in with your credentials

### Generate API Key (Required for Scripts)

1. Click **Settings** (gear icon) in the left sidebar
2. Select **API** from the settings menu
3. Click **Create API Key**
4. Copy the generated key
5. Store it in Azure Key Vault:

```powershell
# Connect to Azure first
Connect-AzAccount

# Store the API key
$apiKey = Read-Host -AsSecureString "Enter n8n API key"
Set-AzKeyVaultSecret -VaultName "irdecode-prod-kv" -Name "n8n-api-key" -SecretValue $apiKey
```

---

## 2. Create Credentials

### Option A: Automated Import (Recommended)

Use the PowerShell script to import all credentials from Azure Key Vault:

```powershell
cd D:\Project\Nura\scripts
.\import-n8n-credentials.ps1 -KeyVaultName "irdecode-prod-kv"
```

**Prerequisites:**
- Azure PowerShell module installed: `Install-Module Az.KeyVault -Scope CurrentUser`
- Logged in to Azure: `Connect-AzAccount`
- Key Vault secrets populated (see [Required Secrets](#required-key-vault-secrets))

**Expected Output:**
```
✅ Created credential: Nura PostgreSQL (ID: xxx)
✅ Created credential: Nura Redis (ID: xxx)
✅ Created credential: Azure OpenAI (ID: xxx)
✅ Created credential: Azure AI Search (ID: xxx)
✅ Created credential: Miniflux API (ID: xxx)
✅ Created credential: OpenAI (ID: xxx)
```

### Option B: Manual Creation

If you prefer to create credentials manually in the n8n UI:

#### 2.1 PostgreSQL Credential

1. Go to **Credentials** → **Add Credential**
2. Search for **Postgres**
3. Fill in:
   - **Name**: `Nura PostgreSQL`
   - **Host**: `irdecode-prod-psql.postgres.database.azure.com`
   - **Database**: `irdecode`
   - **User**: `irdecode_admin`
   - **Password**: *(from Key Vault)*
   - **Port**: `5432`
   - **SSL**: ✅ Enabled
4. Click **Save**

#### 2.2 Redis Credential

1. Add new **Redis** credential
2. Fill in:
   - **Name**: `Nura Redis`
   - **Host**: `nura-redis`
   - **Port**: `6379`
   - **Password**: *(from Key Vault)*
   - **SSL**: ✅ Enabled
3. Click **Save**

#### 2.3 Azure OpenAI Credential

1. Add new **OpenAI** credential
2. Fill in:
   - **Name**: `Azure OpenAI`
   - **API Key**: *(from Key Vault: azure-openai-api-key)*
   - **Base URL**: `https://irdecode-prod-openai.openai.azure.com/`
3. Click **Save**

#### 2.4 Azure AI Search Credential

1. Add new **HTTP Header Auth** credential
2. Fill in:
   - **Name**: `Azure AI Search`
   - **Header Name**: `api-key`
   - **Header Value**: *(from Key Vault: azure-search-api-key)*
3. Click **Save**

#### 2.5 Miniflux API Credential

1. Add new **HTTP Header Auth** credential
2. Fill in:
   - **Name**: `Miniflux API`
   - **Header Name**: `X-Auth-Token`
   - **Header Value**: *(from Key Vault: miniflux-api-key)*
3. Click **Save**

#### 2.6 OpenAI Credential

1. Add new **OpenAI** credential
2. Fill in:
   - **Name**: `OpenAI`
   - **API Key**: *(from Key Vault: openai-api-key)*
3. Click **Save**

### Required Key Vault Secrets

| Secret Name | Description |
|-------------|-------------|
| `n8n-api-key` | n8n API key for script authentication |
| `postgres-host` | PostgreSQL server hostname |
| `postgres-database` | Database name |
| `postgres-user` | Database username |
| `postgres-password` | Database password |
| `redis-host` | Redis server hostname |
| `redis-password` | Redis password |
| `azure-openai-api-key` | Azure OpenAI API key |
| `azure-openai-resource` | Azure OpenAI resource name |
| `azure-search-api-key` | Azure AI Search admin key |
| `azure-search-endpoint` | Azure AI Search endpoint URL |
| `miniflux-api-key` | Miniflux RSS API token |
| `openai-api-key` | OpenAI API key |

---

## 3. Import Workflows

### Option A: Automated Import (Recommended)

```powershell
cd D:\Project\Nura\scripts
.\import-n8n-workflows.ps1 -KeyVaultName "irdecode-prod-kv"
```

**Expected Output:**
```
✅ Created: WF-02: Agent 1 - IMTT Source Evaluation (ID: xxx)
✅ Created: WF-03: Agent 2 - Narrative Clustering (ID: xxx)
✅ Created: WF-04: Escalation & Narrative Clustering (ID: xxx)
✅ Created: WF-05: Public API Endpoints (ID: xxx)
```

**Dry Run Mode:**
To preview without making changes:
```powershell
.\import-n8n-workflows.ps1 -KeyVaultName "irdecode-prod-kv" -DryRun
```

### Option B: Manual Import

1. Go to **Workflows** in the left sidebar
2. Click **Add Workflow** → **Import from File**
3. Select workflow files from `workflows/` directory:
   - `01_ingestion.json`
   - `02_agent_source.json`
   - `03_agent_narrative.json`
   - `04_escalation.json`
   - `05_public_api.json`
4. Repeat for each workflow file

### Workflow Descriptions

| File | Workflow Name | Purpose |
|------|---------------|---------|
| `01_ingestion.json` | Content Ingestion | Fetches RSS feeds from Miniflux |
| `02_agent_source.json` | Agent 1 - IMTT Source Evaluation | Evaluates source credibility |
| `03_agent_narrative.json` | Agent 2 - Narrative Clustering | Groups related stories |
| `04_escalation.json` | Escalation & Clustering | Handles priority escalations |
| `05_public_api.json` | Public API Endpoints | Exposes REST API for clients |

---

## 4. Activate Workflows

### Option A: Activate via Script

```powershell
.\import-n8n-workflows.ps1 -KeyVaultName "irdecode-prod-kv" -Activate
```

### Option B: Activate via UI

1. Go to **Workflows** in the left sidebar
2. Find the workflow you want to activate
3. Click on the workflow to open it
4. Toggle the **Active** switch in the top-right corner
5. Confirm activation

### Activation Order

Activate workflows in this order to ensure dependencies are ready:

1. **WF-05: Public API Endpoints** - Exposes webhooks for other workflows
2. **01 - Content Ingestion** - Starts the data pipeline
3. **WF-02: Agent 1 - IMTT Source Evaluation** - Processes ingested content
4. **WF-03: Agent 2 - Narrative Clustering** - Groups evaluated content
5. **WF-04: Escalation & Clustering** - Handles alerts

---

## 5. Verify Everything Works

### 5.1 Check Credentials

1. Go to **Credentials** in the left sidebar
2. Verify all 6 credentials exist:
   - ✅ Nura PostgreSQL
   - ✅ Nura Redis
   - ✅ Azure OpenAI
   - ✅ Azure AI Search
   - ✅ Miniflux API
   - ✅ OpenAI
3. Click each credential and use **Test** button if available

### 5.2 Check Workflows

1. Go to **Workflows** in the left sidebar
2. Verify all 5 workflows exist and are active (green toggle)

### 5.3 Test API Endpoints

Test the Public API workflow webhooks:

```powershell
# Test health endpoint (if configured)
Invoke-RestMethod -Uri "https://api.irdecode.com/webhook/health" -Method GET

# List narratives (example)
Invoke-RestMethod -Uri "https://api.irdecode.com/webhook/narratives" -Method GET
```

### 5.4 Test Database Connection

```powershell
cd D:\Project\Nura\scripts
.\db_smokecheck.ps1 -KeyVaultName "irdecode-prod-kv"
```

### 5.5 Trigger Manual Execution

1. Open **01 - Content Ingestion** workflow
2. Click **Execute Workflow** (play button)
3. Watch the execution flow through nodes
4. Check for any errors (red nodes)

### 5.6 Check Execution Logs

1. Go to **Executions** in the left sidebar
2. Review recent executions
3. Click on any execution to see:
   - Input/output data for each node
   - Timing information
   - Error messages (if any)

---

## Troubleshooting

### Credential Import Fails

**Error:** `400 Bad Request` when importing credentials

**Solution:** The n8n API requires specific boolean fields. The script handles this automatically, but if manually creating:
- PostgreSQL needs: `allowUnauthorizedCerts: false`, `sshTunnel: false`
- Redis needs: `ssl: true`, `disableTlsVerification: true`
- OpenAI needs: `header: false`

### Workflow Import Fails

**Error:** `request/body must NOT have additional properties`

**Solution:** Workflow JSON files may contain extra fields like `staticData`, `tags`, `triggerCount` that n8n API rejects. The import script strips these automatically. If importing manually, edit the JSON to keep only: `name`, `nodes`, `connections`, `settings`.

### Cannot Connect to Database

1. Check PostgreSQL firewall rules allow your IP
2. Verify SSL is enabled for Azure PostgreSQL
3. Test connection string manually:
   ```powershell
   $pass = Get-AzKeyVaultSecret -VaultName "irdecode-prod-kv" -Name "postgres-password" -AsPlainText
   psql "host=irdecode-prod-psql.postgres.database.azure.com dbname=irdecode user=irdecode_admin password=$pass sslmode=require"
   ```

### Workflow Execution Fails

1. Open the failed workflow
2. Click on the red node to see error details
3. Common issues:
   - **Credential not found**: Link the correct credential to the node
   - **Connection timeout**: Check network/firewall settings
   - **Invalid response**: Check API endpoint and parameters

### Need to Re-import

If you need to update workflows after making changes:

```powershell
# The script will update existing workflows with the same name
.\import-n8n-workflows.ps1 -KeyVaultName "irdecode-prod-kv"
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Import credentials | `.\import-n8n-credentials.ps1 -KeyVaultName "irdecode-prod-kv"` |
| Import workflows | `.\import-n8n-workflows.ps1 -KeyVaultName "irdecode-prod-kv"` |
| Import + activate | `.\import-n8n-workflows.ps1 -KeyVaultName "irdecode-prod-kv" -Activate` |
| Dry run | `.\import-n8n-workflows.ps1 -KeyVaultName "irdecode-prod-kv" -DryRun` |
| Test n8n API | `.\test-n8n-api.ps1 -KeyVaultName "irdecode-prod-kv"` |
| Test database | `.\db_smokecheck.ps1 -KeyVaultName "irdecode-prod-kv"` |

---

## Related Documentation

- [n8n Workflow Specifications](n8n-workflow-specifications.md) - Detailed workflow logic
- [Architecture](Architecture.md) - System architecture overview
- [Secrets Management](security/secrets.md) - Key Vault configuration
