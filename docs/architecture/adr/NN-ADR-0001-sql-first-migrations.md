---
doc_type: adr
version: 1.0
last_updated: 2026-02-04
owner: Nura Neural Team
status: approved
---

# NN-ADR-0001: SQL-First Migrations

- **Status**: Accepted
- **Context**: The project requires a repeatable, versioned database migration workflow that works consistently across local development (Windows) and CI/CD environments.
- **Decision**: We will use a SQL-first migration approach. All schema changes will be captured in versioned `.sql` files (e.g., `V001__initial_schema.sql`) stored in the `database/migrations` directory. This format is compatible with tools like Flyway.
- **Consequences**:
  - Database schema changes become version-controlled and auditable.
  - The `database/migrations` folder becomes the single source of truth for the database schema.
  - Rollbacks are handled by creating a new, forward-fixing migration file rather than editing an existing one.
