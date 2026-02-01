<#
.SYNOPSIS
    Imports credentials from Azure Key Vault into n8n

.DESCRIPTION
    Fetches credentials from Azure Key Vault and imports them into n8n
    using the Credentials API. Supports multiple credential types.

.PARAMETER N8nUrl
    Base URL of the n8n instance

.PARAMETER KeyVaultName
    Azure Key Vault name containing the secrets

.PARAMETER ApiKey
    n8n API key (optional - will fetch from Key Vault if not provided)

.PARAMETER DryRun
    Show what would be imported without making changes

.EXAMPLE
    .\import-n8n-credentials.ps1 -KeyVaultName "nura-kv"

.EXAMPLE
    .\import-n8n-credentials.ps1 -KeyVaultName "nura-kv" -DryRun
#>

param(
    [string]$N8nUrl = "https://api.irdecode.com",
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,
    [string]$ApiKey,
    [string]$ApiKeySecretName = "n8n-api-key",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# ===========================================
# Credential Mappings
# ===========================================
# NOTE: Credential names MUST match exactly what workflows expect
# Maps Key Vault secrets to n8n credential format
# ===========================================

# Static values from deployment (non-sensitive)
$PostgresHost = "irdecode-prod-psql.postgres.database.azure.com"
$PostgresDatabase = "nura"
$PostgresUser = "nuraadmin"
$PostgresPort = 5432  # Must be number, not string
$PostgresSsl = "require"

$RedisHost = "nura-redis"
$RedisPort = 6379  # Must be number, not string

$AiSearchEndpoint = "https://nura-search.search.windows.net"
$MinifluxUrl = "https://nura-miniflux.proudbeach-e6523ab9.australiaeast.azurecontainerapps.io"
$AzureOpenAiEndpoint = "https://irdecode-prod-openai.openai.azure.com/"

$CredentialMappings = @(
    # =========================================
    # PostgreSQL - Used by ALL workflows
    # Key Vault secret: postgres-admin-password
    # NOTE: allowUnauthorizedCerts and sshTunnel must be explicitly set
    # =========================================
    @{
        Name            = "Nura PostgreSQL"
        Type            = "postgres"
        KeyVaultSecrets = @{
            password = "postgres-admin-password"
        }
        StaticValues    = @{
            host                    = $PostgresHost
            database                = $PostgresDatabase
            user                    = $PostgresUser
            port                    = $PostgresPort
            ssl                     = $PostgresSsl
            allowUnauthorizedCerts  = $false
            sshTunnel               = $false
        }
    },
    
    # =========================================
    # Redis - Used by 05_public_api for caching
    # No Key Vault secret needed (internal network, no auth)
    # NOTE: n8n schema requires ssl+disableTlsVerification even for non-SSL
    # =========================================
    @{
        Name         = "Nura Redis"
        Type         = "redis"
        StaticValues = @{
            host                   = $RedisHost
            port                   = $RedisPort
            ssl                    = $true   # Required by schema validation
            disableTlsVerification = $true   # Actual connection is internal, no TLS
        }
    },
    
    # =========================================
    # Azure OpenAI - Used by 02, 03, 04 for GPT analysis & embeddings
    # Key Vault secret: ai-services-api-key
    # Uses openAiApi type with Azure endpoint URL
    # NOTE: header must be explicitly false
    # =========================================
    @{
        Name            = "Azure OpenAI"
        Type            = "openAiApi"
        KeyVaultSecrets = @{
            apiKey = "ai-services-api-key"
        }
        StaticValues    = @{
            url    = $AzureOpenAiEndpoint
            header = $false
        }
    },
    
    # =========================================
    # Azure AI Search - Used by 02, 03, 04 for vector search
    # Key Vault secret: nura-search-api-key
    # =========================================
    @{
        Name            = "Azure AI Search"
        Type            = "httpHeaderAuth"
        KeyVaultSecrets = @{
            value = "nura-search-api-key"
        }
        StaticValues    = @{
            name = "api-key"
        }
    },
    
    # =========================================
    # Miniflux API - Used by 01_ingestion for RSS feeds
    # NOTE: Miniflux API key must be generated from Miniflux UI
    # Key Vault secret: miniflux-api-key (must add manually after Miniflux setup)
    # =========================================
    @{
        Name            = "Miniflux API"
        Type            = "httpHeaderAuth"
        KeyVaultSecrets = @{
            value = "miniflux-api-key"
        }
        StaticValues    = @{
            name = "X-Auth-Token"
        }
    },
    
    # =========================================
    # OpenAI (Direct) - Alternative to Azure OpenAI
    # Key Vault secret: openai-api-key
    # NOTE: header must be explicitly false
    # =========================================
    @{
        Name            = "OpenAI"
        Type            = "openAiApi"
        KeyVaultSecrets = @{
            apiKey = "openai-api-key"
        }
        StaticValues    = @{
            header = $false
        }
    }
)

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

function Write-WarningMsg {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Gray
}

# ===========================================
# Azure Key Vault Functions
# ===========================================
function Initialize-AzureKeyVault {
    Write-Step "Initializing Azure Key Vault Connection"
    
    if (-not (Get-Module -ListAvailable -Name Az.KeyVault)) {
        throw "Az.KeyVault module not installed. Install with: Install-Module -Name Az.KeyVault -Scope CurrentUser"
    }
    
    if (-not (Get-Module -Name Az.KeyVault)) {
        Import-Module Az.KeyVault -ErrorAction Stop
    }
    
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Info "Not logged into Azure. Running Connect-AzAccount..."
            Connect-AzAccount
        }
        else {
            Write-Success "Connected to Azure as: $($context.Account.Id)"
        }
    }
    catch {
        Write-Info "Authenticating to Azure..."
        Connect-AzAccount
    }
    
    try {
        $null = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction Stop
        Write-Success "Key Vault '$KeyVaultName' accessible"
    }
    catch {
        throw "Cannot access Key Vault '$KeyVaultName': $($_.Exception.Message)"
    }
}

function Get-KeyVaultSecret {
    param(
        [string]$SecretName,
        [string]$DefaultValue = $null
    )
    
    try {
        $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -AsPlainText -ErrorAction Stop
        return $secret
    }
    catch {
        if ($DefaultValue) {
            return $DefaultValue
        }
        return $null
    }
}

# ===========================================
# n8n API Functions
# ===========================================
function Get-N8nAuthHeaders {
    $headers = @{
        "Content-Type" = "application/json"
        "Accept"       = "application/json"
    }
    
    $resolvedApiKey = $ApiKey
    if (-not $resolvedApiKey) {
        $resolvedApiKey = Get-KeyVaultSecret -SecretName $ApiKeySecretName
    }
    if (-not $resolvedApiKey) {
        $resolvedApiKey = $env:N8N_API_KEY
    }
    
    if (-not $resolvedApiKey) {
        throw "n8n API key not found. Provide via -ApiKey, Key Vault secret '$ApiKeySecretName', or N8N_API_KEY env var"
    }
    
    $headers["X-N8N-API-KEY"] = $resolvedApiKey
    return $headers
}

function Get-ExistingCredentials {
    param([hashtable]$Headers)
    
    try {
        $response = Invoke-RestMethod -Uri "$N8nUrl/api/v1/credentials" -Method GET -Headers $Headers -ErrorAction Stop
        return $response.data
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        
        if ($statusCode -eq 405) {
            Write-WarningMsg "Credentials list endpoint not available (405). Will create without duplicate check."
            return @()
        }
        
        if ($statusCode -eq 401 -or $statusCode -eq 403) {
            throw "Authentication failed. Verify your n8n API key."
        }
        
        Write-WarningMsg "Could not fetch existing credentials. Will attempt to create all."
        return @()
    }
}

function New-N8nCredential {
    param(
        [string]$Name,
        [string]$Type,
        [hashtable]$Data,
        [hashtable]$Headers
    )
    
    $body = @{ name = $Name; type = $Type; data = $Data } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri "$N8nUrl/api/v1/credentials" -Method POST -Headers $Headers -Body $body -ErrorAction Stop
        return $response
    }
    catch {
        # Try to get detailed error message
        $errorResponse = $null
        if ($_.Exception.Response) {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $errorResponse = $reader.ReadToEnd()
            $reader.Close()
        }
        if ($errorResponse) {
            Write-ErrorMsg "API Error: $errorResponse"
        }
        throw "Failed to create credential: $($_.Exception.Message)"
    }
}

function Update-N8nCredential {
    param(
        [string]$CredentialId,
        [string]$Name,
        [string]$Type,
        [hashtable]$Data,
        [hashtable]$Headers
    )
    
    $body = @{ name = $Name; type = $Type; data = $Data } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri "$N8nUrl/api/v1/credentials/$CredentialId" -Method PATCH -Headers $Headers -Body $body -ErrorAction Stop
        return $response
    }
    catch {
        throw "Failed to update credential: $($_.Exception.Message)"
    }
}

# ===========================================
# Import Function
# ===========================================
function Import-SingleCredential {
    param(
        [hashtable]$Mapping,
        [hashtable]$Headers,
        [array]$ExistingCredentials
    )
    
    $credName = $Mapping.Name
    $credType = $Mapping.Type
    
    Write-Host "`n  Processing: $credName ($credType)" -ForegroundColor White
    
    $credData = @{}
    $missingSecrets = @()
    
    # First, add static values (non-sensitive, hardcoded)
    if ($Mapping.StaticValues) {
        foreach ($field in $Mapping.StaticValues.Keys) {
            $credData[$field] = $Mapping.StaticValues[$field]
            Write-Info "    Static: $field = $($Mapping.StaticValues[$field])"
        }
    }
    
    # Then, fetch each required secret from Key Vault
    if ($Mapping.KeyVaultSecrets) {
        foreach ($field in $Mapping.KeyVaultSecrets.Keys) {
            $secretName = $Mapping.KeyVaultSecrets[$field]
            
            $secretValue = Get-KeyVaultSecret -SecretName $secretName
            
            if ($secretValue) {
                $credData[$field] = $secretValue
                Write-Info "    Secret: $field = ******* (from $secretName)"
            }
            else {
                $missingSecrets += $secretName
            }
        }
    }
    
    # Check if we have any data at all
    if ($credData.Count -eq 0) {
        Write-WarningMsg "Skipping '$credName' - no data available"
        return @{ Status = "Skipped"; Reason = "No data" }
    }
    
    # Check if we have missing secrets (but allow if we have static values)
    if ($missingSecrets.Count -gt 0) {
        # If we have ONLY static values and no secrets could be found, that might be OK for some creds
        $hasOnlyStaticValues = ($Mapping.KeyVaultSecrets -eq $null) -or ($Mapping.KeyVaultSecrets.Count -eq 0)
        if (-not $hasOnlyStaticValues) {
            Write-WarningMsg "Skipping '$credName' - missing secrets: $($missingSecrets -join ', ')"
            return @{ Status = "Skipped"; Reason = "Missing secrets: $($missingSecrets -join ', ')" }
        }
    }
    
    # Check if credential already exists
    $existing = $ExistingCredentials | Where-Object { $_.name -eq $credName -and $_.type -eq $credType }
    
    if ($DryRun) {
        if ($existing) {
            Write-Info "[DRY RUN] Would update existing credential: $credName"
        }
        else {
            Write-Info "[DRY RUN] Would create new credential: $credName"
        }
        Write-Info "[DRY RUN] Data fields: $($credData.Keys -join ', ')"
        return @{ Status = "DryRun"; Action = $(if ($existing) { "Update" } else { "Create" }) }
    }
    
    try {
        if ($existing) {
            $null = Update-N8nCredential -CredentialId $existing.id -Name $credName -Type $credType -Data $credData -Headers $Headers
            Write-Success "Updated credential: $credName"
            return @{ Status = "Updated"; Id = $existing.id }
        }
        else {
            $result = New-N8nCredential -Name $credName -Type $credType -Data $credData -Headers $Headers
            Write-Success "Created credential: $credName"
            return @{ Status = "Created"; Id = $result.id }
        }
    }
    catch {
        Write-ErrorMsg "Failed to import '$credName': $($_.Exception.Message)"
        return @{ Status = "Failed"; Error = $_.Exception.Message }
    }
}

# ===========================================
# Main Execution
# ===========================================
function Main {
    Write-Host "`n" -NoNewline
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║           n8n Credential Import from Azure Key Vault          ║" -ForegroundColor Magenta
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    
    if ($DryRun) {
        Write-WarningMsg "DRY RUN MODE - No changes will be made"
    }
    
    # Initialize Azure connection
    Initialize-AzureKeyVault
    
    # Get n8n auth headers
    Write-Step "Connecting to n8n"
    $headers = Get-N8nAuthHeaders
    Write-Success "n8n API key obtained"
    
    # Get existing credentials
    Write-Step "Fetching Existing Credentials"
    $existingCreds = Get-ExistingCredentials -Headers $headers
    Write-Info "Found $($existingCreds.Count) existing credentials in n8n"
    
    # Import each credential
    Write-Step "Importing Credentials"
    
    $results = @{
        Created = 0
        Updated = 0
        Skipped = 0
        Failed  = 0
    }
    
    foreach ($mapping in $CredentialMappings) {
        $result = Import-SingleCredential -Mapping $mapping -Headers $headers -ExistingCredentials $existingCreds
        
        switch ($result.Status) {
            "Created" { $results.Created++ }
            "Updated" { $results.Updated++ }
            "Skipped" { $results.Skipped++ }
            "Failed" { $results.Failed++ }
            "DryRun" { 
                if ($result.Action -eq "Create") { $results.Created++ }
                else { $results.Updated++ }
            }
        }
    }
    
    # Summary
    Write-Step "Import Summary"
    Write-Host "  Created: $($results.Created)" -ForegroundColor Green
    Write-Host "  Updated: $($results.Updated)" -ForegroundColor Cyan
    Write-Host "  Skipped: $($results.Skipped)" -ForegroundColor Yellow
    Write-Host "  Failed:  $($results.Failed)" -ForegroundColor Red
    
    if ($results.Failed -gt 0) {
        Write-Host "`n"
        throw "Some credentials failed to import"
    }
    
    Write-Host "`n✅ Credential import completed successfully!" -ForegroundColor Green
}

# Run main function
Main
