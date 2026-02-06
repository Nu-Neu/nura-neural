# Database migrations (SQL-first)

This project uses SQL-first migrations for PostgreSQL.

## Tooling
Recommended: Flyway (simple versioned SQL).

## Directory layout
- `database/schema.sql`: baseline reference schema (human-readable)
- `database/migrations/`: Flyway migrations (source of truth)

## Baseline migration
This repo keeps a minimal `V001__baseline.sql` in `database/migrations/` to establish migration history.

If it’s missing (e.g., in a fresh checkout), you can generate it:
- `powershell -File scripts/db_bootstrap_baseline_migration.ps1`

## Applying migrations
- Local (requires Docker):
  - Set environment variables: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
  - Run: `powershell -File scripts/db_migrate.ps1`

## Versioning policy
- Migrations are append-only.
- Never edit an applied migration; create a new one instead.
- Use `V{N}__{description}.sql` where `{N}` increments by 1.
