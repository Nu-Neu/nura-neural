---
doc_type: operations
version: 1.0
last_updated: 2026-02-04
owner: Nura Neural Team
status: approved
---

# Monitoring & Alerting Strategy

## 1. Philosophy

Our monitoring strategy is based on the "Four Golden Signals" adapted for a serverless environment:

1.  **Latency:** How long do key operations take? (e.g., n8n workflow execution time).
2.  **Traffic:** How much demand is on the system? (e.g., API requests per minute).
3.  **Errors:** What is the rate of failures? (e.g., HTTP 5xx responses, failed workflow executions).
4.  **Saturation:** How "full" is the service? (e.g., CPU/Memory utilization, database storage).

All metrics are collected in **Azure Log Analytics** and visualized in **Azure Monitor Dashboards**.

---

## 2. Key Monitored Resources & Metrics

### 2.1 Azure Container Apps (`irdecode-prod-n8n`, `irdecode-prod-redis`)

- **Metrics:**
    - `CPU Usage`: Saturation. Alert when > 80% for 5 mins.
    - `Memory Usage`: Saturation. Alert when > 85% for 5 mins.
    - `Replica Count`: Traffic/Scaling. Informational alerts on scale-up/down events.
    - `HTTP Requests`: Traffic.
    - `HTTP 4xx/5xx Response Codes`: Errors. Alert on any spike in 5xx errors.

### 2.2 Azure Database for PostgreSQL (`irdecode-prod-psql`)

- **Metrics:**
    - `CPU credit balance`: Saturation. Alert when < 20 credits (indicates sustained high load on a burstable B2s instance).
    - `IOPS consumed percentage`: Saturation. Alert when > 90%.
    - `Storage used`: Saturation. Alert when > 90% of provisioned storage.
    - `Active connections`: Saturation. Alert when > 80 connections.

### 2.3 Azure AI Search (`irdecode-prod-search`)

- **Metrics (Free Tier):**
    - `StorageSize`: Saturation. The size of the index in bytes. Alert when > 45MB (90% of 50MB limit).
    - `DocumentCount`: Saturation. Number of documents in the index. Alert when > 9,000 (90% of 10k limit).
    - `SearchLatency`: Latency.
    - `ThrottledQueriesPercentage`: Errors/Saturation. Alert if > 1%.

### 2.4 n8n Application-Level Monitoring

- **Mechanism:** The `WF-ERROR-central-error-handler` workflow is configured as the error workflow for all other workflows.
- **Metrics:**
    - **`n8n_workflow_execution_time`**: A custom metric sent to Log Analytics at the end of each successful run.
    - **`n8n_workflow_failure`**: A custom log event sent to Log Analytics whenever the error workflow is triggered. Includes workflow name and error details.

---

## 3. Health Check Scripts

A daily health check is run automatically to provide a snapshot of system status.

**Script Location:** `scripts/daily_health_check.sh`

```bash
#!/bin/bash
# A simplified version of the daily health check script.

echo "=== Nura Neural Daily Health Check ==="
echo "Time: $(date)"

# 1. Check AI Search Stats
SEARCH_STATS=$(curl -s "https://irdecode-prod-search.search.windows.net/indexes/nura-items/stats?api-version=2023-11-01" -H "api-key: $AZURE_SEARCH_ADMIN_KEY")
DOC_COUNT=$(echo $SEARCH_STATS | jq '.documentCount')
STORAGE_MB=$(echo $SEARCH_STATS | jq '.storageSize / (1024*1024)')
echo "AI Search: $DOC_COUNT docs, ${STORAGE_MB}MB storage"
if (( $(echo "$STORAGE_MB > 45" | bc -l) )); then
  echo "⚠️ ALERT: AI Search storage is critical."
fi

# 2. Check Database Connectivity (Smoke Test)
# This assumes the script is running from a whitelisted IP
psql "postgres://$DB_USER:$DB_PASS@$DB_HOST:5432/$DB_NAME" -c "SELECT 1;"
if [ $? -eq 0 ]; then
    echo "Database Connectivity: OK"
else
    echo "🔥 CRITICAL: Database connectivity failed."
fi

# 3. Check last n8n sync time from Redis
LAST_SYNC=$(redis-cli -h $REDIS_HOST -a $REDIS_PASSWORD GET sync:pg-to-ai:last_run_timestamp)
echo "Last PG-to-AI-Search Sync: $(date -d @$LAST_SYNC)"

echo "Health Check Complete."
```
