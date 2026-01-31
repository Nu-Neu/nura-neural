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

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker is required for this smoke check. Install Docker Desktop or run checks via psql locally."
}

$jdbcHost = $HostName
$env:PGPASSWORD = $Password

Write-Host "Checking connectivity and a few expected objects in $Database on $HostName:$Port"

# Uses the official postgres image to run psql without requiring local installation.
$checkSql = @'
SELECT 1;
SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='sources') AS has_sources;
SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='content') AS has_content;
SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='claims') AS has_claims;
SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='narratives') AS has_narratives;
'@

$temp = New-TemporaryFile
$checkSql | Set-Content -Path $temp -Encoding UTF8

try {
  docker run --rm `
    -e PGPASSWORD="$Password" `
    -v "${temp}:/check.sql" `
    postgres:16-alpine `
    psql -h "$jdbcHost" -p "$Port" -U "$User" -d "$Database" -f /check.sql
} finally {
  Remove-Item -Force $temp -ErrorAction SilentlyContinue
}
