# Architecture Documentation: Nura Neural (Dev/MVP Edition)

**Version:** 2.0  
**Last Updated:** January 31, 2026  
**Environment:** Dev → MVP (June 30, 2026)

---

## 1. Tech Stack

### 1.1 Core Infrastructure (Already Deployed)

| Component | Technology | Resource Name | Notes |
| :--- | :--- | :--- | :--- |
| **Container Environment** | Azure Container Apps | `irdecode-prod-n8n-env` | Shared ACA environment |
| **Workflow Engine** | n8n (Container App) | `irdecode-prod-n8n` | Central orchestration via OpenAI nodes |
| **Database** | Azure PostgreSQL Flexible | `irdecode-prod-psql` | Shared by n8n, Miniflux, app data |
| **Blob Storage** | Azure Storage Account | `irdecodeprodst` | Content archives, embeddings cache |
| **Secrets** | Azure Key Vault | `irdecode-prod-kv` | API keys, connection strings |
| **Container Registry** | Azure ACR | `irdecodeprodacr` | Custom service images |
| **Logging** | Log Analytics | `irdecode-prod-logs` | Centralized monitoring |
| **CDN/WAF** | Azure Front Door | `irdecode-prod-fd` | Global edge + WAF protection |

### 1.2 Services to Deploy

| Component | Technology | SKU/Size | Purpose |
| :--- | :--- | :--- | :--- |
| **Vector Search** | **Azure AI Search** | Basic (Dev) → Standard S1 (MVP) | Vector + semantic/hybrid search |
| **RSS Aggregator** | Miniflux (Container App) | 0.25 vCPU / 0.5Gi | PostgreSQL-native feed reader |
| **RSS Generator** | RSSHub (Container App) | 0.25 vCPU / 0.5Gi | Generates feeds for non-RSS sites |
| **Text Extraction** | SMRY Fork (Container App) | 0.25 vCPU / 0.5Gi | Clean text extraction service |
| **Cache** | Redis (Container App) | 0.25 vCPU / 0.5Gi | RSSHub caching layer |
| **Widgets** | **Cloudflare Pages** | Free | Global CDN, DDoS protection, GitHub integration |

### 1.3 AI/LLM Stack (Farsi/Arabic Optimized)

| Component | Technology | Use Case | Cost Est. |
| :--- | :--- | :--- | :--- |
| **Agent 1 LLM** | **Azure OpenAI GPT-4o** | IMTT scoring, claim decomposition (Farsi/Arabic) | ~$110/mo |
| **Agent 2 LLM** | **Azure OpenAI GPT-4o** | Narrative clustering (Farsi/Arabic accuracy critical) | ~$80/mo |
| **Widget Responses** | **Azure OpenAI GPT-4.1-mini** | Fast responses, English output only | ~$5/mo |
| **Escalation LLM** | **Azure OpenAI o4-mini** | Contested cases, OSINT profiles | ~$15/mo |
| **Embeddings** | **text-embedding-3-large** | 3072-dim vectors, strong multilingual support | ~$13/mo |

> **Note:** GPT-4o used for both agents due to superior Farsi/Arabic understanding. GPT-4.1-mini reserved for widget responses (English output). All via Azure AI Foundry (`irdecode-prod-openai`).

### 1.4 Multilingual Strategy

| Aspect | Approach |
| :--- | :--- |
| **Input Languages** | Farsi (Persian), Arabic, English |
| **Output Language** | English only (per PRD) |
| **Primary Model** | GPT-4o (best Farsi/Arabic comprehension) |
| **Embedding Model** | text-embedding-3-large (strong cross-lingual) |
| **Search Analyzers** | `fa.microsoft` (Farsi), `ar.microsoft` (Arabic), `en.microsoft` |
| **Claim Extraction** | Preserve original language + English translation |
| **RTL Handling** | Store original text with direction metadata |

### 1.5 Model Selection Rationale

| Requirement | GPT-4o | GPT-4.1-mini | o4-mini |
| :--- | :--- | :--- | :--- |
| ≥80% accuracy | ✅ 85%+ | ✅ 78-82% | ✅ 90%+ |
| <30s latency | ✅ 2-5s | ✅ <2s | ⚠️ 4-8s |
| **Farsi support** | ✅ **Excellent** | ✅ Good | ✅ Good |
| **Arabic support** | ✅ **Excellent** | ✅ Good | ✅ Good |
| RTL text handling | ✅ **Best** | ✅ Good | ✅ Good |
| Context window | 128K | 128K | 200K |
| Cost efficiency | Medium | High | Medium |

**Strategy:** 
- **GPT-4o** for Agent 1 & Agent 2 (Farsi/Arabic accuracy is critical for propaganda detection)
- **GPT-4.1-mini** for widget responses only (English output, speed priority)
- **o4-mini** for escalation cases requiring deep reasoning

### 1.6 Widget Hosting (Cloudflare Pages)

| Feature | Benefit |
| :--- | :--- |
| **Global CDN** | 300+ edge locations for <50ms latency |
| **Free tier** | Unlimited bandwidth, custom domains |
| **DDoS Protection** | Critical for activist target sites |
| **GitHub Integration** | Push-to-deploy from `/widgets` folder |
| **Preview Deployments** | PR previews for testing |

**Domain:** `widgets.nura-neural.com` → Cloudflare Pages  
**CORS:** Configured to allow requests to Azure n8n webhooks

---

## 2. System Architecture

### 2.1 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         INGESTION LAYER                             │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────────────┐  │
│  │  RSSHub  │──▶│ Miniflux │──▶│   n8n    │──▶│  SMRY Extractor  │  │
│  │ (scraper)│   │ (50+ RSS)│   │ (trigger)│   │   (clean text)   │  │
│  └──────────┘   └──────────┘   └──────────┘   └──────────────────┘  │
└─────────────────────────────────────┬───────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          STORAGE LAYER                              │
│  ┌────────────┐   ┌────────────────┐   ┌─────────┐   ┌───────────┐  │
│  │ PostgreSQL │   │ Azure AI Search│   │  Blob   │   │   Redis   │  │
│  │  (app DB)  │   │ (vectors+hybrid)│   │ Storage │   │  (cache)  │  │
│  └────────────┘   └────────────────┘   └─────────┘   └───────────┘  │
└─────────────────────────────────────┬───────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         ANALYSIS LAYER                              │
│  ┌─────────────────────┐        ┌─────────────────────┐             │
│  │   Agent 1 (GPT-4o)  │        │   Agent 2 (GPT-4o)  │             │
│  │  IMTT + Claims (FA/AR)│        │ Narrative Clustering │             │
│  └──────────┬──────────┘        └──────────┬──────────┘             │
│             └───────────┬───────────────────┘                       │
│                         ▼                                           │
│              ┌────────────────────┐                                 │
│              │  o4-mini (escalate)│                                 │
│              └────────────────────┘                                 │
└─────────────────────────────────────┬───────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          SERVING LAYER                              │
│  ┌────────────────┐   ┌─────────────────┐   ┌───────────────────┐   │
│  │ n8n Webhooks   │──▶│  Azure Front    │──▶│ GPT-4.1-mini      │   │
│  │ (API endpoints)│   │    Door (CDN)   │   │ (widget responses)│   │
│  └────────────────┘   └─────────────────┘   └───────────────────┘   │
└─────────────────────────────────────┬───────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          CLIENT LAYER                               │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │               Cloudflare Pages (widgets.nura-neural.com)      │  │
│  │    ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │  │
│  │    │ irdecode.com│  │Action4Iran  │  │  Embeddable iframes │  │  │
│  │    └─────────────┘  └─────────────┘  └─────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow

The system operates within a single **Azure Container Apps Environment**, utilizing internal service discovery for secure communication.

1.  **Ingestion Flow**:
    *   **RSSHub** (Internal App) scrapes regime media sites and generates RSS feeds. It caches results in **Redis**.
    *   **Miniflux** (App) polls 50+ feeds (standard RSS + RSSHub feeds) every 15 minutes and stores headers in **PostgreSQL**.
    *   **n8n** triggers a scheduled workflow:
        1.  Calls Miniflux API (Internal DNS) to get new unread items.
        2.  Sends URLs to **SMRY Service** (Internal App) to extract clean text.
        3.  Stores full content in **PostgreSQL** and **Blob Storage**.

2.  **Analysis Flow**:
    *   **Agent 1**: n8n triggers on new content → Queries **Azure AI Search** for context → Calls **GPT-4o** for IMTT scoring (Farsi/Arabic) → Extracts claims with English translation → Updates **PostgreSQL**.
    *   **Agent 2**: Scheduled n8n workflow (6h) → Fetches unclustered claims → Generates embeddings (multilingual) → Upserts to **Azure AI Search** → Calls **GPT-4o** to cluster narratives across languages.

3.  **Serving Flow**:
    *   **Public Widgets** (hosted on **Cloudflare Pages**) make requests to **n8n Webhook URLs** via Azure Front Door.
    *   n8n handles the request, queries Postgres/Azure AI Search (multilingual), calls **GPT-4.1-mini** for English responses.
    *   Responses cached in **Redis** (TTL: 1 hour) for <3s cached responses.

***

## 3. Data Models

### `sources`
*   `source_id` (PK): UUID
*   `domain`: e.g., `tasnimnews.com`
*   `name`: Display name
*   `name_original`: Name in original language (Farsi/Arabic)
*   `country`: `IR`, `IQ`, `SY`, etc.
*   `language`: Primary language (`fa`, `ar`, `en`)
*   `credibility_tier`: `propaganda`, `unverified`, `credible`
*   `imtt_scores`: JSONB `{independence: 0.2, methodology: 0.1...}`
*   `last_evaluated`: Timestamp

### `content`
*   `content_id` (PK): UUID
*   `source_id` (FK): Link to `sources`
*   `url`: Canonical URL
*   `title`: Headline (original language)
*   `title_en`: English translation
*   `content_text`: Extracted body text (original)
*   `content_text_en`: English translation (summary)
*   `language`: Detected language (`fa`, `ar`, `en`)
*   `text_direction`: `rtl` or `ltr`
*   `ingested_at`: Timestamp
*   `analysis_status`: `pending`, `complete`, `failed`

### `claims`
*   `claim_id` (PK): UUID
*   `content_id` (FK): Link to `content`
*   `claim_text`: Extracted assertion (original language)
*   `claim_text_en`: English translation
*   `language`: Claim language (`fa`, `ar`, `en`)
*   `claim_type`: `concrete`, `narrative`
*   `verification_status`: `verified`, `false`
*   `confidence`: Float (0.0-1.0)

### `narratives`
*   `narrative_id` (PK): UUID
*   `label`: Auto-generated label (English)
*   `label_fa`: Farsi label (if applicable)
*   `label_ar`: Arabic label (if applicable)
*   `cluster_size`: Count of articles
*   `languages`: Array of languages in cluster `['fa', 'ar']`
*   `timeline`: JSONB Array of dates/variants

***

## 4. API Endpoints (n8n Webhooks)

| Endpoint | Method | Purpose | Response Time |
| :--- | :--- | :--- | :--- |
| `/webhook/analyze` | POST | Full article analysis (Farsi/Arabic/English) | <30s |
| `/webhook/fact-check` | POST | Verify claim text/URL | <3s cached / <15s fresh |
| `/webhook/credibility` | GET | Source trust score by domain | <1s |
| `/webhook/narratives` | GET | Trending narratives list | <2s |
| `/webhook/narratives/:id` | GET | Narrative detail + timeline | <2s |
| `/webhook/search` | POST | Hybrid search across claims | <3s |

### Request/Response Examples

**POST /webhook/fact-check**
```json
// Request
{"text": "ایران ۵۰۰ کلاهک هسته‌ای دارد", "language": "fa"}

// Response
{
  "verdict": "false",
  "confidence": 0.92,
  "original_text": "ایران ۵۰۰ کلاهک هسته‌ای دارد",
  "translation": "Iran has 500 nuclear warheads",
  "evidence": [
    {"source": "IAEA Report 2025", "excerpt": "...", "url": "..."}
  ],
  "related_narratives": ["narrative_uuid_1"],
  "source_credibility": "propaganda"
}
```

**GET /webhook/credibility?domain=tasnimnews.com**
```json
{
  "domain": "tasnimnews.com",
  "name": "Tasnim News Agency",
  "name_original": "خبرگزاری تسنیم",
  "country": "IR",
  "language": "fa",
  "tier": "propaganda",
  "imtt": {"independence": 0.1, "methodology": 0.2, "transparency": 0.1, "triangulation": 0.15},
  "last_evaluated": "2026-01-30T12:00:00Z"
}
```

***

## 5. Cost Summary (Dev/MVP)

| Component | Dev (Monthly) | MVP (Monthly) |
| :--- | :--- | :--- |
| **Azure AI Search** | $75 (Basic) | $243 (S1) |
| **GPT-4o (Agent 1 + 2)** | $95 | $190 |
| **GPT-4.1-mini (Widgets)** | $3 | $5 |
| **o4-mini (Escalation)** | $8 | $15 |
| **Embeddings** | $7 | $13 |
| **Container Apps (new)** | $30 | $60 |
| **Cloudflare Pages** | Free | Free |
| **Total (new services)** | **~$218** | **~$526** |

> Existing infrastructure (PostgreSQL, n8n, Storage, Front Door, Key Vault) already provisioned under `irdecode-prod-rg`.

***

## 6. Folder Structure (Repo)

```
/nura-neural
├── /docs
│   ├── PRD.md                    # Product Requirements
│   └── architecture.md           # This document
├── /infrastructure
│   ├── main.tf                   # Terraform: Azure AI Search, Container Apps
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Deployment outputs
│   └── terraform.tfvars.example  # Config template
├── /workflows
│   ├── 01_ingestion.json         # n8n: Miniflux → PostgreSQL pipeline
│   ├── 02_agent_source.json      # n8n: Agent 1 IMTT evaluation (GPT-4o)
│   ├── 03_agent_narrative.json   # n8n: Agent 2 clustering (GPT-4o)
│   ├── 04_escalation.json        # n8n: o4-mini escalation
│   └── 05_public_api.json        # n8n: Webhook endpoints (GPT-4.1-mini)
├── /services
│   └── /text-extractor
│       ├── Dockerfile
│       ├── server.js
│       └── package.json
├── /widgets                      # Deployed via Cloudflare Pages
│   ├── /src
│   │   ├── fact-check.js
│   │   ├── credibility-badge.js
│   │   ├── narrative-tracker.js
│   │   └── propaganda-detector.js
│   ├── /styles
│   └── index.html                # Test harness
├── /database
│   └── schema.sql                # PostgreSQL init script (multilingual)
└── README.md
```

***

## 7. Security & Compliance

| Concern | Mitigation |
| :--- | :--- |
| **API Keys** | Stored in Azure Key Vault (`irdecode-prod-kv`), rotated quarterly |
| **Data in Transit** | TLS 1.3 (Front Door → ACA → Services) |
| **Data at Rest** | Azure-managed encryption (PostgreSQL, Blob, Search) |
| **Azure OpenAI Data** | No training on customer data; data stays in Azure |
| **Persian/Arabic Political Content** | Human-in-the-loop for escalation; audit logs |
| **Widget Security** | Cloudflare DDoS protection; CORS restricted to known domains |
| **Access Control** | n8n behind Front Door with WAF; internal services not exposed |

***

## 8. Monitoring & Alerts

| Metric | Threshold | Alert |
| :--- | :--- | :--- |
| n8n Workflow Failures | >5/hour | PagerDuty |
| Azure AI Search Latency | >500ms p95 | Email |
| GPT-4o Token Usage | >80% quota | Slack |
| Widget Response Time | >5s | Log Analytics |
| PostgreSQL Connections | >80% pool | Email |
| Cloudflare Error Rate | >1% | Cloudflare Alerts |

### 1.3 TwitterAPI.io Integration

| Feature | Endpoint | Use Case |
| :--- | :--- | :--- |
| **User Tweets** | `/twitter/user/tweets` | Monitor regime account posts |
| **User Replies** | `/twitter/user/replies` | Track engagement patterns |
| **User Mentions** | `/twitter/user/mentions` | Find discussions about sources |
| **User Likes** | `/twitter/user/likes` | Analyze network behavior |
| **Search** | `/twitter/search` | Keyword tracking (Farsi/Arabic) |

**Configuration:**
- **Plan:** Growth ($100/mo) - 150K requests/month
- **Polling:** Every 30 minutes per monitored account (during evaluation)
- **Accounts:** ~50 regime-linked accounts
- **Keywords:** ~100 Farsi/Arabic keywords
- **n8n Integration:** HTTP Request node with API key

**n8n HTTP Request Example:**
```json
{
  "method": "GET",
  "url": "https://api.twitterapi.io/twitter/user/tweets",
  "headers": {"X-API-Key": "{{$credentials.twitterApiIoKey}}"},
  "qs": {"userName": "khaboronline", "count": 100}
}
```
