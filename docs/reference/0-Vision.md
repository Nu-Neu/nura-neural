
# Product Vision: Nura (MVP Phase)

## Problem Statement

The immense volume of news, disinformation, and complex narratives surrounding Iran makes it impossible for activists to distinguish truth from regime propaganda.

- **Pain Point:** Users are overwhelmed by noise (4k+ daily items) and lack tools to verify source credibility or understand narrative context.
- **Consequence:** Inadvertent spread of misinformation and lack of effective international awareness.


## Target Users \& Personas

### 1. The Diaspora Activist (Primary)

- **Profile:** Iranians living abroad (e.g., Omid).
- **Goal:** To be the "voice of Iran" by amplifying verified news.
- **Needs:**
    - Aggregation of 200+ fragmented sources into one feed.
    - A "Trust Score" to confidently share content.
    - Ready-to-share "News Cards" for social media activism.


### 2. The International Observer (Secondary)

- **Profile:** Non-Iranian journalists and politicians.
- **Needs:** Contextualization of events and clear flagging of propaganda patterns.


## Value Proposition

**"Clarity in Chaos"**
A scalable AI-intelligence platform that aggregates ~200 sources, filters noise, and scientifically scores content.

- **Core Features:**
    - **Smart Aggregation:** Ingests ~4,000 daily items but uses AI to de-duplicate and cluster them into unique stories.
    - **Propaganda Detection:** Identifies patterns (e.g., "Dehumanization") using `GPT-5-nano`.
    - **Actionable Output:** Generates sharable assets (News Cards) with citations.
    - **Bilingual Intelligence:** Translates Farsi feeds to English with context.


## Success Metrics

1. **Engagement:** Average "News Card" shares per active user > 5 per week.
2. **Accuracy:** >85% alignment between AI propaganda detection and human expert validation (measured on a random sample of 50 items/week).
3. **User Acquisition:** Onboarding 50 active activists/journalists by Month 1.

## Constraints

### Technical \& Infrastructure

- **Architecture:** Self-hosted **n8n** (Orchestration) + **Azure OpenAI** + **Vector DB** (for deduplication).
- **Volume Management:**
    - Input: ~200 sources (RSS/Twitter) ≈ 2,000–4,000 items/day.
    - **Optimization Strategy:** Strictly implement **Vector Deduplication** (using `text-embedding-3-small`) to group similar articles *before* sending to expensive LLMs. Reduce analysis load by ~70%.
- **AI Models:**
    - `GPT-5-nano`: For classification and scoring (Cost-effective).
    - `Perplexity Pro`: **Only** triggered for high-impact/disputed news verification (Rate limited).
- **Frontend:** Framer (reading JSON output via Webhooks).


### Time \& Budget

- **Deadline:** MVP Launch in **1 week** (Mid-Feb 2026).
- **Budget Runway:** \$5,000 Azure credits must last until **June 2026**.
    - *Critical:* Avoid "Per-Tweet" analysis. Analyze "Per-Cluster" or "Per-Thread".
- **Data Scope:**
    - Phase 1: RSS + Twitter (Twitterapi.io).
    - Future: Telegram, Web Scraping, User Feedback Loop (RAG Chat).
<span style="display:none">[^1][^2]</span>

<div align="center">⁂</div>

[^1]: design-trust-narrative-system-v1.0.md

[^2]: Iran Propaganda Archive Jan2026

