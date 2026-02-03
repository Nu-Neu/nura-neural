# Team Roles & Responsibilities Structure

**Effective Date:** Feb 2026
**Framework:** Belbin Team Roles + Technical Expertise Mapping

## 1. Core Team Structure

| Name | Role | Belbin Role | Key Responsibilities |
|:---|:---|:---|:---|
| **Amir** | **Software Architect** | *Monitor Evaluator* | System design, Security, Cloud architecture, Technical decision veto. |
| **Saman** | **Automation Lead** | *Implementer* | n8n workflow logic, API integrations, error handling logic. |
| **Reyhaneh** | **Data Specialist** | *Specialist* | PostgreSQL schema, Vector indexing, Database optimization. |
| **Navid** | **AI Engineer** | *Plant* | LLM Prompts, RAG pipeline tuning, Embedding strategies (Python). |
| **Sina** | **DevOps & Security** | *Completer Finisher* | CI/CD, Infrastructure deployment, PIM/IAM Security enforcement. |
| **Dr. Kaveh**| **Media Domain Expert**| *Monitor Evaluator* | Source classification, Political context, Ground truth verification. |
| **Mani** | **UX Lead** | *Teamworker* | User Personas ("Sarah"), Visual Design, Usability. |
| **Farzad** | **Frontend Dev** | *Shaper* | Framer Implementation, Speed-to-Market. |

## 2. Governance & Workflow

### Decision Making (ADR Process)
*   **Proposer**: Any team member can draft an ADR in `docs/03_DECISIONS`.
*   **Reviewers**: Must include Amir (Tech) and relevant Specialist (e.g., Reyhaneh for DB).
*   **Veto Power**: Architect (Amir) retains veto on architectural regressions.

### Access Control (PIM)
*   **Infrastructure Changes**: Require **Contributor** role (activated via PIM for 8h).
*   **Secret Management**: Requires **Key Vault Administrator** role.
*   **Custodian**: Sina monitors access logs and role activation.

### Escalation Layout
1.  **Code/Logic Issue** → Saman/Farzad
2.  **Data/Accuracy Issue** → Reyhaneh/Navid
3.  **Infrastructure/Security** → Sina
4.  **Strategic Blocker** → Product Owner / Amir

## 3. Skill Gap Analysis
*   **Critical Gap**: QA Specialist for AI Hallucination verification (currently shared by Dr. Kaveh/Navid).
*   **Secondary Gap**: React/Frontend developer (for Phase 2 migration from Framer).
