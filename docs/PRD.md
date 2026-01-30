# Product Requirements Document: Nura Neural

**Version:** 1.0  
**Date:** January 31, 2026  
**Project Name:** Nura Neural  
**Target Launch:** June 30, 2026

---

## 1. Project Overview
**Nura Neural** is an AI-powered intelligence platform designed to automatically detect propaganda, verify claims, and profile sources for media and activist organizations. The system ingests news feeds, utilizes two specialized AI agents to evaluate credibility and cluster narratives, and delivers actionable insights via embeddable web widgets. The MVP will launch by June 30, 2026, serving `irdecode.com` and `Action4Iran.com`.

## 2. User Stories
- **As an Admin**, I want to configure RSS feeds and Twitter keywords so **Nura Neural** automatically ingests relevant content for analysis.
- **As a Researcher**, I want "Agent 1" to evaluate sources using the **IMTT rubric** (Independence, Methodology, Transparency, Triangulation) to identify propaganda outlets.
- **As a Researcher**, I want "Agent 2" to cluster semantically similar claims into narratives so I can track the evolution of disinformation campaigns.
- **As a Journalist**, I want to use the **Nura Neural Widget** to instantly fact-check text or URLs against verified evidence.
- **As a Site Owner**, I want to embed a "Credibility Badge" that displays a source's trust score to my readers.

## 3. Key Features
### Dual-Agent Backend
*   **Source Evaluator (Agent 1):** Classifies sources (Baseline, Propaganda, etc.) with evidence logs and confidence scores based on the IMTT rubric.
*   **Narrative Clusterer (Agent 2):** Groups semantically similar claims to map narrative evolution over time.

### Granular Analysis
*   **Claim Decomposition:** Breaks articles down into "Concrete Fact," "Narrative/Framing," and "Opinion" layers.
*   **Verification:** Cross-references concrete claims against a trusted evidence database.

### Embeddable Widget Suite
*   **Fact-Check Form:** Instant verification for user-submitted text/URLs.
*   **Propaganda Detector:** Visual indicator (Clean/Biased/Propaganda) with technique analysis.
*   **Narrative Tracker:** Real-time feed of trending disinformation narratives.
*   **Source Credibility Badge:** Visual trust score for cited domains.

### OSINT Profiling
*   **Automated Profiling:** Generates source profiles based on historical accuracy, bias, and network behavior.

## 4. Technical Constraints
*   **Infrastructure:** Microsoft Azure (Container Apps, SQL Database, Blob Storage).
*   **AI Stack:** **OpenAI GPT-4o** for reasoning; **Azure AI Search** with vector indexing for RAG; orchestrated via **LangChain**.
*   **Performance:**
    *   Cached widget responses: **<3 seconds**
    *   Fresh analysis: **<30 seconds**
*   **Scope:** MVP limited to English & Persian input (English output only) and RSS/Twitter sources.
*   **Timeline:** Alpha (Feb 2026), Beta (April 2026), MVP Launch (June 30, 2026).

## 5. Success Metrics
*   **Volume:** **10,000+ claims** processed and indexed by launch.
*   **Accuracy:** **≥80% match** against human expert classifications for propaganda detection.
*   **Adoption:** Widgets successfully deployed and live on **2 target websites** (irdecode.com, Action4Iran.com).
*   **Scale:** System supports **500+ concurrent widget users** with stable performance.
