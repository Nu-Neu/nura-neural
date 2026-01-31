# GitHub Issues Backlog (Phased)

This backlog is derived from:
- [docs/PRD.md](docs/PRD.md)
- [docs/Architecture.md](docs/Architecture.md)
- [docs/IMTT_Inspired_Source_Scoring_Framework.md](docs/IMTT_Inspired_Source_Scoring_Framework.md)
- [docs/HighLevelPlanning_PhasedDeliverables.md](docs/HighLevelPlanning_PhasedDeliverables.md)
- [database/schema.sql](database/schema.sql)

Conventions used:
- **Epics**: one per phase.
- **Features**: major deliverables within a phase.
- **Tasks**: actionable work items; keep them small enough to complete in 0.5–2 days.

Each issue includes **Acceptance Criteria** and **Dependencies**.

---

## Phase 1: Foundations & Governance (EPIC)
**Goal:** Establish DB-per-tenant conventions, SQL-first migrations, and secure configuration for repeatable environments.
**Tasks:**
- Task 1: Create Epic/Feature/Task labels
- Task 2: Document tenancy conventions (DB/index/blob container naming)

### Phase 1: Tenancy & Environment Conventions (FEATURE)
**Goal:** Define the DB-per-tenant operational model and naming conventions used everywhere.
**Tasks:**
- Task 1: Write tenancy naming spec (db/index/container)
- Task 2: Define environment variable contract (dev/beta/prod)

### Phase 1: SQL-First Migrations Bootstrap (FEATURE)
**Goal:** Establish a simple SQL-first migration workflow that can run locally and in CI/CD.
**Tasks:**
- Task 1: Select migration tool and document workflow
- Task 2: Add initial migration structure and a “how to apply” guide

### Phase 1: Secrets & Config Hygiene (FEATURE)
**Goal:** Ensure secrets are not committed and are managed via secret storage.
**Tasks:**
- Task 1: Document secret sources (Key Vault/local) and rotation approach
- Task 2: Add repo guardrails (gitignore + docs) for state/secrets

---

## Phase 2: Core Database Schema (System of Record) (EPIC)
**Goal:** Deploy the foundational tenant schema with integrity constraints, auditability, and multilingual support.
**Tasks:**
- Task 1: Convert baseline schema into migrations
- Task 2: Apply to a fresh tenant database (dev)

### Phase 2: Baseline Schema Migration Set (FEATURE)
**Goal:** Translate the current schema into versioned migrations.
**Tasks:**
- Task 1: Create initial migration from current schema
- Task 2: Verify repeatable apply on empty DB
- Task 3: Document enum evolution rules

### Phase 2: Constraints, Indexes, and History (FEATURE)
**Goal:** Ensure dedupe, query performance, and historical evaluation patterns are correct.
**Tasks:**
- Task 1: Add uniqueness constraints/dedupe keys
- Task 2: Add baseline indexes for read paths
- Task 3: Validate “current-pointer” evaluation history behavior

---

## Phase 3: Ingestion Storage & Processing Model (EPIC)
**Goal:** Make ingestion reliable and observable: ingest → extract → store with dedupe and status transitions.
**Tasks:**
- Task 1: Define source registry model and activation controls
- Task 2: Define content ingestion write model and processing states

### Phase 3: Source Registry & Curation (FEATURE)
**Goal:** Represent curated sources (feeds/accounts/keywords) with enable/disable and metadata.
**Tasks:**
- Task 1: Define source schema fields aligned to ingestion types
- Task 2: Define admin/editor workflows for source curation

### Phase 3: Ingestion State + Health Tracking (FEATURE)
**Goal:** Standardize ingestion statuses, dedupe, and error visibility.
**Tasks:**
- Task 1: Define processing status transitions + failure reasons
- Task 2: Define ingestion health tables/views for dashboards

---

## Phase 4: IMTT-Inspired Source Scoring (EPIC)
**Goal:** Produce explainable, repeatable source scores with evidence and history, suitable for UI and ranking.
**Tasks:**
- Task 1: Define scoring model (pillar scores + tiers)
- Task 2: Define evidence storage and audit trails

### Phase 4: Scoring Model + Storage (FEATURE)
**Goal:** Store pillar scores, derived tiers, and evaluation metadata over time.
**Tasks:**
- Task 1: Define pillar score fields and weighting policy
- Task 2: Store evaluation history and “current” pointer

### Phase 4: Overrides + Drift Monitoring (FEATURE)
**Goal:** Support editorial overrides and detect tier drift.
**Tasks:**
- Task 1: Define manual override path with audit log
- Task 2: Define drift monitoring signals and alerts

---

## Phase 5: Claims Extraction & Narrative Clustering (EPIC)
**Goal:** Convert content into claims and narratives that can be searched, clustered, and served.
**Tasks:**
- Task 1: Define claims storage (original + English)
- Task 2: Define narrative clustering storage and linking

### Phase 5: Claims & Verification Hooks (FEATURE)
**Goal:** Store extracted claims with translation, type, and verification status.
**Tasks:**
- Task 1: Define claim table contract and indexes
- Task 2: Define verification evidence storage

### Phase 5: Narratives + Linking Graph (FEATURE)
**Goal:** Store narratives, membership links, and timeline metadata.
**Tasks:**
- Task 1: Define narrative model and membership table
- Task 2: Define timeline/query read patterns

---

## Phase 6: Search Sync Contract (Postgres → Azure AI Search) (EPIC)
**Goal:** Ensure search index is a consistent, query-optimized mirror of Postgres truth with idempotent operations.
**Tasks:**
- Task 1: Define index document mapping and IDs
- Task 2: Define outbox tracking and reconciliation

### Phase 6: Index Mapping + Document IDs (FEATURE)
**Goal:** Define what gets indexed and how each document is keyed for idempotent updates.
**Tasks:**
- Task 1: Define document schemas for claims/content/narratives
- Task 2: Define deterministic document IDs and versioning

### Phase 6: Outbox, Retry, and Reconciliation (FEATURE)
**Goal:** Make indexing reliable with retries and drift repair.
**Tasks:**
- Task 1: Define outbox/sync tracking schema
- Task 2: Define backfill and periodic reconciliation strategy

---

## Phase 7: Serving APIs & Query Performance (EPIC)
**Goal:** Deliver stable endpoints and optimized read models for briefing, narrative detail, credibility, and search.
**Tasks:**
- Task 1: Define read models for main endpoints
- Task 2: Define caching and rate limiting strategy

### Phase 7: Read Models + Views (FEATURE)
**Goal:** Provide query-optimized views/materialized views for the most common access paths.
**Tasks:**
- Task 1: Define views for “last 24 hours” briefing and narrative detail
- Task 2: Define materialized view refresh plan (if used)

### Phase 7: API Contract + Access Control (FEATURE)
**Goal:** Define request/response schemas and minimal access control (API keys/rate limits).
**Tasks:**
- Task 1: Define endpoint contracts for credibility/narratives/search/fact-check
- Task 2: Define API key storage and rate-limit signals

---

## Phase 8: Daily Briefing & Podcast Automation (EPIC)
**Goal:** Produce a repeatable daily pipeline to generate briefing outputs and a podcast episode.
**Tasks:**
- Task 1: Define briefing selection query and storage
- Task 2: Define podcast artifacts and publishing hooks

### Phase 8: Briefing Dataset + Storage (FEATURE)
**Goal:** Persist the daily briefing dataset for traceability and re-generation.
**Tasks:**
- Task 1: Define selection criteria and query inputs
- Task 2: Define briefing storage schema (narratives/items)

### Phase 8: Podcast Artifacts + Status Tracking (FEATURE)
**Goal:** Track script generation, audio generation, and publishing status with retries.
**Tasks:**
- Task 1: Define script storage and metadata
- Task 2: Define audio artifact storage references and status transitions

---

## Phase 9: Production Hardening & Multi-Tenant Expansion (EPIC)
**Goal:** Make operations repeatable across tenants and safe under load.
**Tasks:**
- Task 1: Define tenant onboarding automation
- Task 2: Define backup/restore and observability baseline

### Phase 9: Tenant Onboarding Automation (FEATURE)
**Goal:** Automate provisioning of DB/index/blob container/secrets for a new tenant.
**Tasks:**
- Task 1: Define provisioning workflow and inputs
- Task 2: Define verification checklist for onboarding

### Phase 9: Observability + Resilience (FEATURE)
**Goal:** Establish dashboards/alerts and operational runbooks.
**Tasks:**
- Task 1: Define SLIs/SLOs and dashboard metrics
- Task 2: Define alerting for ingestion lag, backlog, and failures
