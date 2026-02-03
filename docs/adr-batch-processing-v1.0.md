---
doc_type: adr
version: 1.0
last_updated: 2026-02-03
owner: Architecture Team
status: approved
---

# ADR-001: Adoption of Batch Processing for AI Model Inference

## 1. Context & Problem Statement
The NURA platform requires extensive use of Large Language Models (LLMs) for tasks such as content summarization, entity extraction, and data classification. 

Reliance on **Synchronous APIs** (Request/Response) creates two critical issues:
1.  **High Operational Cost**: Real-time inference is priced at a premium.
2.  **Scalability Bottlenecks**: Synchronous endpoints have strict Rate Limits (RPM/TPM), causing `429 Too Many Requests` errors during bulk data processing.

We need an architectural pattern that decouples processing time from submission time to optimize for cost and throughput.

## 2. Decision
We will enforce the use of **Asynchronous Batch APIs** (e.g., OpenAI Batch API, Anthropic Message Batches) for all **non-interactive** workloads.

### Key Architectural Changes
-   **Default Strategy**: Any feature not requiring sub-second latency must use the Batch API.
-   **Queue Mechanism**: The system will implement a "Store-and-Forward" pattern:
    1.  **Accumulate**: Workers collect tasks into a staging buffer.
    2.  **Dispatch**: A scheduled job aggregates tasks into a JSONL file and uploads it to the provider.
    3.  **Poll**: A separate poller checks status and retrieves results upon completion.
    4.  **Reconcile**: Results are mapped back to original records in the database.

## 3. Consequences

### Positive Impacts
-   **Cost Efficiency**: Direct **50% reduction** in token costs [Ref: REQ-BATCH-001].
-   **Resilience**: Decoupled architecture prevents cascading failures due to provider rate limits [Ref: REQ-BATCH-002].
-   **Throughput**: Ability to process millions of tokens concurrently without HTTP connection overhead.

### Negative Impacts / Trade-offs
-   **Latency**: Service Level Agreement (SLA) for these tasks changes from "Immediate" to "Within 24 Hours".
-   **Complexity**: Requires state management (Processing -> Uploaded -> Completed -> Failed) which is more complex than a simple synchronous call.

## 4. Technical Design

### Data Flow Diagram

```mermaid
sequenceDiagram
    participant App as Application Core
    participant DB as Database (Queue)
    participant BatchSvc as Batch Service
    participant AI as AI Provider

    Note over App, DB: Phase 1: Accumulation
    App->>DB: Enqueue Task (Status: PENDING)
    
    Note over BatchSvc, AI: Phase 2: Dispatch (Cron Job)
    BatchSvc->>DB: Fetch PENDING tasks
    BatchSvc->>BatchSvc: Generate .jsonl File
    BatchSvc->>AI: Upload Batch File
    AI-->>BatchSvc: Return Batch ID
    BatchSvc->>DB: Update Status: SUBMITTED
    
    Note over BatchSvc, AI: Phase 3: Reconciliation
    loop Every 15 Mins
        BatchSvc->>AI: Check Status (Batch ID)
        alt is Completed
            BatchSvc->>AI: Download Results
            BatchSvc->>DB: Update Records & Trigger Events
        end
    end
