<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# Master Functional Specification: Source Evaluation \& Narrative Intelligence

**Version:** 3.0 (Final Engineering Release)
**Date:** February 2, 2026
**Status:** Approved for Development
**Reference:** Nura Neural Platform - Logic Core

***

## 1. Executive Summary

This document defines the **hard logic** for the Nura Platform’s AI reasoning layer. It replaces subjective editorial guidelines with deterministic algorithms, database constraints, and scoring formulas.

**Primary Goal:** Enable the "Three-Layer AI" to verify news and cluster narratives without constant human intervention.
**Key Output:** Every news item receives a `trust_score` (15-95) and is assigned to a `narrative_id`.

***

## 2. Data Dictionary \& Enumerations

### 2.1 Source Classification Taxonomy

**Field:** `source_profiles.source_class` (Enum) \& `source_subclass` (Enum)
*Strict hierarchy defining the "Base Score".*


| Class (Enum) | Subclass (Enum) | Base Score Range | Definition/Logic |
| :-- | :-- | :-- | :-- |
| **REGIME_MEDIA** | `STATE_NEWS_AGENCY` | 35-40 | Official mouthpiece. **Rule:** If quoting official → Statement of Record. |
|  | `IRGC_AFFILIATED` | 35-40 | Security/Military wing. **Rule:** -5 bias penalty on protest news. |
|  | `STATE_INTERNATIONAL` | 35-40 | PressTV/HispanTV. Targeted at foreign audiences. |
| **GREY_TABLOID** | `ANONYMOUS_TELEGRAM` | 20-30 | No masthead. **Rule:** Never serves as corroboration. |
|  | `CLICKBAIT_DIASPORA` | 20-30 | Ad-farm news sites. Low reliability. |
| **ACTIVIST_CITIZEN** | `CITIZEN_VERIFIED` | 60-65 | Established (e.g., 1500tasvir). **Rule:** High provenance, needs 1 confirm. |
|  | `CITIZEN_EMERGING` | 50-55 | New/Unknown. **Rule:** Needs 2 confirmations. |
| **MAINSTREAM_DIASPORA** | `INTL_BROADCASTER` | 75-80 | BBC/VOA Persian. Professional but state-funded. |
|  | `INDEPENDENT_PERSIAN` | 72-77 | Small, independent (e.g., IranWire). |
| **NGO_WATCHDOG** | `HUMAN_RIGHTS_INTL` | 90-95 | Amnesty/HRW. **Rule:** "Anchor Source" (can confirm alone). |
|  | `TECH_MONITOR` | 90-95 | NetBlocks. **Rule:** Authority on internet/cyber. |
| **INTL_WIRE** | `GLOBAL_WIRE` | 95-100 | Reuters/AP. **Rule:** The "Final Arbiter". |
| **KEY_FIGURE** | `HEAD_OF_STATE` | 60 (Fixed) | Trump/Pezeshkian. **Rule:** Statement of Record. |
|  | `OPPOSITION_LEADER` | 60 (Fixed) | Pahlavi/Alinejad. **Rule:** Factual claims need corroboration. |

### 2.2 Entity Types

**Field:** `items.metadata.entities[]`
*Used for clustering logic.*

* `PERSON` (Named individuals)
* `ORG` (Groups, parties, military units)
* `STATE_BODY` (Ministries, Parliament)
* `EVENT` (Specific incident: "Zahedan Friday Protest")
* `POLICY` (Abstract: "Nuclear Deal", "Hijab Bill")
* `LOCATION` (Geospatial anchor)

***

## 3. Module A: Source Logic \& Proxy Detection

### 3.1 The "Statement of Record" Logic (VIP Handling)

**Trigger:** `source_class = KEY_FIGURE`
**Logic:**

1. **Intent Detection:** Does the text contain "I will", "We plan", "I condemn"?
    * *Result:* `trust_level = STATEMENT_RECORD`. `final_score` = Authenticity Score (high).
2. **Fact Detection:** Does the text contain numbers ("500 killed"), past tense events ("They attacked"), or causality?
    * *Result:* Treat as `UNVERIFIED_CLAIM`.
    * *Constraint:* `corroboration_min_required = 1`.
    * *Scoring:* Do NOT use the VIP's status to boost the truth score. Only independent confirmation increases the score.

### 3.2 Proxy Detection Algorithm

**Trigger:** Weekly batch job or new source onboarding.
**Formula:** `Proxy_Score = (0.3 × Content_Overlap) + (0.3 × Narrative_Align) + (0.2 × Amplification_Net) + (0.2 × Tech_Overlap)`

**Thresholds \& Actions:**

* **≥ 0.70 (State Proxy):**
    * Action: Reclassify `source_class` → `REGIME_MEDIA` (or apply -10 penalty).
    * Constraint: This source *cannot* corroborate other regime sources.
* **0.40 - 0.69 (Grey Zone):**
    * Action: Label "State Affiliated" warning.
    * Constraint: Force human audit.

***

## 4. Module B: Item Trust Scoring Engine

**Formula:**
`Final_Score = CLAMP(15, 95, [Base_Contrib + Provenance + Corroboration + Transparency + Modifiers])`

### 4.1 Base Contribution

* **Formula:** `ROUND(0.45 × source_profiles.base_score)`
* **Range:** 9 to 45 points.


### 4.2 Provenance Score (Max 20)

* **URL Valid:** +6 (Valid standard domain, no shorteners).
* **Timestamp:** +5 (Parseable `publish_date` consistent with ingestion time).
* **Author:** +4 (Specific byline; 0 if "Staff/Admin").
* **Dateline:** +3 (Explicit location asserted in text).
* **Media:** +2 (Contains original non-stock image/video).


### 4.3 Corroboration Score (Max 20)

* *Query:* Vector search top 50 similar items + Filter by `independent_owner`.
* **0 Matches:** 0 points.
* **1 Match:** +8 points.
* **2 Matches:** +14 points.
* **3 Matches:** +18 points.
* **4+ Matches:** +20 points.
* **Constraint:** If all matches are from the same `ownership_cluster` (e.g., all IRGC outlets), score = 0.


### 4.4 Transparency Score (Max 15)

* **Source Level (0-9):** Ownership page (+3), Corrections policy (+2), Staff list (+2), Contact info (+2).
* **Item Level (0-6):** Named author (+2), Primary source links (+1), Methodology explained (+1).
* **Penalties:** Anonymous author (-3), No timestamp (-2).


### 4.5 Modifiers (The "Red Flags")

* **Anonymous Sourcing:** -8 (e.g., "Informed sources said").
* **Unverified Numbers:** -10 (Casualty counts without method/confirmation).
* **Primary Doc:** +6 (Link to PDF/Official Statement).
* **Correction:** +5 (Item is an explicit correction of a previous error).

***

## 5. Module C: Narrative Clustering Logic

**Goal:** Group items into "Narratives" (Claims/Events), not just "Topics".

### 5.1 The Clustering Algorithm

**Step 1: Candidate Retrieval**

* Input: New Item Vector ($V_{new}$).
* Query: Approximate Nearest Neighbor (ANN) on `items` index.
* Window: Past 14 days.

**Step 2: Similarity Gating (Is it the same story?)**

* Calculate `Cos_Sim` (Cosine Similarity).
* Calculate `Entity_Overlap` (Count of shared PERSON/ORG/EVENT entities).
* **Match Condition:**
    * (`Cos_Sim` > 0.85) OR
    * (`Cos_Sim` > 0.75 AND `Entity_Overlap` ≥ 2)

**Step 3: Stance/Frame Check**

* If **Match Condition** is met:
    * Check `Main_Event_ID`. If identical → **Merge**.
    * Even if Stance is opposite (e.g., "Protest was peaceful" vs "Protest was riot") → **Merge**. (It is the *same narrative event*, just disputed).

**Step 4: New vs. Existing**

* If Match Found → Add `item_id` to `narrative_id`. Update `last_seen`.
* If No Match → Create **New Narrative**.


### 5.2 Narrative Time Windows

* **Breaking News:** Cluster window 72 hours. (Logic: After 3 days, it's history or a new phase).
* **Protests/Crackdowns:** Cluster window 7 days. (Logic: Death tolls update slowly).
* **Policy/Nuclear:** Cluster window 14 days. (Logic: Diplomatic rounds are slow).

***

## 6. Feed Triage \& Metadata Triage (Pre-LLM)

**Location:** Ingestion Worker (Python/n8n)
**Action:** Binary Pass/Fail before API cost is incurred.

1. **Deduplication:**
    * Check `url_hash` in DB. If exists → **FAIL**.
    * Check `content_hash` (SimHash). If >95% match in last 24h → **FAIL** (Reprint).
2. **Spam Filter:**
    * `Title_Length` < 15 chars → **FAIL**.
    * `Body_Length` < 200 chars → **FAIL** (unless Video Post).
    * Blocked Keywords (Casino, Crypto, etc.) → **FAIL**.
3. **Language Gate:**
    * If `lang` not in [FA, EN, AR] → **FAIL**.

***

## 7. Developer Implementation Notes

### 7.1 Configuration Constants (Config.py)

*Do not hardcode these numbers in logic files.*

```python
# Weights
WEIGHT_BASE = 0.45
WEIGHT_PROVENANCE = 1.0
WEIGHT_CORROBORATION = 1.0

# Thresholds
SCORE_MIN = 15
SCORE_MAX = 95
PROXY_THRESHOLD_HIGH = 0.70
PROXY_THRESHOLD_MED = 0.40

# Clustering
SIMILARITY_STRICT = 0.85
SIMILARITY_HYBRID = 0.75
MIN_ENTITY_OVERLAP = 2
```


### 7.2 API Response Schema (Trust Object)

*This is the JSON contract for the Frontend.*

```json
{
  "trust_score": 72,
  "trust_level": "HIGH",
  "badges": ["VERIFIED_SOURCE", "CORROBORATED"],
  "breakdown": {
    "base": 36,
    "provenance": 12,
    "corroboration": 14,
    "transparency": 10,
    "modifiers": 0
  },
  "warnings": [],
  "is_official_statement": false
}
```


***
**End of Specification**
*Approved by: System Architect \& Editorial Lead*
<span style="display:none">[^1][^2][^3][^4]</span>

<div align="center">⁂</div>

[^1]: Meeting Minutes Strategic.docx

[^2]: Iran Propaganda Archive Jan2026

[^3]: Propagand Workflow.docx

[^4]: let's look at this process as a expert which exprt.docx

