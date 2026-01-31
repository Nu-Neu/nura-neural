$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$schemaPath = Join-Path $repoRoot 'database/schema.sql'
$migrationsDir = Join-Path $repoRoot 'database/migrations'
$baselinePath = Join-Path $migrationsDir 'V1__baseline.sql'

if (-not (Test-Path $schemaPath)) {
  throw "Missing schema file: $schemaPath"
}

if (-not (Test-Path $migrationsDir)) {
  New-Item -ItemType Directory -Path $migrationsDir | Out-Null
}

if (Test-Path $baselinePath) {
  Write-Host "Baseline migration already exists: $baselinePath"
  exit 0
}

Copy-Item -Path $schemaPath -Destination $baselinePath
Write-Host "Created baseline migration: $baselinePath"
