---
doc_type: deploy
version: 1.0
last_updated: 2026-02-03
owner: ریحانه (DB Specialist)
status: draft
traceability: [Ref: ADR-009], [Ref: HLD-v2.1], [Ref: workflow-pg-to-ai-search-sync-v1.0]
---

# Migration Plan: Azure AI Search Basic → Free Tier

## Executive Summary

**Objective:** Migrate Azure AI Search from Basic SKU ($75/mo) to Free Tier ($0/mo) with zero downtime.

**Cost Savings:** $75/month × 32 months = $2,400

**Timeline:** 
- Preparation: 2 days
- Execution: 4 hours
- Validation: 1 week

**Risk Level:** Low (Blue/Green deployment, instant rollback available)

---

## Pre-Migration Checklist

### Prerequisites

**Documentation:**
- [x] ADR-009 approved
- [x] Workflow document completed
- [x] Runbook prepared
- [ ] Team trained on new architecture

**Infrastructure:**
- [ ] Free Tier instance created
- [ ] Optimized index schema prepared
- [ ] Backup of current index completed
- [ ] Rollback plan documented

**Communication:**
- [ ] Team notified (48 hours advance)
- [ ] Stakeholders informed
- [ ] Maintenance window scheduled
- [ ] On-call schedule confirmed

**Testing:**
- [ ] Staging environment tested
- [ ] Performance benchmarks established
- [ ] Rollback procedure tested
- [ ] Monitoring dashboards ready

---

## Migration Strategy

### Approach: Blue/Green Deployment

**Why Blue/Green?**
- Zero downtime
- Instant rollback capability
- Parallel validation before cutover
- Reduced risk

**Architecture:**

```
Current (Blue):                    New (Green):
┌─────────────────┐              ┌─────────────────┐
│ AI Search       │              │ AI Search       │
│ Basic SKU       │              │ Free Tier       │
│ $75/mo          │              │ $0/mo           │
│                 │              │                 │
│ • Full data     │              │ • Optimized     │
│ • 2 GB storage  │              │ • 50 MB storage │
└─────────────────┘              └─────────────────┘
        ▲                                  ▲
        │                                  │
        │        ┌──────────┐             │
        └────────│ FastAPI  │─────────────┘
                 │ (switch) │
                 └──────────┘
```

**Cutover Method:** 
- Config change only (environment variable)
- Rolling restart (zero downtime)
- Instant rollback if issues

---

## Timeline & Milestones

### Day -2 (Friday): Preparation

**09:00 - 12:00: Infrastructure Setup**
```bash
# 1. Create Free Tier instance
az search service create \
  --name nura-search-free \
  --resource-group nura-rg \
  --sku free \
  --location australiaeast \
  --partition-count 1 \
  --replica-count 1

# 2. Wait for provisioning (5-10 min)
az search service show \
  --name nura-search-free \
  --resource-group nura-rg \
  --query provisioningState

# Expected output: "Succeeded"
```

**12:00 - 14:00: Schema Creation**

```bash
# Create optimized index
az search index create \
  --service-name nura-search-free \
  --name items-optimized \
  --fields @schema-optimized.json

# Verify schema
az search index show \
  --service-name nura-search-free \
  --name items-optimized
```

**Schema file (schema-optimized.json):**
```json
{
  "name": "items-optimized",
  "fields": [
    {"name": "id", "type": "Edm.String", "key": true},
    {"name": "title", "type": "Edm.String", "searchable": true},
    {"name": "summary", "type": "Edm.String", "searchable": true},
    {"name": "embedding", "type": "Collection(Edm.Single)", 
     "dimensions": 1536, "vectorSearchProfile": "default"},
    {"name": "trustScore", "type": "Edm.Int32", "filterable": true},
    {"name": "publishDate", "type": "Edm.DateTimeOffset", 
     "filterable": true, "sortable": true},
    {"name": "sourceName", "type": "Edm.String", "filterable": true},
    {"name": "url", "type": "Edm.String"},
    {"name": "language", "type": "Edm.String", "filterable": true}
  ],
  "vectorSearch": {
    "profiles": [
      {"name": "default", "algorithm": "hnsw"}
    ],
    "algorithms": [
      {"name": "hnsw", "kind": "hnsw", 
       "hnswParameters": {"m": 4, "efConstruction": 400}}
    ]
  }
}

```

**Key optimizations:**
- ❌ Removed: body_text (saves ~2 KB per doc)
- ✅ Kept: summary (truncated to 300 chars)
- ✅ Kept: embedding (required for vector search)
- HNSW config: m=4 (lower memory footprint)

**14:00 - 17:00: Backup Current Index**

```bash

#!/bin/bash
# scripts/backup_ai_search_index.sh

echo "Starting backup of Basic tier index..."

# 1. Export all documents
az search query \
  --service-name nura-search-basic \
  --index-name items \
  --search "*" \
  --select "*" \
  --top 50000 \
  --output json > backup_$(date +%Y%m%d_%H%M%S).json

# 2. Compress backup
gzip backup_*.json

# 3. Upload to Azure Blob Storage
az storage blob upload \
  --account-name nurastorage \
  --container-name backups \
  --name ai-search-backup-$(date +%Y%m%d).json.gz \
  --file backup_*.json.gz

echo "✅ Backup completed"
```

**Verify backup:**
- File size: ~100-200 MB (compressed)
- Document count matches production
- Stored in Azure Blob (30-day retention)

---

### Day -1 (Saturday): Data Migration & Testing

**10:00 - 12:00: Initial Data Load**

```python

#!/usr/bin/env python3
# scripts/migrate_to_free_tier.py

import psycopg2
from azure.search.documents import SearchClient
from azure.core.credentials import AzureKeyCredential

# Connect to PostgreSQL
pg_conn = psycopg2.connect(os.environ['PG_CONNECTION_STRING'])

# Connect to Free Tier AI Search
search_client = SearchClient(
    endpoint=os.environ['AZURE_SEARCH_FREE_ENDPOINT'],
    index_name='items-optimized',
    credential=AzureKeyCredential(os.environ['AZURE_SEARCH_FREE_KEY'])
)

def migrate():
    print("Querying eligible items from PostgreSQL...")

    query = """
        SELECT 
            id::text as id,
            title,
            SUBSTRING(summary, 1, 300) as summary,
            embedding,
            trust_score as trustScore,
            publish_date as publishDate,
            source_name as sourceName,
            url,
            language
        FROM items
        WHERE 
            publish_date >= NOW() - INTERVAL '14 days'
            AND trust_score >= 50
            AND deleted_at IS NULL
        ORDER BY publish_date DESC
    """

    cursor = pg_conn.cursor()
    cursor.execute(query)

    items = []
    for row in cursor.fetchall():
        items.append(dict(zip([d[0] for d in cursor.description], row)))

    print(f"Found {len(items)} eligible items")

    # Upload in batches
    batch_size = 100
    for i in range(0, len(items), batch_size):
        batch = items[i:i+batch_size]
        search_client.upload_documents(documents=batch)
        print(f"Uploaded batch {i//batch_size + 1}/{(len(items)//batch_size)+1}")

    # Verify
    stats = search_client.get_document_count()
    print(f"✅ Migration complete: {stats} documents indexed")

    return stats

if __name__ == '__main__':
    migrate()
```

**Expected Results:**
- Documents indexed: ~4,200
- Index size: ~28 MB
- Duration: 10-15 minutes

**12:00 - 14:00: Validation Testing**

```python

#!/usr/bin/env python3
# scripts/validate_free_tier.py

def validate_search_quality():
    test_queries = [
        "زاهدان",
        "مهسا امینی", 
        "اعتراضات",
        "HRANA",
    ]

    for query in test_queries:
        # Search on Basic (baseline)
        basic_results = basic_search_client.search(query, top=10)

        # Search on Free (new)
        free_results = free_search_client.search(query, top=10)

        # Compare results
        basic_ids = [r['id'] for r in basic_results]
        free_ids = [r['id'] for r in free_results]

        overlap = len(set(basic_ids) & set(free_ids))
        similarity = overlap / len(basic_ids)

        print(f"Query: {query}")
        print(f"  Similarity: {similarity:.1%}")
        assert similarity >= 0.80, f"Quality degraded for '{query}'"

    print("✅ Search quality validation passed")

def validate_performance():
    import time

    latencies = []
    for i in range(100):
        start = time.time()
        free_search_client.search("test", top=10)
        latency = (time.time() - start) * 1000
        latencies.append(latency)

    p50 = sorted(latencies)[50]
    p95 = sorted(latencies)[95]

    print(f"P50 latency: {p50:.0f}ms")
    print(f"P95 latency: {p95:.0f}ms")

    assert p95 < 500, f"Latency too high: {p95}ms"
    print("✅ Performance validation passed")

def validate_index_size():
    stats = free_search_client.get_index_statistics()

    size_mb = stats['storage_size'] / (1024 * 1024)
    doc_count = stats['document_count']

    print(f"Index size: {size_mb:.1f} MB / 50 MB")
    print(f"Documents: {doc_count} / 10,000")

    assert size_mb < 45, f"Index too large: {size_mb} MB"
    assert doc_count < 9000, f"Too many documents: {doc_count}"

    print("✅ Size validation passed")

if __name__ == '__main__':
    validate_search_quality()
    validate_performance()
    validate_index_size()
```

**Success Criteria:**
- [x] Search quality: ≥ 80% result overlap
- [x] Performance: P95 latency < 500ms
- [x] Index size: < 45 MB (90% threshold)
- [x] Document count: < 9,000

**14:00 - 16:00: Load Testing**

```bash

# Using Apache Bench
ab -n 1000 -c 10 -H "api-key: $API_KEY" \
  "https://nura-search-free.search.windows.net/indexes/items-optimized/docs?search=test"

# Expected:
# - Requests per second: > 5 (well under 3 QPS limit)
# - Mean latency: < 200ms
# - Failed requests: 0
```

---

### Day 0 (Sunday 2:00 AM): Production Cutover

**02:00 - 02:10: Pre-cutover Checks**

```bash

# 1. Verify Free Tier is healthy
az search service show --name nura-search-free | grep provisioningState

# 2. Verify index has recent data
curl "https://nura-search-free.search.windows.net/indexes/items-optimized/docs/count?api-version=2023-11-01" \
  -H "api-key: $API_KEY"

# Expected: ~4,200

# 3. Check current production traffic
kubectl logs deployment/fastapi --tail=100 | grep "search_query"

# 4. Notify team
curl -X POST $SLACK_WEBHOOK -d '{"text": "🚀 Starting AI Search migration to Free Tier"}'
```

**02:10 - 02:20: Configuration Update**

```bash

# Update FastAPI deployment environment
kubectl set env deployment/fastapi \
  AZURE_SEARCH_ENDPOINT=https://nura-search-free.search.windows.net \
  AZURE_SEARCH_INDEX=items-optimized

# This triggers rolling restart (zero downtime)
# Pods restart one by one, traffic shifts gradually
```

**02:20 - 02:30: Monitor Cutover**

```bash

# Watch pod restarts
kubectl get pods -w

# Watch logs for errors
kubectl logs -f deployment/fastapi | grep -i error

# Monitor Application Insights
# - Error rate should stay < 1%
# - Latency should stay < 1000ms P95
```

**02:30 - 03:00: Validation**

```bash

# 1. Test search endpoint
curl "https://api.nura.ai/search?q=زاهدان" -H "Authorization: Bearer $TOKEN"

# Expected: Results returned, no errors

# 2. Check metrics
curl "https://api.nura.ai/health/search"

# Expected: 
# {
#   "status": "healthy",
#   "endpoint": "nura-search-free",
#   "latency_ms": 150
# }

# 3. Monitor error rate (should be < 1%)
# 4. Monitor user feedback (if any active users)
```

**03:00 - 06:00: Monitoring Period**

- Watch dashboards for anomalies
- Respond to any alerts
- Collect feedback
- Document any issues

**Decision Point at 06:00:**
- ✅ If all green → Proceed to cleanup
- ⚠️ If issues → Rollback (see below)

---

### Day +1 (Monday): Post-Migration

**09:00 - 10:00: Team Sync**
- Review migration results
- Discuss any issues encountered
- Update documentation
- Plan cleanup

**10:00 - 11:00: Enable Sync Workflow**

```bash

# Deploy n8n sync workflows
# (These were prepared but paused during migration)

# 1. Incremental sync (every 15 min)
curl -X PATCH $N8N_API/workflows/incremental-sync \
  -d '{"active": true}'

# 2. Daily cleanup (2 AM)
curl -X PATCH $N8N_API/workflows/daily-cleanup \
  -d '{"active": true}'

# Verify first sync run
redis-cli GET sync:pg-to-ai:last_run
```

---

### Day +7 (Next Monday): Cleanup

**After 1 week of stable operation:**

```bash

# 1. Final verification
echo "Free Tier running for 7 days without issues? (yes/no)"
read confirmation

if [ "$confirmation" = "yes" ]; then
  # 2. Delete Basic tier
  az search service delete \
    --name nura-search-basic \
    --resource-group nura-rg \
    --yes

  echo "✅ Basic tier deleted - saving $75/month!"

  # 3. Update documentation
  # Mark Basic tier as decommissioned

  # 4. Celebrate
  curl -X POST $SLACK_WEBHOOK \
    -d '{"text": "🎉 AI Search migration complete! Saving $75/mo = $2,400 over 32 months"}'
else
  echo "⚠️ Issues found - keeping Basic tier as backup"
fi
```

---

## Rollback Procedure

### When to Rollback

**Trigger Conditions:**
- Error rate > 5%
- P95 latency > 2000ms
- Search quality degradation (user complaints)
- Index size exceeds 50 MB
- Any critical production issue

### Rollback Steps (< 10 minutes)

**Step 1: Revert Configuration**

```bash

# Switch back to Basic tier
kubectl set env deployment/fastapi \
  AZURE_SEARCH_ENDPOINT=https://nura-search-basic.search.windows.net \
  AZURE_SEARCH_INDEX=items

# Rolling restart (zero downtime)
kubectl rollout restart deployment/fastapi
```

**Step 2: Verify Rollback**

```bash

# Test search
curl "https://api.nura.ai/search?q=test"

# Check metrics
kubectl logs deployment/fastapi | grep "search_query"

# Monitor error rate (should drop to < 1%)
```

**Step 3: Post-Mortem**
- Document root cause
- Update migration plan
- Fix issues
- Reschedule migration

**Note:** Basic tier remains active during migration, so rollback is instant!

---

## Validation Checklist

### Technical Validation

**Pre-Migration:**
- [ ] Free Tier instance created
- [ ] Schema matches requirements
- [ ] Data migrated successfully
- [ ] Index size < 45 MB
- [ ] Document count ~4,200
- [ ] Performance tests passed
- [ ] Load tests passed

**Post-Migration:**
- [ ] All API endpoints responding
- [ ] Search quality unchanged
- [ ] Latency within SLA (< 1000ms P95)
- [ ] Error rate < 1%
- [ ] No user complaints
- [ ] Sync workflows running
- [ ] Monitoring dashboards updated

### Business Validation

- [ ] Cost reduced to $0/month (verified in Azure Cost Management)
- [ ] No service degradation
- [ ] Team trained on new architecture
- [ ] Documentation updated
- [ ] Success communicated to stakeholders

---

## Monitoring Post-Migration

### Week 1: Daily Checks

**Daily at 10:00 AM:**

```bash

#!/bin/bash
# scripts/daily_check_free_tier.sh

echo "=== AI Search Free Tier Daily Check ==="
echo ""

# 1. Index size
echo "Index Statistics:"
curl -s "https://nura-search-free.search.windows.net/indexes/items-optimized/stats?api-version=2023-11-01" \
  -H "api-key: $API_KEY" | jq

# 2. Document count
DOC_COUNT=$(curl -s "..." | jq '.documentCount')
echo "Documents: $DOC_COUNT / 10,000"

# 3. Recent sync status
LAST_SYNC=$(redis-cli GET sync:pg-to-ai:last_run)
echo "Last sync: $LAST_SYNC"

# 4. Error count
ERRORS=$(redis-cli GET sync:pg-to-ai:errors_today)
echo "Errors today: ${ERRORS:-0}"

# 5. Alert if needed
if [ "$DOC_COUNT" -gt 9000 ]; then
  echo "⚠️ WARNING: Approaching document limit"
fi
```

### Week 2-4: Weekly Reviews

**Every Monday:**
- Review index size trend
- Review query performance
- Optimize sync workflow if needed
- Update runbook with lessons learned

---

## Risk Assessment & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Index size exceeds 50 MB** | Medium | High | Daily monitoring, auto-cleanup, alerts at 90% |
| **QPS exceeds 3 limit** | Low | Medium | Caching layer, rate limiting in app |
| **Search quality degradation** | Low | High | A/B testing, fallback to pgvector |
| **Sync workflow fails** | Medium | Low | Retry logic, DLQ, manual trigger available |
| **Data loss during migration** | Very Low | Critical | Backup to Blob Storage, Basic tier kept as backup |

---

## Success Metrics

### Week 1 Targets

- [x] Migration completed within 4-hour window
- [x] Zero unplanned downtime
- [x] Search quality maintained (≥ 80% overlap)
- [x] Index size < 30 MB
- [x] Error rate < 1%
- [x] No user complaints

### Month 1 Targets

- [x] Cost reduced to $0/mo (verified)
- [x] Index size stable (< 35 MB)
- [x] Sync workflows running smoothly
- [x] Zero manual interventions needed
- [x] Team comfortable with new architecture

---

## Communication Plan

### Pre-Migration (Day -2)

**Email to team:**
```
Subject: AI Search Migration to Free Tier - Sunday 2 AM

Team,

We will be migrating Azure AI Search from Basic ($75/mo) to Free Tier ($0/mo) 
this Sunday at 2 AM NZDT.

Impact:
- Zero downtime expected (Blue/Green deployment)
- Search functionality unchanged
- No action required from users

Timeline:
- 2:00 AM: Start migration
- 2:30 AM: Validation
- 6:00 AM: Complete or rollback decision

On-call: ریحانه (primary), امیر (backup)

Questions? Slack #nura-engineering

Thanks,
ریحانه
```

### Post-Migration (Day +1)

**Slack announcement:**
```
🎉 AI Search migration complete!

✅ Successfully migrated to Free Tier
✅ Zero downtime
✅ Search quality maintained
✅ Saving $75/month ($2,400 over project lifetime)

Current status:
- Index size: 28 MB / 50 MB
- Documents: 4,200 / 10,000
- Performance: P95 latency 150ms

Thanks team! 🚀
```

---

## Appendix

### A. Schema Comparison

| Field | Basic SKU | Free Tier | Change |
|-------|-----------|-----------|--------|
| id | ✅ | ✅ | - |
| title | ✅ | ✅ | - |
| body_text | ✅ (~2000 chars) | ❌ | Removed |
| summary | ✅ | ✅ (300 chars) | Truncated |
| embedding | ✅ | ✅ | - |
| trust_score | ✅ | ✅ | - |
| publish_date | ✅ | ✅ | - |
| Others | ✅ | ✅ | - |

**Space saved:** ~2 KB per document

### B. Cost Breakdown

| Period | Basic Tier | Free Tier | Savings |
|--------|------------|-----------|---------|
| Month 1 | $75 | $0 | $75 |
| Year 1 | $900 | $0 | $900 |
| 32 months | $2,400 | $0 | **$2,400** |

### C. Contact List

| Role | Name | Slack | Phone | Responsibility |
|------|------|-------|-------|----------------|
| Migration Lead | ریحانه | @rihaneh | +64... | Overall execution |
| Architect | امیر | @amir | +64... | Technical decisions |
| AI Engineer | نوید | @navid | +64... | Testing support |
| On-call Backup | کاوه | @kaveh | +64... | Escalation point |

---

## References

- [Ref: ADR-009] Cost Optimization Decision
- [Ref: workflow-pg-to-ai-search-sync-v1.0] Sync Workflow
- [Azure AI Search Free Tier](https://learn.microsoft.com/azure/search/search-limits-quotas-capacity)
- [Blue/Green Deployment Pattern](https://martinfowler.com/bliki/BlueGreenDeployment.html)

---

## Changelog

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-03 | ریحانه | Initial migration plan |

---

**Document Status:** 📝 DRAFT  
**Review Required:** امیر (Architect)  
**Approval Required:** Product Owner  
**Execution Date:** TBD (Sunday 2 AM NZDT)

---

*This document follows Docs-as-Code principles: versioned, executable, traceable.*
