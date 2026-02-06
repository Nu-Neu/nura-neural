# Nura Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-06

## Active Technologies
- SQL (PostgreSQL 16.x), PowerShell 7.x for scripts + pgvector 0.5+, Flyway (SQL migrations) (003-db-foundation-schema)
- PostgreSQL 16 + pgvector on Azure VM (Standard_B2s) (003-db-foundation-schema)
- n8n Workflow (JSON export) + PostgreSQL/pgvector + n8n (Container App), Azure OpenAI, Redis 7, PostgreSQL 16 + pgvector (004-wf02-embedding-clustering)
- PostgreSQL (content_items, clusters, knowledge_base, content_analysis tables) (004-wf02-embedding-clustering)

- n8n workflow (JSON export), SQL migrations + n8n 1.x (queue mode), Azure OpenAI (gpt-5-nano, gpt-4o-mini), Redis 7, PostgreSQL 16+pgvector (002-wf01-ingestion-translation)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for n8n workflow (JSON export), SQL migrations

## Code Style

n8n workflow (JSON export), SQL migrations: Follow standard conventions

## Recent Changes
- 004-wf02-embedding-clustering: Added n8n Workflow (JSON export) + PostgreSQL/pgvector + n8n (Container App), Azure OpenAI, Redis 7, PostgreSQL 16 + pgvector
- 003-db-foundation-schema: Added SQL (PostgreSQL 16.x), PowerShell 7.x for scripts + pgvector 0.5+, Flyway (SQL migrations)

- 002-wf01-ingestion-translation: Added n8n workflow (JSON export), SQL migrations + n8n 1.x (queue mode), Azure OpenAI (gpt-5-nano, gpt-4o-mini), Redis 7, PostgreSQL 16+pgvector

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
