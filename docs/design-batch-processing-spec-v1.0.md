---
doc_type: design
version: 1.0
last_updated: 2026-02-03
owner: Architecture Team
status: approved
---

# Technical Spec: AI Batch Processing Service

## 1. Overview
This document specifies the technical implementation details for the Asynchronous Batch Processing system defined in [Ref: ADR-001]. It covers the database schema, state transitions, and internal service interfaces.

## 2. Database Schema (ERD)

We require two main tables: one to track the **Batch Job** (the file uploaded to the provider) and one to track individual **Batch Items** (the specific requests inside that file).

### Table: `batch_jobs`
Represents a single `.jsonl` file uploaded to the AI provider.

| Column | Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PK | Internal unique identifier. |
| `provider_id` | VARCHAR(255) | YES | The ID returned by OpenAI/Anthropic (e.g., `batch_abc123`). |
| `provider_name` | ENUM | NO | 'OPENAI', 'ANTHROPIC'. |
| `status` | ENUM | NO | Current state of the batch (see State Machine). |
| `input_file_id` | VARCHAR(255) | YES | ID of the uploaded file on provider side. |
| `output_file_id` | VARCHAR(255) | YES | ID of the result file on provider side. |
| `created_at` | TIMESTAMP | NO | When the batch record was created. |
| `completed_at` | TIMESTAMP | YES | When the provider finished processing. |

### Table: `batch_items`
Represents a single logical task (e.g., summarizing one document) linked to a batch job.

| Column | Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PK | Internal unique identifier. |
| `batch_job_id` | UUID | FK | Links to `batch_jobs.id`. |
| `custom_id` | VARCHAR(255) | NO | Correlation ID sent to provider (e.g., `req-123`). |
| `request_payload` | JSONB | NO | The actual prompt/data sent. |
| `response_payload` | JSONB | YES | The result received from provider. |
| `status` | ENUM | NO | 'PENDING', 'COMPLETED', 'FAILED'. |
| `retry_count` | INT | NO | Default 0. Used for error handling. |

```mermaid
erDiagram
    batch_jobs ||--|{ batch_items : contains
    batch_jobs {
        uuid id PK
        string provider_id
        enum status
        timestamp created_at
    }
    batch_items {
        uuid id PK
        uuid batch_job_id FK
        string custom_id
        jsonb request_payload
        jsonb response_payload
    }
