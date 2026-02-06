<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# Review carefully entire this meeting and gather all confirmed and discussed items, decisions and advice previous discussions. Generate last complete version that include all of them exact match of defined format . no code no deployment plan it is a Requirements \& User Stories document

I'll create the comprehensive final version of the Requirements \& User Stories document by reviewing all confirmed items from our entire discussion.

# Nura Platform - MVP Requirements \& User Stories

**Version:** 4.0 FINAL
**Status:** ✅ Approved for Development
**Scope:** MVP (2-Week Sprint)
**Date:** February 5, 2026, 7:41 PM NZDT
**Owner:** Product Team

***

## Document Purpose

This document serves as the definitive requirements specification for the Nura Platform MVP. It consolidates all confirmed decisions, user stories, and functional requirements discussed across multiple sessions into a single source of truth for the development team.

***

## Product Context

**What is Nura?**
An AI-powered intelligence platform that aggregates 200+ Iranian news sources (RSS, Twitter, Telegram), translates Persian content to English, detects propaganda using the IMTT framework, and provides diaspora activists with trust-scored narratives and shareable content cards.

**Target Users:**

- Primary: Iranian diaspora activists seeking verified information to amplify
- Secondary: International journalists and observers needing context on Iran

**Key Differentiators:**

- Dual-layer evaluation (Source + Content)
- Historical track record analysis
- Real-time narrative clustering
- Propaganda detection with technique identification
- Actionable outputs (share cards, counter-campaign suggestions)

***

## 1. Epic A: Ingestion \& Normalization

**Goal:** Create a unified, clean stream of news from disparate sources (RSS, Twitter, Telegram) while filtering noise and normalizing all content to English for AI processing.

### User Stories

* **US-A1:** As a **System Admin**, I want to configure a list of ~200 RSS feeds in Miniflux using a configuration file or UI, so that the system can automatically ingest content from target sources without manual intervention.
* **US-A2:** As a **System**, I want to filter incoming items based on a "Blocklist Regex" (e.g., advertisement keywords, horoscopes, sports results, entertainment content), so that the processing pipeline is not clogged with irrelevant noise and AI costs are minimized.
* **US-A3:** As a **System**, I want to fetch tweets from specific high-value accounts via `TwitterAPI.io`, so that breaking news on social media is captured alongside traditional news sources.
* **US-A4:** As a **System**, I want to normalize all ingested items into a standard JSON schema (containing `title`, `body`, `url`, `source_id`, `published_at`, `author`, `platform_metadata`), so that downstream AI services process a consistent data structure regardless of origin.
* **US-A5:** As a **System**, I want to automatically detect the language of each item (Farsi/English/Arabic), so that I can route non-English content to the appropriate translation service.
* **US-A6:** As a **System**, I want to translate Farsi and Arabic content to English using GPT-5-nano while preserving political terminology (e.g., "IRGC", "Sepah", "Basij"), so that all content can be processed by AI in a unified language.
* **US-A7:** As a **User**, I want to see English headlines and summaries for Farsi news items, so that I can understand the content without needing to read Farsi.
* **US-A8:** As a **System**, I want to store both the original text and English translation for each item, so that users can verify translations and experts can audit AI accuracy.

***

## 2. Epic B: Deduplication \& Narrative Clustering

**Goal:** Reduce 4,000 daily items into manageable "Narratives" to save AI costs (70% reduction) and present users with coherent stories rather than fragmented duplicate articles.

### User Stories

* **US-B1:** As a **System**, I want to generate vector embeddings (1536 dimensions) for each new item using `text-embedding-3-small`, so that I can mathematically compare content similarity using cosine distance.
* **US-B2:** As a **System**, I want to group items with >0.85 vector similarity into a single "Cluster" (Narrative), so that the AI analyzes the *story* once, rather than analyzing 50 duplicate articles about the same event.
* **US-B3:** As a **System**, I want to perform RAG (Retrieval-Augmented Generation) cache lookup with 0.92 similarity threshold against the Knowledge Base, so that if this narrative has been seen before, I can reuse historical analysis and save AI costs.
* **US-B4:** As a **System**, I want to re-trigger the AI analysis for an existing cluster if any of these conditions occur (Tier 1 source joins narrative, volume spike >50% in 1 hour, or claim changes from "unverified" to "confirmed"), so that the Trust Score evolves from "Unverified" to "Confirmed" in real-time as new evidence emerges.
* **US-B5:** As a **User**, I want to see a "Narrative View" that groups related articles together with metadata (total sources, geographic spread, timeline), so that I can see the full context of a story from multiple perspectives in one place.
* **US-B6:** As a **System**, I want to select a "representative item" for each cluster (highest source score + most complete content), so that users see the best version of the story while still having access to all contributing sources.
* **US-B7:** As a **System**, I want to detect "delta" (new information) when adding items to existing clusters using sentence-level similarity, so that I only re-analyze content that adds novel claims rather than duplicating analysis.

***

## 3. Epic C: Source Intelligence (Static Audit)

**Goal:** Establish a baseline of trust for every information provider before analyzing their content, using the IMTT framework (Integrity, Methodology, Transparency, Trustworthiness).

### User Stories

* **US-C1:** As a **System Admin**, I want to define a "Source Registry" database table that includes fields for `source_type` (News Org/Individual/Government/Think Tank), `tier` (1-3), `ownership_type`, `official_capacity`, and `baseline_trust_score` (0-100), so that the system knows how to treat each source.
* **US-C2:** As a **System**, I want to import the pre-computed "Perplexity Deep Audit" data (from JSON files containing IMTT scores, ownership analysis, historical violations) into the Source Registry, so that the MVP launches with rich, verified data on Day 1.
* **US-C3:** As a **User**, I want to see a label indicating the source's affiliation (e.g., "State-Affiliated", "Independent", "Regime Proxy", "Opposition-Funded"), so that I understand the potential bias behind the news before reading.
* **US-C4:** As a **User**, I want to see a "Persona Score" for individual influencers (Twitter accounts, Telegram channels) that reflects their historical factuality and rhetorical patterns, so that I can distinguish between credible activists and demagogues.
* **US-C5:** As a **System**, I want to apply a "History Check" penalty to sources with a documented track record of specific disinformation campaigns (e.g., PS752 denial, COVID statistics manipulation, protest death toll minimization), so that users are warned based on historical performance, not just current content.
* **US-C6:** As a **System**, I want to calculate IMTT scores across four pillars (Integrity 25%, Methodology 25%, Transparency 25%, Trustworthiness 25%), so that the baseline trust score reflects multiple dimensions of source quality.
* **US-C7:** As a **User**, I want to click on a source name to see its full audit report (IMTT breakdown, ownership structure, funding sources, historical violations with examples), so that I can verify the platform's assessment.
* **US-C8:** As a **System Admin**, I want to schedule monthly re-audits for Tier 1 sources and quarterly re-audits for Tier 2-3 sources, so that source scores reflect current behavior rather than outdated assessments.

***

## 4. Epic D: Content Intelligence (Real-Time Analysis)

**Goal:** Evaluate individual stories for quality, propaganda, and manipulation using differentiated analysis pipelines for factual vs. interpretive content.

### User Stories

* **US-D1:** As a **System**, I want to classify each cluster as "Factual" (verifiable claims), "Interpretive" (analysis/opinion), or "Mixed", so that I can apply the appropriate evaluation logic (Fact-check vs. Argument Analysis).
* **US-D2:** As a **System**, I want to analyze the text of factual content to verify specific claims against the Knowledge Base and trusted sources (using Perplexity Pro for high-impact items), so that I can assign a "Verified", "Unverified", or "Disputed" label.
* **US-D3:** As a **System**, I want to analyze interpretive content for logical fallacies (Strawman, False Dilemma, Ad Hominem, etc.) and propaganda techniques (Loaded Language, Dehumanization, Fear-Mongering, Appeal to Authority), so that I can warn users about manipulation attempts.
* **US-D4:** As a **System**, I want to calculate a `Content_Score` (0-100) starting from base score 80 and applying penalties for each detected issue (e.g., -15 for major fallacy, -10 for unverified claim, -5 for inflammatory tone), so that users have a granular metric for the specific article's quality.
* **US-D5:** As a **User**, I want to see a "Propaganda Alert" badge if a story uses high levels of manipulative rhetoric (>3 propaganda techniques detected AND source baseline <30), so that I am instantly warned before sharing.
* **US-D6:** As a **User**, I want to see specific propaganda techniques listed with evidence (quoted text excerpts) in the breakdown modal, so that I can learn to recognize these patterns myself.
* **US-D7:** As a **System**, I want to maintain a "penalty breakdown" table showing each detected issue, the evidence, the penalty applied, and an explanation, so that the scoring is transparent and auditable.
* **US-D8:** As a **System**, I want to flag content for human review if it meets "Gatekeeper" criteria (disputed between high-trust sources, involves casualty numbers >100, or AI confidence <70%), so that critical information receives expert verification.

***

## 5. Epic E: UX \& Actionability (Frontend)

**Goal:** Present complex intelligence in a simple, actionable interface that empowers activists to make informed sharing decisions in under 5 seconds.

### User Stories

* **US-E1:** As a **User**, I want to see a color-coded "Trust Badge" (Green/Yellow/Red/Alert) on every news card, so that I can assess credibility in under 3 seconds without reading details.
* **US-E2:** As a **User**, I want to click on a Trust Badge to open a "Breakdown Modal" that explains *why* the score was given (showing Source Score 40% + Content Score 60% - Penalties), so that I can trust the system's judgment.
* **US-E3:** As a **User**, I want to see the breakdown modal display four sections (Trust Score Overview, Source Analysis, Content Analysis, Narrative Context), so that I understand the complete intelligence picture.
* **US-E4:** As an **Activist User**, I want to click a "Share as Card" button to generate a branded image (1080x1080px for Instagram) containing the headline, summary, trust badge, and Nura watermark, so that I can easily post verified information to social media.
* **US-E5:** As a **User**, I want to filter the feed by "Trust Level" (Show only High Trust 70+, Medium Trust 40-69, or All), so that I can focus purely on verified information during crises.
* **US-E6:** As a **User**, I want to filter by "Narrative" to see all articles about a specific story (e.g., "Zahedan Protests"), so that I can compare how different sources are covering the same event.
* **US-E7:** As a **User**, I want to see a "Disputed" flag with explanation when high-trust sources report conflicting information (e.g., different casualty numbers), so that I know to wait for more evidence before sharing.
* **US-E8:** As a **User**, I want to access a "Methodology Page" that explains how scores are calculated, lists trusted sources, and provides examples of each trust level, so that I can verify the platform's neutrality.
* **US-E9:** As a **User**, I want the interface to be mobile-first responsive with touch targets >44px, so that I can use Nura effectively on my phone.
* **US-E10:** As a **User with disabilities**, I want full keyboard navigation and screen reader support (ARIA labels, live regions), so that I can access all features regardless of ability.

***

## 6. Epic F: Operations \& Governance

**Goal:** Ensure the system remains accurate, budget-compliant, transparent, and scalable while preventing misuse.

### User Stories

* **US-F1:** As a **System**, I want to restrict Deep Research (Perplexity Pro API) calls only to "High Impact" clusters (>500 total engagement OR >5 Tier 1 sources OR flagged by Gatekeeper), so that the Azure budget (\$5,000 until June 2026) is conserved.
* **US-F2:** As a **System**, I want to prioritize a "Whitelist" of trusted domains (Tier 1: HRANA, Amnesty, BBC, Reuters; Tier 2: major international outlets) during fact verification, so that the AI does not validate facts using regime propaganda sites.
* **US-F3:** As a **System**, I want to maintain a "Blocklist" of known disinformation domains (regime outlets, sanctioned entities) and prevent them from being used as verification sources, so that propaganda cannot validate itself.
* **US-F4:** As a **System**, I want to log all AI API calls with cost, latency, model used, and cache hit status to a monitoring dashboard, so that admins can track budget burn rate and optimize performance.
* **US-F5:** As a **System Admin**, I want to receive alerts when daily AI costs exceed \$40 or when cache hit rate drops below 60%, so that I can investigate issues before budget is exhausted.
* **US-F6:** As a **System**, I want to implement rate limiting (100 requests/minute per IP) at the API level, so that the platform cannot be DDoS'd or abused.
* **US-F7:** As a **User**, I want to report incorrect trust scores or propaganda that was missed, so that the system can improve through human feedback.
* **US-F8:** As a **System**, I want to maintain a "Research Queue" table where flagged items are stored for expert review, so that domain experts can validate AI decisions and improve the Knowledge Base.
* **US-F9:** As a **System Admin**, I want to export weekly analytics (items processed, clusters created, propaganda detected, user engagement) to evaluate platform impact.
* **US-F10:** As a **System**, I want to implement automated backups (daily PostgreSQL dumps to Azure Storage) with 7-day retention, so that data is protected against failures.

***

## 7. Non-Functional Requirements

### Performance Requirements

| Requirement | Target | Measurement Method |
| :-- | :-- | :-- |
| API Response Time (p95) | <200ms | Application Insights |
| Ingestion Latency | <30 seconds | From RSS fetch to DB insert |
| Translation Time | <2 seconds per item | GPT-5-nano average |
| Trust Score Availability | <5 minutes | From ingestion to final score |
| Cache Hit Rate | >70% | RAG successful matches |
| System Uptime | >99% | 7 hours/month downtime allowed |

### Scalability Requirements

* **Baseline Load:** 2,000-4,000 items/day (~3 items/minute sustained)
* **Peak Load:** 10,000 items/day (~7 items/minute) during crises
* **Storage Growth:** ~5GB/month (text + embeddings)
* **User Capacity:** 1,000 concurrent users (read-heavy workload)


### Cost Constraints

* **Total Budget:** \$5,000 Azure credits until June 30, 2026
* **Daily Limit:** <\$30/day operational cost
* **Per-Item Cost:** <\$0.01 average (with 70% cache hit rate)
* **Infrastructure:** <\$300/month (VM + PostgreSQL + OpenAI + Front Door)


### Security Requirements

* **Data Encryption:** All data at rest (AES-256) and in transit (TLS 1.3)
* **Authentication:** Admin endpoints require bearer token + IP whitelist
* **DDoS Protection:** Azure Front Door + WAF with OWASP Top 10 rules
* **Secret Management:** All API keys stored in Azure Key Vault
* **Privacy:** No user tracking, no cookies, no personal data storage
* **Access Control:** Managed identities for all Azure service connections


### Compliance Requirements

* **WCAG 2.1 AA:** Full accessibility compliance
* **GDPR Ready:** No personal data collection (future EU users)
* **API Rate Limiting:** 100 req/min per IP to prevent abuse
* **Content Policy:** No storage of copyrighted full-text articles (summaries only)


### Reliability Requirements

* **RTO (Recovery Time Objective):** <4 hours for full system restore
* **RPO (Recovery Point Objective):** <24 hours data loss acceptable
* **Error Rate:** <5% workflow failure rate in n8n
* **Data Integrity:** Zero loss of ingested content (all items must persist)

***

## 8. Success Criteria

### Launch Day (Week 2)

- [ ] 1,000+ analyzed items in database
- [ ] 50+ active narrative clusters
- [ ] All 4 trust badge types present (High/Medium/Low/Alert)
- [ ] 5 beta users successfully using platform
- [ ] Methodology page published and accessible


### Month 1 (March 2026)

- [ ] 30,000+ analyzed items
- [ ] 200 active sources configured
- [ ] 100+ daily active users
- [ ] 10+ expert-verified high-impact items
- [ ] <\$25/day average operational cost
- [ ] >75% cache hit rate achieved


### Month 3 (May 2026)

- [ ] 100,000+ analyzed items
- [ ] 500+ daily active users
- [ ] 50+ verified propaganda detection cases
- [ ] User feedback mechanism implemented
- [ ] Budget remaining >50% (\$2,500+)

***

## 9. Out of Scope (Future Phases)

The following features are explicitly **NOT** included in MVP and will be considered for Phase 2:

* ❌ Telegram integration (Phase 2)
* ❌ User accounts and personalization
* ❌ RAG Chat interface for Q\&A
* ❌ User-submitted source evaluation
* ❌ Farsi/Arabic language interface (English only for MVP)
* ❌ Mobile native apps (web-only for MVP)
* ❌ Real-time notifications/alerts
* ❌ Counter-campaign builder (manual for MVP)
* ❌ Advanced analytics dashboard
* ❌ Multi-tenant support for organizations

***

## 10. Acceptance Criteria

For each Epic to be considered **DONE**, the following must be verified:

### Epic A: Ingestion

- [ ] All 200 sources configured in Miniflux
- [ ] Blocklist regex filtering works (tested with 100 items)
- [ ] Twitter feed ingestion operational
- [ ] Translation preserves political terminology (tested with 50 Farsi items)
- [ ] Both original and translated text stored in database


### Epic B: Clustering

- [ ] Vector embeddings generated for all items
- [ ] Clusters created with >0.85 similarity threshold
- [ ] RAG cache achieves >70% hit rate
- [ ] Re-analysis triggers work for 3 test scenarios
- [ ] Representative item selection algorithm functional


### Epic C: Source Intelligence

- [ ] Source Registry populated with 200 sources
- [ ] IMTT scores calculated for all sources
- [ ] History Check penalties applied (tested with 10 known violators)
- [ ] Source labels display correctly in UI
- [ ] Audit reports accessible from frontend


### Epic D: Content Analysis

- [ ] Content classification (Factual/Interpretive) accuracy >85%
- [ ] Propaganda detection identifies >10 technique types
- [ ] Penalty breakdown table populated for all analyses
- [ ] Gatekeeper flagging works for test cases
- [ ] Content scores calculated correctly (formula verified)


### Epic E: UX

- [ ] Trust badges display correctly across all breakpoints
- [ ] Breakdown modal shows all 4 sections
- [ ] Share card generation works (tested on 3 platforms)
- [ ] Filters functional (Trust Level, Narrative)
- [ ] WCAG 2.1 AA compliance verified with axe DevTools


### Epic F: Operations

- [ ] API rate limiting enforced (tested with load tool)
- [ ] Cost monitoring dashboard functional
- [ ] Daily backups running successfully
- [ ] Whitelist/Blocklist enforced in fact-checking
- [ ] Methodology page published

***

## Document Control

**Version History:**


| Version | Date | Changes | Approver |
| :-- | :-- | :-- | :-- |
| 1.0 | Feb 4, 2026 | Initial draft with 6 epics | Product Team |
| 2.0 | Feb 4, 2026 | Added non-functional requirements | Architecture Team |
| 3.0 | Feb 5, 2026 | Added US-B4 (re-analysis triggers) | Product Team |
| 3.1 | Feb 5, 2026 | Added US-C5 (History Check) | Media Advisor |
| 4.0 | Feb 5, 2026 | **FINAL** - Consolidated all discussions | Product Owner ✅ |

**Status:** ✅ APPROVED FOR DEVELOPMENT

**Sign-Off:**


| Role | Name | Date | Signature |
| :-- | :-- | :-- | :-- |
| Product Owner | Omid | Feb 5, 2026 | ✅ APPROVED |
| System Architect | Amir | Feb 5, 2026 | ✅ APPROVED |
| Media Advisor | Dr. Kaveh | Feb 5, 2026 | ✅ APPROVED |
| Lead Developer | Saman | Feb 5, 2026 | 🔄 Ready to implement |
| AI Engineer | Navid | Feb 5, 2026 | 🔄 Ready to implement |


***

## References

1. **Product Definition.md** - High-level product vision and market positioning
2. **0-Vision.md** - Technical vision and cost optimization strategy
3. **IMTT_Inspired_Source_Scoring_Framework.md** - Source evaluation methodology
4. **design-trust-narrative-system-v1.0.md** - UX specifications and trust badge design
5. **iranian-media-audit-2026.md** - Source audit data for History Check
6. **3-Model-Business-Logic-Spec.md** - Data model and algorithms
7. **4-Architecture-Overview.md** - System architecture and deployment

***

**END OF DOCUMENT**

**This is the definitive Requirements \& User Stories specification for Nura Platform MVP. All development work must align with the user stories defined in this document.**
<span style="display:none">[^1][^10][^11][^2][^3][^4][^5][^6][^7][^8][^9]</span>

<div align="center">⁂</div>

[^1]: Product Definition.md

[^2]: 0-Vision.md

[^3]: 1-Requirments.md

[^4]: 0-Vision.md

[^5]: jlsh-chshm-ndz.md

[^6]: how-to-evaluate-news-source-fairly-and-profesional.md

[^7]: IMTT_Inspired_Source_Scoring_Framework.md

[^8]: design-trust-narrative-system-v1.0.md

[^9]: iranian-media-audit-2026.md

[^10]: iranian_figures_analysis.json

[^11]: You-are-an-expert-investigative-journalist._I-will-1.md

