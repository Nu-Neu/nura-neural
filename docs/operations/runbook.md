---
doc_type: operations
version: 1.0
last_updated: 2026-02-04
owner: Nura Neural Team
status: approved
---

# Operations Runbook

## 1. Overview

**Purpose:** This runbook provides a centralized guide for common operational tasks, emergency procedures, and health checks for the Nura Neural platform.

**Audience:** On-call engineers, DevOps, and administrators.

**Scope:** Covers the entire production environment, including Azure Container Apps, PostgreSQL, and Azure AI Search.

---

## 2. Emergency Contacts

| Role | Name | Slack | Availability |
|------|------|-------|--------------|
| **Primary On-Call** | Amir | `@amir` | 24/7 |
| **DB Specialist** | Reyhaneh | `@reyhaneh` | Mon-Fri 9-5 |
| **DevOps Lead** | Sina | `@sina` | Mon-Fri 9-5 |
| **Escalation** | Product Owner | `@owner` | Business Hours |

---

## 3. Common Operational Procedures

### 3.1 Restarting a Service

**Use Case:** A container app (e.g., `n8n`) is unresponsive or logging errors.

**Procedure:**
1.  Navigate to the Azure Portal > `irdecode-prod-rg` > `irdecode-container-env`.
2.  Select the container app (e.g., `irdecode-prod-n8n`).
3.  Go to the "Revisions" blade.
4.  Select the latest active revision and click "Restart".

**PowerShell Command:**
```powershell
# Ensure you are logged into Azure
az containerapp revision restart --name irdecode-prod-n8n --resource-group irdecode-prod-rg
```

### 3.2 Manually Triggering a Database Migration

**Use Case:** A migration failed during a CI/CD run and needs to be applied manually.

**Prerequisites:**
- Azure PIM access activated (`Contributor` role).
- Local machine IP added to the PostgreSQL firewall rules.

**Procedure:**
1.  Open a PowerShell terminal.
2.  Navigate to the project's `scripts` directory.
3.  Run the migration script:
    ```powershell
    .\db_migrate.ps1
    ```

### 3.3 Re-indexing Azure AI Search

**Use Case:** The search index is out of sync with the PostgreSQL database or has become corrupted. This is a **destructive** operation.

**Procedure:**
1.  **Delete the existing index:**
    ```powershell
    # scripts/rebuild-search-index.ps1
    Invoke-RestMethod -Method DELETE -Uri "https://irdecode-prod-search.search.windows.net/indexes/nura-items?api-version=2023-11-01" -Headers @{"api-key" = $env:AZURE_SEARCH_ADMIN_KEY}
    ```
2.  **Re-create the index from Terraform:**
    ```powershell
    # /infrastructure
    terraform apply -target=azurerm_search_index.items_index
    ```
3.  **Trigger the full sync workflow:**
    - Manually run the `WF-05-pg-to-ai-search-sync` workflow in the n8n UI with the `FULL_SYNC` parameter set to `true`.

---

## 4. Alert Responses

### Alert: `High CPU Usage on n8n Container`

- **Threshold:** >80% for 5 minutes.
- **Cause:** Likely an infinite loop in a workflow or processing a very large data payload.
- **Action:**
    1.  Check the n8n "Executions" log to identify the stuck workflow.
    2.  Cancel the execution.
    3.  If the container remains at high CPU, restart it (see section 3.1).

### Alert: `Database Storage > 90%`

- **Threshold:** PostgreSQL storage is approaching its limit.
- **Cause:** The data archival/cleanup workflow (`WF-06-daily-cleanup`) has failed.
- **Action:**
    1.  Manually trigger the `WF-06-daily-cleanup` workflow.
    2.  If it fails, investigate the logs.
    3.  As a temporary fix, connect to the DB and manually run `DELETE FROM items WHERE created_at < NOW() - INTERVAL '90 days';`.
    4.  If the issue persists, scale up the database storage via the Azure Portal (requires downtime).

### Alert: `AI Search Storage > 80%`

- **Threshold:** The Free Tier AI Search index is nearing its 50 MB limit.
- **Cause:** The 14-day retention policy is not being enforced correctly by the sync workflow.
- **Action:**
    1.  Trigger the `WF-05-pg-to-ai-search-sync` workflow. It should automatically remove documents older than 14 days.
    2.  If that fails, run the re-indexing procedure (see section 3.3) as a last resort.
