# Architecture Documentation: Nura Neural (Azure Container Apps Edition)

## 1. Tech Stack

| Component | Technology | Reason |
| :--- | :--- | :--- |
| **Workflow Engine** | **n8n (Container App)** | Central orchestration for data pipelines and API endpoints. Already deployed, allowing seamless integration with other containerized services. |
| **RSS Aggregator** | **Miniflux (Container App)** | Efficient, PostgreSQL-native feed reader. Deployed as a microservice (0.25 vCPU) to handle polling independently from n8n. |
| **RSS Generator** | **RSSHub (Container App)** | Generates RSS feeds for regime media (non-RSS sites). Deployed internally so only Miniflux allows access. |
| **Text Extraction** | **SMRY Fork (Container App)** | Internal-only Node.js service for clean text extraction. "Paywall bypass" disabled for compliance. |
| **Vector DB** | **Qdrant (Container App)** | Vector store for RAG and clustering. Deployed with persistent storage volume in the same environment. |
| **Database** | **Azure Database for PostgreSQL** | Managed service (Flexible Server) shared by n8n, Miniflux, and the application data (sources/claims). |
| **Cache** | **Redis (Container App)** | Caching layer required by RSSHub to prevent rate-limiting from source sites. |
| **LLM** | **OpenAI GPT-4o** | Reasoning engine for IMTT evaluation and claim extraction. |
| **Embeddings** | **text-embedding-3-large** | Vector generation for semantic search. |
| **Frontend** | **Azure Static Web Apps** | Hosts the widget JavaScript library and assets globally. |

***

## 2. System Architecture

The system operates within a single **Azure Container Apps Environment**, utilizing internal service discovery for secure communication.

1.  **Ingestion Flow**:
    *   **RSSHub** (Internal App) scrapes regime media sites and generates RSS feeds. It caches results in **Redis**.
    *   **Miniflux** (App) polls 50+ feeds (standard RSS + RSSHub feeds) every 15 minutes and stores headers in **PostgreSQL**.
    *   **n8n** triggers a scheduled workflow:
        1.  Calls Miniflux API (Internal DNS) to get new unread items.
        2.  Sends URLs to **SMRY Service** (Internal App) to extract clean text.
        3.  Stores full content in **PostgreSQL** and **Blob Storage**.

2.  **Analysis Flow**:
    *   **Agent 1**: n8n triggers on new content → Queries **Qdrant** for context → Calls **GPT-4o** for IMTT scoring → Updates **PostgreSQL**.
    *   **Agent 2**: Scheduled n8n workflow (6h) → Fetches unclustered claims → Generates embeddings → Upserts to **Qdrant** → Groups into narratives.

3.  **Serving Flow**:
    *   **Public Widgets** (hosted on Static Web Apps) make requests to **n8n Webhook URLs**.
    *   n8n handles the request, queries Postgres/Qdrant, and returns the JSON response.

***

## 3. Data Models

### `sources`
*   `source_id` (PK): UUID
*   `domain`: e.g., `tasnimnews.com`
*   `name`: Display name
*   `credibility_tier`: `propaganda`, `unverified`, `credible`
*   `imtt_scores`: JSONB `{independence: 0.2, methodology: 0.1...}`
*   `last_evaluated`: Timestamp

### `content`
*   `content_id` (PK): UUID
*   `source_id` (FK): Link to `sources`
*   `url`: Canonical URL
*   `title`: Headline
*   `content_text`: Extracted body text
*   `ingested_at`: Timestamp
*   `analysis_status`: `pending`, `complete`, `failed`

### `claims`
*   `claim_id` (PK): UUID
*   `content_id` (FK): Link to `content`
*   `claim_text`: Extracted assertion
*   `claim_type`: `concrete`, `narrative`
*   `verification_status`: `verified`, `false`
*   `confidence`: Float (0.0-1.0)

### `narratives`
*   `narrative_id` (PK): UUID
*   `label`: Auto-generated label
*   `cluster_size`: Count of articles
*   `timeline`: JSONB Array of dates/variants

***

## 4. API Endpoints (n8n Webhooks)

*   `POST https://[n8n-url]/webhook/analyze`
    *   **Purpose:** Instant article analysis for widgets.
*   `GET https://[n8n-url]/webhook/credibility?domain=...`
    *   **Purpose:** Fetch source tier for the Badge widget.
*   `GET https://[n8n-url]/webhook/narratives`
    *   **Purpose:** Fetch trending narratives list.

***

## 5. Folder Structure (Repo)

```
/nura-neural
├── /infrastructure
│   ├── main.bicep              # Azure Bicep/ARM templates for Container Apps
│   └── container-apps.yaml     # Configuration for Miniflux, RSSHub, etc.
├── /workflows (n8n)
│   ├── 01_ingestion.json       # Miniflux -> Postgres pipeline
│   ├── 02_agent_source.json    # IMTT Evaluation logic
│   └── 03_public_api.json      # Webhook definitions
├── /services
│   └── /text-extractor         # SMRY Fork code
│       ├── Dockerfile
│       └── server.js
├── /widgets
│   ├── /src                    # JS source for Embeds
│   └── index.html              # Test harness
└── /database
    └── schema.sql              # PostgreSQL init script
```
