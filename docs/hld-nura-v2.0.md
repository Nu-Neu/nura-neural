---
doc_type: architecture
version: 2.0
last_updated: 2026-02-03
owner: Amir (Architecture Lead)
status: approved
traceability: [Ref: SRS-v2.4, Ref: ENG-SPEC-v4.0]
---

# High-Level Design (HLD) v2.0 - Nura MVP Edition

## 1. Executive Summary
This document defines the architecture for **Nura MVP (Phase 1)**, optimized for rapid delivery and efficient use of a **$5,000 Azure Credit**. 

**Key Strategic Shifts from v1.1:**
- **Infrastructure:** Leveraging existing **Miniflux** deployment for robust RSS ingestion.
- **Twitter Data:** Transition from direct API to **twitterapi.io** for 100x cost efficiency.
- **Database:** Standardizing on **PostgreSQL Flexible Server (Burstable B2s)** to balance performance (2 vCore) with MVP budget constraints.
- **AI Model:** Standardization on **GPT-4o-mini** for 95% of tasks to maximize speed and minimize token costs.
- **Budget utilization:** Estimated run-rate of **~$275/month**, providing **18+ months of runway**.

---

## 2. System Architecture

The Nura platform follows a **4-Layer Microservices Architecture**, deployed entirely on **Azure Container Apps** and **Azure PaaS** services.

### 2.1 High-Level Context
```mermaid
graph TD
    User[Activist / Journalist] -->|HTTPS| FramerUI[Framer UI]
    FramerUI -->|REST API| Gateway[FastAPI Gateway]
    
    subgraph "Azure Cloud (East US / West Europe)"
        Gateway -->|Read/Write| DB[(PostgreSQL B2s)]
        Gateway -->|Search| Search[Azure AI Search]
        
        subgraph "Ingestion Layer"
            RSS[RSS Feeds] -->|Webhook| Miniflux[Miniflux Container]
            Miniflux -->|JSON| N8N[n8n Workflow]
            Twitter[twitterapi.io] -->|Polling| N8N
        end
        
        subgraph "Reasoning Layer"
            N8N -->|Extract/Cluster| OpenAI[Azure OpenAI]
            OpenAI -->|Embeddings/Metadata| DB
        end
    end

    3. Detailed Component Design
3.1 Layer 1: Ingestion (The Senses)
Responsible for gathering raw data with minimal latency and high reliability.

Component	Technology	Configuration	Rationale for MVP
RSS Engine	Miniflux	Existing Container	Native RSS parsing, webhook support, 0 maintenance.
Twitter	twitterapi.io	Pay-as-you-go	$0.15/1k tweets vs $100/mo official API.
Orchestrator	n8n	Self-Hosted	Visually manage data flows and error handling.
Data Flow:

Miniflux fetches article -> Sends Webhook to n8n.

n8n checks PostgreSQL for duplicates (URL Hash).

If new, sends to GPT-4o-mini for metadata extraction.

3.2 Layer 2: AI Reasoning (The Brain)
Processing raw text into trusted insights using deterministic algorithms.

Task	Model	Logic
Metadata Extraction	gpt-4o-mini	Extract: Author, Date, Entities, Body.
Trust Scoring	Python Code	Deterministic formula (15-95) based on metadata.
Embeddings	text-embedding-3-small	1536-dim vectors for clustering.
Clustering	gpt-4o-mini	Logic: "Is this the same event as Cluster X?"
Constraint: o3-mini and gpt-4o are reserved for Phase 2 to conserve complexity, not just cost.

3.3 Layer 3: Persistence (The Memory)
optimized for the Burstable B2s tier (2 vCore, 4GB RAM).

Primary DB: PostgreSQL 16 Flexible Server

Extension: pgvector (Vector Search)

Optimization Strategy:

Retention: Keep embeddings in Hot/RAM for 30 days only.

Indexing: HNSW (m=8, ef_construction=32) for lower memory footprint.

Archival: Raw HTML moves to Azure Blob Storage (Hot) immediately.

3.4 Layer 4: Presentation (The Face)
API Gateway: FastAPI on Container Apps (1 Replica, scaling to 2).

Search Engine: Azure AI Search (Basic) for user-facing "Hybrid Search" (Keyword + Semantic).

Frontend: Framer (React) connecting to FastAPI.

4. Technology Stack & Budget Breakdown
Total Budget: $5,000 Credit
Target Monthly Burn: ~$275

Service	SKU / Config	Estimated Cost	Notes
PostgreSQL	Flexible Server (B2s)	~$35.00	2 vCore, 4GB RAM, 128GB Storage
AI Search	Basic Tier	~$75.00	Required for high-quality RAG
OpenAI	GPT-4o-mini	~$115.00	Based on 5k items/day
Compute	Container Apps (x2)	~$40.00	Miniflux + FastAPI + n8n
Storage	Blob (Hot)	~$10.00	HTML Archives
Twitter	twitterapi.io	~$20.00	External API Cost
Total		~$295.00	~17 Months Runway
5. Implementation Roadmap (Week 1 Focus)
Week 1: Foundation (Current)
 Infra: Validate existing Azure resources (Amir).

 DB: Apply Schema DDL for items, trust_signals, narratives (Reyhaneh).

 Ingestion: Connect Miniflux Webhook to n8n (Navid).

 API: Deploy FastAPI "Hello World" to Container App (Amir).

Week 2: The Pipeline
 AI: Implement TrustScorer class in Python.

 Data: Ingest first 100 RSS items -> DB.

 UI: Connect Framer Trust Badge to API Mock.

6. Risk Management
Risk	Probability	Mitigation Strategy
DB Performance	Medium	If B2s is too slow, upgrade to General Purpose ($130/mo). We have budget.
Twitter Ban	Low	twitterapi.io handles rotation. Fallback to RSSHub if needed.
AI Hallucination	Low	Trust Score is deterministic code, not LLM generated.
Approved by: Product Owner, Amir (Architect), Reyhaneh (DB), Navid (AI)

text


*Figure 1: Data Ingestion Sequence - Miniflux to PostgreSQL*

***
