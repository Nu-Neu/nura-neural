# Nura Neural - Documentation Contribution Rules

When asked to create or update documentation, you must follow these rules to maintain consistency and clarity across the project.

## 1. Use the Standard Document Structure

All documentation must fit into the established structure. Do not create new top-level documents.

- **`docs/01-discovery-and-planning.md`**: For business goals, project scope, and roadmap.
- **`docs/02-requirements.md`**: For functional/non-functional requirements and user stories.
- **`docs/03-architecture-overview.md`**: For the high-level system design, diagrams, and infrastructure.
- **`docs/04-ai-engineering.md`**: For AI model specifics, prompts, and vector search logic.
- **`docs/architecture/adr/`**: For all significant architectural decisions.
- **`docs/workflows/`**: For detailed specifications of each n8n workflow.
- **`docs/operations/`**: For runbooks, monitoring, and cost management procedures.

## 2. Document All Decisions in ADRs

Any significant technical decision **must** be captured in an Architecture Decision Record (ADR).

- **Location**: `docs/architecture/adr/`
- **Format**: `NN-ADR-XXXX-title.md` (e.g., `NN-ADR-0005-new-caching-strategy.md`)
- **Content**: Each ADR should clearly state the **Context**, **Decision**, and **Consequences** (both positive and negative).

## 3. Use the Standard Metadata Header

Every markdown document must begin with a YAML frontmatter block for metadata.

```yaml
---
doc_type: <type>      # e.g., architecture, adr, operations, workflow
version: <x.y>        # e.g., 1.0
last_updated: <YYYY-MM-DD>
owner: Nura Neural Team
status: <draft|approved|deprecated>
---
```

## 4. Diagrams Must Use Mermaid.js

All diagrams (flowcharts, sequence diagrams, etc.) included in the documentation must be created using Mermaid.js syntax. This ensures they are version-controlled and easy to update.

**Example:**
````mermaid
graph TD
    A[Start] --> B{Is it documented?};
    B -- Yes --> C[Great!];
    B -- No --> D[Create ADR];
````

## 5. Keep the Archive Clean

The `docs/archive/` directory is for read-only historical reference. Do not add new files to it. When you consolidate an old document into the new structure, move the original file into the archive.
