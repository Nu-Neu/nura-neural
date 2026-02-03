# Copilot Instructions for Nura Neural

## 1. Architecture Overview

The Nura Neural platform is an AI-driven system built on Azure to analyze and score news content. The architecture is **workflow-first**, with core business logic orchestrated by **n8n** running in an Azure Container App.

- **Source of Truth**: All data is stored in an **Azure PostgreSQL Flexible Server**. The schema is managed via SQL-first migrations. See `database/migrations/`.
- **Orchestration**: The `irdecode-prod-n8n` Azure Container App runs the n8n engine, executing workflows defined in `workflows/*.json`.
- **AI Processing**: Workflows call Azure OpenAI (`GPT-5-nano`) for tasks like metadata extraction and `text-embedding-3-small` for generating vector embeddings.
- **Caching**:
    - An `irdecode-prod-redis` container app provides a general-purpose cache.
    - Azure AI Search (`nura-search`) is used as an ephemeral cache for the most recent 14 days of data to power search queries. It is not a source of truth.
- **Infrastructure**: All infrastructure is managed via Terraform in the `infrastructure/` directory.

For a detailed view, see [docs/03-architecture-overview.md](docs/03-architecture-overview.md).

## 2. Critical Developer Workflows

### Azure Access - MANDATORY Pre-Flight Check

**CRITICAL**: Before performing ANY Azure-related operation (deployment, running scripts that access Azure), you **MUST** remind the user to verify their PIM access is active by running:

```powershell
.\scripts\check-azure-access.ps1
```
If it fails, direct them to activate their roles in the Azure portal for the `irdecode-prod-rg` resource group. A quick check is to run `az group show --name irdecode-prod-rg`.

### Database Migrations

The project uses a SQL-first migration approach.

- **To apply migrations**: Run the `db_migrate.ps1` script. This requires elevated Azure permissions and the local IP to be added to the database firewall.
  ```powershell
  .\scripts\db_migrate.ps1
  ```
- **To check DB connectivity**: Use the smoke test script.
  ```powershell
  .\scripts\db_smokecheck.ps1
  ```

### n8n Workflow & Credential Deployment

Workflows (`*.json`) and credentials (`CREDENTIALS.json`) are managed in the repository and deployed via scripts.

- **To deploy all workflows**:
  ```powershell
  .\scripts\import-n8n-workflows.ps1
  ```
- **To deploy credentials**:
  ```powershell
  .\scripts\import-n8n-credentials.ps1
  ```

### Common Operations

Refer to [docs/operations/runbook.md](docs/operations/runbook.md) for common operational tasks, such as:
- Restarting a container app (`az containerapp revision restart`).
- Manually re-indexing Azure AI Search.

## 3. Project Conventions

- **Workflow-First Logic**: Before writing custom code, consider if the logic can be implemented within an n8n workflow. The goal is to keep the compute layer as stateless as possible.
- **Secrets Management**: All secrets are stored in the `irdecode-prod-kv` Azure Key Vault. Services use Managed Identities to access it. Do not place secrets in code or environment variables.
- **Cost Optimization**: The architecture is aggressively cost-optimized. Note the use of burstable (`B2s`) and free tiers. See [docs/operations/finops.md](docs/operations/finops.md) for details.
- **Terraform**: The main infrastructure is defined in `infrastructure/main.tf`. When deploying, use the `infrastructure/deploy.ps1` script.
