---
doc_type: design
version: 1.0
last_updated: 2026-02-03
owner: ریحانه (DB Specialist), امیر (Software Architect)
status: draft
traceability: [Ref: ADR-009], [Ref: HLD-v2.1]
---

# Workflow: PostgreSQL to Azure AI Search Sync

## Overview

این مستند workflow همگام‌سازی داده بین PostgreSQL (source of truth) و Azure AI Search (search index) را توضیح می‌دهد.

### Purpose
- نگه‌داشتن Azure AI Search Free Tier sync با PostgreSQL
- فقط recent + high-trust items را index کردن (بهینه‌سازی فضا)
- Fallback به PostgreSQL برای historical queries

### Scope
- **In Scope:** Incremental sync, error handling, monitoring
- **Out of Scope:** Full rebuild (سند جداگانه)

---

## Architecture Overview

### System Components

PostgreSQL (Master) → n8n Sync Workflow → Azure AI Search (Free Tier)
                              ↓
                          Redis Cache
                          (State & Locks)

### Key Constraints

**Azure AI Search Free Tier Limits:**
- Storage: 50 MB max
- Documents: 10,000 max
- QPS: 3 max

**Our Strategy:**
- Index only: 14 days recent + trust_score >= 50
- Expected size: ~28 MB (56% of limit)
- Expected docs: ~4,200 (42% of limit)

---

## Data Flow

### Stage 1: Source Query (PostgreSQL)

**Query eligible items:**
```sql

SELECT 
    id,
    title,
    summary,
    embedding,
    trust_score,
    publish_date,
    source_name,
    url,
    language
FROM items
WHERE 
    publish_date >= NOW() - INTERVAL '14 days'
    AND trust_score >= 50
    AND deleted_at IS NULL
ORDER BY publish_date DESC;
```

**Filters:**
- Age: <= 14 days
- Trust: >= 50 (Medium+ quality)
- Status: Not deleted

---

### Stage 2: Transform (n8n)

**Optimization:**
- Remove body_text (save ~2 KB per doc)
- Truncate summary to 300 chars
- Keep embedding (required for vector search)

**Transform function:**
```javascript

function transformForAISearch(item) {
    return {
        id: item.id,
        title: item.title,
        summary: item.summary.substring(0, 300),
        embedding: item.embedding,
        trustScore: item.trust_score,
        publishDate: item.publish_date,
        sourceName: item.source_name,
        url: item.url,
        language: item.language
    };
}
```

---

### Stage 3: Upload (Azure AI Search)

**Method:** Batch upsert (merge or upload)  
**Batch size:** 100 documents  
**Concurrency:** 3 parallel batches

---

## Sync Strategies

### 1. Incremental Sync (Primary)

**Schedule:** Every 15 minutes  
**Trigger:** Cron  
**Method:** Delta detection using cursor

**Logic:**
1. Get last sync timestamp from Redis
2. Query PostgreSQL for items updated since cursor
3. Transform to AI Search format
4. Batch upload to AI Search
5. Update cursor in Redis
6. Log metrics

**Expected volume per run:**
- New items: ~125 (500/day ÷ 96 runs)
- Updates: ~50 (trust score changes)
- Total: ~175 documents

**Implementation notes:**
- n8n workflow: "Incremental Sync PG to AI"
- Execution time: 3-5 seconds
- Retry: 3 attempts with exponential backoff

---

### 2. Daily Cleanup

**Schedule:** Daily at 2 AM NZDT  
**Purpose:** Remove old or low-trust items

**Logic:**
1. Calculate cutoff: 14 days ago
2. Query AI Search for items older than cutoff OR trust < 50
3. Batch delete
4. Monitor index size
5. Alert if approaching limits

**Expected volume:**
- Deleted per day: ~500 items
- Space freed: ~3.5 MB/day

**Safety checks:**
- Alert at 90% storage (45 MB)
- Alert at 90% documents (9,000)

---

### 3. Full Rebuild (Manual)

**Trigger:** Manual only  
**Use cases:** Schema changes, corruption, major bugs

**Steps:**
1. Create new index with updated schema
2. Query ALL eligible items from PostgreSQL
3. Batch upload to new index
4. Validate counts and size
5. Switch application config (zero downtime)
6. Delete old index

**Duration:** 30-60 minutes  
**Downtime:** 0 (blue/green deployment)

---

## Error Handling

### Error Categories

| Error | Severity | Retry | Alert |
|-------|----------|-------|-------|
| Network timeout | Low | 3x | Slack if all fail |
| Rate limit 429 | Medium | Wait 60s | Log only |
| Document too large | Medium | Truncate, retry | Slack |
| Index full 50MB | **High** | Stop sync | PagerDuty |
| PostgreSQL down | **Critical** | Stop | PagerDuty |

### Retry Configuration

- Max attempts: 3
- Initial delay: 1 second
- Max delay: 60 seconds
- Backoff: Exponential (2x)

### Dead Letter Queue (DLQ)

**Storage:** Redis List  
**Key:** `sync:failed:items`  
**TTL:** 7 days  
**Max size:** 1,000 items

**Manual processing:** Weekly review and replay

---

## Conflict Resolution

### Scenario 1: Item Updated in Both

**Resolution:** PostgreSQL wins (always)  
**Method:** Upsert overwrites AI Search

### Scenario 2: Item Deleted in PostgreSQL

**Resolution:** Delete from AI Search  
**Detection:** Check deleted_at flag

### Scenario 3: Trust Score Dropped

**Resolution:** Delete from AI Search  
**Detection:** trust_score < 50 in update

---

## Monitoring

### Real-Time Metrics (Redis)

Keys:
- `sync:pg-to-ai:last_run` - Last successful sync time
- `sync:pg-to-ai:items_today` - Items synced today
- `sync:pg-to-ai:errors_today` - Error count
- `sync:failed:items` - Failed items queue

### Alerts (Azure Monitor)

**Alert 1: Sync Failures**  
Condition: errors_today > 5  
Action: Slack notification

**Alert 2: Index Size Critical**  
Condition: size_mb > 45 (90%)  
Action: PagerDuty + auto-cleanup

**Alert 3: Sync Stopped**  
Condition: last_run > 30 min ago  
Action: PagerDuty

---

## Manual Operations

### Pause Sync
```bash

# Set pause flag
redis-cli SET sync:pg-to-ai:paused 1

# Or disable n8n workflow
curl -X PATCH n8n-api/workflows/{id} -d '{"active": false}'
```

### Resume Sync
```bash

redis-cli DEL sync:pg-to-ai:paused
```

### Force Full Resync
```bash

# Reset cursor
redis-cli DEL sync:pg-to-ai:last_run

# Next run will sync all items from last 14 days
```

---

## Performance Tuning

### Batch Size

Current: 100 docs/batch  
Range: 50-200 docs/batch  
Optimize for: Network latency vs processing time

### Concurrency

Current: 3 parallel batches  
Max: 5 (to stay under 3 QPS limit)

### Incremental Embedding Updates

Only sync items where embedding actually changed (saves bandwidth)

---

## Testing

### Unit Tests
- Transform function
- Batch chunking
- Retry logic
- Error handling

### Integration Tests
- Full sync cycle (insert → sync → verify)
- Update cycle (update → sync → verify)
- Delete cycle (delete → sync → verify deleted)
- Index size validation

---

## Runbook: Common Issues

### Issue 1: Sync Lag

**Symptoms:** Last sync > 1 hour ago

**Diagnosis:**
```bash

redis-cli GET sync:pg-to-ai:last_run
curl n8n-api/executions?workflowId={id}
```

**Resolution:** Manually trigger sync or reset cursor

### Issue 2: Index Full

**Symptoms:** Upload errors "QuotaExceeded"

**Resolution:**
```bash

python scripts/emergency_cleanup.py --max-age-days 10
```

---

## Security

### Secrets (Azure Key Vault)
- azure-search-endpoint
- azure-search-admin-key  
- postgresql-connection-string
- redis-connection-string

### Access Control
- n8n: Managed Identity
- Scripts: Service Principal (least privilege)
- Key rotation: Quarterly

---

## Success Metrics

### Week 1 (Post-implementation)
- Sync success rate: > 99%
- Average sync duration: < 10 seconds
- Index size: < 30 MB
- Document count: 4,000-5,000

### Week 4 (Steady state)
- Sync success rate: > 99.5%
- Cache hit rate: > 40%
- Index size stable: 28-35 MB
- Zero manual interventions

---

## References

- [Ref: ADR-009] Cost Optimization
- [Ref: HLD-v2.1] System Architecture
- [Azure AI Search Indexing](https://learn.microsoft.com/azure/search/)
- [n8n PostgreSQL Node](https://docs.n8n.io/)

---

## Changelog

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-03 | ریحانه + امیر | Initial draft |

---

**Status:** 📝 DRAFT  
**Owner:** ریحانه  
**Next Review:** Week 2 (post-implementation)

