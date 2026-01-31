# Tenancy Naming (DB-per-tenant)

This project uses a DB-per-tenant isolation model.

## Terms
- **tenant_slug**: lowercase, alphanumeric plus hyphen. Example: `acme`, `tenant-001`.
- **env**: one of `dev`, `beta`, `prod`.

## Naming formulas
Use these deterministic names across infrastructure, workflows, and code.

### PostgreSQL database
- **Name:** `${tenant_slug}_nura_${env}`
- **Examples:**
  - `tenant-001_nura_dev`
  - `tenant-001_nura_prod`

### Azure AI Search index
- **Name:** `${tenant_slug}-nura-${env}`
- **Examples:**
  - `tenant-001-nura-dev`
  - `tenant-001-nura-prod`

### Blob storage container
- **Name:** `${tenant_slug}-nura-${env}`
- **Rules:** must be lowercase; hyphens allowed.

## Notes
- Keep `tenant_slug` stable over time; treat it as an identifier.
- Never embed secrets in names.
