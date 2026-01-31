param(
  [Parameter(Mandatory = $false)][string]$HostName = $env:DB_HOST,
  [Parameter(Mandatory = $false)][int]$Port = [int]($env:DB_PORT ? $env:DB_PORT : 5432),
  [Parameter(Mandatory = $false)][string]$Database = $env:DB_NAME,
  [Parameter(Mandatory = $false)][string]$User = $env:DB_USER,
  [Parameter(Mandatory = $false)][string]$Password = $env:DB_PASSWORD
)

$ErrorActionPreference = 'Stop'

function Require($name, $value) {
  if (-not $value) { throw "Missing required parameter/env var: $name" }
}

Require 'DB_HOST' $HostName
Require 'DB_NAME' $Database
Require 'DB_USER' $User
Require 'DB_PASSWORD' $Password

$repoRoot = Split-Path -Parent $PSScriptRoot
$migrationsDir = Join-Path $repoRoot 'database/migrations'

powershell -File (Join-Path $repoRoot 'scripts/db_bootstrap_baseline_migration.ps1')

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker is required to run Flyway in this setup. Install Docker Desktop or add Flyway CLI to PATH and update this script."
}

$jdbc = "jdbc:postgresql://$HostName`:$Port/$Database"

Write-Host "Running migrations against $jdbc"

docker run --rm `
  -e FLYWAY_URL="$jdbc" `
  -e FLYWAY_USER="$User" `
  -e FLYWAY_PASSWORD="$Password" `
  -e FLYWAY_SCHEMAS=public `
  -v "${migrationsDir}:/flyway/sql" `
  flyway/flyway:10 `
  -connectRetries=10 migrate
