---
doc_type: requirements
version: 1.0
last_updated: 2026-02-04
owner: Nura Neural Team
status: draft
---

# Requirements v1.0

## 1. Functional Requirements

### 1.1 Core User Stories

This section consolidates the primary user needs driving the Nura Neural platform, derived from persona analysis of activists, journalists, and researchers.

| Persona | User Story | Requirement ID |
|:---|:---|:---|
| **Global Observer** | As a news consumer, I want to see a clear trust score (15-95) next to each news item to quickly assess credibility. | `REQ-FUNC-001` |
| **Global Observer** | As a foreign observer, I want to read a short "Context Box" in English explaining why a news item matters to avoid propaganda framing. | `REQ-FUNC-002` |
| **Diaspora Activist** | As an activist, I want the system to generate ready-to-use social media captions (X, Instagram) to share verified stories instantly. | `REQ-FUNC-003` |
| **Diaspora Activist** | As an advocate, I want to see bullet points comparing "Regime Claims" vs. "Verified Facts" to effectively debate misinformation. | `REQ-FUNC-004` |
| **Intelligence Analyst** | As an analyst, I want the system to ingest news from key Persian and Arabic sources to capture critical local developments. | `REQ-FUNC-005` |

### 1.2 System-Level Functional Requirements

| ID | Requirement | Description |
|:---|:---|:---|
| `REQ-SYS-001` | **Data Ingestion** | The system must automatically fetch news from over 500 configured RSS feeds and the Twitter API on a scheduled basis (5-15 minutes). |
| `REQ-SYS-002` | **Deduplication** | The system must prevent duplicate content from being processed by checking the SHA-256 hash of the item's URL. |
| `REQ-SYS-003` | **AI Trust Scoring** | Every ingested item must be processed by the Trust Scoring Engine to generate a credibility score between 15 and 95. |
| `REQ-SYS-004` | **Narrative Clustering** | The system must group related news items covering the same event into a single "Narrative" to provide thematic context. |
| `REQ-SYS-005` | **Automated Translation** | All non-English content (primarily Persian and Arabic) must be automatically translated into English to enable analysis and accessibility. |
| `REQ-SYS-006` | **Public API** | The system must expose a public, read-only API endpoint (`GET /webhook/feed`) to allow partner front-ends to consume the processed data. |

## 2. Non-Functional Requirements (NFRs)

| Category | ID | Requirement | Acceptance Criteria |
|:---|:---|:---|:---|
| **Performance** | `REQ-NFR-001` | **Ingestion Latency** | P95 processing time per ingested item must be ≤ 5 seconds. |
| **Performance** | `REQ-NFR-002` | **API Response Time** | The public API (`/feed`) must respond in < 500ms under moderate load. |
| **Reliability** | `REQ-NFR-003` | **System Uptime** | The data ingestion and API services must maintain 99.5% uptime. |
| **Reliability** | `REQ-NFR-004` | **Batch Job Resilience** | Asynchronous batch jobs (e.g., historical analysis) must include automatic retry logic to handle transient provider failures. |
| **Cost** | `REQ-NFR-005` | **Operational Cost** | Monthly operational costs must remain under $15 in the "MVP Light" configuration, as defined in ADR-009. |
| **Security** | `REQ-NFR-006` | **Data-in-Transit** | All external communication must be encrypted using TLS 1.2+. |
| **Security** | `REQ-NFR-007` | **Secret Management** | All credentials, API keys, and connection strings must be stored in Azure Key Vault and accessed via Managed Identity. |
| **Usability** | `REQ-NFR-008` | **Language Accessibility** | While the primary UI is English, users must be able to view the original Persian/Arabic text alongside the English translation to verify accuracy. |

## 3. Glossary of Terms

| Term | Definition |
|:---|:---|
| **Trust Score** | A numerical value (15-95) indicating the credibility of a news item, calculated based on source, provenance, and corroboration. |
| **Narrative** | A cluster of related news items, documents, and social media posts that together form a cohesive story or event. |
| **Source Class** | A classification of a media outlet based on its ownership and bias (e.g., `REGIME_MEDIA`, `NGO_WATCHDOG`, `INTL_WIRE`). |
| **Proxy Detection** | An algorithmic process to identify state-affiliated sources that masquerade as independent media. |
| **pgvector** | A PostgreSQL extension that enables storing and querying of high-dimensional vector embeddings for similarity search. |
| **HNSW** | (Hierarchical Navigable Small World) An algorithm used by `pgvector` to create an efficient index for fast Approximate Nearest Neighbor (ANN) search. |
| **RAG** | (Retrieval-Augmented Generation) An AI technique that combines a large language model with an external knowledge base (like our database) to generate informed, factual responses. |
