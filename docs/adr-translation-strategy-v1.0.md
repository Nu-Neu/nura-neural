---
doc_type: adr
version: 1.0
last_updated: 2026-02-03
owner: Architecture Team
status: approved
---

# ADR-002: Multi-Language Ingestion & Translation Strategy

## 1. Context
Nura ingests content in Persian (FA), Arabic (AR), and English (EN). Our target audience requires English output, but we must ingest Persian sources to capture local narratives. We need a cost-effective strategy to translate content without blowing the budget on irrelevant news.

## 2. Decision
We will implement a **"Filtered Eager Translation"** strategy using `GPT-4o-mini`.

### 2.1 Layer 0: Zero-Cost Filtering (Miniflux)
To minimize API costs, we will block irrelevant content *before* it enters our system using Miniflux's built-in rule engine.
- **Mechanism:** Miniflux `Block Rules` (Regex).
- **Pattern:** `(فوتبال|لیگ برتر|سینما|کنسرت|بازیگر|فال|استقلال|پرسپولیس|قیمت خودرو|حوادث)`
- **Goal:** Discard ~80-90% of "Yellow/Sports" news at the source.

### 2.2 Layer 1: AI Translation
For items that pass the filter:
1. **Check Language:** If `lang == 'en'`, skip translation.
2. **Translate:** If `lang in ['fa', 'ar']`:
   - **Model:** `GPT-4o-mini`.
   - **Rationale:** At $0.15/1M tokens, it is significantly cheaper and higher quality for Persian than Azure Translator or Llama-3-8B.
   - **Prompt:** "Translate to objective, journalistic English. Preserve all entities (names, places) exactly."
3. **Persist:** Store **BOTH** original and translated text in `items` table.

### 2.3 Data Schema Update
The `items` table will support:
- `title` (Original)
- `bodytext` (Original)
- `title_en` (English / Translated)
- `bodytext_en` (English / Translated)
- `language` (e.g., 'fa')

## 3. Consequences
- **Financial:** translation costs are capped by Miniflux filtering. Only high-value political/social news incurs AI cost.
- **Operational:** We maintain a unified English vector space for clustering, while preserving original Persian text for user verification and activist use cases.
