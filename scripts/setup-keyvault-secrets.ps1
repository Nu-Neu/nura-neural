<#
.SYNOPSIS
    Sets up required secrets in Azure Key Vault for Nura Neural

.DESCRIPTION
    Interactive script to populate Azure Key Vault with credentials
    needed for n8n workflows.

.PARAMETER KeyVaultName
    Azure Key Vault name to store secrets

.EXAMPLE
    .\setup-keyvault-secrets.ps1 -KeyVaultName "nura-kv"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName
)

$ErrorActionPreference = "Stop"

# ===========================================
# Secret Definitions
# ===========================================
$SecretGroups = @(
    @{
        Name    = "n8n API"
        Secrets = @(
            @{ Name = "n8n-api-key"; Description = "n8n API key for automation" }
        )
    },
    @{
        Name    = "OpenAI"
        Secrets = @(
            @{ Name = "openai-api-key"; Description = "OpenAI API key" }
        )
    },
    @{
        Name    = "Azure OpenAI"
        Secrets = @(
            @{ Name = "azure-openai-api-key"; Description = "Azure OpenAI API key" }
            @{ Name = "azure-openai-resource"; Description = "Azure OpenAI resource name" }
            @{ Name = "azure-openai-api-version"; Description = "API version (e.g., 2024-02-15-preview)"; Default = "2024-02-15-preview" }
        )
    },
    @{
        Name    = "PostgreSQL"
        Secrets = @(
            @{ Name = "postgres-host"; Description = "PostgreSQL host" }
            @{ Name = "postgres-database"; Description = "Database name" }
            @{ Name = "postgres-user"; Description = "Database user" }
            @{ Name = "postgres-password"; Description = "Database password" }
            @{ Name = "postgres-port"; Description = "Port number"; Default = "5432" }
        )
    },
    @{
        Name    = "Slack"
        Secrets = @(
            @{ Name = "slack-bot-token"; Description = "Slack Bot OAuth token (xoxb-...)" }
            @{ Name = "slack-webhook-url"; Description = "Slack incoming webhook URL" }
        )
    },
    @{
        Name    = "Supabase"
        Secrets = @(
            @{ Name = "supabase-url"; Description = "Supabase project URL" }
            @{ Name = "supabase-service-key"; Description = "Supabase service role key" }
        )
    },
    @{
        Name    = "Redis"
        Secrets = @(
            @{ Name = "redis-host"; Description = "Redis host" }
            @{ Name = "redis-password"; Description = "Redis password" }
            @{ Name = "redis-port"; Description = "Redis port"; Default = "6379" }
        )
    },
    @{
        Name    = "Vector Databases"
        Secrets = @(
            @{ Name = "pinecone-api-key"; Description = "Pinecone API key" }
            @{ Name = "qdrant-url"; Description = "Qdrant server URL" }
            @{ Name = "qdrant-api-key"; Description = "Qdrant API key" }
        )
    }
)

# ===========================================
# Helper Functions
# ===========================================
function Write-Header {
    param([string]$Message)
    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Get-SecureInput {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )
    
    if ($Default) {
        $displayPrompt = "$Prompt [$Default]: "
    }
    else {
        $displayPrompt = "${Prompt}: "
    }
    
    $input = Read-Host -Prompt $displayPrompt
    
    if ([string]::IsNullOrWhiteSpace($input) -and $Default) {
        return $Default
    }
    
    return $input
}

# ===========================================
# Main Execution
# ===========================================
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║         NURA NEURAL - KEY VAULT SECRET SETUP                 ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

# Initialize Azure
Write-Header "Connecting to Azure"

if (-not (Get-Module -ListAvailable -Name Az.KeyVault)) {
    throw "Az.KeyVault module required. Install: Install-Module -Name Az.KeyVault"
}

Import-Module Az.KeyVault -ErrorAction Stop

$context = Get-AzContext
if (-not $context) {
    Connect-AzAccount
}

Write-Host "✅ Connected to Azure" -ForegroundColor Green

# Verify Key Vault
try {
    $kv = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction Stop
    Write-Host "✅ Key Vault '$KeyVaultName' found" -ForegroundColor Green
}
catch {
    throw "Key Vault '$KeyVaultName' not found or not accessible"
}

# Process each group
foreach ($group in $SecretGroups) {
    Write-Header $group.Name
    
    $configure = Read-Host "Configure $($group.Name) secrets? (y/n)"
    if ($configure -ne 'y') {
        Write-Host "  Skipping..." -ForegroundColor Yellow
        continue
    }
    
    foreach ($secret in $group.Secrets) {
        # Check if secret already exists
        $existing = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secret.Name -ErrorAction SilentlyContinue
        
        if ($existing) {
            $overwrite = Read-Host "  Secret '$($secret.Name)' exists. Overwrite? (y/n)"
            if ($overwrite -ne 'y') {
                Write-Host "    Keeping existing value" -ForegroundColor Yellow
                continue
            }
        }
        
        $value = Get-SecureInput -Prompt "  $($secret.Description)" -Default $secret.Default
        
        if ([string]::IsNullOrWhiteSpace($value)) {
            Write-Host "    Skipping (no value provided)" -ForegroundColor Yellow
            continue
        }
        
        # Store secret
        $secureValue = ConvertTo-SecureString $value -AsPlainText -Force
        Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secret.Name -SecretValue $secureValue | Out-Null
        Write-Host "    ✅ Stored: $($secret.Name)" -ForegroundColor Green
    }
}

Write-Header "Setup Complete"
Write-Host "`n✨ Key Vault secrets configured!" -ForegroundColor Green
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "  1. Run credential import: .\import-n8n-credentials.ps1 -KeyVaultName '$KeyVaultName'" -ForegroundColor White
Write-Host "  2. Run workflow import:   .\import-n8n-workflows.ps1 -KeyVaultName '$KeyVaultName'" -ForegroundColor White
Write-Host ""
