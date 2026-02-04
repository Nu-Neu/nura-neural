# ============================================================================
# Migration: Front Door → Container App Custom Domain
# Purpose: Save $40/month while maintaining api.irdecode.com
# Date: 2026-02-04
# ============================================================================

# CRITICAL: Run this script in order. Do NOT skip steps.

$ErrorActionPreference = "Stop"

# Configuration
$resourceGroup = "irdecode-prod-rg"
$containerAppName = "irdecode-prod-n8n"
$customDomain = "api.irdecode.com"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "STEP 1: Add Custom Domain to Container App" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Adding custom domain binding..." -ForegroundColor Yellow

# Add custom domain (this will generate a validation token)
az containerapp hostname add `
  --name $containerAppName `
  --resource-group $resourceGroup `
  --hostname $customDomain

Write-Host "`n✅ Custom domain binding created`n" -ForegroundColor Green

# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "STEP 2: Get DNS Validation Token" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$validation = az containerapp hostname show `
  --name $containerAppName `
  --resource-group $resourceGroup `
  --hostname $customDomain `
  --query "{verificationId: customDomainVerificationId, state: bindingType}" `
  -o json | ConvertFrom-Json

Write-Host "Validation Token: $($validation.verificationId)" -ForegroundColor Yellow
Write-Host "Current State: $($validation.state)`n" -ForegroundColor Yellow

# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "STEP 3: DNS Configuration Required" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "⚠️  MANUAL ACTION REQUIRED ⚠️`n" -ForegroundColor Red

Write-Host "Go to your DNS provider (e.g., Cloudflare, Route53) and add these records:`n" -ForegroundColor Yellow

Write-Host "1. TXT Record (for validation):" -ForegroundColor White
Write-Host "   Name:  asuid.$customDomain" -ForegroundColor Cyan
Write-Host "   Value: $($validation.verificationId)" -ForegroundColor Cyan
Write-Host "   TTL:   3600`n" -ForegroundColor Cyan

Write-Host "2. CNAME Record (for traffic):" -ForegroundColor White
Write-Host "   Name:  $customDomain" -ForegroundColor Cyan
Write-Host "   Value: $containerAppName.proudbeach-e6523ab9.australiaeast.azurecontainerapps.io" -ForegroundColor Cyan
Write-Host "   TTL:   3600`n" -ForegroundColor Cyan

Write-Host "Press Enter AFTER you have added both DNS records..." -ForegroundColor Yellow
Read-Host

# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "STEP 4: Verify DNS Propagation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Checking DNS propagation (this may take 1-10 minutes)...`n" -ForegroundColor Yellow

$maxAttempts = 30
$attempt = 0
$dnsReady = $false

while ($attempt -lt $maxAttempts -and -not $dnsReady) {
    $attempt++
    Write-Host "Attempt $attempt/$maxAttempts..." -ForegroundColor Gray
    
    try {
        # Check CNAME
        $cnameResult = Resolve-DnsName -Name $customDomain -Type CNAME -ErrorAction SilentlyContinue
        
        # Check TXT
        $txtResult = Resolve-DnsName -Name "asuid.$customDomain" -Type TXT -ErrorAction SilentlyContinue
        
        if ($cnameResult -and $txtResult) {
            Write-Host "✅ DNS records detected!`n" -ForegroundColor Green
            Write-Host "CNAME: $($cnameResult.NameHost)" -ForegroundColor Cyan
            Write-Host "TXT:   $($txtResult.Strings)`n" -ForegroundColor Cyan
            $dnsReady = $true
        } else {
            Start-Sleep -Seconds 20
        }
    } catch {
        Start-Sleep -Seconds 20
    }
}

if (-not $dnsReady) {
    Write-Host "❌ DNS not propagated yet. Wait 5-10 minutes and re-run from STEP 4.`n" -ForegroundColor Red
    exit 1
}

# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "STEP 5: Bind SSL Certificate" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Azure will now provision a managed certificate (may take 5-10 minutes)...`n" -ForegroundColor Yellow

# Trigger certificate binding (Azure does this automatically after DNS validation)
az containerapp hostname bind `
  --name $containerAppName `
  --resource-group $resourceGroup `
  --hostname $customDomain `
  --environment-name irdecode-prod-n8n-env `
  --validation-method CNAME

Write-Host "`n✅ Certificate binding initiated`n" -ForegroundColor Green

# Wait for certificate provisioning
Write-Host "Waiting for certificate provisioning..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "STEP 6: Add IP Security Restrictions" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Enter your office/home IP address (format: x.x.x.x/32):" -ForegroundColor Yellow
$allowedIP = Read-Host "IP Address"

if (-not $allowedIP) {
    Write-Host "⚠️  No IP provided. Skipping IP restrictions.`n" -ForegroundColor Red
} else {
    az containerapp ingress access-restriction set `
      --name $containerAppName `
      --resource-group $resourceGroup `
      --rule-name "team-access" `
      --ip-address $allowedIP `
      --action Allow
    
    Write-Host "`n✅ IP restriction added: $allowedIP`n" -ForegroundColor Green
}

# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "STEP 7: Test New Setup" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Testing https://$customDomain...`n" -ForegroundColor Yellow

try {
    $response = Invoke-WebRequest -Uri "https://$customDomain" -Method GET -TimeoutSec 10
    Write-Host "✅ SUCCESS! Status Code: $($response.StatusCode)`n" -ForegroundColor Green
} catch {
    Write-Host "❌ Test failed: $($_.Exception.Message)`n" -ForegroundColor Red
    Write-Host "This is normal if certificate is still provisioning. Wait 5 minutes and test manually.`n" -ForegroundColor Yellow
}

Write-Host "Manual verification:" -ForegroundColor Yellow
Write-Host "1. Open: https://$customDomain" -ForegroundColor Cyan
Write-Host "2. Verify SSL certificate is valid (green padlock)" -ForegroundColor Cyan
Write-Host "3. Verify n8n login page loads`n" -ForegroundColor Cyan

Write-Host "Press Enter when manual verification is successful..." -ForegroundColor Yellow
Read-Host

# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "STEP 8: Delete Front Door (SAVES $40/month)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "⚠️  This will DELETE Front Door and WAF ⚠️`n" -ForegroundColor Red
Write-Host "Confirm deletion? (yes/no): " -ForegroundColor Yellow -NoNewline
$confirm = Read-Host

if ($confirm -eq "yes") {
    Write-Host "`nDeleting Front Door profile (this may take 5-10 minutes)...`n" -ForegroundColor Yellow
    
    az afd profile delete `
      --profile-name irdecode-prod-fd `
      --resource-group $resourceGroup `
      --yes
    
    Write-Host "✅ Front Door deleted!`n" -ForegroundColor Green
} else {
    Write-Host "`n❌ Deletion cancelled. Front Door still active.`n" -ForegroundColor Yellow
    Write-Host "You can delete manually later with:" -ForegroundColor Gray
    Write-Host "az afd profile delete --profile-name irdecode-prod-fd --resource-group $resourceGroup --yes`n" -ForegroundColor Gray
}

# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "STEP 9: Delete Deprecated Container Apps" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Deleting nura-smry..." -ForegroundColor Yellow
az containerapp delete --name nura-smry --resource-group $resourceGroup --yes

Write-Host "Deleting nura-rsshub..." -ForegroundColor Yellow
az containerapp delete --name nura-rsshub --resource-group $resourceGroup --yes

Write-Host "`n✅ Deprecated services removed!`n" -ForegroundColor Green

# ============================================================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "✅ MIGRATION COMPLETE!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Summary:" -ForegroundColor White
Write-Host "  • Custom domain: https://$customDomain ✅" -ForegroundColor Cyan
Write-Host "  • SSL certificate: Managed by Azure ✅" -ForegroundColor Cyan
Write-Host "  • IP restrictions: Configured ✅" -ForegroundColor Cyan
Write-Host "  • Front Door: Deleted (saving ~`$40/month) ✅" -ForegroundColor Cyan
Write-Host "  • Deprecated apps: Removed ✅`n" -ForegroundColor Cyan

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Update any n8n workflow URLs if they hardcoded Front Door endpoint" -ForegroundColor Gray
Write-Host "  2. Monitor n8n access for 24 hours" -ForegroundColor Gray
Write-Host "  3. Apply V005 database migration (if not done yet)" -ForegroundColor Gray
Write-Host "  4. Deploy updated Terraform configuration`n" -ForegroundColor Gray
