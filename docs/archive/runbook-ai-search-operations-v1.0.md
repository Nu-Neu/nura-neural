---
doc_type: deploy
version: 1.0
last_updated: 2026-02-03
owner: ریحانه (DB Specialist)
status: draft
traceability: [Ref: ADR-009], [Ref: HLD-v2.1], [Ref: migration-ai-search-free-tier-v1.0]
---

# Runbook: Azure AI Search Operations (Free Tier)

## Overview

**Purpose:** Operational guide for managing Azure AI Search Free Tier on a daily basis.

**Audience:** 
- On-call engineers
- DevOps team
- Database administrators

**Scope:**
- Daily health checks
- Common operational tasks
- Troubleshooting procedures
- Alert responses
- Emergency procedures

---

## Quick Reference

### Service Details

**Instance Name:** nura-search-free  
**Resource Group:** nura-rg  
**SKU:** Free Tier  
**Index Name:** items-optimized

**Limits:**
- Storage: 50 MB max
- Documents: 10,000 max
- QPS: 3 max

**Current Usage:**
- Storage: 28-35 MB (56-70%)
- Documents: 4,200-5,000 (42-50%)

### Emergency Contacts

| Role | Name | Slack | Availability |
|------|------|-------|--------------|
| Primary | ریحانه | @rihaneh | Mon-Fri 9-5 |
| Backup | امیر | @amir | 24/7 |
| Escalation | Product Owner | @owner | Business hours |

---

## Daily Operations

### Morning Health Check (10:00 AM)

Run this script every morning:

```bash

#!/bin/bash
# scripts/daily_ai_search_check.sh

echo "=== Azure AI Search Daily Health Check ==="
echo "Time: $(date)"
echo ""

# Get index statistics
STATS=$(curl -s "https://nura-search-free.search.windows.net/indexes/items-optimized/stats?api-version=2023-11-01" \
  -H "api-key: $AZURE_SEARCH_ADMIN_KEY")

DOC_COUNT=$(echo $STATS | jq '.documentCount')
STORAGE_MB=$(echo $STATS | jq '.storageSize / (1024*1024)')

echo "Documents: $DOC_COUNT / 10,000"
echo "Storage: ${STORAGE_MB}MB / 50 MB"

# Test search
RESULT=$(curl -s "https://nura-search-free.search.windows.net/indexes/items-optimized/docs?search=test&api-version=2023-11-01" \
  -H "api-key: $AZURE_SEARCH_ADMIN_KEY")

echo "Search test: OK"

# Check sync
LAST_SYNC=$(redis-cli GET sync:pg-to-ai:last_run)
echo "Last sync: $LAST_SYNC"

# Alerts
if (( $(echo "$STORAGE_MB > 45" | bc -l) )); then
  echo "⚠️ ALERT: Storage critical"
fi

```

---

## Common Tasks

### Task 1: Check Index Size

**Command:**
```bash
az search index show \
  --service-name nura-search-free \
  --name items-optimized \
  --query 'storageSize'
```

**Interpretation:**
- < 40 MB: Healthy
- 40-45 MB: Monitor
- 45-50 MB: Critical
- > 50 MB: Emergency

---

### Task 2: Query Document Count

**Command:**
```bash
curl "https://nura-search-free.search.windows.net/indexes/items-optimized/docs/$count?api-version=2023-11-01" \
  -H "api-key: $AZURE_SEARCH_ADMIN_KEY"
```

**Expected:** 4,000 - 5,000

---

### Task 3: Test Search

**Keyword search:**
```bash
curl "https://nura-search-free.search.windows.net/indexes/items-optimized/docs?search=زاهدان&api-version=2023-11-01" \
  -H "api-key: $AZURE_SEARCH_ADMIN_KEY" | jq
```

---

### Task 4: Manual Cleanup

**When:** Storage > 45 MB

**Command:**
```python
# scripts/manual_cleanup.py
from azure.search.documents import SearchClient
from datetime import datetime, timedelta

def cleanup_old_items(max_age_days=14):
    cutoff = datetime.utcnow() - timedelta(days=max_age_days)
    client = SearchClient(...)

    # Delete old items
    results = client.search(
        filter=f"publishDate lt {cutoff}",
        select="id"
    )

    ids = [r['id'] for r in results]
    client.delete_documents([{'id': id} for id in ids])
    print(f"✅ Deleted {len(ids)} items")
```

**Usage:**
```bash
python scripts/manual_cleanup.py
```

---

### Task 5: Trigger Sync Manually

**Check sync status:**
```bash
redis-cli GET sync:pg-to-ai:last_run
```

**Trigger sync:**
```bash
curl -X POST "$N8N_API/workflows/incremental-sync/execute" \
  -H "Authorization: Bearer $N8N_API_KEY"
```

---

### Task 6: Rebuild Index

**Emergency only - takes 30-60 minutes:**
```bash
# Create new index
az search index create \
  --service-name nura-search-free \
  --name items-$(date +%Y%m%d) \
  --fields @schema-optimized.json

# Run migration
python scripts/migrate_to_free_tier.py

# Switch application
kubectl set env deployment/fastapi \
  AZURE_SEARCH_INDEX=items-$(date +%Y%m%d)
```

---

## Troubleshooting

### Issue 1: No Search Results

**Diagnosis:**
```bash
# Check document count
curl "https://nura-search-free.search.windows.net/indexes/items-optimized/docs/$count?api-version=2023-11-01" \
  -H "api-key: $AZURE_SEARCH_ADMIN_KEY"

# Check sync
redis-cli GET sync:pg-to-ai:last_run
```

**Fix:**
```bash
# Trigger sync
redis-cli DEL sync:pg-to-ai:last_run
curl -X POST "$N8N_API/workflows/incremental-sync/execute"
```

---

### Issue 2: Index Size Exceeded

**Immediate action:**
```bash
# Stop sync
curl -X PATCH "$N8N_API/workflows/incremental-sync" -d '{"active": false}'

# Emergency cleanup
python scripts/manual_cleanup.py --emergency

# Resume sync
curl -X PATCH "$N8N_API/workflows/incremental-sync" -d '{"active": true}'
```

---

### Issue 3: High Latency

**Diagnosis:**
```bash
# Test latency
time curl "https://nura-search-free.search.windows.net/indexes/items-optimized/docs?search=test&api-version=2023-11-01" \
  -H "api-key: $AZURE_SEARCH_ADMIN_KEY"
```

**Common causes:**
- Large index (> 40 MB) → Cleanup
- Rate limit (> 3 QPS) → Add caching
- Network issues → Check Azure status

---

### Issue 4: Sync Stopped

**Diagnosis:**
```bash
# Check workflow status
curl "$N8N_API/workflows/incremental-sync"

# Check errors
redis-cli LLEN sync:failed:items
```

**Fix:**
```bash
# Restart workflow
curl -X PATCH "$N8N_API/workflows/incremental-sync" -d '{"active": true}'

# Replay failed items
python scripts/replay_dlq.py
```

---

### Issue 5: Document Count Mismatch

**Diagnosis:**
```bash
# Count in AI Search
AI_COUNT=$(curl -s "https://nura-search-free.search.windows.net/indexes/items-optimized/docs/$count?api-version=2023-11-01" -H "api-key: $KEY")

# Count in PostgreSQL
PG_COUNT=$(psql $PG_CONN -t -c "SELECT COUNT(*) FROM items WHERE publish_date >= NOW() - INTERVAL '14 days' AND trust_score >= 50")

echo "AI: $AI_COUNT, PG: $PG_COUNT"
```

**Fix:**
```bash
# Force full resync
redis-cli DEL sync:pg-to-ai:last_run
```

---

## Alert Response

### Alert: Index Size > 45 MB

**Severity:** Medium  
**Response:** 4 hours

**Actions:**
1. Verify alert
2. Schedule cleanup
3. Notify team

```bash
bash scripts/daily_ai_search_check.sh
curl -X POST $SLACK_WEBHOOK -d '{"text": "⚠️ AI Search at 90% storage"}'
```

---

### Alert: Sync Stopped

**Severity:** High  
**Response:** 15 minutes

**Actions:**
1. Check workflow
2. Restart if needed
3. Monitor

```bash
curl "$N8N_API/workflows/incremental-sync" | jq '.active'
curl -X PATCH "$N8N_API/workflows/incremental-sync" -d '{"active": true}'
```

---

## Maintenance

### Weekly (Monday 10 AM)

- [ ] Review metrics
- [ ] Check DLQ (dead letter queue)
- [ ] Replay failed items
- [ ] Update documentation

```bash
redis-cli LRANGE sync:failed:items 0 -1
python scripts/replay_dlq.py
```

---

### Monthly (First Monday)

- [ ] Review Free Tier limits
- [ ] API key rotation (quarterly)
- [ ] Disaster recovery drill
- [ ] Documentation updates

---

## Security

### API Key Rotation

**Quarterly or if compromised:**
```bash
# Renew key
az search admin-key renew \
  --service-name nura-search-free \
  --key-type primary

# Update Key Vault
az keyvault secret set \
  --vault-name nura-keyvault \
  --name azure-search-admin-key \
  --value "$NEW_KEY"

# Restart apps
kubectl rollout restart deployment/fastapi
```

---

## Disaster Recovery

### Index Deleted

**RTO:** 1 hour  
**RPO:** 15 minutes

**Procedure:**
```bash
# Recreate index
az search index create --service-name nura-search-free --name items-optimized --fields @schema.json

# Rebuild from PostgreSQL
python scripts/migrate_to_free_tier.py

# Resume sync
curl -X PATCH "$N8N_API/workflows/incremental-sync" -d '{"active": true}'
```

---

### Service Down

**Fallback to PostgreSQL:**
```bash
kubectl set env deployment/fastapi SEARCH_BACKEND=postgresql
```

---

## Cheat Sheet

**Health check:**
```bash
curl -s "https://nura-search-free.search.windows.net/indexes/items-optimized/stats?api-version=2023-11-01" -H "api-key: $KEY" | jq
```

**Document count:**
```bash
curl "https://nura-search-free.search.windows.net/indexes/items-optimized/docs/$count?api-version=2023-11-01" -H "api-key: $KEY"
```

**Last sync:**
```bash
redis-cli GET sync:pg-to-ai:last_run
```

**Trigger sync:**
```bash
curl -X POST "$N8N_API/workflows/incremental-sync/execute" -H "Authorization: Bearer $KEY"
```

---

## Escalation Matrix

| Issue | Severity | First | Escalate To | After |
|-------|----------|-------|-------------|-------|
| Search down | Critical | On-call | امیر | 15 min |
| Sync stopped | High | On-call | ریحانه | 30 min |
| Size exceeded | Medium | On-call | ریحانه | 4 hours |
| Slow queries | Low | On-call | نوید | 1 day |

---

## References

- [Ref: ADR-009] Cost Optimization
- [Ref: migration-ai-search-free-tier-v1.0] Migration Plan
- [Ref: workflow-pg-to-ai-search-sync-v1.0] Sync Workflow
- [Azure AI Search Docs](https://learn.microsoft.com/azure/search/)

---

## Changelog

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-03 | ریحانه | Initial runbook |

---

**Status:** 📝 DRAFT  
**Owner:** ریحانه  
**Next Review:** After 1 month

---

*Keep this runbook updated with operational lessons learned.*
