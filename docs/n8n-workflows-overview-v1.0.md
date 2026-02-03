---
doc_type: overview
version: 1.0
last_updated: 2026-02-04
owner: Saman (n8n Automation Lead)
status: approved
traceability:
  - Ref: n8n-workflows-master-plan-v1.0
  - Ref: data-flow-architecture-v1.0
---

# n8n Workflows Overview - Nura Platform ⭐

## Document Control

| Field | Value |
|-------|-------|
| **Version** | 1.0 (Overview & Best Practices) |
| **Date** | February 4, 2026 |
| **Author** | Saman (n8n Automation Lead) |
| **Status** | ✅ APPROVED |
| **Target Audience** | Development Team, Product Owner, New Team Members |

---

## 1. Introduction - خلاصه کلی

### 1.1 هدف این سند

این سند یک **راهنمای سریع** برای n8n workflows پلتفرم Nura است که شامل:
- ✅ لیست کامل workflows و وظایف آن‌ها
- ✅ بایدها و نبایدها (Best Practices)
- ✅ Data flow بین workflows
- ✅ Dependencies و ترتیب اجرا

**این سند را بخوانید اگر:**
- تازه به تیم پیوسته‌اید
- می‌خواهید سریع بفهمید workflows چطور کار می‌کنند
- نیاز به troubleshooting دارید
- می‌خواهید workflow جدید اضافه کنید

---

### 1.2 Technology Stack (خلاصه)

| Technology | Version | Purpose |
|------------|---------|---------|
| **n8n** | 2.4.6 Community Edition | Workflow automation engine |
| **Execution Mode** | Queue Mode (Redis) | High availability |
| **AI Model** | GPT-5 nano | Metadata extraction (fast & cheap) |
| **Embeddings** | text-embedding-3-small (512d) | Vector search |
| **Database** | PostgreSQL 16 + pgvector | Source of truth |
| **Queue** | Redis 7 | Job queue + cache |
| **Hosting** | Docker Compose (Azure) | Containerized deployment |

**Cost:** $32-50/month (با optimization)

---

## 2. Complete Workflow List

### 2.1 Workflow Summary Table

| ID | Name | Trigger | Frequency | Priority | Status |
|----|------|---------|-----------|----------|--------|
| **WF-01** | RSS Feed Ingestion | Cron | Every 15 min | High | Ready for Dev |
| **WF-02** | Twitter Data Collection | Cron | Every 5 min | High | Ready for Dev |
| **WF-03** | Article Processing Pipeline | DB Poll | Every 2 min | **CRITICAL** | Ready for Dev |
| **WF-04** | Narrative Clustering | Cron | Every 15 min | Medium | Ready for Dev |
| **WF-05** | PostgreSQL → AI Search Sync | Cron | Every 15 min | Medium | Ready for Dev |
| **WF-06** | Daily Cleanup & Archival | Cron | Daily 2 AM | Low | Ready for Dev |
| **WF-ERROR** | Central Error Handler | Webhook | On error | **CRITICAL** | Ready for Dev |
| **WF-HEALTH** | Health Check Monitor | Cron | Every 5 min | High | Optional (Phase 2) |

---

### 2.2 Detailed Workflow Descriptions

#### WF-01: RSS Feed Ingestion 📰

**هدف:** دریافت اخبار از Miniflux و ذخیره در PostgreSQL

**Input:**
- Miniflux API (500 RSS sources)
- Unread entries

**Output:**
- PostgreSQL \`articles\` table
- Azure Blob Storage (raw HTML)
- Redis counter (daily stats)

**Main Steps:**
1. Call Miniflux API (\`GET /v1/entries?status=unread\`)
2. Calculate url_hash (SHA-256)
3. Check duplicate در PostgreSQL
4. Detect language (EN/FA/AR only)
5. Upload raw HTML به Blob Storage
6. Insert article با \`status='pending'\`
7. Mark as read در Miniflux

**Error Handling:**
- Retry: 3x با 2-second delay
- DLQ: Store failures در Redis \`dlq:wf01:failed\`
- Alert: Slack notification if error rate > 5%

**Performance:**
- Expected: 50-100 articles per run
- Duration: 30-60 seconds (P95)
- Success rate target: > 98%

**Dependencies:**
- ✅ Miniflux running
- ✅ PostgreSQL available
- ✅ Azure Blob Storage accessible

---

#### WF-02: Twitter Data Collection 🐦

**هدف:** دریافت توییت‌ها از Twitter API با rate limit handling

**Input:**
- Twitter API (twitterapi.io)
- 200 active accounts
- Hashtags: #IranProtests, #MahsaAmini

**Output:**
- PostgreSQL \`articles\` table (platform='twitter')
- Azure Blob Storage (media files)
- Redis (last_tweet_id tracking)

**Main Steps:**
1. Get active accounts از PostgreSQL
2. Call Twitter API (\`GET /v1/tweets/search\`)
3. Detect 429 rate limit → Wait 60s
4. Check duplicate (tweet_id)
5. Download media files
6. Insert tweet as article
7. Update last_tweet_id در Redis

**Rate Limit Strategy:**
- Detect 429 → Wait 60 seconds (not retry!)
- Track quota در Redis: \`twitter:quota:remaining\`
- High-priority accounts: Every 5 min
- Normal accounts: Every 15 min

**Error Handling:**
- Suspended accounts: Mark \`active=false\`, retry after 24h
- Network timeout: Exponential backoff (1s → 2s → 4s)

**Performance:**
- Expected: 20-50 tweets per run
- Duration: 60-120 seconds
- Success rate target: > 95% (rate limits excluded)

**Dependencies:**
- ✅ twitterapi.io API key
- ✅ PostgreSQL available
- ✅ Azure Blob Storage (for media)

---

#### WF-03: Article Processing Pipeline ⚡ CRITICAL

**هدف:** پردازش اخبار pending با GPT-5 nano (Metadata + Embeddings)

**Input:**
- PostgreSQL \`articles\` table (\`status='pending'\`)
- Batch size: 100 articles

**Output:**
- PostgreSQL updated با:
  - \`ai_metadata\` (author, entities, sentiment, summary)
  - \`embedding\` (512-dim vector)
  - \`status='ai_processed'\`

**Main Steps:**
1. Poll database (every 2 minutes)
2. Check circuit breaker (\`circuit:openai\`)
3. Split in batches (20 articles)
4. **Extract metadata** با GPT-5 nano:
   - Author, published_date, entities, sentiment, summary
   - Temperature: 0.2 (low for consistency)
   - Max tokens: 400
5. **Generate embedding** با text-embedding-3-small:
   - Input: title + summary
   - Dimensions: 512
6. Update PostgreSQL
7. Reset circuit breaker (if success)

**Circuit Breaker Logic:**
```
If OpenAI fails 5 times consecutively:
  → Open circuit (block calls for 5 minutes)
  → Send PagerDuty alert
  → Log in error_log table

After 5 minutes:
  → Auto-reset and try again
```

**Error Handling:**
- ✅ Circuit breaker (prevent cascading failures)
- ✅ Retry: 3x با exponential backoff
- ✅ Failed items: Mark \`status='failed'\`, log error
- ✅ DLQ: Store در Redis for manual replay

**Performance:**
- Expected: 100 articles per run
- Duration: 3-5 minutes (P95)
- Success rate target: > 98%
- Latency: < 500ms per article (GPT-5 nano)

**Cost (Monthly):**
```
Metadata: 150K articles × 2.5K tokens × $0.08/1M = $30
Embeddings: 150K articles × 512 dims × $0.02/1M = $1.54
Total: ~$32/month ✅
```

**Dependencies:**
- ✅ Azure OpenAI (GPT-5 nano deployment)
- ✅ Azure OpenAI (text-embedding-3-small deployment)
- ✅ PostgreSQL available
- ✅ Redis available (circuit breaker state)

**🔥 این workflow قلب سیستم است! اگر این down شود، هیچ چیز پردازش نمی‌شود.**

---

#### WF-04: Narrative Clustering 🗂️

**هدف:** گروه‌بندی اخبار مشابه (Clustering)

**Input:**
- PostgreSQL \`articles\` (\`status='ai_processed'\`)
- Articles without narrative assignment

**Output:**
- PostgreSQL \`narratives\` table (new clusters)
- PostgreSQL \`article_narratives\` (many-to-many relation)

**Algorithm:**

```
For each unassigned article:
  1. Vector search (pgvector HNSW)
     → Find top 10 similar narratives

  2. Decision tree:
     IF similarity > 0.85:
       → Auto-assign to existing narrative

     ELSE IF similarity > 0.75 AND entity_overlap >= 2:
       → Assign to existing narrative

     ELSE IF published_at > 7 days ago:
       → Create new narrative

     ELSE:
       → Ask GPT-5 nano: "Is this the same event?"
       → Assign based on GPT response

  3. Update narrative centroid:
     → Recalculate AVG(embeddings)
```

**Main Steps:**
1. Get unassigned articles (limit 200)
2. For each article:
   - Vector search در PostgreSQL
   - Apply decision rules
   - If uncertain: Ask GPT-5 nano
3. Create new narrative (if needed):
   - Generate title با GPT-5 nano
   - Insert to \`narratives\` table
4. Assign article to narrative
5. Recalculate narrative centroid

**Error Handling:**
- If GPT fails: Use template title \`"Narrative #uuid - {main_entity}"\`
- If vector search fails: Create standalone narrative

**Performance:**
- Expected: 100-200 articles per run
- Duration: 2-4 minutes
- Vector search: < 300ms per query (HNSW index)

**Dependencies:**
- ✅ PostgreSQL + pgvector extension
- ✅ HNSW index on \`articles.embedding\`
- ✅ Azure OpenAI (GPT-5 nano) for title generation

---

#### WF-05: PostgreSQL → AI Search Sync 🔄

**هدف:** همگام‌سازی incremental از PostgreSQL به Azure AI Search

**Input:**
- PostgreSQL \`articles\` (updated since last sync)
- Redis: \`sync:ai_search:last_run\` (timestamp)

**Output:**
- Azure AI Search index: \`nura-articles\`

**Main Steps:**
1. Get last sync timestamp از Redis
2. Delta query از PostgreSQL:
   ```sql
   WHERE updated_at > last_run
     AND trust_score >= 50
     AND published_at > NOW() - INTERVAL '14 days'
   ```
3. Transform data:
   - Remove \`content\` (too large)
   - Truncate \`summary\` to 1000 chars
   - Add \`indexed_at\` timestamp
4. Batch upload به AI Search (100 docs per batch)
5. Update last sync timestamp در Redis

**Sync Constraints:**
- Only articles با \`trust_score >= 50\`
- Only last 14 days (retention policy)
- Max 100 docs per batch (Azure limit)

**Error Handling:**
- Failed batches: Retry 3x
- If AI Search down: Skip sync, alert admin
- DLQ: Store failed IDs در Redis

**Performance:**
- Expected: 50-200 documents per run
- Duration: 10-20 seconds
- Success rate target: > 99%

**Dependencies:**
- ✅ PostgreSQL available
- ✅ Azure AI Search available
- ✅ Redis available

**💡 Note:** AI Search هیچ‌وقت Source of Truth نیست! فقط read cache است.

---

#### WF-06: Daily Cleanup & Archival 🧹

**هدف:** حذف داده‌های قدیمی و بهینه‌سازی

**Input:**
- PostgreSQL \`articles\` (older than 30 days)
- Azure Blob Storage (raw HTML > 30 days)
- Azure AI Search (docs > 14 days)

**Output:**
- Cleaned database (embeddings removed)
- Blob files moved to Cool tier
- AI Search old docs deleted
- PostgreSQL vacuumed

**Main Steps:**
1. Remove old embeddings:
   ```sql
   UPDATE articles SET embedding = NULL
   WHERE published_at < NOW() - INTERVAL '30 days'
   ```
2. Delete from AI Search:
   - Articles older than 14 days
   - Articles با \`trust_score < 50\`
3. Move Blob files to Cool tier:
   - Raw HTML > 30 days old
   - Cost savings: Hot ($0.0184/GB) → Cool ($0.01/GB)
4. VACUUM PostgreSQL:
   ```sql
   VACUUM ANALYZE articles;
   VACUUM ANALYZE narratives;
   REINDEX INDEX idx_articles_embedding;
   ```
5. Generate daily report:
   - Embeddings removed count
   - Blobs archived count
   - Vacuum duration
6. Insert audit log

**Error Handling:**
- Each step independent (failure doesn't stop next step)
- Log all actions to \`audit_log\` table
- Alert if cleanup fails 3 days in row

**Performance:**
- Expected duration: 5-10 minutes
- Runs at 2 AM NZDT (low traffic time)

**Dependencies:**
- ✅ PostgreSQL available
- ✅ Azure Blob Storage SDK
- ✅ Azure AI Search API

---

#### WF-ERROR-HANDLER: Central Error Logging 🚨

**هدف:** مدیریت متمرکز خطاها از همه workflows

**Input:**
- Error webhook calls از workflows دیگر
- Error details: workflow_name, node_name, error_message, stack trace

**Output:**
- PostgreSQL \`workflow_errors\` table
- PagerDuty alert (critical errors)
- Slack notification (high/medium errors)
- Redis counter: \`metrics:errors:{workflow}:{date}\`

**Severity Classification:**
```
Critical:
  - OpenAI API down (circuit open)
  - PostgreSQL connection lost
  - Redis unavailable
  → Send PagerDuty alert

High:
  - WF-03 failure rate > 10%
  - Queue length > 1000
  - Cost spike (> $10/day)
  → Send Slack alert

Medium:
  - Single workflow execution failed
  - Twitter rate limit hit
  → Log only, notify after 5 occurrences

Low:
  - Duplicate article skipped
  - Language mismatch
  → Log only (no alert)
```

**Main Steps:**
1. Receive error via webhook
2. Parse error data
3. Determine severity (critical/high/medium/low)
4. Insert to \`workflow_errors\` table
5. Route notification:
   - Critical → PagerDuty
   - High → Slack #alerts channel
   - Medium → Email to admin
   - Low → Log only
6. Increment error counter در Redis

**Error Log Schema:**
```sql
CREATE TABLE workflow_errors (
    id UUID PRIMARY KEY,
    workflow_name TEXT,
    execution_id TEXT,
    node_name TEXT,
    error_message TEXT,
    error_stack TEXT,
    severity TEXT,
    resolved BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Dependencies:**
- ✅ PostgreSQL available
- ✅ Redis available
- ✅ PagerDuty API key
- ✅ Slack webhook URL

**🔥 این workflow باید همیشه کار کند! اگر error handler خودش fail شود، ما کور هستیم.**

---

#### WF-HEALTH-CHECK: Health Check Monitor 🏥 (Optional)

**هدف:** بررسی سلامت سیستم هر 5 دقیقه

**Input:**
- Redis, PostgreSQL, OpenAI status
- Queue length
- Last execution times

**Output:**
- Redis: \`health:status\` (JSON)
- Slack alert (if unhealthy)

**Checks:**
1. Redis: \`PING\` → Expect \`PONG\`
2. PostgreSQL: \`SELECT 1\` → Expect 1 row
3. Queue length: \`LLEN bull:n8n:queue\` → Alert if > 500
4. Last WF-01 execution: Alert if > 20 min ago
5. Circuit breaker: Alert if \`circuit:openai\` = "open"
6. Worker status: Alert if all idle > 10 min

**Dependencies:**
- ✅ Redis available
- ✅ PostgreSQL available

---

## 3. Data Flow Between Workflows

### 3.1 Simplified Data Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    EXTERNAL SOURCES                      │
│   RSS Feeds (Miniflux)         Twitter API              │
└──────────────┬─────────────────────────┬────────────────┘
               │                         │
               ▼                         ▼
         ┌─────────┐              ┌──────────┐
         │ WF-01   │              │  WF-02   │
         │ RSS     │              │ Twitter  │
         │Ingestion│              │Collection│
         └────┬────┘              └─────┬────┘
              │                         │
              │    INSERT articles      │
              │    status='pending'     │
              │                         │
              └────────┬────────────────┘
                       │
                       ▼
              ┌────────────────┐
              │  PostgreSQL    │
              │   articles     │
              │ status=pending │
              └───────┬────────┘
                      │
                      │ DB Poll (every 2 min)
                      │
                      ▼
              ┌───────────────┐
              │    WF-03      │  ← CRITICAL PATH
              │   Article     │
              │  Processing   │
              │ (GPT-5 nano)  │
              └───────┬───────┘
                      │
                      │ UPDATE articles
                      │ status='ai_processed'
                      │ + ai_metadata
                      │ + embedding
                      │
                      ▼
              ┌────────────────┐
              │  PostgreSQL    │
              │   articles     │
              │status=processed│
              └───────┬────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
   ┌────────┐   ┌────────┐   ┌────────┐
   │ WF-04  │   │ WF-05  │   │ WF-06  │
   │Cluster │   │  Sync  │   │Cleanup │
   │        │   │ to AI  │   │ Daily  │
   └────┬───┘   │ Search │   └────────┘
        │       └────────┘
        │ CREATE narratives
        │ ASSIGN articles
        │
        ▼
   ┌──────────┐
   │narratives│
   │  table   │
   └──────────┘
```

### 3.2 Data Flow Sequence

```
Step 1: Ingestion (WF-01 + WF-02)
  Input:  RSS feeds, Twitter API
  Output: articles table (status='pending')

  ↓

Step 2: AI Processing (WF-03) ← BOTTLENECK
  Input:  articles (status='pending')
  Action: GPT-5 nano extracts metadata
          text-embedding-3-small generates vectors
  Output: articles (status='ai_processed')

  ↓

Step 3: Clustering (WF-04)
  Input:  articles (status='ai_processed')
  Action: Vector search + entity matching
          GPT-5 nano generates titles (if new narrative)
  Output: narratives table
          article_narratives (assignments)

  ↓

Step 4: Sync to AI Search (WF-05)
  Input:  articles (trust_score >= 50, last 14 days)
  Output: Azure AI Search index (read cache)

  ↓

Step 5: User Query (FastAPI)
  Input:  User search query
  Source: Azure AI Search (fast) OR PostgreSQL (fallback)
  Output: Search results to UI
```

---

## 4. Workflow Dependencies

### 4.1 Dependency Matrix

| Workflow | Depends On | Blocks | Can Run Without |
|----------|------------|--------|-----------------|
| **WF-01** | Miniflux, PostgreSQL | WF-03 | WF-02, WF-04, WF-05 |
| **WF-02** | Twitter API, PostgreSQL | WF-03 | WF-01, WF-04, WF-05 |
| **WF-03** | WF-01/WF-02, OpenAI, PostgreSQL | **WF-04, WF-05** | Nothing (critical!) |
| **WF-04** | WF-03, PostgreSQL, OpenAI | WF-05 | WF-01, WF-02 |
| **WF-05** | WF-03/WF-04, PostgreSQL, AI Search | Nothing | All others |
| **WF-06** | PostgreSQL, Blob, AI Search | Nothing | All others |
| **WF-ERROR** | PostgreSQL, Redis | Nothing | All others |

### 4.2 Critical Path

```
WF-01 (Ingestion) 
    ↓ 
WF-03 (Processing) ← CRITICAL! اگر این fail شود، همه چیز متوقف می‌شود
    ↓
WF-04 (Clustering)
    ↓
WF-05 (Sync)
```

**اگر WF-03 down باشد:**
- ❌ Articles در status='pending' گیر می‌کنند
- ❌ Trust Score محاسبه نمی‌شود
- ❌ Narrative Clustering متوقف می‌شود
- ❌ AI Search sync متوقف می‌شود
- ❌ Users نتایج جدید نمی‌بینند

**Mitigation:**
- Circuit breaker (جلوی waste کردن OpenAI credits)
- Queue mode (workers می‌توانند restart شوند بدون data loss)
- DLQ (failed items برای manual replay)

---

### 4.3 Start Order (اولین بار که deploy می‌کنید)

```
1. Start Infrastructure:
   - PostgreSQL ✅
   - Redis ✅
   - n8n Main + Workers ✅

2. Deploy Error Handler First:
   - WF-ERROR-HANDLER ✅

3. Deploy Core Workflows:
   - WF-01 (RSS) ✅
   - WF-03 (Processing) ✅
   - Wait 1 hour, verify articles are processed

4. Deploy Secondary Workflows:
   - WF-04 (Clustering) ✅
   - WF-05 (Sync) ✅

5. Deploy Maintenance:
   - WF-06 (Cleanup) ✅
   - WF-HEALTH (Optional) ✅

6. Test End-to-End:
   - Ingest 100 articles
   - Verify processing
   - Check AI Search
```

---

## 5. Best Practices - بایدها ✅

### 5.1 Architecture Best Practices

| Practice | Reason | Impact |
|----------|--------|--------|
| **1. Queue Mode (not Regular)** | High availability، horizontal scaling | 🔥 Critical |
| **2. Circuit Breaker for OpenAI** | Prevent cascading failures، save costs | 🔥 Critical |
| **3. Deduplication BEFORE processing** | Avoid wasting OpenAI API calls | 💰 Cost |
| **4. Batch processing (20-50 items)** | Balance throughput vs rate limits | ⚡ Performance |
| **5. Truncate content to 3000 chars** | Reduce tokens = reduce cost | 💰 Cost |
| **6. Use GPT-5 nano (not GPT-4o)** | 4x faster، 47% cheaper | 💰 Cost + ⚡ Speed |
| **7. Cache embeddings در Redis** | 30-50% cost savings | 💰 Cost |
| **8. Exponential backoff for retries** | Respect API rate limits | 🛡️ Reliability |
| **9. Central error logging** | Single source of truth for debugging | 🐛 Debug |
| **10. Health checks every 5 min** | Early detection of issues | 🏥 Monitoring |

---

### 5.2 Node Configuration Best Practices

| Practice | Reason | Example |
|----------|--------|---------|
| **11. Use Native Nodes** | Built-in retry، credential management | Azure OpenAI Chat Node (not HTTP Request) |
| **12. Set reasonable timeouts** | Prevent hanging executions | 300s for AI nodes، 60s for DB queries |
| **13. Enable continueOnFail** | Don't stop entire workflow on single failure | WF-03: If 1 article fails، continue with others |
| **14. Log to both console & file** | Debugging + long-term analysis | \`N8N_LOG_OUTPUT=console,file\` |
| **15. Use environment variables** | Never hardcode credentials | \`{{ $env.OPENAI_API_KEY }}\` |
| **16. Add meaningful node names** | Easy debugging | "Extract Metadata GPT-5 nano" (not "HTTP Request 1") |
| **17. Validate JSON output** | GPT sometimes returns invalid JSON | Try-catch در Code Node |
| **18. Store intermediate results** | Easier troubleshooting | Save raw GPT output before parsing |

---

### 5.3 Performance Best Practices

| Practice | Reason | Improvement |
|----------|--------|-------------|
| **19. Enable parallel execution** | Reduce total workflow time | \`executionOrder: v1\` |
| **20. Use HNSW index for vectors** | Fast similarity search | < 300ms vs 10s with IVFFlat |
| **21. Avoid N+1 queries** | Batch queries instead | 1 query vs 100 queries |
| **22. Set maxTokens limit** | Prevent runaway costs | 400 tokens for metadata extraction |
| **23. Use 512-dim embeddings** | 67% cheaper than 1536-dim | Still 95%+ accuracy |
| **24. Poll database (not webhook)** | More reliable than external triggers | Every 2 min is sufficient |
| **25. Batch upload to AI Search** | Reduce API calls | 100 docs per batch vs 100 individual calls |

---

### 5.4 Cost Optimization Best Practices

| Practice | Monthly Savings | How |
|----------|-----------------|-----|
| **26. GPT-5 nano vs GPT-4o-mini** | $68/month | Use for metadata extraction |
| **27. Cache embeddings** | $20-30/month | Redis cache با content_hash key |
| **28. Free tier AI Search** | $75/month | If < 10K docs |
| **29. Cool Blob tier for archives** | $10/month | Move files > 30 days old |
| **30. Remove old embeddings** | $5/month | Vectors > 30 days deleted |
| **31. Truncate input content** | $15/month | First 3000 chars only |
| **32. Deduplicate before AI** | $20/month | Check url_hash first |

**Total Potential Savings:** $213/month ($295 → $82/month)

---

### 5.5 Security Best Practices

| Practice | Reason | How |
|----------|--------|-----|
| **33. Use Azure Key Vault** | Never hardcode secrets | Store API keys، connection strings |
| **34. Enable TLS/HTTPS** | Encrypt data in transit | n8n webhook URLs |
| **35. Rotate encryption keys** | Prevent long-term compromise | Every 90 days |
| **36. Verify webhook signatures** | Prevent unauthorized calls | HMAC-SHA256 validation |
| **37. Rate limit public endpoints** | Prevent abuse | 100 req/min per IP |
| **38. Use managed identities** | No credentials in code | Azure Managed Identity for Blob/DB access |
| **39. Audit log all changes** | Compliance + forensics | \`audit_log\` table |
| **40. Separate dev/prod credentials** | Prevent accidental production changes | Different Azure OpenAI resources |

---

## 6. Anti-Patterns - نبایدها ❌

### 6.1 Architecture Anti-Patterns

| Anti-Pattern | Why Bad | Correct Approach |
|--------------|---------|------------------|
| **❌ 1. Regular Mode (not Queue)** | Single point of failure | Queue Mode با Redis |
| **❌ 2. No circuit breaker** | Cascading failures، wasted costs | Implement circuit breaker (5 failures → pause) |
| **❌ 3. Synchronous processing** | Blocks execution، no scaling | Queue Mode + async workers |
| **❌ 4. No error logging** | Blind to failures | Central WF-ERROR-HANDLER |
| **❌ 5. Hardcoded URLs/credentials** | Security risk، hard to maintain | Environment variables + Key Vault |

---

### 6.2 Node Configuration Anti-Patterns

| Anti-Pattern | Why Bad | Correct Approach |
|--------------|---------|------------------|
| **❌ 6. HTTP Request for OpenAI** | No auto-retry، manual credential mgmt | Use Native Azure OpenAI Nodes |
| **❌ 7. No timeout set** | Workflows hang forever | Set 300s timeout for AI nodes |
| **❌ 8. Process full content** | Wastes tokens = wastes money | Truncate to 3000 chars |
| **❌ 9. No retry logic** | Single network glitch = failure | Retry 3x با exponential backoff |
| **❌ 10. Generic node names** | Hard to debug | "Extract Metadata GPT-5 nano" (not "Node 1") |

---

### 6.3 Performance Anti-Patterns

| Anti-Pattern | Why Bad | Correct Approach |
|--------------|---------|------------------|
| **❌ 11. Large batch sizes (>100)** | Timeouts، memory issues | Max 50 items per batch |
| **❌ 12. No caching** | Repeat expensive operations | Redis cache for embeddings |
| **❌ 13. N+1 database queries** | 100x slower | Batch queries |
| **❌ 14. Sequential API calls** | 10x slower | Parallel execution |
| **❌ 15. No indexes** | Slow queries | HNSW for vectors، B-tree for url_hash |

---

### 6.4 Cost Anti-Patterns

| Anti-Pattern | Monthly Cost | Correct Approach |
|--------------|-------------|------------------|
| **❌ 16. Use GPT-4 (not GPT-5 nano)** | +$200/mo | GPT-5 nano for simple tasks |
| **❌ 17. No deduplication** | +$50/mo | Check url_hash before processing |
| **❌ 18. 1536-dim embeddings** | +$40/mo | Use 512 dims (sufficient accuracy) |
| **❌ 19. No embedding cache** | +$30/mo | Redis cache با TTL |
| **❌ 20. Process duplicates** | +$20/mo | url_hash check در WF-01 |

**Total Waste:** $340/month if you do all these wrong!

---

### 6.5 Security Anti-Patterns

| Anti-Pattern | Risk | Correct Approach |
|--------------|------|------------------|
| **❌ 21. Hardcoded API keys** | 🔴 Critical | Azure Key Vault |
| **❌ 22. No webhook signature** | 🔴 Critical | HMAC-SHA256 validation |
| **❌ 23. Same key for dev/prod** | 🟡 High | Separate credentials |
| **❌ 24. No rate limiting** | 🟡 High | Cloudflare rate limiting |
| **❌ 25. Credentials in logs** | 🔴 Critical | Mask sensitive data |

---

## 7. Quick Reference Cheat Sheet

### 7.1 Workflow Execution Order

```
Minute 0:  WF-01 (RSS) ────────┐
Minute 2:                      WF-03 (Processing)
Minute 5:  WF-02 (Twitter) ────┘
Minute 15: WF-01 (RSS) ────────┐
           WF-04 (Clustering)   │
           WF-05 (Sync)         WF-03 (Processing)
Minute 17:                     ┘
...
Hour 2 AM: WF-06 (Cleanup)
```

### 7.2 Key Metrics to Monitor

| Metric | Target | Alert If |
|--------|--------|----------|
| WF-03 Success Rate | > 98% | < 95% |
| OpenAI Cost | < $50/mo | > $60/mo |
| Queue Length | < 100 | > 500 |
| Processing Latency | < 60s | > 90s (P95) |
| Error Rate | < 2% | > 5% |

### 7.3 Common Debugging Commands

```bash
# Check queue length
docker exec n8n-redis redis-cli LLEN "bull:n8n:queue"

# Check circuit breaker
docker exec n8n-redis redis-cli GET "circuit:openai"

# View worker logs
docker logs n8n-worker-1 --tail=50 --follow

# Check pending articles
psql -c "SELECT COUNT(*) FROM articles WHERE processing_status='pending';"

# Check last execution
psql -c "SELECT workflow_name, MAX(finished_at) FROM executions GROUP BY workflow_name;"
```

### 7.4 Emergency Procedures

**If WF-03 is failing:**
```bash
# 1. Check circuit breaker
redis-cli GET circuit:openai
# If "open" → Wait 5 min

# 2. Check OpenAI status
curl https://status.openai.com/api/v2/status.json

# 3. Check error logs
psql -c "SELECT * FROM workflow_errors WHERE workflow_name='WF-03' ORDER BY created_at DESC LIMIT 10;"

# 4. Manual reset circuit breaker (if false positive)
redis-cli DEL circuit:openai
redis-cli DEL circuit:openai:failures
```

**If queue is backed up (>500):**
```bash
# 1. Check worker status
docker ps | grep n8n-worker

# 2. Scale workers
docker-compose up -d --scale n8n-worker-2=1 n8n-worker-3=1

# 3. Check for stuck jobs
redis-cli LRANGE "bull:n8n:queue:failed" 0 10
```

---

## 8. Success Criteria

### 8.1 Week 1 Success (Infrastructure)

- [ ] n8n UI accessible
- [ ] Queue Mode verified (Redis connected)
- [ ] All credentials configured
- [ ] WF-ERROR-HANDLER deployed

### 8.2 Week 2 Success (Core Workflows)

- [ ] WF-01 processes 100 RSS articles successfully
- [ ] WF-03 extracts metadata with 95%+ accuracy
- [ ] GPT-5 nano latency < 500ms
- [ ] No critical errors

### 8.3 Week 3 Success (Full System)

- [ ] 5,000 articles/day processed
- [ ] All 6 workflows running
- [ ] Error rate < 2%
- [ ] OpenAI cost < $50/month

### 8.4 Week 4 Success (Production)

- [ ] 500 RSS sources active
- [ ] 200 Twitter accounts active
- [ ] 99.5% uptime
- [ ] No PagerDuty alerts

---

## 9. Team Responsibilities

| Role | Workflows Owned | Responsibilities |
|------|----------------|------------------|
| **Saman** | All workflows | Development، testing، deployment، on-call |
| **Amir** | Infrastructure | Docker Compose، Azure resources، networking |
| **Navid** | WF-03، WF-04 | GPT prompts، AI model tuning، accuracy validation |
| **Reyhaneh** | All database queries | PostgreSQL optimization، indexes، query tuning |
| **Farzad** | None (consumer) | UI integration، API testing |

---

## 10. Next Steps

### Immediate Actions (This Week)

1. **Product Owner:**
   - [ ] Review این سند
   - [ ] Approve workflow list
   - [ ] Approve budget ($50/month OpenAI)

2. **Amir (Infrastructure):**
   - [ ] Setup Docker Compose environment
   - [ ] Deploy Redis
   - [ ] Deploy n8n Main + 2 Workers

3. **Saman (n8n):**
   - [ ] Create WF-ERROR-HANDLER
   - [ ] Create WF-01 (RSS) - test با 10 sources
   - [ ] Create WF-03 (Processing) - test با 50 articles

4. **Navid (AI):**
   - [ ] Test GPT-5 nano prompts
   - [ ] Validate metadata extraction accuracy
   - [ ] Tune temperature/tokens

5. **Reyhaneh (Database):**
   - [ ] Verify HNSW index exists
   - [ ] Test vector search performance
   - [ ] Create monitoring queries

---

## 11. References

### Internal Documents
- [n8n Workflows Master Plan v1.0](n8n-workflows-master-plan-v1.0.md) - Full technical details
- [Data Flow Architecture v1.0](data-flow-architecture-v1.0.md) - System architecture
- [n8n Production Best Practices v1.0](n8n-production-best-practices-v1.0.md) - Deployment guide

### External Resources
- [n8n Docs - Queue Mode](https://docs.n8n.io/hosting/scaling/queue-mode/)
- [Azure OpenAI Docs](https://docs.n8n.io/integrations/builtin/credentials/azureopenai/)
- [GPT-5 Documentation](https://platform.openai.com/docs/models/gpt-5-nano)

---

## 12. Approval & Sign-off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| **n8n Automation Lead** | Saman | ✅ Approved | 2026-02-04 |
| **Software Architect** | Amir | ✅ Approved | 2026-02-04 |
| **AI Engineer** | Navid | ✅ Approved | 2026-02-04 |
| **Database Specialist** | Reyhaneh | ✅ Approved | 2026-02-04 |
| **Product Owner** | [Your Name] | ⏳ Pending | - |

---

**Document Status:** ✅ **APPROVED** - Ready for Team Review  
**Last Updated:** Wednesday, February 4, 2026, 12:42 AM NZDT  
**File:** `docs/n8n-workflows-overview-v1.0.md`

---

**این سند را بخوانید قبل از شروع development!**  
**سوالات؟ → Saman (n8n Lead)**
