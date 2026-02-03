---
doc_type: architecture
version: 1.0
last_updated: 2026-02-04
owner: Nura Neural Team
status: draft
---

# Architecture Overview v1.0

## 1. System Overview & High-Level Design (HLD)

### 1.1. System Context & Goals
The Nura Intelligence Platform is an AI-driven system designed to ingest, analyze, and score news content from the Iranian information space. Its primary goal is to combat misinformation by providing users with a quantifiable **Trust Score** and contextual **Narrative Clustering**. The architecture is built on **Azure** and prioritizes a **serverless, workflow-first** model to ensure scalability and extreme cost-efficiency, as outlined in **ADR-009**.

### 1.2. High-Level Architecture Diagram

The system follows a 4-layer microservices pattern orchestrated by **n8n**.

```mermaid
graph TD
    subgraph "External Sources"
        RSS[RSS Feeds (500+)]
        Twitter[Twitter (twitterapi.io)]
    end

    subgraph "Layer 1: Ingestion (Azure Container Apps)"
        N8N[n8n Workflow Engine]
        Redis[Redis Cache for State]
    end

    subgraph "Layer 2: AI & Persistence (Azure PaaS)"
        Postgres[(PostgreSQL B2s - Source of Truth)]
        AISearch[Azure AI Search (Free Tier Cache)]
        OpenAI[Azure OpenAI (GPT-5-nano)]
        Blob[Blob Storage for Archives]
    end
    
    subgraph "Layer 3: Presentation"
        API[Public API (n8n Webhook)]
    end

    RSS -->|Polls every 15m| N8N
    Twitter -->|Polls every 5m| N8N
    N8N -->|Stores & Processes| Postgres
    N8N -->|Embeds & Classifies| OpenAI
    N8N -->|Caches State| Redis
    Postgres -->|Syncs recent items| AISearch
    Postgres -->|Archives raw HTML| Blob
    API -->|Serves data to partners| Framer[Partner Front-Ends]

```

### 1.3. Design Principles
- **Workflow-First**: Business logic resides in version-controlled n8n workflows, not custom code where possible.
- **Stateless Compute**: Container Apps scale to zero, minimizing idle costs.
- **Single Source of Truth**: PostgreSQL is the master record for all data; other services like AI Search are considered ephemeral caches.
- **Cost-Optimized**: Aggressive use of caching, batching, and free/burstable service tiers.

## 2. Infrastructure & Deployment View

### 2.1. Deployed Resources
The production environment (`irdecode-prod-rg`) consists of 17 core resources, primarily hosted in Azure's East US region.

| Resource Name | Type | Purpose | Cost/mo (Est.) |
|:---|:---|:---|:---|
| `irdecode-prod-psql` | PostgreSQL Flexible | Primary Database (B2s) | ~$35.00 |
| `irdecode-prod-n8n` | Container App | Orchestrator | ~$0.90 |
| `irdecode-prod-redis` | Container App | Cache & State Store | ~$0.45 |
| `nura-search` | AI Search | Search Index (Free Tier) | $0.00 |
| `irdecode-prod-openai`| Azure OpenAI | AI Models (GPT-5-nano) | Pay-per-use |
| `irdecode-storage` | Storage Account | Raw HTML Archives | ~$1.20 |
| `irdecode-prod-kv` | Key Vault | Secrets Management | $0.00 |
| *Other Networking/Logging* | VNet, Subnets, etc. | Connectivity & Monitoring | <$1.00 |

**Total Estimated Fixed Cost**: **~$38/mo** (excluding variable AI tokens).

### 2.2. Deployment Model
- **Infrastructure as Code (IaC)**: All infrastructure is managed via **Terraform**.
- **Compute**: The `n8n` and `Redis` services run as **Azure Container Apps**, configured for consumption-based scaling.
  - `n8n`: 0.25 vCPU, 0.5Gi RAM, scales from 0 to 2 instances.
  - `Redis`: 0.125 vCPU, 0.25Gi RAM, single replica.
- **Workflows**: n8n workflow definitions (`.json` files) are stored in the Git repository and deployed via a CI/CD pipeline.

## 3. Security Architecture

### 3.1. Network Security
- **Zero Trust Network**: The network is designed with a Zero Trust philosophy. The PostgreSQL database and Redis cache have **no public internet access**.
- **VNet Integration**: All services are isolated within the `irdecode-prod-vnet` virtual network. Communication between services occurs over the private network.
- **Ingress Control**: Public access is restricted to the `n8n` container app's ingress over HTTPS (TLS 1.2+).

### 3.2. Secret Management
- **Centralized Secrets**: All secrets (database connection strings, API keys) are stored securely in **Azure Key Vault**.
- **Managed Identity**: Azure services (like the n8n Container App) use **Managed Identities** to authenticate with Key Vault, eliminating the need to store credentials in application code or environment variables.

## 4. Data Architecture

### 4.1. Data Flow
1.  **Ingestion**: n8n workflows poll RSS and Twitter feeds, perform initial deduplication, and filter irrelevant content.
2.  **Processing**: For each new item, n8n orchestrates calls to Azure OpenAI to extract metadata and generate vector embeddings (`text-embedding-3-small`, 512 dimensions).
3.  **Persistence**: The processed article, its metadata, and vector embedding are stored in the **PostgreSQL** `articles` table.
4.  **Analysis**: The Trust Scoring engine calculates a score, and the Narrative Clustering engine identifies related articles using `pgvector`'s HNSW index.
5.  **Caching**: A separate n8n workflow periodically syncs recent, high-trust items from PostgreSQL to **Azure AI Search** to power fast, public-facing queries.
6.  **Presentation**: The public API, built as an n8n webhook, queries AI Search (with a fallback to PostgreSQL) to serve data to front-end clients.

### 4.2. Database Schema
- **`sources`**: A registry of all news sources and their baseline trust levels.
- **`articles`**: The core table containing all ingested news items, their content, AI-generated metadata (`ai_metadata` JSONB field), and the final `trust_score`.
- **`pgvector` Extension**: Used on the `articles.embedding` column (VECTOR(512)) to enable efficient vector similarity search.
