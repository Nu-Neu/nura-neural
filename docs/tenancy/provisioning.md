# Tenant Provisioning (DB-per-tenant)

This document defines the minimum provisioning workflow for onboarding a new tenant.

## Inputs
- `tenant_slug`
- `env` (`dev` | `beta` | `prod`)

## Outputs
- A tenant database created on the configured PostgreSQL flexible server
- A tenant-specific Azure AI Search index
- A tenant blob container for archives/artifacts
- Secrets stored in the configured secret store (connection strings, API keys)

## Provisioning workflow (manual-first)
1. Create a new PostgreSQL database using the tenancy naming rules.
2. Apply SQL migrations to the new database (baseline migration first).
3. Create the Azure AI Search index for the tenant.
4. Create the blob container for the tenant.
5. Create/update secrets in the secret store for the tenant (DB URL, search keys, etc.).
6. Run smoke checks:
   - DB connectivity
   - Migrations applied
   - Basic read/write access

## Ownership
- Infrastructure: Terraform-managed resources (where applicable)
- Operational steps: onboarding checklist + automated scripts (as they are added)

## Validation checklist
- Names match docs/tenancy/naming.md
- No secrets are written to git-tracked files
- DB schema matches migration history
