<#
.SYNOPSIS
    Tests n8n API connectivity and available endpoints

.PARAMETER N8nUrl
    Base URL of the n8n instance

.PARAMETER ApiKey
    n8n API key

.EXAMPLE
    .\test-n8n-api.ps1 -N8nUrl "https://api.irdecode.com" -ApiKey "your-key"
#>

param(
    [string]$N8nUrl = "https://api.irdecode.com",
    [string]$ApiKey
)

$ErrorActionPreference = "Continue"

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              N8N API DIAGNOSTIC TEST                         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`nTarget: $N8nUrl`n" -ForegroundColor Yellow

# Build headers
$headers = @{
    "Content-Type" = "application/json"
    "Accept"       = "application/json"
}

if ($ApiKey) {
    $headers["X-N8N-API-KEY"] = $ApiKey
}

# Test endpoints
$endpoints = @(
    @{ Method = "GET"; Path = "/healthz"; Desc = "Health check" },
    @{ Method = "GET"; Path = "/api/v1/workflows"; Desc = "Workflows (API v1)" },
    @{ Method = "GET"; Path = "/api/v1/credentials"; Desc = "Credentials (API v1)" },
    @{ Method = "GET"; Path = "/api/v1/credentials/schema"; Desc = "Credential schemas (API v1)" },
    @{ Method = "GET"; Path = "/rest/workflows"; Desc = "Workflows (REST)" },
    @{ Method = "GET"; Path = "/rest/credentials"; Desc = "Credentials (REST)" },
    @{ Method = "GET"; Path = "/api/v1/audit"; Desc = "Audit (Enterprise)" }
)

foreach ($ep in $endpoints) {
    $url = "$N8nUrl$($ep.Path)"
    Write-Host "Testing: $($ep.Method) $($ep.Path)" -ForegroundColor White -NoNewline
    Write-Host " ($($ep.Desc))" -ForegroundColor Gray
    
    try {
        $response = Invoke-WebRequest `
            -Uri $url `
            -Method $ep.Method `
            -Headers $headers `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        Write-Host "  ✅ $($response.StatusCode) - OK" -ForegroundColor Green
        
        # Show sample response for successful calls
        if ($response.Content) {
            try {
                $json = $response.Content | ConvertFrom-Json
                if ($json.data) {
                    Write-Host "     Items: $($json.data.Count)" -ForegroundColor Gray
                }
            }
            catch { }
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $statusDesc = $_.Exception.Response.StatusDescription
        
        if ($statusCode) {
            $color = switch ($statusCode) {
                401 { "Red" }
                403 { "Red" }
                404 { "Yellow" }
                405 { "Yellow" }
                default { "Red" }
            }
            Write-Host "  ❌ $statusCode - $statusDesc" -ForegroundColor $color
        }
        else {
            Write-Host "  ❌ Connection failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n─────────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 200/201: Endpoint works" -ForegroundColor Green
Write-Host "  - 401/403: Authentication issue - check API key" -ForegroundColor Red
Write-Host "  - 404: Endpoint doesn't exist in this n8n version" -ForegroundColor Yellow
Write-Host "  - 405: Method not allowed - different API structure" -ForegroundColor Yellow
Write-Host ""

# Check n8n version if possible
Write-Host "Checking n8n version..." -ForegroundColor White
try {
    $versionResponse = Invoke-RestMethod -Uri "$N8nUrl/api/v1/audit" -Method GET -Headers $headers -ErrorAction SilentlyContinue
}
catch {
    # Try to get version from response headers or other means
    try {
        $healthResponse = Invoke-WebRequest -Uri "$N8nUrl/healthz" -Method GET -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($healthResponse.Headers["X-n8n-Version"]) {
            Write-Host "  n8n Version: $($healthResponse.Headers["X-n8n-Version"])" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "  Could not determine n8n version" -ForegroundColor Gray
    }
}

Write-Host "`nRecommendations:" -ForegroundColor Yellow
Write-Host "  1. Ensure API is enabled in n8n settings" -ForegroundColor White
Write-Host "  2. Generate API key: Settings > API > Create API Key" -ForegroundColor White
Write-Host "  3. For self-hosted: Set N8N_PUBLIC_API_DISABLED=false" -ForegroundColor White
Write-Host ""
