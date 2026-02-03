# Copilot Instructions for Nura Neural

## Azure Operations - MANDATORY Pre-Flight Check

**CRITICAL**: Before performing ANY Azure-related operation (deployment, infrastructure changes, resource management, Key Vault access, etc.), you MUST:

1. **Remind the user** to verify their Azure access is active:
   ```powershell
   .\scripts\check-azure-access.ps1
   ```

2. **Check that these roles are ACTIVE (not just assigned) on MCPP Subscription:**
   - ✅ Contributor role
   - ✅ Key Vault Secrets Officer (if accessing secrets)

3. **If access fails**, direct user to activate PIM roles:
   - URL: https://portal.azure.com/#view/Microsoft_Azure_PIMCommon/ActivationMenuBlade/~/azurerbac
   - Subscription: MCPP Subscription (`0029263c-cf9e-4e08-b543-2eeea360c7fc`)
   - Resource Group: `irdecode-prod-rg`

4. **Before running Azure CLI commands**, always suggest:
   ```powershell
   # Quick access check
   az group show --name irdecode-prod-rg --query name -o tsv
   ```

## Project Context

- **Repository**: nura-neural
- **Cloud Provider**: Azure (MCPP Subscription)
- **Resource Group**: irdecode-prod-rg
- **Key Vault**: irdecode-prod-kv
- **Infrastructure**: Terraform (see `/infrastructure`)
- **Orchestration**: n8n workflows (see `/workflows`)
- **Database**: PostgreSQL Flexible Server

## Key Scripts

| Script | Purpose |
|--------|---------|
| `scripts/check-azure-access.ps1` | Pre-flight Azure access validation |
| `scripts/db_smokecheck.ps1` | Database connectivity test |
| `scripts/db_migrate.ps1` | Run database migrations |
| `infrastructure/deploy.ps1` | Terraform deployment |

## Standard Workflow

1. Run `check-azure-access.ps1` first
2. If PIM not active → activate via Azure Portal
3. Re-run check to confirm
4. Proceed with Azure operations
