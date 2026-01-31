param(
  [Parameter(Mandatory = $false)]
  [string]$Repo = "",

  [Parameter(Mandatory = $false)]
  [string]$Token = "",

  [Parameter(Mandatory = $false)]
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Get-RepoFromGitRemote {
  try {
    $remoteUrl = (git remote get-url origin).Trim()
  } catch {
    throw "Unable to read git remote 'origin'. Pass -Repo owner/repo explicitly."
  }

  # Supports:
  # - https://github.com/OWNER/REPO
  # - https://github.com/OWNER/REPO.git
  # - git@github.com:OWNER/REPO.git
  if ($remoteUrl -match 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)(\.git)?$') {
    return "$($Matches.owner)/$($Matches.repo)"
  }

  throw "Unsupported origin remote URL format: $remoteUrl"
}

function Invoke-GitHubApi {
  param(
    [Parameter(Mandatory = $true)][ValidateSet('GET','POST','PATCH')][string]$Method,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $false)]$Body
  )

  $headers = @{
    Authorization        = "Bearer $script:Token"
    Accept               = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent'         = 'nura-neural-issues-bootstrap'
  }

  $uri = "https://api.github.com$Path"

  if ($script:WhatIf) {
    Write-Host "[WhatIf] $Method $uri"
    if ($Body) { Write-Host ($Body | ConvertTo-Json -Depth 20) }
    return $null
  }

  if ($null -ne $Body) {
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 20)
  }

  return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
}

function Ensure-Label {
  param(
    [Parameter(Mandatory = $true)][string]$Owner,
    [Parameter(Mandatory = $true)][string]$RepoName,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Color,
    [Parameter(Mandatory = $false)][string]$Description = ""
  )

  $path = "/repos/$Owner/$RepoName/labels"

  try {
    Invoke-GitHubApi -Method POST -Path $path -Body @{ name = $Name; color = $Color; description = $Description } | Out-Null
    Write-Host "Created label: $Name"
  } catch {
    # 422 means it already exists; ignore
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -eq 422) {
      Write-Host "Label exists: $Name"
      return
    }
    throw
  }
}

function New-Issue {
  param(
    [Parameter(Mandatory = $true)][string]$Owner,
    [Parameter(Mandatory = $true)][string]$RepoName,
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$Body,
    [Parameter(Mandatory = $false)][string[]]$Labels = @()
  )

  $payload = @{ title = $Title; body = $Body }
  if ($Labels.Count -gt 0) { $payload.labels = $Labels }

  $issue = Invoke-GitHubApi -Method POST -Path "/repos/$Owner/$RepoName/issues" -Body $payload
  Write-Host "Created issue #$($issue.number): $Title"
  return $issue
}

# --- Resolve repo/token ---
if (-not $Repo) {
  $Repo = Get-RepoFromGitRemote
}

if (-not $Token) {
  $Token = $env:GITHUB_TOKEN
}

if (-not $Token -and -not $WhatIf) {
  throw "No GitHub token provided. Set `$env:GITHUB_TOKEN or pass -Token. Token needs 'repo' scope (classic) or 'Issues: Read/Write' (fine-grained)."
}

$script:Token = $Token
$script:WhatIf = [bool]$WhatIf

if ($Repo -notmatch '^(?<owner>[^/]+)/(?<repo>[^/]+)$') {
  throw "Invalid -Repo format. Expected owner/repo, got: $Repo"
}

$owner = $Matches.owner
$repoName = $Matches.repo

Write-Host "Target repo: $owner/$repoName"

# --- Labels ---
$labelsToEnsure = @(
  @{ name = 'type:epic';   color = '5319e7'; description = 'Phase epic (one per phase)' },
  @{ name = 'type:feature'; color = '1d76db'; description = 'Major deliverable within a phase' },
  @{ name = 'type:task';   color = '0e8a16'; description = 'Actionable implementation task' }
)

for ($i = 1; $i -le 9; $i++) {
  $labelsToEnsure += @{ name = "phase:$i"; color = 'fbca04'; description = "Phase $i" }
}

foreach ($l in $labelsToEnsure) {
  Ensure-Label -Owner $owner -RepoName $repoName -Name $l.name -Color $l.color -Description $l.description
}

# --- Issue definitions ---
# Structure: phases -> epic + features -> tasks
$phases = @(
  @{ 
    phase = 1; name = 'Foundations & Governance';
    epicAcceptance = @(
      'DB-per-tenant conventions documented and agreed.',
      'SQL-first migrations scaffold exists and is documented.',
      'Secret management approach documented (no secrets in repo).'
    );
    features = @(
      @{ name = 'Tenancy & Environment Conventions';
         acceptance = @('Tenancy naming spec exists (db/index/blob container).','Environment variable contract documented.');
         tasks = @(
           @{ title='Write tenancy naming specification'; acc=@('Naming covers DB, AI Search index, blob container.','Examples provided for dev/prod.'); deps=@() },
           @{ title='Define environment variable contract'; acc=@('Dev/beta/prod variables listed.','Secrets vs non-secrets separated.'); deps=@() }
         )
      },
      @{ name = 'SQL-First Migrations Bootstrap';
         acceptance = @('Migration tool selected and justified.','Repo contains migrations folder + apply instructions.');
         tasks = @(
           @{ title='Select SQL-first migration tool'; acc=@('Decision captured in docs.','Local and CI usage described.'); deps=@() },
           @{ title='Add migration scaffold + apply guide'; acc=@('Migrations directory exists.','Guide includes apply/rollback strategy.'); deps=@('Select SQL-first migration tool') }
         )
      },
      @{ name = 'Secrets & Config Hygiene';
         acceptance = @('Secrets/state are not committed.','Docs describe Key Vault/local setup.');
         tasks = @(
           @{ title='Document secret sources and rotation'; acc=@('Key Vault usage documented.','Rotation steps defined.'); deps=@() },
           @{ title='Add repo guardrails for secrets/state'; acc=@('.gitignore updated for terraform state and env files.','Docs warn against committing secrets.'); deps=@('Document secret sources and rotation') }
         )
      }
    )
  },
  @{ 
    phase = 2; name = 'Core Database Schema (System of Record)';
    epicAcceptance = @(
      'Baseline schema is applied via migrations on an empty tenant DB.',
      'Core constraints and indexes exist for primary query paths.',
      'Evaluation history/current-pointer behavior verified.'
    );
    features = @(
      @{ name = 'Baseline Schema Migration Set';
         acceptance = @('Initial migration derived from database/schema.sql.','Repeatable apply verified.');
         tasks = @(
           @{ title='Create initial migration from baseline schema'; acc=@('Migration creates extensions/enums/core tables.','Migration is idempotent where appropriate.'); deps=@('Add migration scaffold + apply guide') },
           @{ title='Verify clean apply on empty tenant DB'; acc=@('Apply succeeds on a new database.','Smoke checks confirm tables/enums exist.'); deps=@('Create initial migration from baseline schema') }
         )
      },
      @{ name = 'Constraints, Indexes, and History';
         acceptance = @('Dedupe constraints defined for content.','Indexes cover recency/status/source lookups.','Current-pointer patterns validated.');
         tasks = @(
           @{ title='Add uniqueness + dedupe constraints'; acc=@('Canonical URL uniqueness decided and implemented.','Hash-based dedupe strategy documented.'); deps=@('Verify clean apply on empty tenant DB') },
           @{ title='Add baseline performance indexes'; acc=@('Indexes added for hot queries (recent content, status).','Indexes are documented.'); deps=@('Verify clean apply on empty tenant DB') },
           @{ title='Validate evaluation history current-pointer behavior'; acc=@('Only one current row enforced per subject.','Historical rows preserved.'); deps=@('Verify clean apply on empty tenant DB') }
         )
      }
    )
  },
  @{ 
    phase = 3; name = 'Ingestion Storage & Processing Model';
    epicAcceptance = @(
      'Source registry supports enable/disable and metadata.',
      'Ingestion write model is idempotent and observable.',
      'Processing statuses and failure reasons are standardized.'
    );
    features = @(
      @{ name = 'Source Registry & Curation';
         acceptance = @('Source types supported align with schema enums.','Admin/editor curation workflow described.');
         tasks = @(
           @{ title='Finalize source registry schema contract'; acc=@('Fields cover feeds/accounts/keywords/newsletters.','Enable/disable and last_checked supported.'); deps=@('Verify clean apply on empty tenant DB') },
           @{ title='Define source curation workflow'; acc=@('CRUD operations and validation rules documented.','Health/coverage expectations defined.'); deps=@('Finalize source registry schema contract') }
         )
      },
      @{ name = 'Ingestion State + Health Tracking';
         acceptance = @('Status transitions defined and consistent.','Health tables/views support dashboards and alerts.');
         tasks = @(
           @{ title='Define processing status transitions'; acc=@('Allowed transitions documented.','Failure reasons captured consistently.'); deps=@('Finalize source registry schema contract') },
           @{ title='Define ingestion health read model'; acc=@('Tables/views support lag and error rates.','Query examples for dashboards included.'); deps=@('Define processing status transitions') }
         )
      }
    )
  },
  @{ 
    phase = 4; name = 'IMTT-Inspired Source Scoring';
    epicAcceptance = @(
      'Pillar scores and derived tier are stored with evidence and history.',
      'Manual overrides are supported with audit trails.',
      'Score drift is observable.'
    );
    features = @(
      @{ name = 'Scoring Model + Storage';
         acceptance = @('Pillar scores (0–5) stored per evaluation.','Derived tier computation rules documented.');
         tasks = @(
           @{ title='Define pillar score schema + tier rules'; acc=@('Pillars and tier mapping documented.','Stored evaluation includes rationale and evidence links.'); deps=@('Validate evaluation history current-pointer behavior') },
           @{ title='Implement evaluation history + current pointer for source scores'; acc=@('New evaluations append; only one current.','Queries return current + history.'); deps=@('Define pillar score schema + tier rules') }
         )
      },
      @{ name = 'Overrides + Drift Monitoring';
         acceptance = @('Override mechanism exists and is auditable.','Drift signals defined.');
         tasks = @(
           @{ title='Add manual override path with audit log'; acc=@('Override records who/why/when.','Override does not delete automated history.'); deps=@('Implement evaluation history + current pointer for source scores') },
           @{ title='Define drift monitoring metrics and thresholds'; acc=@('Tier change metrics defined.','Alert conditions documented.'); deps=@('Implement evaluation history + current pointer for source scores') }
         )
      }
    )
  },
  @{ 
    phase = 5; name = 'Claims Extraction & Narrative Clustering';
    epicAcceptance = @(
      'Claims are stored with original + English translation.',
      'Narratives are stored with membership links and timeline support.',
      'Relationships support drill-down from narratives to items.'
    );
    features = @(
      @{ name = 'Claims & Verification Hooks';
         acceptance = @('Claim model supports type/status/confidence.','Evidence references are stored for verification.');
         tasks = @(
           @{ title='Finalize claim storage contract'; acc=@('Original text + English translation fields defined.','Indexes support retrieval by content/time.'); deps=@('Verify clean apply on empty tenant DB') },
           @{ title='Define verification evidence storage model'; acc=@('Evidence links and excerpts are supported.','Verification statuses mapped and stored.'); deps=@('Finalize claim storage contract') }
         )
      },
      @{ name = 'Narratives + Linking Graph';
         acceptance = @('Narrative model supports labels/summaries and multilingual metadata.','Membership table supports many-to-many.');
         tasks = @(
           @{ title='Finalize narratives and membership schema'; acc=@('Narrative membership supports claim/content linkage.','Timeline fields support ordering and grouping.'); deps=@('Finalize claim storage contract') },
           @{ title='Define narrative timeline query patterns'; acc=@('Queries for “last 24h” and narrative detail documented.','Index requirements identified.'); deps=@('Finalize narratives and membership schema') }
         )
      }
    )
  },
  @{ 
    phase = 6; name = 'Search Sync Contract (Postgres → Azure AI Search)';
    epicAcceptance = @(
      'Document mapping and deterministic IDs defined.',
      'Idempotent upsert/delete rules documented.',
      'Outbox/retry/reconciliation strategy defined.'
    );
    features = @(
      @{ name = 'Index Mapping + Document IDs';
         acceptance = @('Indexed entities selected and documented.','Document IDs are deterministic and stable.');
         tasks = @(
           @{ title='Define search index document schemas'; acc=@('Schemas defined for at least claims and narratives.','Fields include language metadata and timestamps.'); deps=@('Finalize narratives and membership schema') },
           @{ title='Define deterministic document ID + versioning scheme'; acc=@('Doc IDs derived from Postgres UUIDs.','Version field strategy defined for reindexing.'); deps=@('Define search index document schemas') }
         )
      },
      @{ name = 'Outbox, Retry, and Reconciliation';
         acceptance = @('Sync tracking/outbox schema defined.','Backfill and reconciliation behavior defined.');
         tasks = @(
           @{ title='Define outbox/sync tracking schema for indexing'; acc=@('Tracks status, attempts, error, last_attempt.','Supports delete tombstones.'); deps=@('Define deterministic document ID + versioning scheme') },
           @{ title='Define backfill + reconciliation strategy'; acc=@('Backfill steps documented.','Reconciliation periodically detects and repairs drift.'); deps=@('Define outbox/sync tracking schema for indexing') }
         )
      }
    )
  },
  @{ 
    phase = 7; name = 'Serving APIs & Query Performance';
    epicAcceptance = @(
      'Read models defined for core endpoints.',
      'Materialized view strategy documented if needed.',
      'API access control approach defined.'
    );
    features = @(
      @{ name = 'Read Models + Views';
         acceptance = @('Views defined for briefing and narrative detail.','Refresh strategy defined if materialized views are used.');
         tasks = @(
           @{ title='Define read models for briefing and narrative detail'; acc=@('SQL queries documented and optimized.','Index requirements listed.'); deps=@('Define narrative timeline query patterns') },
           @{ title='Define materialized view usage + refresh plan'; acc=@('Decide which queries use MVs.','Refresh schedule and failure handling documented.'); deps=@('Define read models for briefing and narrative detail') }
         )
      },
      @{ name = 'API Contract + Access Control';
         acceptance = @('Endpoint request/response schemas documented.','API key and rate-limit signals defined.');
         tasks = @(
           @{ title='Document endpoint contracts for core APIs'; acc=@('Schemas cover credibility, narratives, narrative detail, search, fact-check.','Error responses standardized.'); deps=@('Define read models for briefing and narrative detail') },
           @{ title='Define API key storage and rate-limit signals'; acc=@('DB tables/fields defined for API keys.','Rate-limit strategy documented.'); deps=@('Document endpoint contracts for core APIs') }
         )
      }
    )
  },
  @{ 
    phase = 8; name = 'Daily Briefing & Podcast Automation';
    epicAcceptance = @(
      'Daily briefing dataset selection is defined and persistable.',
      'Podcast script/audio artifact tracking is defined.',
      'Status transitions and retries are defined.'
    );
    features = @(
      @{ name = 'Briefing Dataset + Storage';
         acceptance = @('Selection criteria and query inputs defined.','Storage schema supports traceability.');
         tasks = @(
           @{ title='Define briefing selection criteria and query inputs'; acc=@('Criteria cover top narratives and representative items.','Time window defaults are defined.'); deps=@('Define read models for briefing and narrative detail') },
           @{ title='Define briefing storage schema'; acc=@('Stores narrative IDs, item IDs, computed ranks.','Supports regeneration.'); deps=@('Define briefing selection criteria and query inputs') }
         )
      },
      @{ name = 'Podcast Artifacts + Status Tracking';
         acceptance = @('Script storage is defined.','Audio artifact references and statuses defined.');
         tasks = @(
           @{ title='Define podcast script storage schema'; acc=@('Stores script text, model metadata, run timestamps.','Linked to briefing dataset.'); deps=@('Define briefing storage schema') },
           @{ title='Define audio artifact tracking + publishing metadata'; acc=@('Stores blob references, duration, publish status.','Retryable failure states defined.'); deps=@('Define podcast script storage schema') }
         )
      }
    )
  },
  @{ 
    phase = 9; name = 'Production Hardening & Multi-Tenant Expansion';
    epicAcceptance = @(
      'Tenant onboarding workflow is defined and repeatable.',
      'Backup/restore runbook exists per tenant.',
      'Dashboards and alerts defined for core SLIs.'
    );
    features = @(
      @{ name = 'Tenant Onboarding Automation';
         acceptance = @('Provisioning workflow inputs/outputs defined.','Verification checklist defined.');
         tasks = @(
           @{ title='Define tenant provisioning workflow'; acc=@('Creates DB/index/blob container and secrets.','Inputs include tenant slug and environment.'); deps=@('Write tenancy naming specification') },
           @{ title='Create tenant onboarding verification checklist'; acc=@('Checklist covers DB migrations, indexing, and health.','Runbook is documented.'); deps=@('Define tenant provisioning workflow') }
         )
      },
      @{ name = 'Observability + Resilience';
         acceptance = @('SLIs/SLOs defined.','Alerts defined for ingestion lag and sync backlog.');
         tasks = @(
           @{ title='Define SLIs/SLOs and dashboard metrics'; acc=@('Metrics cover ingestion throughput/lag, failures, sync backlog.','Owners and thresholds defined.'); deps=@('Define ingestion health read model') },
           @{ title='Define alerting for lag/backlog/failures'; acc=@('Alert conditions and routing defined.','Runbook links included.'); deps=@('Define SLIs/SLOs and dashboard metrics') }
         )
      }
    )
  }
)

# --- Create issues ---
$created = New-Object System.Collections.Generic.List[object]
$issueNumberByTitle = @{}
$issueNumberByPhaseEpic = @{}

foreach ($phase in $phases) {
  $phaseNum = $phase.phase
  $phaseLabel = "phase:$phaseNum"

  $epicTitle = "[EPIC] Phase $phaseNum: $($phase.name)"
  $epicBody = @(
    "**Type:** Epic",
    "**Phase:** $phaseNum",
    "",
    "**Goal:** $($phase.epicAcceptance[0])",
    "",
    "**Acceptance Criteria:**",
    ($phase.epicAcceptance | ForEach-Object { "- $_" }),
    "",
    "**Dependencies:**",
    "- None",
    "",
    "**References:**",
    "- docs/HighLevelPlanning_PhasedDeliverables.md",
    "- docs/PRD.md",
    "- docs/Architecture.md",
    "- database/schema.sql"
  ) -join "`n"

  $epicIssue = New-Issue -Owner $owner -RepoName $repoName -Title $epicTitle -Body $epicBody -Labels @('type:epic', $phaseLabel)
  $issueNumberByTitle[$epicTitle] = $epicIssue.number
  $issueNumberByPhaseEpic[$phaseNum] = $epicIssue.number
  $created.Add(@{ number = $epicIssue.number; title = $epicTitle; url = $epicIssue.html_url })

  foreach ($feature in $phase.features) {
    $featureTitle = "[FEATURE] Phase $phaseNum: $($feature.name)"
    $featureBody = @(
      "**Type:** Feature",
      "**Phase:** $phaseNum",
      "",
      "**Goal:** $($feature.acceptance[0])",
      "",
      "**Acceptance Criteria:**",
      ($feature.acceptance | ForEach-Object { "- $_" }),
      "",
      "**Dependencies:**",
      "- Part of: #$($epicIssue.number)",
      "",
      "**References:**",
      "- docs/HighLevelPlanning_PhasedDeliverables.md"
    ) -join "`n"

    $featureIssue = New-Issue -Owner $owner -RepoName $repoName -Title $featureTitle -Body $featureBody -Labels @('type:feature', $phaseLabel)
    $issueNumberByTitle[$featureTitle] = $featureIssue.number
    $created.Add(@{ number = $featureIssue.number; title = $featureTitle; url = $featureIssue.html_url })

    foreach ($task in $feature.tasks) {
      $taskTitle = "[TASK] Phase $phaseNum: $($task.title)"

      $depsLines = @("- Part of: #$($featureIssue.number)")
      foreach ($d in $task.deps) {
        # If dependency task has already been created, link to its issue number; otherwise keep as text.
        $depTitle = "[TASK] Phase $phaseNum: $d"
        if ($issueNumberByTitle.ContainsKey($depTitle)) {
          $depsLines += "- Depends on: #$($issueNumberByTitle[$depTitle])"
        } else {
          $depsLines += "- Depends on: $d"
        }
      }

      $taskBody = @(
        "**Type:** Task",
        "**Phase:** $phaseNum",
        "",
        "**Goal:** $($task.acc[0])",
        "",
        "**Acceptance Criteria:**",
        ($task.acc | ForEach-Object { "- $_" }),
        "",
        "**Dependencies:**",
        ($depsLines -join "`n"),
        "",
        "**References:**",
        "- docs/HighLevelPlanning_PhasedDeliverables.md"
      ) -join "`n"

      $taskIssue = New-Issue -Owner $owner -RepoName $repoName -Title $taskTitle -Body $taskBody -Labels @('type:task', $phaseLabel)
      $issueNumberByTitle[$taskTitle] = $taskIssue.number
      $created.Add(@{ number = $taskIssue.number; title = $taskTitle; url = $taskIssue.html_url })
    }
  }
}

# --- Write summary ---
$summaryPath = Join-Path (Get-Location) 'docs/github-issues-created.md'
$lines = @(
  "# Created GitHub Issues",
  "",
  "Repo: $owner/$repoName",
  "",
  "Generated by scripts/create_github_issues.ps1",
  ""
)

foreach ($c in $created) {
  $lines += "- #$($c.number) $($c.title) ($($c.url))"
}

$lines -join "`n" | Set-Content -Path $summaryPath -Encoding UTF8
Write-Host "Wrote summary: $summaryPath"
