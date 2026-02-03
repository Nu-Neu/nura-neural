---
doc_type: requirements
version: 1.0
last_updated: 2026-02-03
owner: Product Team
status: approved
---

# Requirements: Multi-Language Support & Filtering

## 1. Overview
Nura must ingest news from Persian (FA) and Arabic (AR) sources to capture local narratives regarding Iranian affairs. However, the core analysis engine and the primary user interface operate in English. This module defines requirements for ingestion, filtering, translation, and storage of multi-language content.

## 2. User Stories (Scoped IDs)

### REQ-LANG-001: Persian & Arabic Ingestion
**As an** Intelligence Analyst,
**I want** the system to ingest news from key Persian and Arabic sources (e.g., BBC Persian, Al-Arabiya, Local Telegram channels),
**So that** I don't miss critical local developments that haven't reached Western wires yet.

### REQ-LANG-002: Irrelevant Content Filtering (Cost Control)
**As a** Product Owner,
**I want** the system to automatically discard non-political/yellow news (e.g., Sports, Celebrity Gossip) *before* processing,
**So that** we do not waste AI tokens and storage on irrelevant data.

### REQ-LANG-003: Automated Translation
**As a** Non-Persian Speaker,
**I want** all non-English items to be automatically translated into objective English,
**So that** I can understand the content and the system can cluster it with other English news.

### REQ-LANG-004: Bilingual Verification Access
**As a** Bilingual User (Activist),
**I want** to see both the English translation and the original Persian text,
**So that** I can verify the accuracy of the translation and share the original source with my local network.

## 3. Acceptance Criteria (AC)

### AC-LANG-001: Source Support
- [ ] System must successfully fetch and parse RSS/HTML from RTL (Right-to-Left) sources.
- [ ] Character encoding (UTF-8) must be preserved correctly for Persian/Arabic characters.

### AC-LANG-002: Noise Reduction
- [ ] **Zero-Cost Filter:** Configuring Miniflux block rules for keywords (e.g., "فوتبال", "سینما") must stop at least 80% of irrelevant items.
- [ ] **Verification:** "Sports" articles must NOT appear in the `items` database table.

### AC-LANG-003: Translation Quality
- [ ] Translation must be performed by `GPT-4o-mini` (or equivalent high-quality model).
- [ ] Proper Nouns (Entities) like "Zahedan", "Khamenei", "Evin Prison" must be transliterated correctly, not translated literally.
- [ ] Translation latency must not exceed 5 seconds per item.

### AC-LANG-004: Dual Storage
- [ ] Database schema must store `title` (original), `body` (original), `title_en`, and `body_en`.
- [ ] API response for `GET /items/{id}` must include both language versions.

## 4. Dependencies
- **Upstream:** Miniflux RSS Reader (for filtering).
- **Downstream:** Narrative Clustering Engine (requires English text).

## 5. References
- [Ref: ADR-002] Multi-Language Ingestion Strategy.
