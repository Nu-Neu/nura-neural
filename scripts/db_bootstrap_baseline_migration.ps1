[CmdletBinding()]
param(
  [string]$MigrationsDir = "database/migrations",
  [string]$BaselineFileName = "V001__baseline.sql"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$migrationsPath = Join-Path $repoRoot $MigrationsDir
$baselinePath = Join-Path $migrationsPath $BaselineFileName

if (-not (Test-Path $migrationsPath)) {
  throw "Migrations directory not found: $migrationsPath"
}

if (Test-Path $baselinePath) {
  Write-Host "Baseline migration already exists: $BaselineFileName"
  exit 0
}

@"
-- =============================================================================
-- Nura - Baseline (Flyway)
-- Version: V001
-- Date: 2026-02-06
--
-- Purpose:
--   Establish Flyway migration history starting point for a fresh database.
--   The actual schema is defined in subsequent versioned migrations.
-- =============================================================================

SELECT 1;
"@ | Set-Content -Path $baselinePath -Encoding UTF8

Write-Host "Created baseline migration: $BaselineFileName"