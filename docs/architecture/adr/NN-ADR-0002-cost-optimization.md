---
doc_type: adr
version: 1.0
last_updated: 2026-02-04
owner: Nura Neural Team
status: approved
---

# NN-ADR-0002: Cost Optimization Strategy

- **Status**: Approved
- **Context**: The initial architecture (`HLD-v2.0`) projected a monthly cost of ~$295, creating a limited runway on the project's $5,000 budget. Key cost drivers were the Azure AI Search "Basic" tier ($75/mo) and the use of `GPT-4o-mini` for all AI tasks (~$30/mo).
- **Decision**: We will implement a series of aggressive cost-optimization measures:
    1.  **Downgrade AI Search**: Move from the "Basic" SKU to the **Free Tier**. This is feasible by implementing a 14-day retention policy for indexed data.
    2.  **Change Primary LLM**: Migrate from `GPT-4o-mini` to the more cost-effective **`GPT-5-nano`** for all structured data extraction and classification tasks. `GPT-4o-mini` will be reserved for complex, edge-case reasoning.
    3.  **Enable RAG with Cost Controls**: The cost savings from the above decisions make it financially viable to implement a Retrieval-Augmented Generation (RAG) chat feature, with strict token limits and usage caps.
- **Consequences**:
  - **Positive**: Reduces estimated monthly costs from ~$295 to **~$38**, extending the financial runway by over 3.5 years. Unlocks the ability to build a key user-facing feature (RAG Chat).
  - **Negative**: The free tier of AI Search has no semantic ranking and lower QPS limits, requiring the application to handle more complex scoring logic and be resilient to potential throttling.
