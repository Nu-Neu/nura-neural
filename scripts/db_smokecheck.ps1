[CmdletBinding()]
param(
  [string[]]$ExpectedTables = @('sources', 'content_items', 'clusters', 'content_analysis', 'knowledge_base')
)

$ErrorActionPreference = 'Stop'

$hostName = $env:DB_HOST
$port = $env:DB_PORT
$dbName = $env:DB_NAME
$user = $env:DB_USER
$password = $env:DB_PASSWORD

foreach ($v in @('DB_HOST','DB_PORT','DB_NAME','DB_USER','DB_PASSWORD')) {
  if (-not [Environment]::GetEnvironmentVariable($v)) { throw "Missing required env var: $v" }
}

function Invoke-PsqlQuery {
  param([Parameter(Mandatory=$true)][string]$Query)

  $psql = Get-Command psql -ErrorAction SilentlyContinue
  if ($psql) {
    $env:PGPASSWORD = $password
    try {
      return & $psql.Source -h $hostName -p $port -U $user -d $dbName -v ON_ERROR_STOP=1 -Atc $Query
    } finally {
      Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    }
  }

  $docker = Get-Command docker -ErrorAction SilentlyContinue
  if (-not $docker) {
    throw "Neither 'psql' nor 'docker' are available to run smoke checks."
  }

  # On GitHub Actions (ubuntu-latest) we can use host networking.
  $networkArgs = @('--network','host')

  $args = @(
    'run','--rm'
  ) + $networkArgs + @(
    '-e',"PGPASSWORD=$password",
    'postgres:16',
    'psql',
    '-h',$hostName,
    '-p',$port,
    '-U',$user,
    '-d',$dbName,
    '-v','ON_ERROR_STOP=1',
    '-Atc',$Query
  )

  return & $docker.Source @args
}

$existing = Invoke-PsqlQuery -Query @"
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;
"@

$existingSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($t in ($existing -split "`n")) {
  $name = $t.Trim()
  if ($name) { [void]$existingSet.Add($name) }
}

$missing = @()
foreach ($t in $ExpectedTables) {
  if (-not $existingSet.Contains($t)) { $missing += $t }
}

if ($missing.Count -gt 0) {
  throw "DB smoke check failed. Missing tables: $($missing -join ', ')"
}

Write-Host "DB smoke check passed. Found expected tables: $($ExpectedTables -join ', ')"

# T001: Verify PostgreSQL 16+ and pgvector 0.5+
Write-Host "`nVerifying PostgreSQL version..."
$pgVersion = Invoke-PsqlQuery -Query "SHOW server_version;"
$pgMajor = [int]($pgVersion -split '\.')[0]
if ($pgMajor -lt 16) {
  throw "PostgreSQL version $pgVersion is below required 16.x"
}
Write-Host "PostgreSQL version: $pgVersion (OK)"

Write-Host "`nVerifying pgvector extension..."
$vectorVersion = Invoke-PsqlQuery -Query "SELECT extversion FROM pg_extension WHERE extname = 'vector';"
if (-not $vectorVersion) {
  throw "pgvector extension not installed"
}
$vectorParts = $vectorVersion -split '\.'
$vectorMajor = [int]$vectorParts[0]
$vectorMinor = [int]$vectorParts[1]
if ($vectorMajor -eq 0 -and $vectorMinor -lt 5) {
  throw "pgvector version $vectorVersion is below required 0.5+"
}
Write-Host "pgvector version: $vectorVersion (OK)"

# T003: Verify all required extensions
Write-Host "`nVerifying required extensions..."
$requiredExtensions = @('uuid-ossp', 'vector', 'pg_trgm', 'btree_gin')
$installedExtensions = (Invoke-PsqlQuery -Query "SELECT extname FROM pg_extension;") -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$missingExtensions = @()
foreach ($ext in $requiredExtensions) {
  if ($installedExtensions -notcontains $ext) {
    $missingExtensions += $ext
  } else {
    Write-Host "  Extension '$ext': Installed"
  }
}
if ($missingExtensions.Count -gt 0) {
  throw "Missing required extensions: $($missingExtensions -join ', ')"
}
Write-Host "All required extensions present (OK)"

# T004: Verify core tables exist
Write-Host "`nVerifying core tables..."
$coreTables = @('content_items', 'knowledge_base', 'clusters', 'sources')
foreach ($table in $coreTables) {
  if (-not $existingSet.Contains($table)) {
    throw "Missing core table: $table"
  }
  Write-Host "  Table '$table': Exists"
}
Write-Host "All core tables present (OK)"

# T002: Verify V008 migration applied
Write-Host "`nVerifying V008 migration applied..."
$v008Applied = Invoke-PsqlQuery -Query @"
SELECT version FROM flyway_schema_history 
WHERE version = '008' AND success = true;
"@
if (-not $v008Applied) {
  throw "V008__core_schema_prereqs.sql has not been applied or failed"
}
Write-Host "V008 migration: Applied (OK)"

Write-Host "`n=== All DB foundation checks passed ===" -ForegroundColor Green