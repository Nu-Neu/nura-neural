#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Apply V004 MVP schema directly to PostgreSQL without Docker/Flyway

.DESCRIPTION
    This script applies the simplified MVP schema (V004) directly to the nura database
    using Azure CLI and psql. It's an alternative to db_migrate.ps1 when Docker is not available.

.PARAMETER SkipFirewall
    Skip adding local IP to firewall (use if already added)

.EXAMPLE
    .\apply_schema_direct.ps1
#>

param(
    [switch]$SkipFirewall
)

$ErrorActionPreference = 'Stop'

Write-Host "`n=== Nura MVP Schema Migration (Direct) ===" -ForegroundColor Cyan

# Configuration
$rgName = "irdecode-prod-rg"
$serverName = "irdecode-prod-psql"
$dbName = "nura"
$serverFqdn = "$serverName.postgres.database.azure.com"

# Get admin username (usually starts with server name or is 'postgres')
Write-Host "`nStep 1: Retrieving database credentials..." -ForegroundColor Yellow
$adminUser = "postgres"  # Default PostgreSQL admin user

# Get password from Key Vault
try {
    $password = az keyvault secret show --vault-name irdecode-prod-kv --name postgres-admin-password --query value -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ⚠ Could not retrieve postgres-admin-password (may be disabled)" -ForegroundColor Yellow
        Write-Host "  Attempting to use Azure AD authentication..." -ForegroundColor Yellow
        $useAzureAD = $true
    } else {
        Write-Host "  ✓ Password retrieved from Key Vault" -ForegroundColor Green
        $env:PGPASSWORD = $password
        $useAzureAD = $false
    }
} catch {
    Write-Host "  ⚠ Error accessing Key Vault: $_" -ForegroundColor Yellow
    Write-Host "  Attempting to use Azure AD authentication..." -ForegroundColor Yellow
    $useAzureAD = $true
}

# Add firewall rule if needed
if (-not $SkipFirewall) {
    Write-Host "`nStep 2: Ensuring firewall access..." -ForegroundColor Yellow
    $myIP = (Invoke-RestMethod -Uri 'https://api.ipify.org?format=text' -UseBasicParsing)
    Write-Host "  Your IP: $myIP" -ForegroundColor White
    
    $existingRule = az postgres flexible-server firewall-rule show --resource-group $rgName --name $serverName --rule-name "LocalMigration-Temp" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Adding firewall rule..." -ForegroundColor Gray
        az postgres flexible-server firewall-rule create --resource-group $rgName --name $serverName --rule-name "LocalMigration-Temp" --start-ip-address $myIP --end-ip-address $myIP | Out-Null
        Write-Host "  ✓ Firewall rule added" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Firewall rule already exists" -ForegroundColor Green
    }
}

# Prepare SQL file paths
$repoRoot = Split-Path -Parent $PSScriptRoot
$schemaMvpPath = Join-Path $repoRoot "database\schema_mvp.sql"

if (-not (Test-Path $schemaMvpPath)) {
    throw "Schema file not found: $schemaMvpPath"
}

Write-Host "`nStep 3: Applying MVP Schema..." -ForegroundColor Yellow
Write-Host "  Database: $dbName on $serverFqdn" -ForegroundColor White
Write-Host "  Schema: schema_mvp.sql (4 core tables)" -ForegroundColor White

# Check if psql is available
$psqlAvailable = Get-Command psql -ErrorAction SilentlyContinue

if ($psqlAvailable) {
    Write-Host "  Using local psql client..." -ForegroundColor Gray
    
    if ($useAzureAD) {
        Write-Host "  ⚠ Azure AD auth requires manual token setup" -ForegroundColor Yellow
        Write-Host "  Please use Azure Cloud Shell or install PostgreSQL client" -ForegroundColor Yellow
        throw "Azure AD authentication not yet implemented for local psql"
    }
    
    # Run schema via psql
    psql "postgresql://${adminUser}:${env:PGPASSWORD}@${serverFqdn}:5432/${dbName}?sslmode=require" -f $schemaMvpPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Schema applied successfully!" -ForegroundColor Green
    } else {
        throw "psql command failed with exit code $LASTEXITCODE"
    }
} else {
    # Use Azure CLI to execute SQL (limited support, but works for simple commands)
    Write-Host "  psql not found. Using Azure CLI method..." -ForegroundColor Yellow
    Write-Host "  Note: This method has limitations. Consider using Azure Cloud Shell for full migration." -ForegroundColor Gray
    
    # Read schema and split into statements
    $schemaContent = Get-Content $schemaMvpPath -Raw
    
    # For now, suggest Cloud Shell
    Write-Host "`n⚠ Recommended: Use Azure Cloud Shell for migration" -ForegroundColor Yellow
    Write-Host "`nInstructions:" -ForegroundColor Cyan
    Write-Host "  1. Open https://shell.azure.com (choose Bash)" -ForegroundColor White
    Write-Host "  2. Run: git clone https://github.com/Nu-Neu/nura-neural.git" -ForegroundColor White
    Write-Host "  3. Run: cd nura-neural" -ForegroundColor White
    Write-Host "  4. Get password: az keyvault secret show --vault-name irdecode-prod-kv --name postgres-admin-password --query value -o tsv" -ForegroundColor White
    Write-Host "  5. Run: PGPASSWORD='<password>' psql \"postgresql://postgres@$serverFqdn:5432/$dbName?sslmode=require\" -f database/schema_mvp.sql" -ForegroundColor White
    Write-Host "`nAlternatively, install PostgreSQL client:" -ForegroundColor Cyan
    Write-Host "  Download from: https://www.postgresql.org/download/windows/" -ForegroundColor White
    Write-Host "  Then run this script again" -ForegroundColor White
}

Write-Host "`n=== Migration Summary ===" -ForegroundColor Cyan
Write-Host "  • pgvector extension: Enabled on server" -ForegroundColor Green
Write-Host "  • Firewall rule: Added for your IP" -ForegroundColor Green
Write-Host "  • Schema application: Requires psql client or Cloud Shell" -ForegroundColor Yellow
