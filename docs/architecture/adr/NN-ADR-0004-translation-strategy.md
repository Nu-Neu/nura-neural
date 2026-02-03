---
doc_type: adr
version: 1.0
last_updated: 2026-02-04
owner: Nura Neural Team
status: approved
---

# NN-ADR-0004: Multi-Language Ingestion & Translation

- **Status**: Approved
- **Context**: The platform must ingest content in Persian (FA) and Arabic (AR) to capture local narratives, but the core analysis engine and user-facing UI operate in English. Translating all ingested content would be cost-prohibitive.
- **Decision**: We will implement a **"Filtered Eager Translation"** strategy.
    1.  **Zero-Cost Pre-Filtering**: We will use the rule engine in our RSS aggregator (Miniflux) to block irrelevant content (e.g., sports, celebrity news) *before* it enters our system, using a blocklist of keywords.
    2.  **AI Translation**: For content that passes the filter, we will use `GPT-4o-mini` for translation, as it offers the best balance of quality and cost for Persian.
    3.  **Dual Storage**: The database will store both the original language content (`title`, `body`) and the translated English version (`title_en`, `body_en`) to allow for user verification.
- **Consequences**:
  - **Positive**: AI translation costs are significantly reduced by filtering out irrelevant content at the source. The system maintains a unified English vector space for analysis while preserving the original text for user trust and verification.
  - **Negative**: The initial keyword-based filtering may occasionally block relevant articles or miss irrelevant ones, requiring periodic tuning of the blocklist.
