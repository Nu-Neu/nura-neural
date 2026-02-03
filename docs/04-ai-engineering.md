---
doc_type: ai_engineering
version: 1.0
last_updated: 2026-02-04
owner: Nura AI Team
status: draft
---

# AI Engineering & Core Logic v1.0

This document centralizes the core algorithms, prompts, and parameters that define the Nura Neural AI engine.

## 1. Trust Scoring Engine

The Trust Scoring Engine is a deterministic algorithm that assigns a credibility score to every ingested news item. It replaces subjective judgment with a transparent, formula-driven approach.

### 1.1. Scoring Formula
The final score is a weighted sum of four components, clamped between 15 and 95.

`Final_Score = CLAMP(15, 95, [Base_Score + Provenance_Score + Corroboration_Score + Transparency_Score])`

| Component | Weight | Description |
|:---|:---|:---|
| **Base Score** | 45% | The inherent credibility of the source, based on its classification. |
| **Provenance** | 20% | The quality and clarity of the sourcing within the article itself. |
| **Corroboration** | 25% | The degree to which other independent, high-trust sources report the same facts. |
| **Transparency** | 10% | Penalties for anonymous authors or a lack of clear publication dates. |

### 1.2. Source Classification & Base Scores
The `source_class` is the most significant factor in the trust score. It is a strict enumeration that determines the starting `base_score`.

| Class (Enum) | Subclass (Enum) | Base Score (0-100) |
|:---|:---|:---|
| `INTL_WIRE` | `GLOBAL_WIRE` (e.g., Reuters, AP) | 95-100 |
| `NGO_WATCHDOG` | `HUMAN_RIGHTS_INTL` (e.g., Amnesty) | 90-95 |
| `MAINSTREAM_DIASPORA`| `INTL_BROADCASTER` (e.g., BBC Persian) | 75-80 |
| `ACTIVIST_CITIZEN` | `CITIZEN_VERIFIED` (e.g., 1500tasvir) | 60-65 |
| `REGIME_MEDIA` | `STATE_NEWS_AGENCY` (e.g., IRNA) | 35-40 |
| `GREY_TABLOID` | `ANONYMOUS_TELEGRAM` | 20-30 |

## 2. Narrative Clustering Engine

The platform uses a hybrid approach to group related articles into "narratives."

### 2.1. Vector Search Parameters
- **Vectorization Model**: `text-embedding-3-small` (512 dimensions).
- **Vector Store**: PostgreSQL with the `pgvector` extension.
- **Indexing Algorithm**: **HNSW** (Hierarchical Navigable Small World).
  - `m`: 16 (number of connections per layer).
  - `ef_construction`: 64 (quality of the graph build).
- **Similarity Search**:
  - **Metric**: Cosine Distance.
  - **Threshold**: A new item is considered a candidate for an existing cluster if its similarity score is `> 0.85`.

### 2.2. Clustering Logic
1.  **Candidate Search**: For a new article, perform a vector search to find the top 5 most similar articles already in a narrative.
2.  **Entity Overlap**: Check if the new article shares key named entities (Persons, Locations) with the candidate narrative.
3.  **LLM Verification**: If similarity is high but entity overlap is low, use a final check with `GPT-5-nano` to ask: "Does this article discuss the same core event as this summary?"

## 3. Core AI Prompts

### 3.1. Metadata Extraction Prompt
- **Model**: `GPT-5-nano`
- **Purpose**: To extract structured data from raw article text.
- **Prompt**:
  ```
  You are a precise data extraction engine. From the following text, extract the author, a 1-2 sentence summary, and key named entities (people, locations, organizations). Respond ONLY in JSON format.

  Text: "{article_text}"

  JSON Output:
  {
    "author": "...",
    "summary": "...",
    "entities": {
      "people": [],
      "locations": [],
      "organizations": []
    }
  }
  ```

### 3.2. Narrative Title Generation Prompt
- **Model**: `GPT-5-nano`
- **Purpose**: To create a concise, descriptive title for a new narrative cluster.
- **Prompt**:
  ```
  You are a news editor. Based on this collection of headlines, write a short, neutral, 4-6 word title for the overall event.

  Headlines:
  - "{headline_1}"
  - "{headline_2}"
  - "{headline_3}"

  Title:
  ```
