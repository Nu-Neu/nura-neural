---
doc_type: architecture
version: 2.1
last_updated: 2026-02-03
owner: Amir (Software Architect) + Sina (DevOps Lead)
status: approved
traceability: [Ref: SRS-v2.4 (docs/01_REQUIREMENTS/SRS-Master.md), Ref: ENG-SPEC-v4.0, Ref: ADR-009-v2.2, Ref: workflow-pg-to-ai-search-sync-v2.0]
---

# High-Level Design (HLD) v2.1 - NURA Platform

## Document Control

| Field | Value |
|-------|-------|
| **Document Type** | Architecture Design (HLD) |
| **Version** | 2.1 |
| **Status** | ✅ APPROVED |
| **Last Updated** | Tuesday, February 3, 2026, 10:53 PM NZDT |
| **Supersedes** | HLD-v2.0 |
| **Owner** | Amir (Architect) + Sina (DevOps) |
| **Reviewers** | Reyhaneh (DB), Navid (AI), Mani (UX) |

---

## Executive Summary

This document describes the **as-deployed** architecture of the NURA Intelligence Platform. Version 2.1 reflects the **actual production infrastructure** running on Azure Container Apps, eliminating outdated references to theoretical designs.

### Key Changes from HLD v2.0

| Aspect | v2.0 (Theoretical) | v2.1 (Actual) | Impact |
|--------|-------------------|---------------|--------|
| **Deployment** | Generic Containers | **Azure Container Apps** | Serverless scale |
| **Orchestration** | n8n mentioned | **n8n as Central Hub** | Workflow-first |
| **Cost Model** | $295/mo (est) | **$6-117/mo (actual)** | 60-98% Savings |
| **Infrastructure** | Conceptual | **17 Deployed Resources** | Inventory-based |
| **State** | Redis (vague) | **Redis (Documented Keys)** | Clear state model |

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Infrastructure Inventory](#2-infrastructure-inventory)
3. [Layer 1: Data Ingestion](#3-layer-1-data-ingestion)
4. [Layer 2: AI Processing](#4-layer-2-ai-processing)
5. [Layer 3: Persistence](#5-layer-3-persistence)
6. [Layer 4: Presentation](#6-layer-4-presentation)
7. [Workflow Architecture](#7-workflow-architecture)
8. [Cost Analysis](#8-cost-analysis)
9. [Deployment Model](#9-deployment-model)
10. [Security Architecture](#10-security-architecture)
11. [Monitoring & Observability](#11-monitoring--observability)
12. [Disaster Recovery](#12-disaster-recovery)
13. [Implementation Roadmap](#13-implementation-roadmap)
14. [Decision Log](#14-decision-log)

---

## 1. System Overview

### 1.1 High-Level Architecture

```mermaid
graph TD
    subgraph "External Sources"
        RSS[RSS Feeds (500+)]
        Twitter[Twitter (twitterapi.io)]
    end

    subgraph "Azure Container Apps"
        N8N[n8n Workflow Engine]
        Redis[Redis Cache]
    end

    subgraph "Azure PaaS"
        Postgres[(PostgreSQL B2s)]
        AISearch[Azure AI Search]
        OpenAI[Azure OpenAI]
        Blob[Blob Storage]
    end

    RSS -->|Poll 15m| N8N
    Twitter -->|Poll 5m| N8N
    N8N -->|State| Redis
    N8N -->|Store| Postgres
    N8N -->|Embed| OpenAI
    N8N -->|Index| AISearch
    Postgres -->|Archive| Blob
```

### 1.2 Design Principles

- **Workflow-First**: Logic resides in n8n where possible.
- **Stateless Compute**: Container Apps scale to zero.
- **Cost-Optimized**: Aggressive use of caching and batching (ADR-009).

---

## 2. Infrastructure Inventory

### 2.1 Deployed Resources (17 Total)

| Resource Name | Type | Purpose | Cost/mo |
|---------------|------|---------|---------|
| `irdecode-prod-rg` | Resource Group | Container | $0 |
| `irdecode-prod-psql` | PostgreSQL Flexible | Database (B2s) | ~$35.00 |
| `irdecode-prod-n8n` | Container App | Orchestrator | ~$0.90 |
| `irdecode-prod-redis` | Container App | Cache | ~$0.45 |
| `nura-search` | AI Search | Search Index (Basic) | $75.00 |
| `irdecode-prod-kv` | Key Vault | Secrets | $0.00 |
| `irdecode-prod-openai`| Azure OpenAI | AI Models | Pay-per-use |
| `irdecode-logs` | Log Analytics | Monitoring | <$1.00 |
| `irdecode-vnet` | VNet | Networking | $0 |
| `*-subnet` (x4) | Subnets | Isolation | $0 |
| `irdecode-storage` | Storage Account | Blobs | ~$1.20 |

**Total Fixed Cost**: ~$113/mo (excluding variable AI tokens).

---

## 3. Layer 1: Data Ingestion

### 3.1 Workflows

- **RSS Poller**: Runs every 15 min. Fetches from Miniflux/Direct.
- **Twitter Poller**: Runs every 5 min. Uses `twitterapi.io`.
- **Deduplication**: SHA-256 hash check against `items` table.

### 3.2 Deduplication Logic
```sql
SELECT EXISTS(SELECT 1 FROM items WHERE url_hash = $1)
```

---

## 4. Layer 2: AI Processing

### 4.1 Trust Scoring
Executed as a JavaScript Function in n8n.
- **Inputs**: Source Score, Metadata, Vector Corroboration.
- **Output**: 15-95 Score + JSON Breakdown.

### 4.2 Narrative Clustering
Hybrid approach:
1. **Vector Search**: Find candidates (`similarity > 0.85`).
2. **Entity Overlap**: Check for shared entities.
3. **LLM Verification**: GPT-4o-mini final check.

---

## 5. Layer 3: Persistence

### 5.1 PostgreSQL Schema
- **Table `items`**: Partitioned by month.
- **Table `trust_signals`**: Stores scoring breakdown.
- **Extension `pgvector`**: HNSW index (`m=16`, `ef=64`).

### 5.2 Redis Keys
- `sync:last_run`: Timestamp of last AI Search sync.
- `workflow:state:{id}`: Intermediate workflow data.
- `dlq:failed_items`: List of failed ingestion jobs.

---

## 6. Layer 4: Presentation

### 6.1 API Strategy
- **MVP**: n8n Webhooks (`GET /webhook/feed`).
- **Phase 2**: FastAPI container.

### 6.2 Framer Integration
- Fetches JSON from n8n webhooks.
- Renders Trust Badge and Modal components.

---

## 7. Workflow Architecture

| ID | Name | Trigger | Nodes | Description |
|----|------|---------|-------|-------------|
| WF-01 | `pg-to-ai-sync` | Cron (15m) | 11 | Syncs DB items to AI Search index. |
| WF-02 | `rss-ingest` | Cron (15m) | 8 | Ingests and scores RSS items. |
| WF-03 | `twitter-ingest`| Cron (5m) | 7 | Ingests tweets. |
| WF-04 | `daily-cleanup` | Cron (Daily)| 4 | Archives old data. |

---

## 8. Cost Analysis (ADR-009)

| Scenario | Monthly Cost | Runway ($5k) |
|----------|--------------|--------------|
| **MVP Light** | $6 - $15 | ~300 months |
| **MVP Moderate**| $117 | 42 months |
| **Full Prod** | $295 | 16 months |

**Strategy**: Start Light, scale to Moderate.

---

## 9. Deployment Model

### 9.1 Container Apps
- **n8n**: 0.25 vCPU, 0.5Gi RAM. Auto-scale 1-2.
- **Redis**: 0.125 vCPU, 0.25Gi RAM. Single replica.

### 9.2 Configuration
- Managed Identity for Key Vault access.
- Secrets: `postgres-conn`, `openai-key`.

---

## 10. Security Architecture

- **Network**: VNet integration. No public access to DB/Redis.
- **Secrets**: All credentials in Key Vault.
- **Ingress**: TLS 1.2+ only.

---

## 11. Monitoring

- **Log Analytics**: Centralized logs.
- **Alerts**:
  - Sync Failure (Slack)
  - DB Storage > 90% (Email)
  - OpenAI Quota > 80% (Email)

---

## 12. Disaster Recovery

- **DB**: Geo-redundant backups (1h RTO).
- **Workflows**: Git versioned (GitHub Actions).
- **Region Failover**: East US -> West US 2.

---

## 13. Implementation Roadmap

- **Week 1**: Infra Setup (Done).
- **Week 2**: Ingestion Workflows (In Progress).
- **Week 3**: API & Scoring Logic.
- **Week 4**: UI Integration.

---

## 14. Decision Log

- **ADR-001**: n8n for Orchestration.
- **ADR-003**: PostgreSQL B2s (Burstable).
- **ADR-009**: Cost Optimization Strategy.

---
