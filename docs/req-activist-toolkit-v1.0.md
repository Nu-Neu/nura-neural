---
doc_type: requirements
version: 1.0
last_updated: 2026-02-03
owner: Product Team
status: approved
---

# Requirements: Activist Toolkit & Smart Sharing

## 1. Overview
NURA is not just for consuming news; it is an enablement platform for the Iranian Diaspora. This module defines features that help users effectively share verified narratives on social media (X/Twitter, Instagram) to counter propaganda and amplify the voice of the Iranian people to an international audience.

## 2. User Stories (Scoped IDs)

### REQ-ACT-001: Contextual Social Captioning
**As a** Diaspora Activist,
**I want** the system to generate ready-to-use captions for X (Twitter) and Instagram based on the news item,
**So that** I can share the story instantly without worrying about language barriers, tone, or formatting.

### REQ-ACT-002: Counter-Narrative Talking Points
**As a** Community Advocate,
**I want** to see bullet points comparing "Regime Claims" vs. "Verified Facts",
**So that** I can effectively debate misinformation in social media comments sections.

### REQ-ACT-003: Shareable Visual Assets (Instagram Mode)
**As a** Social Media User,
**I want** to download a branded image summarizing the news and its Trust Score,
**So that** I can post it to my Instagram Story/Feed as visually verified content.

## 3. Acceptance Criteria (AC)

### AC-ACT-001: AI Caption Generation
- [ ] The "Share" modal must offer 3 tonal options:
    - **Informative:** Neutral, journalistic tone.
    - **Advocacy:** Passionate, call-to-action oriented.
    - **Debunking:** Focused on correcting specific propaganda.
- [ ] Generated text must include relevant hashtags (e.g., #IranRevolution, #WomanLifeFreedom) but avoid banned/shadow-banned tags.
- [ ] Text must be length-optimized for the platform (280 chars for X).
- [ ] **Traceability**: Validates [REQ-ACT-001].

### AC-ACT-002: Propaganda Counter-Script
- [ ] If a narrative includes a "Regime Proxy" source, the UI must show a "Counter-Narrative" box.
- [ ] Box must list:
    1.  The Lie (What state media says).
    2.  The Truth (What verified sources say).
    3.  The Evidence (Link to primary doc/photo).
- [ ] Content must be copy-pasteable.
- [ ] **Traceability**: Validates [REQ-ACT-002].

### AC-ACT-003: Dynamic Image Generation (OG Image)
- [ ] System must generate a static image (PNG/JPG) on the fly containing:
    - Headline.
    - Trust Badge (Green/Yellow/Red).
    - Source Name.
    - NURA Watermark (for brand authority).
- [ ] Image dimensions must be optimized for Instagram Story (9:16) and Twitter Card (2:1).
- [ ] **Traceability**: Validates [REQ-ACT-003].

## 4. Technical Constraints
- **AI Model:** Use `GPT-4o-mini` for caption generation (low latency, low cost).
- **Image Gen:** Use a template-based engine (e.g., `satori` or `html-to-image`) rather than expensive diffusion models (DALL-E) to keep costs low and text readable.
- **Language:** Output must be high-quality English (primary) but support user editing before copying.

## 5. References
- [Ref: SRS-v2.4] Core Platform Requirements.
