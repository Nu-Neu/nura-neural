# n8n Configuration Guide for Nura Neural

This guide walks you through setting up n8n with all required credentials and workflows for the Nura Neural pipeline.

---

## Table of Contents

1. [Access n8n](#1-access-n8n)
2. [Quick Start with Scripts](#2-quick-start-with-scripts)
3. [Setup Azure Key Vault Secrets](#3-setup-azure-key-vault-secrets)
4. [Import Credentials](#4-import-credentials)
5. [Import Workflows](#5-import-workflows)
6. [Manual Credential Setup](#6-manual-credential-setup)
7. [Configure Workflow Connections](#7-configure-workflow-connections)
8. [Activate Workflows](#8-activate-workflows)
9. [Verify Everything Works](#9-verify-everything-works)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Access n8n

### n8n Instance URL

```
https://api.irdecode.com
```

> **Note**: This is the default URL configured in the import scripts.

### Login

1. Open the n8n URL in your browser
2. Login with your admin credentials
3. If this is the first time, you may need to set up an owner account

### Enable API Access (for script imports)

1. Go to **Settings** → **API**
2. Click **Create API Key**
3. Copy the API key for use with import scripts
4. Store this key securely using one of these methods:
   - **Azure Key Vault** (recommended): Store as secret named `n8n-api-key`
   - **Environment Variable**: Set `N8N_API_KEY` in your environment

---

## 2. Quick Start with Scripts

For automated setup, use the provided PowerShell scripts in this order:

```powershell
cd D:\Project\Nura\scripts

# Step 1: Setup secrets in Azure Key Vault (interactive)
.\setup-keyvault-secrets.ps1 -KeyVaultName "nura-kv"

# Step 2: Import credentials from Key Vault to n8n
.\import-n8n-credentials.ps1 -KeyVaultName "nura-kv"

# Step 3: Import and activate workflows
.\import-n8n-workflows.ps1 -KeyVaultName "nura-kv" -Activate
```

> **Prerequisites**:
> - Azure PowerShell module: `Install-Module -Name Az.KeyVault -Scope CurrentUser`
> - Logged in to Azure: `Connect-AzAccount`
> - Access to the Key Vault with secret read/write permissions

---

## 3. Setup Azure Key Vault Secrets

### Using the Setup Script (Recommended)

The `setup-keyvault-secrets.ps1` script provides an interactive way to populate all required secrets.

```powershell
cd D:\Project\Nura\scripts
.\setup-keyvault-secrets.ps1 -KeyVaultName "nura-kv"
```

The script will prompt you for each credential group:

| Group | Secrets |
|-------|---------|
| **n8n API** | `n8n-api-key` |
| **OpenAI** | `openai-api-key` |
| **Azure OpenAI** | `azure-openai-api-key`, `azure-openai-resource`, `azure-openai-api-version` |
| **PostgreSQL** | `postgres-host`, `postgres-database`, `postgres-user`, `postgres-password`, `postgres-port` |
| **Slack** | `slack-bot-token`, `slack-webhook-url` |
| **Supabase** | `supabase-url`, `supabase-service-key` |
| **Redis** | `redis-host`, `redis-password`, `redis-port` |
| **Vector Databases** | `pinecone-api-key`, `qdrant-url`, `qdrant-api-key` |

### Manual Key Vault Setup

If you prefer to set secrets manually:

```powershell
# Login to Azure
Connect-AzAccount

# Set individual secrets
$secretValue = ConvertTo-SecureString "your-api-key" -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName "nura-kv" -Name "openai-api-key" -SecretValue $secretValue
```

### Required Secret Names Reference

| Secret Name | Description | Required For |
|-------------|-------------|--------------|
| `n8n-api-key` | n8n API key for script authentication | All scripts |
| `openai-api-key` | OpenAI API key | OpenAI credential |
| `azure-openai-api-key` | Azure OpenAI API key | Azure OpenAI credential |
| `azure-openai-resource` | Azure OpenAI resource name | Azure OpenAI credential |
| `postgres-host` | PostgreSQL server hostname | PostgreSQL credential |
| `postgres-database` | Database name | PostgreSQL credential |
| `postgres-user` | Database username | PostgreSQL credential |
| `postgres-password` | Database password | PostgreSQL credential |
| `slack-bot-token` | Slack Bot OAuth token | Slack credential |
| `slack-webhook-url` | Slack webhook URL | Slack Webhook credential |

---

## 4. Import Credentials

### Using the Import Script (Recommended)

The `import-n8n-credentials.ps1` script reads credentials from Azure Key Vault and imports them into n8n.

#### Basic Usage

```powershell
cd D:\Project\Nura\scripts

# Import credentials from Key Vault
.\import-n8n-credentials.ps1 -KeyVaultName "nura-kv"

# Preview what would be imported (dry run)
.\import-n8n-credentials.ps1 -KeyVaultName "nura-kv" -DryRun
```

#### With Custom n8n URL

```powershell
.\import-n8n-credentials.ps1 `
    -KeyVaultName "nura-kv" `
    -N8nUrl "https://custom-n8n.example.com"
```

#### With Explicit API Key

```powershell
.\import-n8n-credentials.ps1 `
    -KeyVaultName "nura-kv" `
    -ApiKey "your-n8n-api-key"
```

### Script Parameters Reference

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-KeyVaultName` | (required) | Azure Key Vault name containing secrets |
| `-N8nUrl` | `https://api.irdecode.com` | n8n instance URL |
| `-ApiKey` | (none) | Explicit n8n API key (optional) |
| `-ApiKeySecretName` | `n8n-api-key` | Secret name for n8n API key in Key Vault |
| `-DryRun` | `$false` | Preview without making changes |

### Supported Credential Types

The script automatically creates these n8n credential types:

| Credential Name | n8n Type | Key Vault Secrets Used |
|-----------------|----------|------------------------|
| OpenAI | `openAiApi` | `openai-api-key` |
| PostgreSQL Nura | `postgres` | `postgres-host`, `postgres-database`, `postgres-user`, `postgres-password`, `postgres-port` |
| Slack | `slackApi` | `slack-bot-token` |
| Slack Webhook | `slackWebhookApi` | `slack-webhook-url` |
| Azure OpenAI | `azureOpenAiApi` | `azure-openai-api-key`, `azure-openai-resource`, `azure-openai-api-version` |
| Supabase | `supabaseApi` | `supabase-url`, `supabase-service-key` |
| Redis | `redis` | `redis-host`, `redis-password`, `redis-port` |
| Pinecone | `pineconeApi` | `pinecone-api-key` |
| Qdrant | `qdrantApi` | `qdrant-url`, `qdrant-api-key` |

### What the Script Does

1. **Connects to Azure Key Vault** - Authenticates and verifies access
2. **Fetches n8n API key** - From Key Vault or parameter
3. **Retrieves existing credentials** - Checks what's already in n8n
4. **For each credential type**:
   - Reads required secrets from Key Vault
   - Skips if secrets are missing
   - Creates new credential or updates existing one
5. **Reports summary** - Shows created, updated, skipped, and failed counts

### Example Output

```
╔══════════════════════════════════════════════════════════════╗
║         NURA NEURAL - N8N CREDENTIAL IMPORTER                ║
╚══════════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════════
  Importing Credentials from Key Vault
═══════════════════════════════════════════════════════════════

  Processing: OpenAI (openAiApi)
    ✓ apiKey (from: openai-api-key)
    ✅ Created: OpenAI (ID: 12)

  Processing: PostgreSQL Nura (postgres)
    ✓ host (from: postgres-host)
    ✓ database (from: postgres-database)
    ✓ user (from: postgres-user)
    ✓ password (from: postgres-password)
    ✓ port (from: postgres-port)
    ✅ Created: PostgreSQL Nura (ID: 13)

═══════════════════════════════════════════════════════════════
  Import Summary
═══════════════════════════════════════════════════════════════
  Credentials created: 2
  Credentials updated: 0
  Credentials skipped: 8
  Failed imports:      0
```

---

## 5. Import Workflows

### Using the Import Script (Recommended)

The `import-n8n-workflows.ps1` script imports workflow JSON files into n8n.

#### Method 1: Azure Key Vault (Most Secure)

```powershell
cd D:\Project\Nura\scripts

# Import using Azure Key Vault for API key
.\import-n8n-workflows.ps1 -KeyVaultName "nura-kv" -Activate

# With custom secret name
.\import-n8n-workflows.ps1 -KeyVaultName "nura-kv" -ApiKeySecretName "my-n8n-api-key" -Activate
```

#### Method 2: Environment Variable

```powershell
# Set environment variable (one-time setup)
$env:N8N_API_KEY = "your-n8n-api-key"

# Or set permanently for user
[Environment]::SetEnvironmentVariable("N8N_API_KEY", "your-api-key", "User")

# Run script (will auto-detect environment variable)
.\import-n8n-workflows.ps1 -Activate
```

Supported environment variable names:
- `N8N_API_KEY`
- `N8N_APIKEY`
- `NURA_N8N_API_KEY`

#### Method 3: Direct API Key (Development Only)

```powershell
# Import all workflows with explicit API key
.\import-n8n-workflows.ps1 -ApiKey "your-n8n-api-key" -Activate

# With custom URL
.\import-n8n-workflows.ps1 `
    -N8nUrl "https://custom-n8n-instance.com" `
    -ApiKey "your-n8n-api-key"
```

> ⚠️ **Warning**: Avoid using explicit API keys in scripts or command history for production environments.

#### Method 4: Basic Authentication

```powershell
.\import-n8n-workflows.ps1 `
    -Username "admin" `
    -Password "your-password" `
    -Activate
```

### Script Parameters Reference

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-N8nUrl` | `https://api.irdecode.com` | n8n instance URL |
| `-ApiKey` | (none) | Explicit API key |
| `-KeyVaultName` | (none) | Azure Key Vault name |
| `-ApiKeySecretName` | `n8n-api-key` | Secret name in Key Vault |
| `-Username` | (none) | Basic auth username |
| `-Password` | (none) | Basic auth password |
| `-WorkflowDir` | `../workflows` | Workflow JSON directory |
| `-Activate` | `$false` | Auto-activate workflows |
| `-DryRun` | `$false` | Preview without making changes |

### Dry Run Mode

Preview what would be imported without making changes:

```powershell
.\import-n8n-workflows.ps1 -KeyVaultName "nura-kv" -DryRun
```

### Workflows Imported

The script imports these workflows in order:

| File | Workflow Name |
|------|---------------|
| `01_ingestion.json` | WF-01: Ingestion Pipeline |
| `02_agent_source.json` | WF-02: Agent 1 - IMTT Evaluation |
| `03_agent_narrative.json` | WF-03: Agent 2 - Narrative Clustering |
| `04_escalation.json` | WF-04: Escalation Handler |
| `05_public_api.json` | WF-05: Public API Endpoints |

### Option B: Manual Import via UI

1. Go to **Workflows** in n8n
2. Click the **+** button → **Import from File**
3. Select workflow files in order from `workflows/` directory
4. For each imported workflow, verify the name matches expected names

---

## 6. Manual Credential Setup

If you prefer to create credentials manually in the n8n UI, navigate to **Credentials** in the left sidebar.

### 6.1 PostgreSQL - Nura

| Field | Value |
|-------|-------|
| **Credential Name** | `PostgreSQL Nura` |
| **Host** | `irdecode-prod-psql.postgres.database.azure.com` |
| **Port** | `5432` |
| **Database** | `nura` |
| **User** | `<from Key Vault: postgres-user>` |
| **Password** | `<from Key Vault: postgres-password>` |
| **SSL** | `require` (must enable) |

**Test**: Click "Test Connection" - should show "Connection successful"

### 6.2 Azure OpenAI

| Field | Value |
|-------|-------|
| **Credential Name** | `Azure OpenAI` |
| **API Type** | `Azure` |
| **API Key** | `<from Key Vault: azure-openai-api-key>` |
| **Resource Name** | `irdecode-prod-openai` |
| **API Version** | `2024-02-15-preview` |

### 6.3 Azure AI Search (HTTP Header Auth)

| Field | Value |
|-------|-------|
| **Credential Name** | `Azure AI Search` |
| **Credential Type** | HTTP Header Auth |
| **Header Name** | `api-key` |
| **Header Value** | `<from Key Vault: nura-search-api-key>` |

### 6.4 Miniflux API (HTTP Header Auth)

| Field | Value |
|-------|-------|
| **Credential Name** | `Miniflux API` |
| **Credential Type** | HTTP Header Auth |
| **Header Name** | `X-Auth-Token` |
| **Header Value** | `<generated from Miniflux UI>` |

**To generate Miniflux API key:**
1. Open Miniflux: `https://nura-miniflux.<your-aca-domain>.azurecontainerapps.io`
2. Login with admin credentials
3. Go to **Settings** → **API Keys**
4. Click **Create a new API key**
5. Copy the generated key

### 6.5 Redis

| Field | Value |
|-------|-------|
| **Credential Name** | `Nura Redis` |
| **Host** | `nura-redis` |
| **Port** | `6379` |
| **Password** | (leave empty - internal network) |
| **Database** | `0` |

---

## 7. Configure Workflow Connections

After import, each workflow needs credentials assigned (if not automatically matched):

### WF-01: Ingestion Pipeline

| Node | Credential |
|------|------------|
| Miniflux Get Unread | `Miniflux API` |
| PostgreSQL - Check Duplicate | `PostgreSQL Nura` |
| PostgreSQL - Insert Content | `PostgreSQL Nura` |
| PostgreSQL - Log Ingestion | `PostgreSQL Nura` |

### WF-02: Agent 1 - IMTT Evaluation

| Node | Credential |
|------|------------|
| PostgreSQL - Get Pending | `PostgreSQL Nura` |
| GPT-4o IMTT Evaluation | `Azure OpenAI` |
| GPT-4o Content Analysis | `Azure OpenAI` |
| PostgreSQL - Store Evaluation | `PostgreSQL Nura` |
| PostgreSQL - Store Claims | `PostgreSQL Nura` |

### WF-03: Agent 2 - Narrative Clustering

| Node | Credential |
|------|------------|
| PostgreSQL - Get Unclustered | `PostgreSQL Nura` |
| OpenAI Embeddings | `Azure OpenAI` |
| Azure AI Search - Upsert | `Azure AI Search` |
| Azure AI Search - Vector Search | `Azure AI Search` |
| GPT-4o Narrative Label | `Azure OpenAI` |
| PostgreSQL - Upsert Narrative | `PostgreSQL Nura` |
| PostgreSQL - Link Claims | `PostgreSQL Nura` |

### WF-05: Public API Endpoints

| Node | Credential |
|------|------------|
| Redis - Check Cache | `Nura Redis` |
| Redis - Set Cache | `Nura Redis` |
| PostgreSQL - Get Source | `PostgreSQL Nura` |
| PostgreSQL - Get Narratives | `PostgreSQL Nura` |

---

## 8. Activate Workflows

### Activation Order

Activate workflows in this order to ensure dependencies work:

1. **WF-05: Public API Endpoints** (always running - webhook triggers)
2. **WF-01: Ingestion Pipeline** (schedule trigger - every 15 min)
3. **WF-02: Agent 1 - IMTT Evaluation** (webhook + schedule)
4. **WF-03: Agent 2 - Narrative Clustering** (schedule - every 6 hours)

### How to Activate

1. Open the workflow
2. Toggle the **Active** switch in the top-right corner
3. Confirm when prompted

### Verify Activation

- Active workflows show a green status indicator
- Check **Executions** tab to see scheduled runs

---

## 9. Verify Everything Works

### Test 1: Database Connectivity

```sql
-- Run in n8n PostgreSQL node (test mode)
SELECT COUNT(*) FROM sources;
SELECT COUNT(*) FROM content;
```

### Test 2: Miniflux API

1. Open WF-01 in editor
2. Click the Miniflux node
3. Click **Execute Node**
4. Should return unread entries (or empty array if no feeds)

### Test 3: Public API Endpoints

```bash
# Test health endpoint
curl "https://api.irdecode.com/webhook/health"

# Test credibility endpoint
curl "https://api.irdecode.com/webhook/credibility?domain=bbc.com"

# Test narratives endpoint
curl "https://api.irdecode.com/webhook/narratives"
```

### Test 4: Manual Workflow Execution

1. Open WF-01: Ingestion Pipeline
2. Click **Execute Workflow**
3. Monitor the execution progress
4. Check for any errors in nodes

### Test 5: Check Logs

In n8n, go to **Executions** to view:
- Recent workflow runs
- Execution times
- Success/failure status
- Error details (click on failed execution)

---

## 10. Troubleshooting

### Script-Related Issues

#### "Az.KeyVault module not installed"

```powershell
# Install the required module
Install-Module -Name Az.KeyVault -Scope CurrentUser -Force
```

#### "Not logged into Azure"

```powershell
# Login to Azure
Connect-AzAccount

# Or use device code flow
Connect-AzAccount -UseDeviceAuthentication
```

#### "Cannot access Key Vault"

**Causes:**
1. Key Vault doesn't exist
2. No access permissions
3. Wrong Key Vault name

**Solution:**
```powershell
# Verify Key Vault exists
Get-AzKeyVault -VaultName "nura-kv"

# Grant yourself access if needed (requires Owner role)
Set-AzKeyVaultAccessPolicy -VaultName "nura-kv" `
    -UserPrincipalName "your@email.com" `
    -PermissionsToSecrets get,list,set
```

#### "n8n API key not found"

**Solution:**
1. Create API key in n8n UI: **Settings** → **API** → **Create API Key**
2. Store in Key Vault:
   ```powershell
   $secret = ConvertTo-SecureString "your-n8n-api-key" -AsPlainText -Force
   Set-AzKeyVaultSecret -VaultName "nura-kv" -Name "n8n-api-key" -SecretValue $secret
   ```

### Common n8n Issues

#### "Connection refused" for PostgreSQL

```
Error: Connection refused at irdecode-prod-psql.postgres.database.azure.com:5432
```

**Solution:**
1. Verify the PostgreSQL firewall allows Azure services
2. Check SSL is set to `require`
3. Verify username/password are correct

#### "401 Unauthorized" for Azure OpenAI

```
Error: 401 - Invalid subscription key
```

**Solution:**
1. Verify API key is correct
2. Check the Azure OpenAI resource name matches
3. Ensure the API version is supported

#### "Index not found" for Azure AI Search

```
Error: Index 'nura-claims' not found
```

**Solution:**
```powershell
# Create the indexes
cd D:\Project\Nura\infrastructure
.\create-search-indexes.ps1
```

#### Miniflux returns empty results

**Causes:**
1. No RSS feeds configured in Miniflux
2. All items are already marked as read
3. API key is invalid

**Solution:**
1. Add feeds to Miniflux (see OPML import below)
2. Mark some items as unread for testing
3. Regenerate API key

#### Workflow not triggering on schedule

**Solution:**
1. Verify workflow is **Active** (green indicator)
2. Check the schedule trigger configuration
3. Look for timezone issues (n8n uses UTC)

### Debug Mode

To enable detailed logging:

1. Set environment variable: `N8N_LOG_LEVEL=debug`
2. View container logs:
   ```bash
   az containerapp logs show --name irdecode-prod-n8n --resource-group irdecode-prod-rg --follow
   ```

### Support Resources

- [n8n Documentation](https://docs.n8n.io/)
- [n8n Community Forum](https://community.n8n.io/)
- Check `docs/n8n-workflow-specifications.md` for detailed node specs

---

## Quick Reference: Scripts Summary

| Script | Purpose | Command |
|--------|---------|---------|
| `setup-keyvault-secrets.ps1` | Interactive setup of Key Vault secrets | `.\setup-keyvault-secrets.ps1 -KeyVaultName "nura-kv"` |
| `import-n8n-credentials.ps1` | Import credentials from Key Vault to n8n | `.\import-n8n-credentials.ps1 -KeyVaultName "nura-kv"` |
| `import-n8n-workflows.ps1` | Import workflow JSON files to n8n | `.\import-n8n-workflows.ps1 -KeyVaultName "nura-kv" -Activate` |

## Quick Reference: Credential IDs

When importing workflows, these credential IDs are expected:

| Credential ID | Credential Name | Type |
|---------------|-----------------|------|
| `nura-postgres` | PostgreSQL Nura | postgres |
| `azure-openai` | Azure OpenAI | openAiApi |
| `ai-search-auth` | Azure AI Search | httpHeaderAuth |
| `miniflux-auth` | Miniflux API | httpHeaderAuth |
| `nura-redis` | Nura Redis | redis |

If your credential IDs differ, update the workflow JSON files or re-assign credentials in the UI.

---

## Quick Reference: Environment Variables

For automated deployments, set these environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `N8N_API_KEY` | n8n API key for authentication | `n8n_api_xxx...` |
| `N8N_URL` | n8n instance URL (optional) | `https://api.irdecode.com` |

---

*Last updated: February 2025*