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
