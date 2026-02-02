# n8n Workflow Specifications: Detailed Design

**Document:** Workflow Design Specifications  
**Version:** 1.0  
**Date:** February 1, 2026  
**Purpose:** Complete technical specifications for n8n workflow implementation

---

## WF-01: INGESTION PIPELINE

**File:** `workflows/01_ingestion.json`  
**Schedule:** Every 15 minutes  
**Purpose:** Poll Miniflux for unread items, extract text via SMRY, store in PostgreSQL

---

### 1.1 Node Sequence Diagram

```
┌──────────────────┐
│  Schedule Trigger │
│  (*/15 * * * *)  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  HTTP Request    │
│  Miniflux API    │
│  GET /v1/entries │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  IF: Has Items?  │
│  entries.length  │
└────────┬─────────┘
         │ Yes
         ▼
┌──────────────────┐
│  Split In Batches│
│  (batch size: 10)│
└────────┬─────────┘
         │
         ▼
┌──────────────────┐     ┌──────────────────┐
│  Loop Over Items │────▶│  HTTP Request    │
│                  │     │  SMRY /extract   │
└──────────────────┘     └────────┬─────────┘
                                  │
         ┌────────────────────────┘
         ▼
┌──────────────────┐     ┌──────────────────┐
│  Code: Detect    │────▶│  Code: Generate  │
│  Language        │     │  Content Hash    │
└──────────────────┘     └────────┬─────────┘
                                  │
         ┌────────────────────────┘
         ▼
┌──────────────────┐
│  PostgreSQL      │
│  Check Duplicate │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  IF: Is New?     │
│  duplicate=false │
└────────┬─────────┘
         │ Yes
         ▼
┌──────────────────┐     ┌──────────────────┐
│  PostgreSQL      │────▶│  HTTP Request    │
│  INSERT content  │     │  Mark as Read    │
└──────────────────┘     └────────┬─────────┘
                                  │
         ┌────────────────────────┘
         ▼
┌──────────────────┐     ┌──────────────────┐
│  HTTP Request    │────▶│  PostgreSQL      │
│  Trigger WF-02   │     │  Log Ingestion   │
└──────────────────┘     └──────────────────┘
```

---

### 1.2 Node Configurations

#### Node 1: Schedule Trigger
```json
{
  "type": "n8n-nodes-base.scheduleTrigger",
  "name": "Every 15 Minutes",
  "parameters": {
    "rule": {
      "interval": [{"field": "minutes", "minutesInterval": 15}]
    }
  }
}
```

#### Node 2: HTTP Request - Miniflux Get Unread
```json
{
  "type": "n8n-nodes-base.httpRequest",
  "name": "Miniflux Get Unread",
  "parameters": {
    "method": "GET",
    "url": "http://nura-miniflux/v1/entries",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendQuery": true,
    "queryParameters": {
      "parameters": [
        {"name": "status", "value": "unread"},
        {"name": "limit", "value": "100"},
        {"name": "order", "value": "published_at"},
        {"name": "direction", "value": "desc"}
      ]
    },
    "options": {
      "timeout": 30000,
      "response": {"response": {"fullResponse": false}}
    }
  },
  "credentials": {
    "httpHeaderAuth": {"id": "miniflux-auth", "name": "Miniflux API"}
  }
}
```

**Miniflux Credential Configuration:**
```json
{
  "name": "Miniflux API",
  "type": "httpHeaderAuth",
  "data": {
    "name": "X-Auth-Token",
    "value": "={{$credentials.minifluxApiKey}}"
  }
}
```

#### Node 3: IF - Has Items
```json
{
  "type": "n8n-nodes-base.if",
  "name": "Has Items?",
  "parameters": {
    "conditions": {
      "options": {"caseSensitive": true},
      "combinator": "and",
      "conditions": [
        {
          "leftValue": "={{ $json.entries.length }}",
          "rightValue": 0,
          "operator": {"type": "number", "operation": "gt"}
        }
      ]
    }
  }
}
```

#### Node 4: Split In Batches
```json
{
  "type": "n8n-nodes-base.splitInBatches",
  "name": "Batch Items",
  "parameters": {
    "batchSize": 10,
    "options": {}
  }
}
```

#### Node 5: Loop Over Items
```json
{
  "type": "n8n-nodes-base.splitInBatches",
  "name": "Process Each Entry",
  "parameters": {
    "batchSize": 1,
    "options": {"reset": false}
  }
}
```

#### Node 6: HTTP Request - SMRY Extract
```json
{
  "type": "n8n-nodes-base.httpRequest",
  "name": "SMRY Extract Text",
  "parameters": {
    "method": "POST",
    "url": "http://nura-smry/extract",
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "={{ JSON.stringify({ url: $json.url }) }}",
    "options": {
      "timeout": 60000,
      "response": {"response": {"fullResponse": false}}
    }
  },
  "onError": "continueRegularOutput",
  "continueOnFail": true
}
```

#### Node 7: Code - Detect Language
```json
{
  "type": "n8n-nodes-base.code",
  "name": "Detect Language",
  "parameters": {
    "mode": "runOnceForEachItem",
    "jsCode": "// Language detection based on character analysis\nconst text = $json.content || $json.title || '';\n\n// Persian/Farsi detection (Unicode range: 0600-06FF + Persian-specific)\nconst persianRegex = /[\\u0600-\\u06FF\\uFB50-\\uFDFF\\uFE70-\\uFEFF]/g;\nconst persianMatches = (text.match(persianRegex) || []).length;\n\n// Arabic-specific characters (not shared with Persian)\nconst arabicOnlyRegex = /[\\u0621\\u0623\\u0624\\u0625\\u0626]/g;\nconst arabicMatches = (text.match(arabicOnlyRegex) || []).length;\n\n// Hebrew detection\nconst hebrewRegex = /[\\u0590-\\u05FF]/g;\nconst hebrewMatches = (text.match(hebrewRegex) || []).length;\n\nconst totalChars = text.length || 1;\nconst rtlRatio = (persianMatches + arabicMatches + hebrewMatches) / totalChars;\n\nlet language = 'en';\nlet textDirection = 'ltr';\nlet detectedLanguage = 'en-US';\n\nif (rtlRatio > 0.3) {\n  textDirection = 'rtl';\n  if (persianMatches > arabicMatches * 2) {\n    language = 'fa';\n    detectedLanguage = 'fa-IR';\n  } else if (arabicMatches > 0) {\n    language = 'ar';\n    detectedLanguage = 'ar-SA';\n  } else if (hebrewMatches > 0) {\n    language = 'he';\n    detectedLanguage = 'he-IL';\n  }\n}\n\nreturn {\n  ...items[0].json,\n  language,\n  detected_language: detectedLanguage,\n  text_direction: textDirection\n};"
  }
}
```

#### Node 8: Code - Generate Content Hash
```json
{
  "type": "n8n-nodes-base.code",
  "name": "Generate Hash",
  "parameters": {
    "mode": "runOnceForEachItem",
    "jsCode": "const crypto = require('crypto');\n\nconst url = $json.url || '';\nconst content = $json.content || '';\n\n// URL-based hash for deduplication\nconst urlHash = crypto.createHash('sha256').update(url).digest('hex').slice(0, 16);\n\n// Content-based hash for detecting same content at different URLs\nconst contentNormalized = content.toLowerCase().replace(/\\s+/g, ' ').trim().slice(0, 1000);\nconst contentHash = crypto.createHash('sha256').update(contentNormalized).digest('hex').slice(0, 16);\n\nreturn {\n  ...items[0].json,\n  url_hash: urlHash,\n  content_hash: contentHash,\n  external_id: urlHash\n};"
  }
}
```

#### Node 9: PostgreSQL - Check Duplicate
```json
{
  "type": "n8n-nodes-base.postgres",
  "name": "Check Duplicate",
  "parameters": {
    "operation": "executeQuery",
    "query": "SELECT content_id, url, is_duplicate FROM content WHERE external_id = $1 OR url = $2 LIMIT 1",
    "options": {
      "queryReplacement": "={{ [$json.external_id, $json.url] }}"
    }
  },
  "credentials": {
    "postgres": {"id": "nura-postgres", "name": "Nura PostgreSQL"}
  }
}
```

#### Node 10: IF - Is New Content
```json
{
  "type": "n8n-nodes-base.if",
  "name": "Is New?",
  "parameters": {
    "conditions": {
      "combinator": "and",
      "conditions": [
        {
          "leftValue": "={{ $json.length }}",
          "rightValue": 0,
          "operator": {"type": "number", "operation": "equals"}
        }
      ]
    }
  }
}
```

#### Node 11: PostgreSQL - Insert Content
```json
{
  "type": "n8n-nodes-base.postgres",
  "name": "Insert Content",
  "parameters": {
    "operation": "executeQuery",
    "query": "INSERT INTO content (\n  source_id,\n  content_type,\n  external_id,\n  url,\n  title,\n  content_text,\n  language,\n  detected_language,\n  text_direction,\n  author_name,\n  published_at,\n  word_count,\n  ingest_status,\n  analysis_status,\n  ingested_at\n) VALUES (\n  (SELECT source_id FROM sources WHERE identifier LIKE '%' || $1 || '%' LIMIT 1),\n  'article',\n  $2,\n  $3,\n  $4,\n  $5,\n  $6,\n  $7,\n  $8,\n  $9,\n  $10,\n  $11,\n  'completed',\n  'pending',\n  NOW()\n) RETURNING content_id",
    "options": {
      "queryReplacement": "={{ [\n  $('Miniflux Get Unread').item.json.feed.site_url.replace(/^https?:\\/\\//, '').replace(/\\/.*/, ''),\n  $json.external_id,\n  $json.url,\n  $json.title || '',\n  $json.content || '',\n  $json.language,\n  $json.detected_language,\n  $json.text_direction,\n  $('Miniflux Get Unread').item.json.author || null,\n  $('Miniflux Get Unread').item.json.published_at || null,\n  ($json.content || '').split(/\\s+/).length\n] }}"
    }
  },
  "credentials": {
    "postgres": {"id": "nura-postgres", "name": "Nura PostgreSQL"}
  }
}
```

#### Node 12: HTTP Request - Mark as Read
```json
{
  "type": "n8n-nodes-base.httpRequest",
  "name": "Mark as Read",
  "parameters": {
    "method": "PUT",
    "url": "=http://nura-miniflux/v1/entries",
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "={{ JSON.stringify({ entry_ids: [$('Miniflux Get Unread').item.json.id], status: 'read' }) }}",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth"
  },
  "credentials": {
    "httpHeaderAuth": {"id": "miniflux-auth", "name": "Miniflux API"}
  }
}
```

#### Node 13: HTTP Request - Trigger WF-02
```json
{
  "type": "n8n-nodes-base.httpRequest",
  "name": "Trigger Agent 1",
  "parameters": {
    "method": "POST",
    "url": "http://irdecode-prod-n8n/webhook/agent-source",
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "={{ JSON.stringify({ content_id: $json[0].content_id }) }}",
    "options": {"timeout": 5000}
  },
  "continueOnFail": true
}
```

#### Node 14: PostgreSQL - Log Ingestion
```json
{
  "type": "n8n-nodes-base.postgres",
  "name": "Log Ingestion",
  "parameters": {
    "operation": "executeQuery",
    "query": "INSERT INTO ingestion_log (\n  source_id,\n  run_type,\n  started_at,\n  completed_at,\n  duration_ms,\n  items_fetched,\n  items_new,\n  items_duplicate,\n  status,\n  workflow_execution_id\n) VALUES (\n  NULL,\n  'rss_poll',\n  $1,\n  NOW(),\n  $2,\n  $3,\n  $4,\n  $5,\n  'completed',\n  $6\n)",
    "options": {
      "queryReplacement": "={{ [\n  $('Every 15 Minutes').item.json.timestamp || new Date().toISOString(),\n  Date.now() - new Date($('Every 15 Minutes').item.json.timestamp).getTime(),\n  $('Miniflux Get Unread').item.json.entries?.length || 0,\n  $itemIndex + 1,\n  0,\n  $executionId\n] }}"
    }
  },
  "credentials": {
    "postgres": {"id": "nura-postgres", "name": "Nura PostgreSQL"}
  }
}
```

---

### 1.3 SQL Queries

#### Check Duplicate Query
```sql
SELECT content_id, url, is_duplicate 
FROM content 
WHERE external_id = $1 OR url = $2 
LIMIT 1;
```

#### Insert Content Query
```sql
INSERT INTO content (
  source_id,
  content_type,
  external_id,
  url,
  title,
  content_text,
  language,
  detected_language,
  text_direction,
  author_name,
  published_at,
  word_count,
  ingest_status,
  analysis_status,
  ingested_at
) VALUES (
  (SELECT source_id FROM sources WHERE identifier LIKE '%' || $1 || '%' LIMIT 1),
  'article',
  $2,  -- external_id (url_hash)
  $3,  -- url
  $4,  -- title
  $5,  -- content_text
  $6,  -- language (fa/ar/en)
  $7,  -- detected_language (fa-IR)
  $8,  -- text_direction (rtl/ltr)
  $9,  -- author_name
  $10, -- published_at
  $11, -- word_count
  'completed',
  'pending',
  NOW()
) RETURNING content_id;
```

#### Log Ingestion Query
```sql
INSERT INTO ingestion_log (
  source_id,
  run_type,
  started_at,
  completed_at,
  duration_ms,
  items_fetched,
  items_new,
  items_duplicate,
  status,
  workflow_execution_id
) VALUES (
  $1,            -- source_id (NULL for batch)
  'rss_poll',
  $2,            -- started_at
  NOW(),
  $3,            -- duration_ms
  $4,            -- items_fetched
  $5,            -- items_new
  $6,            -- items_duplicate
  'completed',
  $7             -- workflow_execution_id
);
```

---

### 1.4 Error Handling

| Node | Error Strategy | Action |
|------|----------------|--------|
| Miniflux API | Retry 3x with backoff | Log failure, continue |
| SMRY Extract | Continue on fail | Store URL without text |
| PostgreSQL Insert | Stop on error | Alert, manual review |
| Mark as Read | Continue on fail | Will retry next cycle |
| Trigger WF-02 | Continue on fail | WF-02 has own trigger |

---

## WF-02: AGENT 1 - IMTT EVALUATION

**File:** `workflows/02_agent_source.json`  
**Trigger:** Webhook + Schedule (every 30 min for backlog)  
**Purpose:** Evaluate sources using IMTT framework, extract claims

---

### 2.1 Node Sequence Diagram

```
┌──────────────────┐     ┌──────────────────┐
│  Webhook Trigger │     │ Schedule Trigger │
│ /agent-source    │     │ (*/30 * * * *)   │
└────────┬─────────┘     └────────┬─────────┘
         │                        │
         └────────────┬───────────┘
                      ▼
         ┌──────────────────┐
         │  PostgreSQL      │
         │  Get Pending     │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  IF: Has Content │
         └────────┬─────────┘
                  │ Yes
                  ▼
         ┌──────────────────┐
         │  Loop Over Items │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  PostgreSQL      │
         │  Get Source Info │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  IF: Source Needs│
         │  Re-evaluation?  │
         └────────┬─────────┘
                  │ Yes
                  ▼
         ┌──────────────────┐
         │  OpenAI GPT-4o   │
         │  IMTT Evaluation │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  Code: Parse     │
         │  IMTT Response   │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  PostgreSQL      │
         │  Store Source    │
         │  Evaluation      │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  OpenAI GPT-4o   │
         │  Content Analysis│
         │  + Claim Extract │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  Code: Parse     │
         │  Claims          │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  PostgreSQL      │
         │  Store Content   │
         │  Evaluation      │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  PostgreSQL      │
         │  Store Claims    │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  HTTP Request    │
         │  Trigger WF-03   │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  PostgreSQL      │
         │  Log Analysis    │
         └──────────────────┘
```

---

### 2.2 Node Configurations

#### Node 1: Webhook Trigger
```json
{
  "type": "n8n-nodes-base.webhook",
  "name": "Agent Source Trigger",
  "parameters": {
    "path": "agent-source",
    "httpMethod": "POST",
    "responseMode": "responseNode",
    "options": {}
  },
  "webhookId": "agent-source-webhook"
}
```

#### Node 2: Schedule Trigger (Backlog Processing)
```json
{
  "type": "n8n-nodes-base.scheduleTrigger",
  "name": "Every 30 Minutes",
  "parameters": {
    "rule": {
      "interval": [{"field": "minutes", "minutesInterval": 30}]
    }
  }
}
```

#### Node 3: PostgreSQL - Get Pending Content
```json
{
  "type": "n8n-nodes-base.postgres",
  "name": "Get Pending Content",
  "parameters": {
    "operation": "executeQuery",
    "query": "SELECT \n  c.content_id,\n  c.source_id,\n  c.title,\n  c.content_text,\n  c.language,\n  c.text_direction,\n  c.url,\n  c.published_at,\n  s.identifier AS source_domain,\n  s.name AS source_name,\n  s.country,\n  s.credibility_tier AS current_tier,\n  se.evaluated_at AS source_last_evaluated\nFROM content c\nLEFT JOIN sources s ON c.source_id = s.source_id\nLEFT JOIN source_evaluations se ON s.source_id = se.source_id AND se.is_current = true\nWHERE c.analysis_status = 'pending'\nORDER BY c.ingested_at ASC\nLIMIT 20"
  },
  "credentials": {
    "postgres": {"id": "nura-postgres", "name": "Nura PostgreSQL"}
  }
}
```

#### Node 4: OpenAI - IMTT Source Evaluation
```json
{
  "type": "@n8n/n8n-nodes-langchain.openAi",
  "name": "GPT-4o IMTT Evaluation",
  "parameters": {
    "resource": "chat",
    "model": "gpt-4o",
    "messages": {
      "values": [
        {
          "role": "system",
          "content": "You are an expert media analyst specializing in Iranian, Middle Eastern, and Persian-language media. You evaluate news sources using the IMTT (Independence, Methodology, Transparency, Triangulation) framework.\n\nYou MUST respond in valid JSON only. No markdown, no explanations outside JSON."
        },
        {
          "role": "user",
          "content": "Evaluate this news source using the IMTT framework:\n\n**Source:** {{ $json.source_name }} ({{ $json.source_domain }})\n**Country:** {{ $json.country }}\n**Current Tier:** {{ $json.current_tier }}\n\n**Sample Content:**\nTitle: {{ $json.title }}\nContent: {{ $json.content_text.slice(0, 3000) }}\n\nScore each IMTT pillar from 0.0 to 1.0:\n\n1. **INDEPENDENCE** (0.0-1.0): Freedom from political/financial control\n   - 0.0-0.2: State-owned, regime-controlled, or clearly propaganda\n   - 0.2-0.4: State-affiliated but some editorial independence\n   - 0.4-0.6: Partisan but not state-controlled\n   - 0.6-0.8: Mostly independent with occasional bias\n   - 0.8-1.0: Fully independent, transparent ownership\n\n2. **METHODOLOGY** (0.0-1.0): Reporting standards and sourcing\n   - 0.0-0.2: No sourcing, fabricated content\n   - 0.2-0.4: Poor sourcing, anonymous claims\n   - 0.4-0.6: Some sourcing but inconsistent\n   - 0.6-0.8: Good sourcing practices\n   - 0.8-1.0: Excellent methodology, primary sources\n\n3. **TRANSPARENCY** (0.0-1.0): Ownership/funding/corrections disclosure\n   - 0.0-0.2: No disclosure, hidden ownership\n   - 0.2-0.4: Minimal disclosure\n   - 0.4-0.6: Partial transparency\n   - 0.6-0.8: Good transparency\n   - 0.8-1.0: Full transparency, clear corrections policy\n\n4. **TRIANGULATION** (0.0-1.0): Cross-checking, fact-checking, peer review\n   - 0.0-0.2: No fact-checking, known disinformation\n   - 0.2-0.4: Rarely verifies claims\n   - 0.4-0.6: Some verification effort\n   - 0.6-0.8: Regular fact-checking\n   - 0.8-1.0: Rigorous verification, peer-reviewed\n\nRespond with this exact JSON structure:\n```json\n{\n  \"independence\": {\n    \"score\": 0.0,\n    \"reasoning\": \"Brief explanation in English\"\n  },\n  \"methodology\": {\n    \"score\": 0.0,\n    \"reasoning\": \"Brief explanation\"\n  },\n  \"transparency\": {\n    \"score\": 0.0,\n    \"reasoning\": \"Brief explanation\"\n  },\n  \"triangulation\": {\n    \"score\": 0.0,\n    \"reasoning\": \"Brief explanation\"\n  },\n  \"overall_score\": 0.0,\n  \"recommended_tier\": \"propaganda|state_affiliated|partisan|unverified|credible\",\n  \"reasoning\": \"Overall assessment in 2-3 sentences\"\n}\n```"
        }
      ]
    },
    "options": {
      "temperature": 0.3,
      "maxTokens": 1000,
      "responseFormat": "json_object"
    }
  },
  "credentials": {
    "openAiApi": {"id": "azure-openai", "name": "Azure OpenAI"}
  }
}
```

#### Node 5: OpenAI - Content Analysis + Claim Extraction
```json
{
  "type": "@n8n/n8n-nodes-langchain.openAi",
  "name": "GPT-4o Content Analysis",
  "parameters": {
    "resource": "chat",
    "model": "gpt-4o",
    "messages": {
      "values": [
        {
          "role": "system",
          "content": "You are an expert analyst evaluating Iran-related news content. You analyze stance, propaganda risk, plausibility, and extract claims.\n\nYou understand Farsi (Persian) and Arabic fluently. Preserve original language text in your extractions.\n\nRespond in valid JSON only."
        },
        {
          "role": "user",
          "content": "Analyze this content:\n\n**Source:** {{ $json.source_name }} (Credibility: {{ $json.current_tier }})\n**Language:** {{ $json.language }} ({{ $json.text_direction }})\n**Title:** {{ $json.title }}\n**Content:**\n{{ $json.content_text.slice(0, 6000) }}\n\nProvide analysis in this JSON structure:\n```json\n{\n  \"stance\": \"pro_regime|anti_regime|pro_western|anti_western|neutral|mixed\",\n  \"stance_confidence\": 0.0,\n  \"bias_indicators\": [\"list of detected bias indicators\"],\n  \"propaganda_risk\": 0.0,\n  \"propaganda_techniques\": [\"appeal_to_fear\", \"bandwagon\", \"false_dilemma\", \"loaded_language\", \"name_calling\", \"whataboutism\"],\n  \"plausibility\": \"highly_unlikely|unlikely|uncertain|plausible|highly_plausible|confirmed\",\n  \"factuality_score\": 0.0,\n  \"virality_score\": 0.0,\n  \"summary_en\": \"2-3 sentence summary in English\",\n  \"explanation\": \"Why this content received these scores\",\n  \"claims\": [\n    {\n      \"claim_text\": \"Original language claim text (Farsi/Arabic/English)\",\n      \"claim_text_en\": \"English translation of the claim\",\n      \"claim_type\": \"factual|predictive|causal|quantitative|attribution|narrative|opinion\",\n      \"confidence\": 0.0,\n      \"subject_text\": \"Main subject/entity of claim\"\n    }\n  ]\n}\n```\n\nExtract ALL significant claims (minimum 2, maximum 10). Preserve Farsi/Arabic text exactly."
        }
      ]
    },
    "options": {
      "temperature": 0.2,
      "maxTokens": 2000,
      "responseFormat": "json_object"
    }
  },
  "credentials": {
    "openAiApi": {"id": "azure-openai", "name": "Azure OpenAI"}
  }
}
```

#### Node 6: Code - Parse and Validate Response
```json
{
  "type": "n8n-nodes-base.code",
  "name": "Parse Analysis",
  "parameters": {
    "mode": "runOnceForEachItem",
    "jsCode": "const content = $('Get Pending Content').item.json;\nconst imttRaw = $('GPT-4o IMTT Evaluation').item.json;\nconst analysisRaw = $('GPT-4o Content Analysis').item.json;\n\n// Parse IMTT response\nlet imtt;\ntry {\n  imtt = typeof imttRaw.message?.content === 'string' \n    ? JSON.parse(imttRaw.message.content) \n    : imttRaw;\n} catch (e) {\n  imtt = { overall_score: 0.5, recommended_tier: 'unverified' };\n}\n\n// Parse analysis response\nlet analysis;\ntry {\n  analysis = typeof analysisRaw.message?.content === 'string'\n    ? JSON.parse(analysisRaw.message.content)\n    : analysisRaw;\n} catch (e) {\n  analysis = { stance: 'unknown', propaganda_risk: 0.5, claims: [] };\n}\n\n// Calculate credibility tier from IMTT scores\nconst overallScore = imtt.overall_score || \n  ((imtt.independence?.score || 0) + \n   (imtt.methodology?.score || 0) + \n   (imtt.transparency?.score || 0) + \n   (imtt.triangulation?.score || 0)) / 4;\n\nlet credibilityTier;\nif (overallScore < 0.2) credibilityTier = 'propaganda';\nelse if (overallScore < 0.35) credibilityTier = 'state_affiliated';\nelse if (overallScore < 0.5) credibilityTier = 'partisan';\nelse if (overallScore < 0.7) credibilityTier = 'unverified';\nelse credibilityTier = 'credible';\n\nreturn {\n  content_id: content.content_id,\n  source_id: content.source_id,\n  \n  // IMTT scores\n  imtt: {\n    independence: imtt.independence?.score || 0,\n    methodology: imtt.methodology?.score || 0,\n    transparency: imtt.transparency?.score || 0,\n    triangulation: imtt.triangulation?.score || 0,\n    overall_score: overallScore,\n    recommended_tier: credibilityTier,\n    reasoning: imtt.reasoning || ''\n  },\n  \n  // Content evaluation\n  evaluation: {\n    stance: analysis.stance || 'unknown',\n    stance_confidence: analysis.stance_confidence || 0.5,\n    bias_indicators: analysis.bias_indicators || [],\n    propaganda_risk: analysis.propaganda_risk || 0,\n    propaganda_techniques: analysis.propaganda_techniques || [],\n    plausibility: analysis.plausibility || 'uncertain',\n    factuality_score: analysis.factuality_score || 0.5,\n    virality_score: analysis.virality_score || 0,\n    summary_en: analysis.summary_en || '',\n    explanation: analysis.explanation || ''\n  },\n  \n  // Claims\n  claims: (analysis.claims || []).map(c => ({\n    claim_text: c.claim_text,\n    claim_text_en: c.claim_text_en,\n    claim_type: c.claim_type || 'factual',\n    confidence: c.confidence || 0.5,\n    subject_text: c.subject_text || ''\n  }))\n};"
  }
}
```

#### Node 7: PostgreSQL - Store Source Evaluation
```json
{
  "type": "n8n-nodes-base.postgres",
  "name": "Store Source Evaluation",
  "parameters": {
    "operation": "executeQuery",
    "query": "-- Mark previous evaluations as not current\nUPDATE source_evaluations SET is_current = false WHERE source_id = $1 AND is_current = true;\n\n-- Insert new evaluation\nINSERT INTO source_evaluations (\n  source_id,\n  independence,\n  methodology,\n  transparency,\n  triangulation,\n  overall_score,\n  recommended_tier,\n  reasoning,\n  sample_content_ids,\n  model_used,\n  evaluated_by,\n  is_current\n) VALUES (\n  $1, $2, $3, $4, $5, $6, $7, $8, ARRAY[$9]::uuid[], 'gpt-4o', 'agent1', true\n);",
    "options": {
      "queryReplacement": "={{ [\n  $json.source_id,\n  $json.imtt.independence,\n  $json.imtt.methodology,\n  $json.imtt.transparency,\n  $json.imtt.triangulation,\n  $json.imtt.overall_score,\n  $json.imtt.recommended_tier,\n  $json.imtt.reasoning,\n  $json.content_id\n] }}"
    }
  },
  "credentials": {
    "postgres": {"id": "nura-postgres", "name": "Nura PostgreSQL"}
  }
}
```

#### Node 8: PostgreSQL - Store Content Evaluation
```json
{
  "type": "n8n-nodes-base.postgres",
  "name": "Store Content Evaluation",
  "parameters": {
    "operation": "executeQuery",
    "query": "-- Mark previous as not current\nUPDATE content_evaluations SET is_current = false WHERE content_id = $1 AND is_current = true;\n\n-- Insert new evaluation\nINSERT INTO content_evaluations (\n  content_id,\n  stance,\n  stance_confidence,\n  bias_indicators,\n  propaganda_risk,\n  propaganda_techniques,\n  plausibility,\n  factuality_score,\n  virality_score,\n  summary_en,\n  explanation,\n  model_used,\n  evaluated_by,\n  is_current\n) VALUES (\n  $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'gpt-4o', 'agent1', true\n);\n\n-- Update content status\nUPDATE content SET analysis_status = 'completed', analyzed_at = NOW() WHERE content_id = $1;",
    "options": {
      "queryReplacement": "={{ [\n  $json.content_id,\n  $json.evaluation.stance,\n  $json.evaluation.stance_confidence,\n  $json.evaluation.bias_indicators,\n  $json.evaluation.propaganda_risk,\n  $json.evaluation.propaganda_techniques,\n  $json.evaluation.plausibility,\n  $json.evaluation.factuality_score,\n  $json.evaluation.virality_score,\n  $json.evaluation.summary_en,\n  $json.evaluation.explanation\n] }}"
    }
  },
  "credentials": {
    "postgres": {"id": "nura-postgres", "name": "Nura PostgreSQL"}
  }
}
```

#### Node 9: PostgreSQL - Store Claims
```json
{
  "type": "n8n-nodes-base.postgres",
  "name": "Store Claims",
  "parameters": {
    "operation": "executeQuery",
    "query": "INSERT INTO claims (\n  content_id,\n  claim_text,\n  claim_text_en,\n  language,\n  claim_type,\n  confidence,\n  subject_text,\n  extraction_model\n) \nSELECT \n  $1::uuid,\n  claim->>'claim_text',\n  claim->>'claim_text_en',\n  COALESCE((SELECT language FROM content WHERE content_id = $1), 'en'),\n  COALESCE(claim->>'claim_type', 'factual')::claim_type,\n  COALESCE((claim->>'confidence')::float, 0.5),\n  claim->>'subject_text',\n  'gpt-4o'\nFROM jsonb_array_elements($2::jsonb) AS claim\nRETURNING claim_id;",
    "options": {
      "queryReplacement": "={{ [$json.content_id, JSON.stringify($json.claims)] }}"
    }
  },
  "credentials": {
    "postgres": {"id": "nura-postgres", "name": "Nura PostgreSQL"}
  }
}
```

---

### 2.3 IMTT Evaluation Prompt (Full Version)

```markdown
You are an expert media analyst specializing in Iranian, Middle Eastern, and Persian-language media. You evaluate news sources using the IMTT (Independence, Methodology, Transparency, Triangulation) framework.

## Source Information
**Source:** {{ source_name }} ({{ source_domain }})
**Country:** {{ country }}
**Current Credibility Tier:** {{ current_tier }}

## Sample Content
**Title:** {{ title }}
**Language:** {{ language }}
**Content:**
{{ content_text }}

---

## IMTT Framework Evaluation

Score each pillar from 0.0 to 1.0:

### 1. INDEPENDENCE (0.0-1.0)
Evaluate freedom from political, financial, or state control:
- **0.0-0.2**: State-owned, regime-controlled, or known propaganda outlet
- **0.2-0.4**: State-affiliated with limited editorial independence
- **0.4-0.6**: Partisan outlet with clear political bias
- **0.6-0.8**: Mostly independent, occasional bias
- **0.8-1.0**: Fully independent with transparent ownership

Key questions:
- Who owns this outlet?
- Is it government-funded or state-controlled?
- Does it have ties to political parties or factions?

### 2. METHODOLOGY (0.0-1.0)
Evaluate reporting standards and sourcing practices:
- **0.0-0.2**: No sourcing, fabricated content, anonymous claims
- **0.2-0.4**: Poor sourcing, relies on unverified claims
- **0.4-0.6**: Inconsistent sourcing, some primary sources
- **0.6-0.8**: Good sourcing practices, attributes claims
- **0.8-1.0**: Excellent methodology, primary sources, named experts

Key questions:
- Are claims attributed to named sources?
- Does it cite primary documents or evidence?
- Are quotes verified and in context?

### 3. TRANSPARENCY (0.0-1.0)
Evaluate disclosure of ownership, funding, and corrections:
- **0.0-0.2**: No disclosure, hidden ownership, no corrections policy
- **0.2-0.4**: Minimal disclosure, vague about funding
- **0.4-0.6**: Partial transparency, some disclosure
- **0.6-0.8**: Good transparency, clear ownership, corrections made
- **0.8-1.0**: Full transparency, detailed funding disclosure, public corrections

Key questions:
- Is ownership/funding publicly disclosed?
- Does it have a corrections policy?
- Are authors identified with credentials?

### 4. TRIANGULATION (0.0-1.0)
Evaluate cross-checking and fact verification:
- **0.0-0.2**: No fact-checking, known for disinformation
- **0.2-0.4**: Rarely verifies claims, single-source stories
- **0.4-0.6**: Some verification effort
- **0.6-0.8**: Regular fact-checking, multiple sources
- **0.8-1.0**: Rigorous verification, external fact-checks confirm accuracy

Key questions:
- Does it verify claims before publishing?
- Are claims corroborated by other sources?
- Has it been fact-checked by independent organizations?

---

## Response Format

Return ONLY valid JSON with this structure:
```json
{
  "independence": {
    "score": 0.0,
    "reasoning": "Brief explanation"
  },
  "methodology": {
    "score": 0.0,
    "reasoning": "Brief explanation"
  },
  "transparency": {
    "score": 0.0,
    "reasoning": "Brief explanation"
  },
  "triangulation": {
    "score": 0.0,
    "reasoning": "Brief explanation"
  },
  "overall_score": 0.0,
  "recommended_tier": "propaganda|state_affiliated|partisan|unverified|credible",
  "reasoning": "Overall assessment in 2-3 sentences"
}
```
```

---

### 2.4 Content Analysis + Claim Extraction Prompt

```markdown
You are an expert analyst evaluating Iran-related news content for stance, propaganda, and factual claims.

You are fluent in Farsi (Persian), Arabic, and English. You MUST preserve original language text exactly when extracting claims.

## Content Information
**Source:** {{ source_name }}
**Source Credibility:** {{ credibility_tier }}
**Language:** {{ language }} (Text Direction: {{ text_direction }})
**Published:** {{ published_at }}

**Title:** {{ title }}

**Content:**
{{ content_text }}

---

## Analysis Tasks

### 1. Stance Analysis
Classify the overall stance of this content:
- `pro_regime`: Supports Iranian government/IRGC positions
- `anti_regime`: Opposes Iranian government, supports opposition
- `pro_western`: Favorable toward US/EU/Israel positions
- `anti_western`: Critical of US/EU/Israel
- `neutral`: Balanced, no clear stance
- `mixed`: Contains multiple perspectives

### 2. Propaganda Detection
Identify propaganda techniques used:
- `appeal_to_fear`: Exaggerating threats
- `bandwagon`: "Everyone agrees..."
- `false_dilemma`: Only two options presented
- `loaded_language`: Emotionally charged words
- `name_calling`: Personal attacks, labels
- `whataboutism`: Deflecting criticism

Calculate propaganda_risk (0.0-1.0):
- 0.0-0.3: Minimal propaganda elements
- 0.3-0.6: Some propaganda techniques present
- 0.6-0.8: Heavy propaganda
- 0.8-1.0: Pure propaganda

### 3. Plausibility Assessment
Evaluate how plausible the claims are:
- `highly_unlikely`: Contradicts established facts
- `unlikely`: Lacks evidence, unverified
- `uncertain`: Cannot determine truth
- `plausible`: Consistent with known facts
- `highly_plausible`: Well-supported
- `confirmed`: Independently verified

### 4. Claim Extraction
Extract ALL significant factual claims from the content.

For EACH claim:
- Preserve exact original language text (Farsi/Arabic)
- Provide English translation
- Classify claim type:
  - `factual`: Verifiable fact claim
  - `predictive`: Future prediction
  - `causal`: Cause-effect claim
  - `quantitative`: Numbers/statistics
  - `attribution`: Quotes/statements attributed to someone
  - `narrative`: Story framing, not directly verifiable
  - `opinion`: Subjective view

---

## Response Format

Return ONLY valid JSON:
```json
{
  "stance": "pro_regime|anti_regime|pro_western|anti_western|neutral|mixed",
  "stance_confidence": 0.85,
  "bias_indicators": ["loaded_language", "appeal_to_authority"],
  "propaganda_risk": 0.65,
  "propaganda_techniques": ["loaded_language", "whataboutism"],
  "plausibility": "uncertain",
  "factuality_score": 0.4,
  "virality_score": 0.3,
  "summary_en": "2-3 sentence summary in English",
  "explanation": "Why this content received these scores",
  "claims": [
    {
      "claim_text": "ایران موشک‌های بالستیک جدیدی آزمایش کرد",
      "claim_text_en": "Iran tested new ballistic missiles",
      "claim_type": "factual",
      "confidence": 0.6,
      "subject_text": "Iran"
    },
    {
      "claim_text": "این موشک‌ها قادر به حمل کلاهک هسته‌ای هستند",
      "claim_text_en": "These missiles are capable of carrying nuclear warheads",
      "claim_type": "factual",
      "confidence": 0.3,
      "subject_text": "Iranian missiles"
    }
  ]
}
```

Extract minimum 2 claims, maximum 10. Include the most significant claims that could be fact-checked.

---

## WF-03: AGENT 2 - NARRATIVE CLUSTERING

**File:** `workflows/03_agent_narrative.json`  
**Trigger:** Schedule every 6 hours + Webhook from WF-02  
**Purpose:** Generate embeddings, cluster claims into narratives

---

### 3.1 Node Sequence Diagram

```
┌──────────────────┐     ┌──────────────────┐
│ Schedule Trigger │     │ Webhook Trigger  │
│ (0 */6 * * *)    │     │ /cluster-claims  │
└────────┬─────────┘     └────────┬─────────┘
         │                        │
         └────────────┬───────────┘
                      ▼
         ┌──────────────────┐
         │  PostgreSQL      │
         │  Get Unclustered │
         │  Claims          │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  IF: Has Claims? │
         └────────┬─────────┘
                  │ Yes
                  ▼
         ┌──────────────────┐
         │  Loop Over Claims│
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  OpenAI          │
         │  Embeddings      │
         │  (3072-dim)      │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  HTTP Request    │
         │  Azure AI Search │
         │  Upsert Document │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  HTTP Request    │
         │  Azure AI Search │
         │  Vector Search   │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  Code: Group     │
         │  Similar Claims  │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  OpenAI GPT-4o   │
         │  Generate Label  │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  PostgreSQL      │
         │  UPSERT Narrative│
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  PostgreSQL      │
         │  Link Claims     │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  PostgreSQL      │
         │  Refresh Views   │
         └──────────────────┘
```

---

### 3.2 Node Configurations

#### Node 1: PostgreSQL - Get Unclustered Claims
```json
{
  "type": "n8n-nodes-base.postgres",
  "name": "Get Unclustered Claims",
  "parameters": {
    "operation": "executeQuery",
    "query": "SELECT \n  cl.claim_id,\n  cl.content_id,\n  cl.claim_text,\n  cl.claim_text_en,\n  cl.language,\n  cl.claim_type,\n  cl.confidence,\n  cl.subject_text,\n  c.source_id,\n  s.credibility_tier,\n  c.published_at\nFROM claims cl\nJOIN content c ON cl.content_id = c.content_id\nLEFT JOIN sources s ON c.source_id = s.source_id\nLEFT JOIN claim_narratives cn ON cl.claim_id = cn.claim_id\nWHERE cn.claim_id IS NULL\n  AND cl.claim_text_en IS NOT NULL\n  AND LENGTH(cl.claim_text_en) > 20\nORDER BY cl.created_at DESC\nLIMIT 100"
  },
  "credentials": {
    "postgres": {"id": "nura-postgres", "name": "Nura PostgreSQL"}
  }
}
```

#### Node 2: OpenAI - Generate Embeddings
```json
{
  "type": "@n8n/n8n-nodes-langchain.embeddingsOpenAi",
  "name": "Generate Embedding",
  "parameters": {
    "model": "text-embedding-3-large",
    "options": {
      "dimensions": 3072
    }
  },
  "credentials": {
    "openAiApi": {"id": "azure-openai", "name": "Azure OpenAI"}
  }
}
```

#### Node 3: HTTP Request - Azure AI Search Upsert
```json
{
  "type": "n8n-nodes-base.httpRequest",
  "name": "Upsert to AI Search",
  "parameters": {
    "method": "POST",
    "url": "https://nura-search.search.windows.net/indexes/nura-claims/docs/index?api-version=2024-07-01",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "={{ JSON.stringify({\n  value: [{\n    '@search.action': 'mergeOrUpload',\n    id: $json.claim_id,\n    claim_id: $json.claim_id,\n    content_id: $json.content_id,\n    claim_text: $json.claim_text,\n    claim_text_en: $json.claim_text_en,\n    claim_type: $json.claim_type,\n    language: $json.language,\n    source_credibility: $json.credibility_tier || 'unverified',\n    extracted_at: new Date().toISOString(),\n    embedding: $('Generate Embedding').item.json.embedding\n  }]\n}) }}"
  },
  "credentials": {
    "httpHeaderAuth": {"id": "ai-search-auth", "name": "Azure AI Search"}
  }
}
```

#### Node 4: HTTP Request - Vector Search
```json
{
  "type": "n8n-nodes-base.httpRequest",
  "name": "Find Similar Claims",
  "parameters": {
    "method": "POST",
    "url": "https://nura-search.search.windows.net/indexes/nura-claims/docs/search?api-version=2024-07-01",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "={{ JSON.stringify({\n  count: true,\n  select: 'claim_id,claim_text_en,claim_type,source_credibility',\n  top: 20,\n  vectorQueries: [{\n    kind: 'vector',\n    vector: $('Generate Embedding').item.json.embedding,\n    fields: 'embedding',\n    k: 20\n  }],\n  filter: `claim_id ne '${$json.claim_id}'`\n}) }}"
  },
  "credentials": {
    "httpHeaderAuth": {"id": "ai-search-auth", "name": "Azure AI Search"}
  }
}
```

#### Node 5: Code - Group Similar Claims
```json
{
  "type": "n8n-nodes-base.code",
  "name": "Group Similar",
  "parameters": {
    "mode": "runOnceForEachItem",
    "jsCode": "const currentClaim = $('Get Unclustered Claims').item.json;\nconst searchResults = $json.value || [];\n\n// Filter by similarity threshold (score > 0.85)\nconst similarClaims = searchResults\n  .filter(r => r['@search.score'] > 0.85)\n  .map(r => ({\n    claim_id: r.claim_id,\n    claim_text_en: r.claim_text_en,\n    score: r['@search.score']\n  }));\n\n// Include current claim\nconst cluster = [\n  {\n    claim_id: currentClaim.claim_id,\n    claim_text_en: currentClaim.claim_text_en,\n    score: 1.0\n  },\n  ...similarClaims\n];\n\nreturn {\n  current_claim: currentClaim,\n  cluster: cluster,\n  cluster_size: cluster.length,\n  needs_narrative: cluster.length >= 2\n};"
  }
}
```

#### Node 6: OpenAI GPT-4o - Generate Narrative Label
```json
{
  "type": "@n8n/n8n-nodes-langchain.openAi",
  "name": "Generate Narrative Label",
  "parameters": {
    "resource": "chat",
    "model": "gpt-4o",
    "messages": {
      "values": [
        {
          "role": "system",
          "content": "You generate concise narrative labels for clusters of related claims about Iran. Labels should be:\n- Specific and descriptive (not vague)\n- 5-15 words in English\n- Written as a statement/headline\n- Neutral in tone\n\nRespond in JSON only."
        },
        {
          "role": "user",
          "content": "Generate a narrative label for this cluster of {{ $json.cluster_size }} related claims:\n\n{{ $json.cluster.map(c => '- ' + c.claim_text_en).join('\\n') }}\n\nRespond with:\n```json\n{\n  \"label\": \"English narrative label\",\n  \"label_fa\": \"Persian/Farsi translation\",\n  \"label_ar\": \"Arabic translation\",\n  \"description\": \"1-2 sentence description\",\n  \"dominant_stance\": \"pro_regime|anti_regime|pro_western|anti_western|neutral|mixed\"\n}\n```"
        }
      ]
    },
    "options": {
      "temperature": 0.3,
      "maxTokens": 500,
      "responseFormat": "json_object"
    }
  },
  "credentials": {
    "openAiApi": {"id": "azure-openai", "name": "Azure OpenAI"}
  }
}
```

#### Node 7: PostgreSQL - UPSERT Narrative
```json
{
  "type": "n8n-nodes-base.postgres",
  "name": "Upsert Narrative",
  "parameters": {
    "operation": "executeQuery",
    "query": "INSERT INTO narratives (\n  label,\n  label_fa,\n  label_ar,\n  description,\n  dominant_stance,\n  content_count,\n  claim_count,\n  first_seen_at,\n  last_activity_at,\n  is_active\n) VALUES (\n  $1, $2, $3, $4, $5, 1, $6, NOW(), NOW(), true\n)\nON CONFLICT (label) DO UPDATE SET\n  claim_count = narratives.claim_count + EXCLUDED.claim_count,\n  last_activity_at = NOW()\nRETURNING narrative_id",
    "options": {
      "queryReplacement": "={{ [\n  $json.label,\n  $json.label_fa,\n  $json.label_ar,\n  $json.description,\n  $json.dominant_stance,\n  $('Group Similar').item.json.cluster_size\n] }}"
    }
  },
  "credentials": {
    "postgres": {"id": "nura-postgres", "name": "Nura PostgreSQL"}
  }
}
```

#### Node 8: PostgreSQL - Link Claims to Narrative
```json
{
  "type": "n8n-nodes-base.postgres",
  "name": "Link Claims",
  "parameters": {
    "operation": "executeQuery",
    "query": "INSERT INTO claim_narratives (claim_id, narrative_id, similarity_score, is_core_claim)\nSELECT \n  (claim->>'claim_id')::uuid,\n  $1::uuid,\n  (claim->>'score')::float,\n  (claim->>'score')::float > 0.95\nFROM jsonb_array_elements($2::jsonb) AS claim\nON CONFLICT (claim_id, narrative_id) DO UPDATE SET\n  similarity_score = EXCLUDED.similarity_score",
    "options": {
      "queryReplacement": "={{ [\n  $('Upsert Narrative').item.json[0].narrative_id,\n  JSON.stringify($('Group Similar').item.json.cluster)\n] }}"
    }
  },
  "credentials": {
    "postgres": {"id": "nura-postgres", "name": "Nura PostgreSQL"}
  }
}
```

---

## WF-04: ESCALATION (Deferred to Phase 2)

**File:** `workflows/04_escalation.json`  
**Status:** ❌ Not implemented in 48-hour sprint

```
Placeholder for:
- Webhook trigger from WF-02/WF-03
- o4-mini deep reasoning
- Extended context analysis
- Human review queue
```

---

## WF-05: PUBLIC API ENDPOINTS

**File:** `workflows/05_public_api.json`  
**Trigger:** Webhooks for each endpoint  
**Purpose:** Serve widget and API requests

---

### 5.1 Endpoint: GET /webhook/credibility

```
┌──────────────────┐
│  Webhook Trigger │
│  GET /credibility│
│  ?domain=xxx     │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Code: Extract   │
│  Domain Param    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Redis: Check    │
│  Cache           │
└────────┬─────────┘
         │
    ┌────┴────┐
    │ Cache   │
    │ Hit?    │
    └────┬────┘
     Yes │    │ No
         ▼    ▼
┌────────────┐ ┌──────────────────┐
│ Return     │ │  PostgreSQL      │
│ Cached     │ │  Get Source +    │
└────────────┘ │  Evaluation      │
               └────────┬─────────┘
                        │
                        ▼
               ┌──────────────────┐
               │  Code: Format    │
               │  Response        │
               └────────┬─────────┘
                        │
                        ▼
               ┌──────────────────┐
               │  Redis: Set      │
               │  Cache (1 hour)  │
               └────────┬─────────┘
                        │
                        ▼
               ┌──────────────────┐
               │  Respond to      │
               │  Webhook         │
               └──────────────────┘
```

#### Node Configurations

```json
// Webhook Trigger
{
  "type": "n8n-nodes-base.webhook",
  "name": "GET Credibility",
  "parameters": {
    "path": "credibility",
    "httpMethod": "GET",
    "responseMode": "responseNode"
  }
}

// Redis Check Cache
{
  "type": "n8n-nodes-base.redis",
  "name": "Check Cache",
  "parameters": {
    "operation": "get",
    "key": "=credibility:{{ $json.query.domain }}"
  },
  "credentials": {
    "redis": {"id": "nura-redis", "name": "Nura Redis"}
  }
}

// PostgreSQL Query
{
  "type": "n8n-nodes-base.postgres",
  "name": "Get Source",
  "parameters": {
    "operation": "executeQuery",
    "query": "SELECT \n  s.source_id,\n  s.identifier AS domain,\n  s.name,\n  s.name_original,\n  s.country,\n  s.primary_language AS language,\n  s.credibility_tier AS tier,\n  se.independence,\n  se.methodology,\n  se.transparency,\n  se.triangulation,\n  se.overall_score,\n  se.reasoning,\n  se.created_at AS last_evaluated\nFROM sources s\nLEFT JOIN source_evaluations se ON s.source_id = se.source_id AND se.is_current = true\nWHERE s.identifier LIKE '%' || $1 || '%'\n   OR s.config->>'feed_url' LIKE '%' || $1 || '%'\nLIMIT 1",
    "options": {
      "queryReplacement": "={{ [$json.query.domain] }}"
    }
  }
}

// Format Response
{
  "type": "n8n-nodes-base.code",
  "name": "Format Response",
  "parameters": {
    "jsCode": "const source = $('Get Source').item.json;\n\nif (!source || !source.source_id) {\n  return {\n    statusCode: 404,\n    body: {\n      error: 'Source not found',\n      domain: $('GET Credibility').item.json.query.domain\n    }\n  };\n}\n\nreturn {\n  statusCode: 200,\n  body: {\n    domain: source.domain,\n    name: source.name,\n    name_original: source.name_original,\n    country: source.country,\n    language: source.language,\n    tier: source.tier || 'unverified',\n    imtt: {\n      independence: source.independence || null,\n      methodology: source.methodology || null,\n      transparency: source.transparency || null,\n      triangulation: source.triangulation || null,\n      overall: source.overall_score || null\n    },\n    reasoning: source.reasoning,\n    last_evaluated: source.last_evaluated\n  }\n};"
  }
}

// Redis Set Cache
{
  "type": "n8n-nodes-base.redis",
  "name": "Set Cache",
  "parameters": {
    "operation": "set",
    "key": "=credibility:{{ $('GET Credibility').item.json.query.domain }}",
    "value": "={{ JSON.stringify($json.body) }}",
    "expire": true,
    "ttl": 3600
  }
}

// Respond
{
  "type": "n8n-nodes-base.respondToWebhook",
  "name": "Respond",
  "parameters": {
    "respondWith": "json",
    "responseBody": "={{ $json.body }}",
    "options": {
      "responseCode": "={{ $json.statusCode }}",
      "responseHeaders": {
        "entries": [
          {"name": "Access-Control-Allow-Origin", "value": "*"},
          {"name": "Cache-Control", "value": "public, max-age=3600"}
        ]
      }
    }
  }
}
```

---

### 5.2 Endpoint: GET /webhook/narratives

```json
// PostgreSQL Query
{
  "query": "SELECT \n  n.narrative_id,\n  n.label,\n  n.label_fa,\n  n.label_ar,\n  n.description,\n  n.content_count,\n  n.claim_count,\n  n.dominant_stance,\n  n.avg_propaganda_risk,\n  n.consensus_plausibility,\n  n.first_seen_at,\n  n.last_activity_at,\n  n.is_featured\nFROM narratives n\nWHERE n.is_active = true\n  AND n.is_hidden = false\n  AND n.last_activity_at > NOW() - INTERVAL '7 days'\nORDER BY \n  n.is_featured DESC,\n  n.last_activity_at DESC,\n  n.claim_count DESC\nLIMIT $1 OFFSET $2",
  "queryReplacement": "={{ [$json.query.limit || 20, $json.query.offset || 0] }}"
}
```

---

### 5.3 Endpoint: GET /webhook/narratives/:id

```json
// PostgreSQL Query - Narrative Detail
{
  "query": "SELECT \n  n.*,\n  json_agg(DISTINCT jsonb_build_object(\n    'claim_id', cl.claim_id,\n    'claim_text', cl.claim_text,\n    'claim_text_en', cl.claim_text_en,\n    'claim_type', cl.claim_type,\n    'source_tier', s.credibility_tier\n  )) AS claims,\n  json_agg(DISTINCT jsonb_build_object(\n    'event_date', nt.event_date,\n    'key_event', nt.key_event,\n    'description', nt.description\n  )) AS timeline\nFROM narratives n\nLEFT JOIN claim_narratives cn ON n.narrative_id = cn.narrative_id\nLEFT JOIN claims cl ON cn.claim_id = cl.claim_id\nLEFT JOIN content c ON cl.content_id = c.content_id\nLEFT JOIN sources s ON c.source_id = s.source_id\nLEFT JOIN narrative_timeline nt ON n.narrative_id = nt.narrative_id\nWHERE n.narrative_id = $1\nGROUP BY n.narrative_id",
  "queryReplacement": "={{ [$json.params.id] }}"
}
```

---

### 5.4 CORS Configuration

All webhook responses include:
```json
{
  "responseHeaders": {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Cache-Control": "public, max-age=300"
  }
}
```

---

## Error Handling Strategy

### Global Error Handling

| Error Type | Strategy | Action |
|------------|----------|--------|
| API Timeout | Retry 3x with exponential backoff | Log, continue |
| Database Error | Stop workflow | Alert, manual review |
| LLM Error | Retry 2x | Log, mark as failed |
| Parsing Error | Continue with defaults | Log warning |
| Rate Limit | Wait and retry | Implement backoff |

### Error Logging Query

```sql
INSERT INTO analysis_log (
  agent_name,
  run_type,
  started_at,
  completed_at,
  status,
  error_message,
  workflow_execution_id
) VALUES (
  $1,      -- agent_name
  $2,      -- run_type
  $3,      -- started_at
  NOW(),
  'failed',
  $4,      -- error_message
  $5       -- workflow_execution_id
);
```

---

## Credential Configuration Summary

| Credential Name | Type | Configuration |
|-----------------|------|---------------|
| `Nura PostgreSQL` | PostgreSQL | Host: `irdecode-prod-psql.postgres.database.azure.com`, SSL: require |
| `Azure OpenAI` | OpenAI | Base URL: `https://irdecode-prod-openai.openai.azure.com`, API Key from Key Vault |
| `Azure AI Search` | HTTP Header Auth | Header: `api-key`, Value from Key Vault |
| `Miniflux API` | HTTP Header Auth | Header: `X-Auth-Token`, Value from Key Vault |
| `Nura Redis` | Redis | Host: `nura-redis`, Port: 6379 |

---

*End of Workflow Specifications*

**Next:** Generate actual n8n JSON files in Stage 2
