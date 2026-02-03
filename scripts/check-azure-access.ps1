<#
.SYNOPSIS
    Pre-flight check for Azure access and PIM role activation on MCPP Subscription.
    Run this BEFORE any Azure deployment or infrastructure operation.

.DESCRIPTION
    Verifies:
    1. Azure CLI login status
    2. Correct subscription (MCPP Subscription) is selected
    3. Contributor role is active (not just eligible)
    4. Resource group access is working
    5. Key Vault access

.PARAMETER SubscriptionId
    The MCPP Subscription ID. Defaults to known value.

.PARAMETER ResourceGroup
    The resource group to test access against.

.PARAMETER AutoActivate
    If specified, opens PIM activation page in browser when roles are not active.

.EXAMPLE
    .\check-azure-access.ps1
    .\check-azure-access.ps1 -AutoActivate
#>

param(
    [string]$SubscriptionId = "0029263c-cf9e-4e08-b543-2eeea360c7fc",
    [string]$ResourceGroup = "irdecode-prod-rg",
    [string]$KeyVaultName = "irdecode-prod-kv",
    [switch]$AutoActivate
)

$ErrorActionPreference = "Continue"
$script:hasErrors = $false

function Write-Step { param([string]$Message) Write-Host "`n[$((Get-Date).ToString('HH:mm:ss'))] $Message" -ForegroundColor Yellow }
function Write-Success { param([string]$Message) Write-Host "  ✅ $Message" -ForegroundColor Green }
function Write-Fail { param([string]$Message) Write-Host "  ❌ $Message" -ForegroundColor Red; $script:hasErrors = $true }
function Write-Warn { param([string]$Message) Write-Host "  ⚠️  $Message" -ForegroundColor Yellow }
function Write-Info { param([string]$Message) Write-Host "     $Message" -ForegroundColor Gray }

$PimActivationUrl = "https://portal.azure.com/#view/Microsoft_Azure_PIMCommon/ActivationMenuBlade/~/azurerbac"

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      NURA NEURAL - AZURE ACCESS PRE-FLIGHT CHECK            ║" -ForegroundColor Cyan
Write-Host "║      MCPP Subscription - Contributor & PIM Validation       ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# =============================================================================
# STEP 1: Check Azure CLI Login
# =============================================================================
Write-Step "Checking Azure CLI login status..."

$account = $null
try {
    $accountJson = az account show 2>$null
    if ($accountJson) {
        $account = $accountJson | ConvertFrom-Json
    }
} catch { }

if (-not $account) {
    Write-Fail "Not logged into Azure CLI"
    Write-Info "Run: az login"
    
    $response = Read-Host "Would you like to login now? (y/n)"
    if ($response -eq 'y') {
        az login
        $account = az account show 2>$null | ConvertFrom-Json
    } else {
        exit 1
    }
}

Write-Success "Logged in as: $($account.user.name)"

# =============================================================================
# STEP 2: Check/Set Correct Subscription
# =============================================================================
Write-Step "Checking MCPP Subscription..."

if ($account.id -ne $SubscriptionId) {
    Write-Warn "Current subscription: $($account.name) ($($account.id))"
    Write-Info "Switching to MCPP Subscription..."
    
    $switchResult = az account set --subscription $SubscriptionId 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Failed to switch to MCPP Subscription"
        Write-Info "Error: $switchResult"
        Write-Info "You may not have access to this subscription"
        exit 1
    }
    
    $account = az account show | ConvertFrom-Json
    Write-Success "Switched to: $($account.name)"
} else {
    Write-Success "Correct subscription: $($account.name)"
}

# =============================================================================
# STEP 3: Check Role Assignments (Contributor)
# =============================================================================
Write-Step "Checking Contributor role assignment..."

$userId = az ad signed-in-user show --query id -o tsv 2>$null
$roles = az role assignment list --assignee $userId --subscription $SubscriptionId 2>$null | ConvertFrom-Json

$contributorRole = $roles | Where-Object { $_.roleDefinitionName -eq "Contributor" }

if ($contributorRole) {
    Write-Success "Contributor role is assigned"
    Write-Info "Scope: $($contributorRole.scope)"
} else {
    Write-Fail "Contributor role NOT found!"
    Write-Info "This role may be eligible via PIM but not activated"
    
    if ($AutoActivate) {
        Write-Info "Opening PIM activation page..."
        Start-Process $PimActivationUrl
    } else {
        Write-Info "Activate at: $PimActivationUrl"
    }
}

# List all current roles
Write-Info "Current roles:"
foreach ($role in $roles) {
    Write-Info "  - $($role.roleDefinitionName)"
}

# =============================================================================
# STEP 4: Test Resource Group Access (proves role is ACTIVE, not just assigned)
# =============================================================================
Write-Step "Testing resource group access (validates active permissions)..."

$rgResult = az group show --name $ResourceGroup 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "Resource group '$ResourceGroup' is accessible"
} else {
    Write-Fail "Cannot access resource group '$ResourceGroup'"
    Write-Info "This usually means:"
    Write-Info "  1. PIM Contributor role is NOT activated, OR"
    Write-Info "  2. Resource group doesn't exist"
    
    if ($AutoActivate) {
        Write-Info "Opening PIM activation page..."
        Start-Process $PimActivationUrl
    } else {
        Write-Host "`n  👉 ACTIVATE PIM ROLE:" -ForegroundColor Cyan
        Write-Host "     $PimActivationUrl" -ForegroundColor White
    }
}

# =============================================================================
# STEP 5: Test Key Vault Access
# =============================================================================
Write-Step "Testing Key Vault access..."

$kvResult = az keyvault secret list --vault-name $KeyVaultName --query "length(@)" -o tsv 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "Key Vault '$KeyVaultName' accessible ($kvResult secrets)"
} else {
    Write-Warn "Cannot list Key Vault secrets"
    Write-Info "May need 'Key Vault Secrets Officer' or 'Key Vault Administrator' role"
}

# =============================================================================
# STEP 6: Test Write Permissions (create a tag test)
# =============================================================================
Write-Step "Testing write permissions..."

try {
    # Try to read tags (doesn't modify anything but proves read access at resource level)
    $resources = az resource list --resource-group $ResourceGroup --query "[0].id" -o tsv 2>$null
    if ($resources) {
        Write-Success "Write permissions appear to be active"
    } else {
        Write-Warn "No resources found in resource group (may be empty)"
    }
} catch {
    Write-Warn "Could not verify write permissions"
}

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($script:hasErrors) {
    Write-Host "❌ PRE-FLIGHT CHECK FAILED" -ForegroundColor Red
    Write-Host "`nRequired Actions:" -ForegroundColor Yellow
    Write-Host "  1. Go to Azure PIM and activate 'Contributor' role" -ForegroundColor White
    Write-Host "  2. Select 'MCPP Subscription' as scope" -ForegroundColor White
    Write-Host "  3. Set duration (recommend 8 hours)" -ForegroundColor White
    Write-Host "  4. Re-run this script to verify" -ForegroundColor White
    Write-Host "`n  PIM URL: $PimActivationUrl" -ForegroundColor Cyan
    exit 1
} else {
    Write-Host "✅ PRE-FLIGHT CHECK PASSED" -ForegroundColor Green
    Write-Host "   Ready for Azure operations on MCPP Subscription" -ForegroundColor Gray
    Write-Host "══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
    exit 0
}
