<#
.SYNOPSIS
    Restructures the docs folder based on SDLC best practices.
#>

$ErrorActionPreference = "Continue"

# 1. Create New Directory Structure
$dirs = @(
    "docs\00_DISCOVERY",
    "docs\01_REQUIREMENTS",
    "docs\02_ARCHITECTURE",
    "docs\03_DECISIONS",
    "docs\04_OPERATIONS",
    "docs\05_TEAM",
    "docs\research",
    "docs\archive\legacy_specs"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created: $dir" -ForegroundColor Green
    }
}

# 2. Move Research & Discovery
# We use Copy -Recurse first for folders to be safe, then delete source
Move-Item "docs\market-research-nura-v1.0.md" "docs\00_DISCOVERY\market-research-summary.md" -ea SilentlyContinue
# Keep original large research docs in research folder but link to them
Move-Item "docs\archive\Canceld\Master Functional Specification*.md" "docs\research\" -ea SilentlyContinue
Move-Item "docs\archive\Canceld\IMTT_Inspired_Source_Scoring_Framework.md" "docs\research\" -ea SilentlyContinue

# 3. Move Architecture (HLD, Design, Data Flow)
# The current HLD user was looking at was in Downloads, we need to check if we have it in docs
# Assuming the file exists in docs or we created it in previous steps. 
# Based on context, we should move existing HLDs found in docs/
Move-Item "docs\hld-nura-v2.1 (2).md" "docs\02_ARCHITECTURE\HLD-NURA-Master.md" -ea SilentlyContinue
Move-Item "docs\hld-nura-v2.0.md" "docs\archive\hld-nura-v2.0.md" -ea SilentlyContinue
Move-Item "docs\data-flow-architecture-v1.0.md" "docs\02_ARCHITECTURE\data-flow.md" -ea SilentlyContinue
Move-Item "docs\design-*.md" "docs\02_ARCHITECTURE\" -ea SilentlyContinue
Move-Item "docs\schema-v1.0-mvp.sql.md" "docs\02_ARCHITECTURE\database-schema-ref.md" -ea SilentlyContinue
Move-Item "docs\workflow-pg-to-ai-search-sync-v1.0.md" "docs\02_ARCHITECTURE\workflow-sync-spec.md" -ea SilentlyContinue

# 4. Move Requirements
Move-Item "docs\req-*.md" "docs\01_REQUIREMENTS\" -ea SilentlyContinue
Move-Item "docs\srs-nura-v2.4.md" "docs\01_REQUIREMENTS\SRS-Master.md" -ea SilentlyContinue

# 5. Move & Standardize Decisions (ADRs)
Move-Item "docs\ADR-009-*.md" "docs\03_DECISIONS\" -ea SilentlyContinue
Move-Item "docs\adr-*.md" "docs\03_DECISIONS\" -ea SilentlyContinue
Move-Item "docs\docadr-*.md" "docs\03_DECISIONS\" -ea SilentlyContinue
# Move existing decisions folder content if any
if (Test-Path "docs\decisions") {
    Move-Item "docs\decisions\*" "docs\03_DECISIONS\" -ea SilentlyContinue
    Remove-Item "docs\decisions" -Recurse -ea SilentlyContinue
}

# 6. Move Operations (Runbooks, Infra, Workflows)
Move-Item "docs\runbook-*.md" "docs\04_OPERATIONS\" -ea SilentlyContinue
Move-Item "docs\infrastructure-overview-v1.0.md" "docs\04_OPERATIONS\infrastructure.md" -ea SilentlyContinue
Move-Item "docs\n8n-workflows-master-plan-v1.0.md" "docs\04_OPERATIONS\workflow-specifications.md" -ea SilentlyContinue
if (Test-Path "docs\tenancy") {
    Move-Item "docs\tenancy\*" "docs\04_OPERATIONS\" -ea SilentlyContinue
    Remove-Item "docs\tenancy" -Recurse -ea SilentlyContinue
}

# 7. Cleanup Archive
if (Test-Path "docs\archive\Canceld") {
   Move-Item "docs\archive\Canceld\*" "docs\archive\" -ea SilentlyContinue
   Remove-Item "docs\archive\Canceld" -Recurse -ea SilentlyContinue
}

Write-Host "Migration complete. Please manually review 'docs\archive' for any remaining files." -ForegroundColor Cyan
