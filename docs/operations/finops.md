---
doc_type: operations
version: 1.0
last_updated: 2026-02-04
owner: Nura Neural Team
status: approved
---

# FinOps & Cost Management

## 1. Cost Management Strategy

The project's financial strategy is centered on maximizing runway from a fixed budget. The primary goal is to keep monthly operational costs as low as possible without compromising core functionality.

- **Budget:** $5,000
- **Target Monthly Burn Rate:** < $50
- **Projected Runway:** > 3.5 years

This is achieved through a combination of **architectural choices** and **operational discipline**.

---

## 2. Architectural Cost Controls

The infrastructure was designed from the ground up for low cost, based on the decisions in **[NN-ADR-0002](NN-ADR-0002-cost-optimization.md)**.

| Resource | Cost-Saving Measure | Rationale |
|---|---|---|
| **Compute** | Azure Container Apps (Serverless) | Scales to zero. Pay only for what is used. No idle costs. |
| **Database** | PostgreSQL Flexible Server (Burstable `B2s` SKU) | Low baseline cost with the ability to burst CPU for short, intensive tasks like migrations or complex queries. |
| **AI Search** | **Free Tier** | No cost. Sufficient for the 14-day rolling window of "hot" data required for search. |
| **AI Models** | `GPT-5-nano` as primary | 67% cheaper and significantly faster than `GPT-4o-mini` for the majority of tasks (extraction, classification). |
| **Caching** | In-memory Redis Container App | A low-cost Redis instance (`0.125` vCPU) drastically reduces database reads and API calls. |

---

## 3. Estimated Monthly Costs

The following is a breakdown of the estimated monthly costs for the production environment (`irdecode-prod-rg`).

| ID | Resource Name | SKU / Config | Monthly Cost (Est) | Notes |
|----|---------------|--------------|--------------------|-------|
| R06 | `irdecode-prod-psql` | B2s (2vCore, 4GB) | ~$35.00 | The single largest cost. |
| R11 | `irdecode-prod-openai` | S0 (Standard) | ~$6.00 | Usage-based, primarily `GPT-5-nano`. |
| R10 | `irdecode-storage` | LRS Hot/Cool | ~$1.20 | For Terraform state and data archival. |
| R04 | `irdecode-prod-n8n` | 0.25 vCPU, 0.5Gi | ~$0.90 | Scales to zero. |
| R05 | `irdecode-prod-redis` | 0.125 vCPU, 0.25Gi | ~$0.45 | Scales to zero. |
| R09 | `irdecode-logs` | Pay-as-you-go | <$1.00 | For diagnostics and monitoring. |
| R07 | `nura-search` | **Free Tier** | $0.00 | Critical cost-saving measure. |
| - | *Other Resources* | VNet, NSG, etc. | $0.00 | No direct cost. |
| **Total** | | | **~ $44.55** | |

---

## 4. Cost Monitoring & Governance

- **Tooling:** **Azure Cost Management + Billing** is the primary tool for tracking spend.
- **Process:**
    1.  **Monthly Review:** At the end of each month, the Product Owner and DevOps Lead review the actual spend against the forecast.
    2.  **Budget Alerts:** An alert is configured in Azure Cost Management to notify the team if the monthly spend is projected to exceed **$60**.
    3.  **Anomaly Detection:** Any unexpected spike in cost (e.g., from a runaway AI process) is investigated immediately.
- **Cost Optimization Reviews:** The architecture and resource SKUs are reviewed quarterly to identify any new opportunities for cost savings.
