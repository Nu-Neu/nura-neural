# ADR-0001: SQL-first migrations (Flyway)

**Status:** Accepted  
**Date:** 2026-02-01

## Context
The project has a monolithic PostgreSQL schema in database/schema.sql and needs a repeatable, versioned migration workflow suitable for local development on Windows and CI.

## Decision
Adopt a SQL-first migration approach using Flyway-compatible versioned SQL files in database/migrations/.

## Consequences
- Migrations are append-only and become the source of truth.
- Local and CI workflows can apply migrations consistently.
- Rollbacks are handled by forward-fixing (or rebuilding non-prod DBs), rather than editing applied migrations.

## Notes
- Baseline migration is generated from database/schema.sql via scripts/db_bootstrap_baseline_migration.ps1.
- Secrets are provided via environment variables or secret store injection; never committed.
