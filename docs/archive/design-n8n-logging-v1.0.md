---
doc_type: design
version: 1.1
last_updated: 2026-02-03
owner: NURA Backend Team
status: draft
---

# Design Spec: N8N Basic Logging System

## 1. Context [Ref: REQ-LOG-001]
Currently, N8N workflows fail or behave unexpectedly without leaving a persistent trace. We need a standardized logging mechanism that captures system errors and logic states, but avoids cluttering the database with unnecessary logs during normal operation.

## 2. Solution Strategy
We will implement a "Hybrid Logging Pattern" with **Selective Logging Capabilities**:
1.  **Centralized Error Workflow**: Always triggers on failure.
2.  **Explicit Logger Sub-workflow**: A callable workflow that respects a global `LOG_LEVEL` configuration to filter messages dynamically [web:76].

### 2.1 Architecture Diagram

```mermaid
sequenceDiagram
    participant SourceWF as Source Workflow
    participant LogWF as Logger Sub-Workflow
    participant Env as Env Vars / Config
    participant DB as Log Storage

    Note over SourceWF: Normal Execution
    SourceWF->>LogWF: Call (Level: DEBUG, Msg: "Payload received")
    
    rect rgb(240, 248, 255)
    Note right of LogWF: Filtering Logic
    LogWF->>Env: Check NURA_LOG_LEVEL
    alt Level >= Configured Level
        LogWF->>DB: Insert Log Entry
    else Level < Configured Level
        LogWF-->>SourceWF: Skip (No Action)
    end
    end
