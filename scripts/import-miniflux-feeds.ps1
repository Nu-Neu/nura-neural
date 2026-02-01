<#
.SYNOPSIS
    Imports OPML feeds into Miniflux

.DESCRIPTION
    Imports RSS/Atom feeds from an OPML file into a Miniflux instance.
    Supports authentication via API key from Azure Key Vault or environment variable.

.PARAMETER MinifluxUrl
    Base URL of the Miniflux instance (default: from Key Vault or env)

.PARAMETER ApiKey
    Miniflux API key (optional - will fetch from Key Vault or env var if not provided)

.PARAMETER KeyVaultName
    Azure Key Vault name to fetch secrets from (optional)

.PARAMETER OpmlFile
    Path to the OPML file to import (default: ../config/miniflux-feeds.opml)

.PARAMETER DryRun
    Show what would be imported without making changes

.EXAMPLE
    .\import-miniflux-feeds.ps1 -KeyVaultName "irdecode-prod-kv"

.EXAMPLE
    .\import-miniflux-feeds.ps1 -MinifluxUrl "https://rss.example.com" -ApiKey "your-api-key"

.EXAMPLE
    .\import-miniflux-feeds.ps1 -KeyVaultName "irdecode-prod-kv" -OpmlFile "./custom-feeds.opml"
#>

param(
    [string]$MinifluxUrl,
    [string]$ApiKey,
    [string]$KeyVaultName,
    [string]$ApiKeySecretName = "miniflux-api-key",
    [string]$MinifluxUrlSecretName = "miniflux-url",
    [string]$OpmlFile = "../config/miniflux-feeds.opml",
    [switch]$DryRun,
    [switch]$ListFeeds
)

$ErrorActionPreference = "Stop"

# ===========================================
# Helper Functions
# ===========================================
function Write-Step {
    param([string]$Message)
    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Gray
}

# ===========================================
# Secret Retrieval
# ===========================================
function Get-SecretFromKeyVault {
    param(
        [string]$VaultName,
        [string]$SecretName
    )
    
    try {
        if (-not (Get-Module -ListAvailable -Name Az.KeyVault)) {
            return $null
        }
        
        if (-not (Get-Module -Name Az.KeyVault)) {
            Import-Module Az.KeyVault -ErrorAction Stop
        }
        
        $secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -AsPlainText -ErrorAction Stop
        return $secret
    }
    catch {
        return $null
    }
}

function Get-SecretFromEnvironment {
    param([string]$EnvVarName)
    
    $envValue = [Environment]::GetEnvironmentVariable($EnvVarName)
    if (-not $envValue) {
        $envValue = [Environment]::GetEnvironmentVariable($EnvVarName, "User")
    }
    if (-not $envValue) {
        $envValue = [Environment]::GetEnvironmentVariable($EnvVarName, "Machine")
    }
    
    return $envValue
}

function Get-MinifluxApiKey {
    # 1. Use explicitly provided API key
    if ($script:ApiKey) {
        Write-Info "Using provided API key"
        return $script:ApiKey
    }
    
    # 2. Try Azure Key Vault
    if ($script:KeyVaultName) {
        Write-Info "Fetching API key from Key Vault '$($script:KeyVaultName)'..."
        $kvSecret = Get-SecretFromKeyVault -VaultName $script:KeyVaultName -SecretName $script:ApiKeySecretName
        if ($kvSecret) {
            Write-Success "Retrieved API key from Key Vault"
            return $kvSecret
        }
    }
    
    # 3. Try environment variables
    $envVarNames = @("MINIFLUX_API_KEY", "MINIFLUX_APIKEY")
    foreach ($envVar in $envVarNames) {
        $envSecret = Get-SecretFromEnvironment -EnvVarName $envVar
        if ($envSecret) {
            Write-Info "Using API key from environment variable '$envVar'"
            return $envSecret
        }
    }
    
    return $null
}

function Get-MinifluxUrl {
    # 1. Use explicitly provided URL
    if ($script:MinifluxUrl) {
        return $script:MinifluxUrl.TrimEnd('/')
    }
    
    # 2. Try Azure Key Vault
    if ($script:KeyVaultName) {
        $kvUrl = Get-SecretFromKeyVault -VaultName $script:KeyVaultName -SecretName $script:MinifluxUrlSecretName
        if ($kvUrl) {
            Write-Info "Retrieved Miniflux URL from Key Vault"
            return $kvUrl.TrimEnd('/')
        }
    }
    
    # 3. Try environment variable
    $envUrl = Get-SecretFromEnvironment -EnvVarName "MINIFLUX_URL"
    if ($envUrl) {
        Write-Info "Using Miniflux URL from environment"
        return $envUrl.TrimEnd('/')
    }
    
    return $null
}

# ===========================================
# Miniflux API Functions
# ===========================================
function Test-MinifluxConnection {
    param(
        [string]$Url,
        [string]$ApiKey
    )
    
    try {
        $headers = @{
            "X-Auth-Token" = $ApiKey
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod `
            -Uri "$Url/v1/me" `
            -Method GET `
            -Headers $headers `
            -TimeoutSec 30
        
        Write-Success "Connected to Miniflux as: $($response.username)"
        return $true
    }
    catch {
        Write-Error "Failed to connect to Miniflux: $($_.Exception.Message)"
        return $false
    }
}

function Get-MinifluxFeeds {
    param(
        [string]$Url,
        [string]$ApiKey
    )
    
    $headers = @{
        "X-Auth-Token" = $ApiKey
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-RestMethod `
        -Uri "$Url/v1/feeds" `
        -Method GET `
        -Headers $headers
    
    return $response
}

function Get-MinifluxCategories {
    param(
        [string]$Url,
        [string]$ApiKey
    )
    
    $headers = @{
        "X-Auth-Token" = $ApiKey
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-RestMethod `
        -Uri "$Url/v1/categories" `
        -Method GET `
        -Headers $headers
    
    return $response
}

function Import-OpmlToMiniflux {
    param(
        [string]$Url,
        [string]$ApiKey,
        [string]$OpmlContent
    )
    
    $headers = @{
        "X-Auth-Token" = $ApiKey
        "Content-Type" = "application/xml"
    }
    
    $response = Invoke-RestMethod `
        -Uri "$Url/v1/import" `
        -Method POST `
        -Headers $headers `
        -Body $OpmlContent
    
    return $response
}

# ===========================================
# OPML Parsing
# ===========================================
function Get-OpmlFeedCount {
    param([string]$OpmlPath)
    
    [xml]$opml = Get-Content $OpmlPath -Raw -Encoding UTF8
    
    $feeds = @()
    $categories = @{}
    
    # Find all outline elements with xmlUrl (these are feeds)
    $feedNodes = $opml.SelectNodes("//outline[@xmlUrl]")
    
    foreach ($node in $feedNodes) {
        $parentCategory = $node.ParentNode.GetAttribute("text")
        if (-not $parentCategory) {
            $parentCategory = "Uncategorized"
        }
        
        $feeds += @{
            Title = $node.GetAttribute("text")
            Url = $node.GetAttribute("xmlUrl")
            Category = $parentCategory
        }
        
        if (-not $categories.ContainsKey($parentCategory)) {
            $categories[$parentCategory] = 0
        }
        $categories[$parentCategory]++
    }
    
    return @{
        Feeds = $feeds
        Categories = $categories
        TotalCount = $feeds.Count
    }
}

# ===========================================
# Main Script
# ===========================================
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║         NURA NEURAL - MINIFLUX FEED IMPORTER                 ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

# Resolve OPML file path
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$opmlPath = Join-Path $scriptDir $OpmlFile
if (-not (Test-Path $opmlPath)) {
    # Try absolute path
    if (Test-Path $OpmlFile) {
        $opmlPath = $OpmlFile
    }
    else {
        Write-Error "OPML file not found: $OpmlFile"
        exit 1
    }
}

Write-Host "`nConfiguration:" -ForegroundColor White
Write-Info "OPML File:  $opmlPath"
Write-Info "Dry Run:    $DryRun"

# Get Miniflux URL
$resolvedUrl = Get-MinifluxUrl
if (-not $resolvedUrl) {
    Write-Error "Miniflux URL not provided. Use -MinifluxUrl parameter, Key Vault, or MINIFLUX_URL environment variable."
    exit 1
}
Write-Info "Miniflux:   $resolvedUrl"

# Get API Key
$resolvedApiKey = Get-MinifluxApiKey
if (-not $resolvedApiKey) {
    Write-Error @"
Miniflux API key not found. Provide via:
  - -ApiKey parameter
  - Azure Key Vault (-KeyVaultName with secret '$ApiKeySecretName')
  - Environment variable: MINIFLUX_API_KEY
"@
    exit 1
}

# Test connection
Write-Step "Testing Miniflux Connection"
if (-not (Test-MinifluxConnection -Url $resolvedUrl -ApiKey $resolvedApiKey)) {
    exit 1
}

# Parse OPML
Write-Step "Analyzing OPML File"
$opmlInfo = Get-OpmlFeedCount -OpmlPath $opmlPath

Write-Host "`n  Found $($opmlInfo.TotalCount) feeds in $($opmlInfo.Categories.Count) categories:" -ForegroundColor White
foreach ($cat in $opmlInfo.Categories.GetEnumerator() | Sort-Object Name) {
    Write-Info "    $($cat.Name): $($cat.Value) feeds"
}

# List feeds if requested
if ($ListFeeds) {
    Write-Step "Feed List"
    foreach ($feed in $opmlInfo.Feeds) {
        Write-Host "  [$($feed.Category)] $($feed.Title)" -ForegroundColor White
        Write-Info "    $($feed.Url)"
    }
}

# Get existing feeds
Write-Step "Checking Existing Feeds"
$existingFeeds = Get-MinifluxFeeds -Url $resolvedUrl -ApiKey $resolvedApiKey
$existingUrls = @{}
foreach ($feed in $existingFeeds) {
    $existingUrls[$feed.feed_url] = $feed.title
}
Write-Info "Found $($existingFeeds.Count) existing feeds in Miniflux"

# Count new feeds
$newFeeds = $opmlInfo.Feeds | Where-Object { -not $existingUrls.ContainsKey($_.Url) }
$duplicates = $opmlInfo.Feeds | Where-Object { $existingUrls.ContainsKey($_.Url) }

Write-Host "`n  Analysis:" -ForegroundColor White
Write-Info "    New feeds to import: $($newFeeds.Count)"
Write-Info "    Already existing:    $($duplicates.Count)"

if ($duplicates.Count -gt 0) {
    Write-Host "`n  Skipping duplicates:" -ForegroundColor Yellow
    foreach ($dup in $duplicates | Select-Object -First 5) {
        Write-Warning "    $($dup.Title) (already exists as '$($existingUrls[$dup.Url])')"
    }
    if ($duplicates.Count -gt 5) {
        Write-Warning "    ... and $($duplicates.Count - 5) more"
    }
}

# Dry run check
if ($DryRun) {
    Write-Step "Dry Run Complete"
    Write-Warning "No changes made. Remove -DryRun to import feeds."
    
    if ($newFeeds.Count -gt 0) {
        Write-Host "`n  Would import these feeds:" -ForegroundColor White
        foreach ($feed in $newFeeds | Select-Object -First 10) {
            Write-Info "    [$($feed.Category)] $($feed.Title)"
        }
        if ($newFeeds.Count -gt 10) {
            Write-Info "    ... and $($newFeeds.Count - 10) more"
        }
    }
    exit 0
}

# Import OPML
if ($newFeeds.Count -eq 0) {
    Write-Step "Import Complete"
    Write-Success "All feeds already exist in Miniflux. Nothing to import."
    exit 0
}

Write-Step "Importing Feeds"
Write-Info "Sending OPML to Miniflux..."

try {
    $opmlContent = Get-Content $opmlPath -Raw -Encoding UTF8
    $result = Import-OpmlToMiniflux -Url $resolvedUrl -ApiKey $resolvedApiKey -OpmlContent $opmlContent
    
    Write-Success "OPML import completed!"
    
    # Show results
    if ($result.message) {
        Write-Info "Response: $($result.message)"
    }
}
catch {
    $errorMsg = $_.Exception.Message
    
    # Try to get more details from the response
    if ($_.Exception.Response) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            if ($responseBody) {
                $errorMsg += " - $responseBody"
            }
        }
        catch { }
    }
    
    Write-Error "Import failed: $errorMsg"
    exit 1
}

# Verify import
Write-Step "Verifying Import"
Start-Sleep -Seconds 2  # Give Miniflux time to process

$newFeedList = Get-MinifluxFeeds -Url $resolvedUrl -ApiKey $resolvedApiKey
$newCategories = Get-MinifluxCategories -Url $resolvedUrl -ApiKey $resolvedApiKey

$addedCount = $newFeedList.Count - $existingFeeds.Count

Write-Host "`n  Import Summary:" -ForegroundColor White
Write-Info "    Feeds before:  $($existingFeeds.Count)"
Write-Info "    Feeds after:   $($newFeedList.Count)"
Write-Info "    Feeds added:   $addedCount"
Write-Info "    Categories:    $($newCategories.Count)"

if ($addedCount -gt 0) {
    Write-Success "Successfully imported $addedCount new feeds!"
}
else {
    Write-Warning "No new feeds were added. They may have been duplicates or invalid."
}

# Show recently added feeds
$recentFeeds = $newFeedList | Sort-Object -Property id -Descending | Select-Object -First 5
if ($recentFeeds.Count -gt 0) {
    Write-Host "`n  Recently added feeds:" -ForegroundColor White
    foreach ($feed in $recentFeeds) {
        Write-Info "    $($feed.title) ($($feed.feed_url))"
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✨ Feed import complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor White
Write-Info "  1. Open Miniflux: $resolvedUrl"
Write-Info "  2. Review imported feeds in Categories"
Write-Info "  3. Refresh feeds to fetch initial content"
Write-Info "  4. Check for any feeds with errors"
Write-Host ""
