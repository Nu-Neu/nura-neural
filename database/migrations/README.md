# Database migrations (SQL-first)

This project uses SQL-first migrations for PostgreSQL.

## Tooling
Recommended: Flyway (simple versioned SQL).

## Directory layout
- `database/schema.sql`: baseline reference schema (human-readable)
- `database/migrations/`: Flyway migrations (source of truth)

## Creating the baseline migration
Run the bootstrap script once to generate `V1__baseline.sql` from `database/schema.sql`:
- `powershell -File scripts/db_bootstrap_baseline_migration.ps1`

## Applying migrations
- Local (requires Docker):
  - Set environment variables:
    - `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
  - Run:
    - `powershell -File scripts/db_migrate.ps1`

## Versioning policy
- Migrations are append-only.
- Never edit an applied migration; create a new one instead.
- Use `V{N}__{description}.sql` where `{N}` increments by 1.
