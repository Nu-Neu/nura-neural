# Environments

This project uses three environments:
- `dev`: fastest iteration; may be reset.
- `beta`: pre-release validation.
- `prod`: production.

## Configuration contract
Use environment variables (or secret store injection) for secrets.

### Required DB variables
- `DB_HOST`
- `DB_PORT` (default 5432)
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`

### Recommended non-secret variables
- `ENV` (`dev` | `beta` | `prod`)
- `TENANT_SLUG`

## Mapping to tenancy naming
- DB name, search index name, and blob container name must follow docs/tenancy/naming.md.

## Local development
- Use a local `.env` (ignored) or your OS secret store.
- Never commit `.env` or `terraform.tfvars` with secrets.
