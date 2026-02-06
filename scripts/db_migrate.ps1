[CmdletBinding()]
param(
  [string]$DbHost = $env:DB_HOST,
  [string]$DbPort = $env:DB_PORT,
  [string]$DbName = $env:DB_NAME,
  [string]$DbUser = $env:DB_USER,
  [string]$DbPassword = $env:DB_PASSWORD
)

$ErrorActionPreference = 'Stop'

foreach ($pair in @{
  DB_HOST = $DbHost
  DB_PORT = $DbPort
  DB_NAME = $DbName
  DB_USER = $DbUser
  DB_PASSWORD = $DbPassword
}.GetEnumerator()) {
  if (-not $pair.Value) { throw "Missing required value: $($pair.Key)" }
}

$docker = Get-Command docker -ErrorAction Stop

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$migrationsPath = Join-Path $repoRoot 'database/migrations'

if (-not (Test-Path $migrationsPath)) {
  throw "Migrations directory not found: $migrationsPath"
}

# Flyway docker expects JDBC URL
$jdbc = "jdbc:postgresql://$DbHost`:$DbPort/$DbName"

Write-Host "Running Flyway migrations against $jdbc"

& $docker.Source run --rm `
  -e "FLYWAY_URL=$jdbc" `
  -e "FLYWAY_USER=$DbUser" `
  -e "FLYWAY_PASSWORD=$DbPassword" `
  -e "FLYWAY_SCHEMAS=public" `
  -v "${migrationsPath}:/flyway/sql" `
  flyway/flyway:10 `
  -connectRetries=10 migrate

if ($LASTEXITCODE -ne 0) { throw "Flyway migrate failed with exit code $LASTEXITCODE" }

Write-Host "Flyway migrate completed successfully."