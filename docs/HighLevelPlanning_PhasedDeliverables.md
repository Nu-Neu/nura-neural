# High-Level Planning: Phased Deliverables

This document breaks the project into delivery phases based on the existing product, architecture, schema, and scoring framework documents.

## Phase 1: Foundations & Governance
**Goal:** Establish the delivery foundations: DB-per-tenant conventions, SQL-first migrations, secure configuration, and repeatable environments.
**Tasks:**
- Tenancy convention: Define tenant database naming, provisioning workflow, and isolation boundaries (DB-per-tenant, index-per-tenant, blob-container-per-tenant).
- Migration tooling: Select a SQL-first migration tool and create a standard migration workflow for local/dev/prod.
- Baseline migration: Convert the current monolithic schema into a first migration and define a versioning policy for future changes.
- Secrets hygiene: Remove committed secrets/state artifacts, move secrets to managed secret storage, and document safe local dev configuration.
- Environment config: Define per-environment variables (dev/beta/prod), connection strings, and operational toggles.

## Phase 2: Core Database Schema (System of Record)
**Goal:** Deploy the foundational Postgres schema for a tenant database with strong constraints, auditability, and multilingual support.
**Tasks:**
- Core DDL rollout: Apply enums, extensions, and core tables as migrations to a fresh tenant database.
- Integrity constraints: Add required uniqueness constraints (canonical URLs, dedupe keys) and referential integrity for content/claims/narratives.
- Historical tracking: Implement “current pointer” mechanics (e.g., `is_current`) for evaluations and maintain full history.
- Indexing baseline: Add performance-critical indexes for the main query paths (recency, status, source, narrative membership).
- Data lifecycle: Define retention policies for high-volume logs/processing tables and identify candidates for partitioning.

## Phase 3: Ingestion Storage & Processing Model
**Goal:** Make ingestion reliable and observable: ingest → extract → store with dedupe and status transitions.
**Tasks:**
- Source registry: Define how curated sources are represented (feeds/accounts/keywords) and how they are enabled/disabled.
- Content ingestion: Implement the write path for new items (metadata + extracted text) into Postgres, with optional archival to blob storage.
- Processing states: Standardize statuses (`pending/processing/completed/failed/skipped`) and enforce transitions in a consistent way.
- Deduplication: Implement idempotent ingestion using canonical URL normalization and content hashing.
- Ingestion health: Capture counters and failure reasons to support dashboards and alerts.

## Phase 4: IMTT-Inspired Source Scoring
**Goal:** Produce explainable, repeatable source scores with evidence and history, suitable for UI badges and ranking.
**Tasks:**
- Scoring model: Define pillar scores (0–5), derived credibility tiers, and weighting rules.
- Evidence capture: Store supporting evidence links and short rationales (human-readable + machine-parsable).
- Versioned evaluations: Write evaluations as append-only history and mark the latest as current.
- Editorial override: Add a controlled override path (manual tier/score adjustments) with audit trails.
- Drift monitoring: Track score changes over time and alert on unexpected tier shifts for high-impact sources.

## Phase 5: Claims Extraction & Narrative Clustering
**Goal:** Convert content into claims and narratives that can be searched, clustered, and served.
**Tasks:**
- Claims extraction: Extract claims from content while preserving original language and storing English translations.
- Claim verification hooks: Store verification status and evidence references for later fact-check workflows.
- Embeddings generation: Generate multilingual embeddings for claims/content units selected for clustering.
- Narrative clustering: Cluster claims into narratives on a schedule and store narrative labels/summaries for serving.
- Linking graph: Maintain relationships across source → content → claim → narrative for timeline and drill-down views.

## Phase 6: Search Sync Contract (Postgres → Azure AI Search)
**Goal:** Ensure Azure AI Search is a consistent, query-optimized mirror of Postgres truth with idempotent operations.
**Tasks:**
- Document mapping: Define which Postgres entities are indexed (claims, narratives, content summaries) and the canonical document IDs.
- Idempotent upserts: Implement `mergeOrUpload` for deterministic documents keyed by Postgres IDs; repeated runs must not create duplicates.
- Idempotent deletes: Implement delete-by-ID when Postgres marks records deleted or not-indexable; repeated deletes must be safe.
- Outbox tracking: Use a sync tracking table (or outbox) with retry state, last-attempt timestamps, and error capture.
- Backfill + reconciliation: Add a backfill job and periodic reconciliation to repair drift between Postgres and the index.

## Phase 7: Serving APIs (n8n Webhooks) & Query Performance
**Goal:** Deliver stable endpoints for the newsroom UI and future consumers with predictable performance.
**Tasks:**
- Endpoint contract: Define request/response schemas for core endpoints (fact-check, credibility, narratives, narrative detail, search).
- Query patterns: Implement read models optimized for “last 24 hours” briefing, narrative detail timelines, and source credibility lookups.
- Materialized views: Add views where they meaningfully reduce latency and define refresh scheduling and failure handling.
- Caching: Implement caching for high-traffic endpoints (TTL-based) and define cache invalidation rules.
- Access controls: Add API keys/rate limits where needed and ensure consistent logging/trace IDs.

## Phase 8: Daily Briefing & Podcast Automation
**Goal:** Produce a repeatable daily pipeline that generates the briefing and an audio episode from the last 24 hours.
**Tasks:**
- Briefing dataset: Define the selection criteria for top narratives and representative items.
- Script generation: Generate an English script with citations to stored narratives/items and store the script artifact.
- Audio generation: Convert script to audio, store artifacts, and track processing status.
- Publishing: Expose episode metadata and generate/update a podcast RSS feed.
- Monitoring: Alert on missed generation windows and failed episodes.

## Phase 9: Production Hardening & Multi-Tenant Expansion
**Goal:** Make operations repeatable across tenants and safe under load.
**Tasks:**
- Tenant onboarding: Automate “new tenant” provisioning (new DB, index, blob container, secrets) from a single workflow.
- Backup/restore: Define and test backup/restore procedures per tenant database.
- Observability: Dashboards for ingestion lag, analysis throughput, search sync backlog, and DB query latency.
- Data governance: PII policy, retention policy enforcement, and audit export strategy.
- Load & resilience: Validate performance targets and implement retry/backoff patterns for external dependencies.
