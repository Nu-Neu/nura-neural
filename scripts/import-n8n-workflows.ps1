<#
.SYNOPSIS
    Imports Nura Neural workflows into n8n

.DESCRIPTION
    Imports all workflow JSON files from the workflows/ directory into the n8n instance.
    Supports both API key and basic authentication methods.
    Can fetch API key securely from Azure Key Vault or environment variables.

.PARAMETER N8nUrl
    Base URL of the n8n instance (without trailing slash)

.PARAMETER ApiKey
    n8n API key for authentication (optional - will fetch from Key Vault or env var if not provided)

.PARAMETER KeyVaultName
    Azure Key Vault name to fetch secrets from (optional)

.PARAMETER ApiKeySecretName
    Name of the secret in Key Vault containing the n8n API key (default: n8n-api-key)

.PARAMETER Username
    n8n username for Basic Auth (optional if using API key)

.PARAMETER Password
    n8n password for Basic Auth (optional if using API key)

.PARAMETER WorkflowDir
    Directory containing workflow JSON files (default: ../workflows)

.PARAMETER Activate
    Automatically activate workflows after import

.EXAMPLE
    .\import-n8n-workflows.ps1 -KeyVaultName "nura-kv" -Activate

.EXAMPLE
    .\import-n8n-workflows.ps1 -N8nUrl "https://api.irdecode.com" -ApiKey "your-api-key"

.EXAMPLE
    .\import-n8n-workflows.ps1 -N8nUrl "https://api.irdecode.com" -Username "admin" -Password "secret" -Activate
#>

param(
    [string]$N8nUrl = "https://api.irdecode.com",
    
    [string]$ApiKey,
    [string]$KeyVaultName,
    [string]$ApiKeySecretName = "n8n-api-key",
    [string]$Username,
    [string]$Password,
    
    [string]$WorkflowDir = "../workflows",
    [switch]$Activate,
    [switch]$DryRun
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

# ===========================================
# Secure Secret Retrieval
# ===========================================
function Get-SecretFromKeyVault {
    param(
        [string]$VaultName,
        [string]$SecretName
    )
    
    try {
        Write-Host "  Fetching secret '$SecretName' from Azure Key Vault '$VaultName'..." -ForegroundColor Gray
        
        # Check if Az module is available
        if (-not (Get-Module -ListAvailable -Name Az.KeyVault)) {
            Write-Warning "Az.KeyVault module not installed. Install with: Install-Module -Name Az.KeyVault"
            return $null
        }
        
        # Import module if not loaded
        if (-not (Get-Module -Name Az.KeyVault)) {
            Import-Module Az.KeyVault -ErrorAction Stop
        }
        
        # Get secret from Key Vault
        $secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -AsPlainText -ErrorAction Stop
        Write-Success "  Retrieved secret from Key Vault"
        return $secret
    }
    catch {
        Write-Warning "  Failed to retrieve secret from Key Vault: $($_.Exception.Message)"
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
    
    if ($envValue) {
        Write-Host "  Retrieved secret from environment variable '$EnvVarName'" -ForegroundColor Gray
    }
    
    return $envValue
}

function Get-N8nApiKey {
    # 1. Use explicitly provided API key
    if ($script:ApiKey) {
        Write-Host "  Using provided API key" -ForegroundColor Gray
        return $script:ApiKey
    }
    
    # 2. Try Azure Key Vault
    if ($script:KeyVaultName) {
        $kvSecret = Get-SecretFromKeyVault -VaultName $script:KeyVaultName -SecretName $script:ApiKeySecretName
        if ($kvSecret) {
            return $kvSecret
        }
    }
    
    # 3. Try environment variables (multiple common naming conventions)
    $envVarNames = @("N8N_API_KEY", "N8N_APIKEY", "NURA_N8N_API_KEY")
    foreach ($envVar in $envVarNames) {
        $envSecret = Get-SecretFromEnvironment -EnvVarName $envVar
        if ($envSecret) {
            return $envSecret
        }
    }
    
    return $null
}

# ===========================================
# Build Authentication Headers
# ===========================================
function Get-AuthHeaders {
    $headers = @{
        "Content-Type" = "application/json"
        "Accept"       = "application/json"
    }
    
    # Try to get API key from secure sources
    $resolvedApiKey = Get-N8nApiKey
    
    if ($resolvedApiKey) {
        $headers["X-N8N-API-KEY"] = $resolvedApiKey
        Write-Host "  Using API Key authentication" -ForegroundColor Gray
    }
    elseif ($Username -and $Password) {
        $base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${Password}"))
        $headers["Authorization"] = "Basic $base64Auth"
        Write-Host "  Using Basic authentication" -ForegroundColor Gray
    }
    else {
        throw @"
Authentication required. Provide one of the following:
  - API Key via -ApiKey parameter
  - Azure Key Vault via -KeyVaultName parameter (secret name: $ApiKeySecretName)
  - Environment variable: N8N_API_KEY
  - Basic Auth via -Username and -Password parameters
"@
    }
    
    return $headers
}

# ===========================================
# Test n8n Connection
# ===========================================
function Test-N8nConnection {
    param($Headers)
    
    Write-Step "Testing n8n Connection"
    
    try {
        $response = Invoke-RestMethod `
            -Uri "$N8nUrl/api/v1/workflows" `
            -Method GET `
            -Headers $Headers `
            -TimeoutSec 30
        
        Write-Success "Connected to n8n successfully"
        Write-Host "  Found $($response.data.Count) existing workflows" -ForegroundColor Gray
        return $true
    }
    catch {
        Write-Error "Failed to connect to n8n: $($_.Exception.Message)"
        Write-Host "  URL: $N8nUrl" -ForegroundColor Gray
        Write-Host "  Verify the URL and credentials are correct" -ForegroundColor Gray
        return $false
    }
}

# ===========================================
# Import Single Workflow
# ===========================================
function Import-Workflow {
    param(
        [string]$FilePath,
        [hashtable]$Headers
    )
    
    $fileName = Split-Path $FilePath -Leaf
    
    try {
        # Read workflow JSON
        $workflowJson = Get-Content $FilePath -Raw -Encoding UTF8
        $workflow = $workflowJson | ConvertFrom-Json
        
        Write-Host "  Importing: $fileName" -ForegroundColor White
        Write-Host "    Name: $($workflow.name)" -ForegroundColor Gray
        
        if ($DryRun) {
            Write-Host "    [DRY RUN] Would import workflow" -ForegroundColor Yellow
            return @{ success = $true; id = "dry-run"; name = $workflow.name }
        }
        
        # Strip fields not allowed by n8n API for creation/update
        # n8n API rejects: staticData, tags, triggerCount, updatedAt, versionId, createdAt, id
        $cleanWorkflow = @{
            name        = $workflow.name
            nodes       = $workflow.nodes
            connections = $workflow.connections
            settings    = $workflow.settings
        }
        # Re-serialize to clean JSON
        $cleanWorkflowJson = $cleanWorkflow | ConvertTo-Json -Depth 50 -Compress
        
        # Check if workflow already exists by name
        $existingWorkflows = Invoke-RestMethod `
            -Uri "$N8nUrl/api/v1/workflows" `
            -Method GET `
            -Headers $Headers
        
        $existing = $existingWorkflows.data | Where-Object { $_.name -eq $workflow.name }
        
        if ($existing) {
            Write-Warning "    Workflow '$($workflow.name)' already exists (ID: $($existing.id))"
            Write-Host "    Updating existing workflow..." -ForegroundColor Gray
            
            # Update existing workflow
            $response = Invoke-RestMethod `
                -Uri "$N8nUrl/api/v1/workflows/$($existing.id)" `
                -Method PUT `
                -Headers $Headers `
                -Body $cleanWorkflowJson
            
            Write-Success "    Updated: $($response.name) (ID: $($response.id))"
            return @{ success = $true; id = $response.id; name = $response.name; updated = $true }
        }
        else {
            # Create new workflow
            $response = Invoke-RestMethod `
                -Uri "$N8nUrl/api/v1/workflows" `
                -Method POST `
                -Headers $Headers `
                -Body $cleanWorkflowJson
            
            Write-Success "    Created: $($response.name) (ID: $($response.id))"
            return @{ success = $true; id = $response.id; name = $response.name; updated = $false }
        }
    }
    catch {
        Write-Error "    Failed to import $fileName`: $($_.Exception.Message)"
        return @{ success = $false; error = $_.Exception.Message }
    }
}

# ===========================================
# Activate Workflow
# ===========================================
function Enable-Workflow {
    param(
        [string]$WorkflowId,
        [hashtable]$Headers
    )
    
    try {
        $response = Invoke-RestMethod `
            -Uri "$N8nUrl/api/v1/workflows/$WorkflowId/activate" `
            -Method POST `
            -Headers $Headers
        
        return $true
    }
    catch {
        Write-Warning "    Failed to activate workflow: $($_.Exception.Message)"
        return $false
    }
}

# ===========================================
# Main Execution
# ===========================================
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║           NURA NEURAL - N8N WORKFLOW IMPORTER                ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

# Resolve workflow directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$workflowPath = Join-Path $scriptPath $WorkflowDir | Resolve-Path -ErrorAction SilentlyContinue

if (-not $workflowPath) {
    $workflowPath = Resolve-Path $WorkflowDir -ErrorAction SilentlyContinue
}

if (-not $workflowPath -or -not (Test-Path $workflowPath)) {
    Write-Error "Workflow directory not found: $WorkflowDir"
    exit 1
}

Write-Host "`nConfiguration:" -ForegroundColor Yellow
Write-Host "  n8n URL:      $N8nUrl"
Write-Host "  Workflow Dir: $workflowPath"
Write-Host "  Activate:     $Activate"
Write-Host "  Dry Run:      $DryRun"

# Build authentication headers
$headers = Get-AuthHeaders

# Test connection
if (-not (Test-N8nConnection -Headers $headers)) {
    exit 1
}

# Get workflow files in order
$workflowFiles = @(
    "01_ingestion.json",
    "02_agent_source.json",
    "03_agent_narrative.json",
    "04_escalation.json",
    "05_public_api.json"
)

Write-Step "Importing Workflows"

$results = @()
$imported = 0
$updated = 0
$failed = 0

foreach ($file in $workflowFiles) {
    $filePath = Join-Path $workflowPath $file
    
    if (Test-Path $filePath) {
        $result = Import-Workflow -FilePath $filePath -Headers $headers
        $results += $result
        
        if ($result.success) {
            if ($result.updated) {
                $updated++
            }
            else {
                $imported++
            }
            
            # Activate if requested
            if ($Activate -and $result.id -and -not $DryRun) {
                Write-Host "    Activating workflow..." -ForegroundColor Gray
                if (Enable-Workflow -WorkflowId $result.id -Headers $headers) {
                    Write-Success "    Workflow activated"
                }
            }
        }
        else {
            $failed++
        }
    }
    else {
        Write-Warning "  Workflow file not found: $file"
        $failed++
    }
}

# ===========================================
# Summary
# ===========================================
Write-Step "Import Summary"

Write-Host "  New workflows imported: $imported" -ForegroundColor $(if ($imported -gt 0) { "Green" } else { "Gray" })
Write-Host "  Existing workflows updated: $updated" -ForegroundColor $(if ($updated -gt 0) { "Yellow" } else { "Gray" })
Write-Host "  Failed imports: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Gray" })

if ($failed -eq 0) {
    Write-Host "`n✨ All workflows imported successfully!" -ForegroundColor Green
}
else {
    Write-Host "`n⚠️  Some workflows failed to import. Check errors above." -ForegroundColor Yellow
}

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "  1. Open n8n UI: $N8nUrl" -ForegroundColor White
Write-Host "  2. Configure credentials for each workflow" -ForegroundColor White
Write-Host "  3. Test each workflow manually" -ForegroundColor White
Write-Host "  4. Activate production workflows" -ForegroundColor White
Write-Host ""