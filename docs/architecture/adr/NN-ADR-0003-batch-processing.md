---
doc_type: adr
version: 1.0
last_updated: 2026-02-04
owner: Nura Neural Team
status: approved
---

# NN-ADR-0003: Asynchronous Batch Processing for AI

- **Status**: Approved
- **Context**: Many AI tasks, like historical data analysis or bulk content classification, do not require real-time, sub-second responses. Using synchronous (request/response) APIs for these tasks is expensive and can lead to rate-limiting issues (`429 Too Many Requests`).
- **Decision**: We will use **Asynchronous Batch APIs** for all non-interactive AI workloads. The system will follow a "Store-and-Forward" pattern:
    1.  **Accumulate**: Tasks are enqueued in a database table with a `PENDING` status.
    2.  **Dispatch**: A scheduled n8n workflow aggregates pending tasks into a `.jsonl` file and uploads it to the AI provider's Batch API.
    3.  **Reconcile**: A separate poller checks the batch job status and writes the results back to the database upon completion.
- **Consequences**:
  - **Positive**: Reduces AI processing costs by up to 50%. Decouples the system from provider rate limits, increasing reliability for bulk operations.
  - **Negative**: The SLA for batch tasks changes from "instant" to "within 24 hours." This requires the UI to handle an intermediate "processing" state for items in the batch queue.
