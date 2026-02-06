# Nura Neural (Nu-Neu)

A neural network project.

## Status
- Work in progress — see docs/PRD.md for product requirements and planned features.

## Quick start
- Prerequisites: Docker, PowerShell (for some scripts), Flyway (used in CI via Docker).
- Apply DB migrations and run smoke checks:
  - Run the scripts in scripts/ (see database/migrations/README.md).
  - CI runs a migrations smoke test automatically on PRs that touch database/** or scripts/db_*.ps1.

## CI / Workflows
- <a href="https://github.com/Nu-Neu/nura-neural/actions/workflows/migrations-smoke.yml"><img src="https://github.com/Nu-Neu/nura-neural/actions/workflows/migrations-smoke.yml/badge.svg"></a>
  - Purpose: Apply and smoke-test DB migrations against a postgres:16 service using Flyway.
  - Triggers: pull_request and push on main when database/** or scripts/db_*.ps1 change.
- <a href="https://github.com/Nu-Neu/nura-neural/actions/workflows/repo-hygiene.yml"><img src="https://github.com/Nu-Neu/nura-neural/actions/workflows/repo-hygiene.yml/badge.svg"></a>
  - Purpose: Fail when forbidden sensitive or generated artifacts (tfstate, .env, private keys) are tracked.
  - Triggers: runs on all pull_request and push to main.
- <a href="https://github.com/Nu-Neu/nura-neural/actions/workflows/terraform-validate.yml"><img src="https://github.com/Nu-Neu/nura-neural/actions/workflows/terraform-validate.yml/badge.svg"></a>
  - Purpose: Run terraform fmt, init (no backend), and validate inside infrastructure/.
  - Triggers: pull_request and push to main when infrastructure/** changes.

## Project index (top-level)
- README.md
- docs/
  - PRD.md
- database/
  - schema.sql
  - migrations/
    - README.md
    - V001__baseline.sql
- scripts/
  - db_bootstrap_baseline_migration.ps1
  - db_migrate.ps1
  - db_smokecheck.ps1
- infrastructure/
  - Terraform configs
- .github/
  - workflows/
    - migrations-smoke.yml
    - repo-hygiene.yml
    - terraform-validate.yml
- LICENSE (if present)
- CONTRIBUTING.md (if present)

## Repository structure notes
- Database migrations are SQL-first and versioned in database/migrations (Flyway style).
- CI is path-filtered to run only relevant workflows for database and infrastructure changes.
- repo-hygiene protects against committing secrets/artifacts.

## Contributing
- Please open issues or PRs. Follow the repo-hygiene checks before committing (avoid tracking secrets/terraform state).
- Add new migrations as V{N}__{description}.sql; do not edit applied migrations.

## References
- Documentation: docs/PRD.md
- DB migrations: database/migrations/README.md

## Contact / Maintainers
- Repo: https://github.com/Nu-Neu/nura-neural
- Maintainers: (add maintainers / contact details here)
