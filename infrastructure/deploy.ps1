<#
.SYNOPSIS
    Nura Neural Infrastructure Deployment Script

.DESCRIPTION
    Deploys or updates the Nura Neural infrastructure on Azure using Terraform.
    Supports planning, applying, and destroying infrastructure.

.PARAMETER Environment
    Target environment (dev, beta, prod). Default: dev

.PARAMETER Plan
    Run terraform plan only (no changes applied)

.PARAMETER Apply
    Run terraform plan and apply changes

.PARAMETER Destroy
    Destroy all infrastructure (use with caution!)

.PARAMETER AutoApprove
    Skip interactive approval for apply/destroy

.EXAMPLE
    .\deploy.ps1 -Plan
    # Shows planned changes without applying

.EXAMPLE
    .\deploy.ps1 -Apply
    # Plans and applies infrastructure changes

.EXAMPLE
    .\deploy.ps1 -Apply -AutoApprove
    # Applies without interactive confirmation
#>

param(
    [ValidateSet("dev", "beta", "prod")]
    [string]$Environment = "dev",
    
    [switch]$Plan,
    [switch]$Apply,
    [switch]$Destroy,
    [switch]$AutoApprove,
    [switch]$InitOnly
)

$ErrorActionPreference = "Stop"

# ===========================================
# Configuration
# ===========================================
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

$tfVarsFile = "terraform.tfvars"
$tfPlanFile = "tfplan"

# ===========================================
# Helper Functions
# ===========================================
function Write-Step {
    param([string]$Message)
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $($Message.PadRight(60)) ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
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

function Test-Prerequisites {
    Write-Step "Checking Prerequisites"
    
    # Check Terraform
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        Write-Error "Terraform is not installed. Please install from https://terraform.io"
        exit 1
    }
    $tfVersion = terraform version -json | ConvertFrom-Json
    Write-Success "Terraform $($tfVersion.terraform_version) found"
    
    # Check Azure CLI
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "Azure CLI is not installed. Please install from https://aka.ms/installazurecli"
        exit 1
    }
    Write-Success "Azure CLI found"
    
    # Check terraform.tfvars exists
    if (-not (Test-Path $tfVarsFile)) {
        Write-Error "terraform.tfvars not found!"
        Write-Host "  Copy terraform.tfvars.example to terraform.tfvars and fill in your values." -ForegroundColor Yellow
        exit 1
    }
    Write-Success "terraform.tfvars found"
}

function Test-AzureLogin {
    Write-Step "Checking Azure Authentication"
    
    try {
        $account = az account show 2>$null | ConvertFrom-Json
        if ($account) {
            Write-Success "Logged in as: $($account.user.name)"
            Write-Success "Subscription: $($account.name) ($($account.id))"
            return $true
        }
    }
    catch {
        # Not logged in
    }
    
    Write-Warning "Not logged in to Azure. Initiating login..."
    az login
    
    $account = az account show | ConvertFrom-Json
    if (-not $account) {
        Write-Error "Azure login failed"
        exit 1
    }
    Write-Success "Logged in as: $($account.user.name)"
}

function Initialize-Terraform {
    Write-Step "Initializing Terraform"
    
    # Clean up old state lock files if present
    if (Test-Path ".terraform.lock.hcl") {
        Write-Host "  Lock file exists, will upgrade if needed..."
    }
    
    terraform init -upgrade
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform init failed"
        exit 1
    }
    Write-Success "Terraform initialized"
}

function Invoke-TerraformPlan {
    Write-Step "Planning Infrastructure Changes"
    
    terraform plan -var-file="$tfVarsFile" -out="$tfPlanFile" -detailed-exitcode
    
    $exitCode = $LASTEXITCODE
    
    switch ($exitCode) {
        0 { 
            Write-Success "No changes required - infrastructure is up to date"
            return $false 
        }
        1 { 
            Write-Error "Terraform plan failed with errors"
            exit 1 
        }
        2 { 
            Write-Success "Changes detected - plan saved to $tfPlanFile"
            return $true 
        }
    }
}

function Invoke-TerraformApply {
    param([bool]$HasChanges)
    
    if (-not $HasChanges) {
        Write-Warning "No changes to apply"
        return
    }
    
    Write-Step "Applying Infrastructure Changes"
    
    if ($AutoApprove) {
        terraform apply "$tfPlanFile"
    }
    else {
        Write-Host "`nReview the plan above. Do you want to apply these changes?" -ForegroundColor Yellow
        $confirm = Read-Host "Type 'yes' to confirm"
        
        if ($confirm -eq "yes") {
            terraform apply "$tfPlanFile"
        }
        else {
            Write-Warning "Apply cancelled by user"
            return
        }
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform apply failed"
        exit 1
    }
    
    Write-Success "Infrastructure deployed successfully!"
}

function Invoke-TerraformDestroy {
    Write-Step "DESTROYING Infrastructure"
    
    Write-Host "`n⚠️  WARNING: This will destroy ALL Nura Neural infrastructure!" -ForegroundColor Red
    Write-Host "  - Azure AI Search service" -ForegroundColor Red
    Write-Host "  - Container Apps (Redis, RSSHub, Miniflux, SMRY)" -ForegroundColor Red
    Write-Host "  - PostgreSQL databases (miniflux, nura)" -ForegroundColor Red
    Write-Host "  - Blob containers and all stored content" -ForegroundColor Red
    Write-Host "  - Key Vault secrets" -ForegroundColor Red
    
    if (-not $AutoApprove) {
        Write-Host "`nAre you absolutely sure you want to destroy everything?" -ForegroundColor Yellow
        $confirm = Read-Host "Type 'destroy' to confirm"
        
        if ($confirm -ne "destroy") {
            Write-Warning "Destroy cancelled by user"
            return
        }
    }
    
    terraform destroy -var-file="$tfVarsFile" -auto-approve
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform destroy failed"
        exit 1
    }
    
    Write-Success "Infrastructure destroyed"
}

function Show-Outputs {
    Write-Step "Deployment Outputs"
    
    terraform output
    
    Write-Host "`n" -NoNewline
    Write-Step "Next Steps"
    Write-Host "  1. Configure n8n credentials using the outputs above" -ForegroundColor White
    Write-Host "  2. Add RSS feeds to Miniflux" -ForegroundColor White
    Write-Host "  3. Create Azure AI Search indexes (run create-search-indexes.ps1)" -ForegroundColor White
    Write-Host "  4. Import n8n workflows from workflows/*.json" -ForegroundColor White
    Write-Host "  5. Run end-to-end tests" -ForegroundColor White
}

# ===========================================
# Main Execution
# ===========================================
Write-Host "`n"
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║           NURA NEURAL - INFRASTRUCTURE DEPLOYMENT            ║" -ForegroundColor Magenta
Write-Host "║                    Environment: $($Environment.ToUpper().PadRight(27))      ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

# Validate parameters
if (-not $Plan -and -not $Apply -and -not $Destroy -and -not $InitOnly) {
    Write-Host "`nUsage:" -ForegroundColor Yellow
    Write-Host "  .\deploy.ps1 -Plan          # Show planned changes"
    Write-Host "  .\deploy.ps1 -Apply         # Apply changes"
    Write-Host "  .\deploy.ps1 -Destroy       # Destroy infrastructure"
    Write-Host "  .\deploy.ps1 -InitOnly      # Initialize Terraform only"
    Write-Host "`nOptions:"
    Write-Host "  -Environment [dev|beta|prod]  # Target environment"
    Write-Host "  -AutoApprove                  # Skip confirmation prompts"
    exit 0
}

# Run deployment steps
Test-Prerequisites
Test-AzureLogin
Initialize-Terraform

if ($InitOnly) {
    Write-Success "Terraform initialization complete"
    exit 0
}

if ($Destroy) {
    Invoke-TerraformDestroy
    exit 0
}

$hasChanges = Invoke-TerraformPlan

if ($Apply) {
    Invoke-TerraformApply -HasChanges $hasChanges
    Show-Outputs
}

# Cleanup plan file
if (Test-Path $tfPlanFile) {
    Remove-Item $tfPlanFile -Force
}

Write-Host "`n✨ Done!`n" -ForegroundColor Green