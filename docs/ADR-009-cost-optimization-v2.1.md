---
doc_type: adr
version: 2.1
last_updated: 2026-02-03
owner: Amir (Software Architect), Nura Team
status: approved
traceability: [Ref: HLD-v2.0], [Ref: Meeting-2026-02-03], [Ref: SRS-v2.4]
---

# ADR-009: Cost Optimization - Free Tier AI Search + GPT-5-nano Migration

## Status
**APPROVED** - 2026-02-03

## Context

### Problem Statement
بررسی معماری HLD v2.0 در جلسه تاریخ 2026-02-03 نشان داد که:

1. **Budget Runway محدود:** با $295/ماه، فقط 17 ماه runtime از بودجه $5,000 باقی می‌ماند
2. **Over-provisioning:** Azure AI Search Basic ($75/ماه) برای فقط 14 روز داده بیش از حد است
3. **AI Costs:** GPT-4o-mini ($30/ماه) برای structured tasks (extraction, classification) گران است
4. **RAG Chat غیرممکن:** بدون کنترل هزینه، RAG feature می‌تواند $85/ماه اضافه کند

### Business Impact
- MVP فقط 17 ماه عمر دارد (کمتر از Phase 2)
- نمی‌توانیم RAG Chat (killer feature) اضافه کنیم
- ریسک بالای تمام شدن بودجه قبل از product-market fit

---

## Decision Summary

### تصمیم 1: Downgrade Azure AI Search به Free Tier
**Status:** ✅ APPROVED  
**Cost Impact:** -$75/ماه  
**Rationale:** Free Tier (50 MB, 10K docs) کافی است برای 14 روز recent data

### تصمیم 2: Migrate به GPT-5-nano as Primary Model  
**Status:** ✅ APPROVED  
**Cost Impact:** -$24/ماه  
**Rationale:** 67% ارزان‌تر، 2-4x سریع‌تر، بهتر برای structured tasks

### تصمیم 3: Enable RAG Chat با Cost Controls  
**Status:** ✅ APPROVED (conditional)  
**Cost Impact:** +$10-30/ماه (با cap)  
**Rationale:** با GPT-5-nano اقتصادی شده، killer feature برای product

---

## تصمیم 1: Azure AI Search Free Tier

### Implementation Strategy

**Data Optimization:**
```
Before (Full indexing):
  - Fields: id, title, body_text (2000 chars), embedding, metadata
  - Size per doc: 8.4 KB
  - 30 days × 500/day = 15,000 docs
  - Total: 126 MB ❌ (بیشتر از 50 MB)

After (Optimized):
  - Fields: id, title, summary (300 chars), embedding, metadata
  - Filters: trust_score >= 50, age <= 14 days
  - Size per doc: 6.7 KB
  - 14 days × 500/day × 60% (filtered) = 4,200 docs
  - Total: 28 MB ✅ (56% of limit)
```

**Hybrid Architecture:**
- Azure AI Search (Free): 14 روز اخیر، trust ≥ 50
- PostgreSQL (pgvector): 90 روز کامل، all items
- Fallback logic: اگر نتیجه کافی نبود → PostgreSQL

### Trade-offs

| Feature | Basic SKU | Free Tier | Impact |
|---------|-----------|-----------|--------|
| Semantic Ranking | ✅ | ❌ | متوسط - vector search جبران می‌کند |
| Hybrid Scoring | ✅ | ❌ | کم - در application layer ترکیب می‌کنیم |
| QPS | 15 | 3 | کم - traffic < 1 QPS |
| Storage | 2 GB | 50 MB | خوب - 28 MB نیاز داریم |

---

## تصمیم 2: GPT-5-nano Primary Model

### Model Selection Strategy

**Tier 1: GPT-5-nano (95% tasks)**
- Use cases: extraction, translation, classification, clustering, RAG
- Pricing: $0.05/1M input, $0.40/1M output
- Expected cost: $6/ماه

**Tier 2: GPT-4o-mini (5% edge cases)**
- Use cases: complex clustering, narrative summaries
- Expected cost: $0.50/ماه

### Cost Comparison

```
Current (GPT-4o-mini only): $30/ماه
Proposed (GPT-5-nano primary): $6/ماه
Savings: $24/ماه (80% reduction)
```

### Performance Benchmarks

| Task | GPT-4o-mini | GPT-5-nano | Winner |
|------|-------------|------------|--------|
| Metadata Extraction | 96% | 99% | nano ✅ |
| Translation Quality | 8.5/10 | 8.7/10 | nano ✅ |
| Latency (P95) | 1.8s | 0.45s | nano ✅ |
| Complex Reasoning | 87% | 82% | mini ⚠️ |

---

## تصمیم 3: RAG Chat با Cost Controls

### Cost Analysis

**Without Controls (Worst Case):**
```
500 users × 10 queries/day = 150K/month
Cost: 150K × $0.00027 = $40.50/mo 💀
```

**With Controls (Recommended):**
```
Rate Limiting:
  - Free: 400 users × 3 q/day = 1,200
  - Registered: 100 users × 10 q/day = 1,000
  - Total: 66K/month

Caching (40% hit rate):
  - Effective queries: 39.6K
  - Cost: 39.6K × $0.00027 = $10.69/mo

Redis cache: $5/mo
Total: $15.69/mo ✅
```

### Cost Control Mechanisms

1. **Rate Limiting:** 3-10 queries/day per user tier
2. **Smart Caching:** 40-50% hit rate (Redis 24h TTL)
3. **Daily Budget Cap:** $1/day = $30/month max
4. **Progressive Rollout:**
   - Phase 2A (ماه 5-6): 50 users beta → $8/mo
   - Phase 2B (ماه 7-8): 200 users → $10/mo
   - Phase 2C (ماه 9+): 500+ users → $30/mo max (capped)

---

## Budget Impact

### محاسبه نهایی

**MVP (ماه 1-4):**
```
PostgreSQL (B1ms):           $12/ماه
GPT-5-nano (base):           $6/ماه
text-embedding-3-small:      $15/ماه
Azure AI Search (Free):      $0/ماه
Infrastructure:              $80/ماه
────────────────────────────────────
TOTAL:                       $113/ماه
Runtime: 44.2 ماه
```

**Phase 2 with RAG (ماه 5+):**
```
MVP baseline:                $113/ماه
GPT-5-nano (RAG):            $10-30/ماه (با cap)
Redis (cache):               $5/ماه
────────────────────────────────────
TOTAL:                       $128-153/ماه
Runtime: 32.7-39.1 ماه
```

### مقایسه با HLD v2.0

| Version | Monthly Cost | Runtime | Improvement |
|---------|--------------|---------|-------------|
| HLD v2.0 | $295/mo | 17 mo | baseline |
| **HLD v2.1 MVP** | **$113/mo** | **44 mo** | **+27 ماه** 🎉 |
| **HLD v2.1 Full** | **$153/mo** | **33 mo** | **+16 ماه** 🎉 |

**Total Savings:** $182/mo × 32 months = **$5,824**

---

## Consequences

### مزایا (Positive)

1. **بهبود Budget Runway:** از 17 ماه به 33-44 ماه (+16-27 ماه)
2. **صرفه‌جویی هزینه:** $5,824 در طول پروژه
3. **بهبود Performance:** latency 3-4x سریع‌تر (0.6s vs 2s)
4. **Features جدید:** RAG Chat امکان‌پذیر شد

### معایب و Mitigations

1. **Free Tier Limitations:** بدون Semantic Ranking
   - Mitigation: Application-level hybrid scoring + pgvector fallback

2. **Model Quality:** GPT-5-nano برای complex reasoning 5% ضعیف‌تر
   - Mitigation: Fallback به GPT-4o-mini برای edge cases

3. **RAG Cost Risk:** احتمال viral growth
   - Mitigation: Daily cap $1/day + rate limiting + kill switch

4. **Hybrid Complexity:** دو سیستم جستجو
   - Mitigation: Abstraction layer + automated sync

---

## Implementation Plan

### Week 1-2: AI Search Migration
- [ ] Create Free Tier instance
- [ ] Implement optimized schema
- [ ] Deploy sync workflow (n8n)
- [ ] Migrate production data
- [ ] Monitor index size

### Week 3-4: GPT-5-nano Migration
- [ ] A/B test quality vs GPT-4o-mini
- [ ] Update n8n workflows
- [ ] Deploy fallback logic
- [ ] Gradual rollout: 10% → 50% → 100%

### Week 5-6: RAG Chat Beta
- [ ] Deploy Redis cache
- [ ] Implement rate limiting + budget cap
- [ ] Launch beta (50 users)
- [ ] Monitor costs daily

---

## Monitoring

### KPIs

**MVP (Months 1-4):**
- Monthly cost ≤ $120/mo
- Budget runway ≥ 40 months
- AI Search index < 45 MB
- API P95 latency < 1000ms

**Phase 2 (Months 5+):**
- RAG daily cost ≤ $1/day
- Cache hit rate ≥ 40%
- Monthly cost ≤ $160/mo
- Budget runway ≥ 30 months

### Real-Time Alerts

- Daily spend > $10 (warning)
- AI Search index > 45 MB (90% threshold)
- RAG cost > $0.70/day (70% threshold)
- P95 latency > 1000ms (SLA breach)

---

## Rollback Plan

**AI Search Rollback (< 1 hour):**
1. Switch DNS to Basic tier standby
2. Restore backup
3. Update config
4. Validate

**Model Rollback (< 30 min):**
1. Set MODEL=gpt-4o-mini
2. Restart containers
3. Validate quality

**RAG Disable (< 5 min):**
1. Set RAG_ENABLED=false
2. Display maintenance message

---

## Success Metrics

### Phase 1 (MVP)
✅ Monthly cost ≤ $120/mo  
✅ Runtime ≥ 40 months  
✅ API latency < 1000ms  
✅ Zero downtime

### Phase 2 (RAG)
✅ RAG cost ≤ $30/mo (capped)  
✅ Cache hit ≥ 35%  
✅ User satisfaction ≥ 4/5  
✅ Error rate < 5%

---

## References

- [Ref: HLD-v2.0] - High-Level Design v2.0 (superseded)
- [Ref: Meeting-2026-02-03] - Budget Review Meeting
- [Ref: SRS-v2.4] - Requirements Specification
- [Azure AI Search Free Tier](https://learn.microsoft.com/azure/search/search-limits-quotas-capacity)
- [GPT-5-nano Documentation](https://platform.openai.com/docs/models/gpt-5-nano)

---

## Approval

| Role | Name | Decision | Date |
|------|------|----------|------|
| Product Owner | [To be filled] | ✅ Approved | 2026-02-03 |
| Software Architect | Amir | ✅ Approved | 2026-02-03 |
| AI Engineer | Nوید | ✅ Approved | 2026-02-03 |
| DB Specialist | ریحانه | ✅ Approved | 2026-02-03 |
| Media Expert | کاوه | ✅ Approved | 2026-02-03 |

---

**Document Status:** ✅ APPROVED  
**Next Review:** 2026-03-03  
**Contact:** amir@nura.ai

---

*This ADR follows Docs-as-Code principles: versioned, modular, and traceable.*
