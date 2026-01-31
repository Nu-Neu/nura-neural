# Nura's IMTT-Inspired Source Scoring Framework

## Overview
This framework is designed to evaluate and score sources based on the IMTT-inspired pillars: Integrity, Methodology, Transparency, and Trustworthiness. The scoring system automates the evaluation of sources to ensure high-quality content ingestion and analysis.

---

## Scoring Pillars

### 1. Integrity
- **Definition**: Measures the ethical standards and reliability of the source.
- **Metrics**:
  - History of factual reporting.
  - Absence of plagiarism or misinformation.
  - Adherence to journalistic ethics.
- **Scoring**:
  - Binary checks (e.g., plagiarism detection).
  - Weighted scores for historical accuracy.

### 2. Methodology
- **Definition**: Evaluates the rigor and transparency of the source's content creation process.
- **Metrics**:
  - Cited references and data sources.
  - Use of credible methodologies in reporting.
  - Consistency in content structure.
- **Scoring**:
  - Assign weights to the presence of citations and methodology descriptions.

### 3. Transparency
- **Definition**: Assesses the openness of the source regarding its ownership, funding, and affiliations.
- **Metrics**:
  - Disclosure of ownership and funding.
  - Clear identification of authors.
  - Accessibility of editorial policies.
- **Scoring**:
  - Deduct points for missing or unclear disclosures.

### 4. Trustworthiness
- **Definition**: Measures the reputation and credibility of the source within its domain.
- **Metrics**:
  - Peer reviews and endorsements.
  - Audience trust surveys.
  - Domain authority and reputation.
- **Scoring**:
  - Aggregate scores from peer reviews and audience surveys.

---

## Implementation Plan

### Data Collection
- **Sources**: RSS feeds, social media platforms, and manual submissions.
- **Tools**: Miniflux for RSS ingestion, TwitterAPI.io for social media data.
- **Validation**: Deduplication and data validation workflows.

### Scoring Workflow
1. **Ingestion**:
   - Collect data from sources.
   - Validate and deduplicate entries.
2. **Analysis**:
   - Apply scoring algorithms based on the four pillars.
   - Store scores in PostgreSQL for historical tracking.
3. **Serving**:
   - Expose scores via API endpoints.
   - Sync scores with Azure AI Search for fast retrieval.

### Operational Considerations
- **Historical Tracking**: Use `is_current` pointers to manage historical evaluations.
- **Multilingual Support**: Ensure scoring algorithms handle multilingual content.
- **Scalability**: Optimize for high-volume ingestion and scoring.

---

## Next Steps
1. Finalize scoring algorithms for each pillar.
2. Implement ingestion and analysis workflows.
3. Test the framework with a sample dataset.
4. Deploy the framework in a production environment.