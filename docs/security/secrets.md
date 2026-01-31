# Secrets & Sensitive Data Handling

## What is considered a secret
- Database usernames/passwords and full connection strings
- API keys (Search, LLM providers, external ingestion APIs)
- Private keys, certificates, and signing material

## Rules
- Do not commit secrets to the repository.
- Do not commit Terraform state, plans, or tfvars containing secrets.
- Prefer managed secret storage and identity-based access where possible.

## Terraform-specific guidance
- Terraform state may contain sensitive values even when variables/outputs are marked `sensitive`.
- Use a secure remote backend for state.
- Avoid storing long-lived secrets in Terraform-managed resources when practical; source them from secret storage.

## Local development
- Use `.env` (ignored) or your local secret store.
- Provide non-secret examples via `*.example` files.

## Rotation
- Treat any secret that has ever been committed (including in state/plan files) as compromised.
- Rotate:
  - Database passwords
  - Admin keys (e.g., search keys)
  - External ingestion API keys
- Record rotation date/time and affected environments.
