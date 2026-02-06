# Quick diagnostic - PowerShell 5.1 compatible
Write-Host "=== VM SSH Diagnostics ===" -ForegroundColor Cyan

# 1. VM Status
Write-Host "`n[1/4] VM Status:" -ForegroundColor Yellow
az vm get-instance-view --resource-group irdecode-prod-rg --name nura-prod-vm --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" -o tsv

# 2. Public IP
Write-Host "`n[2/4] VM Public IP:" -ForegroundColor Yellow
$publicIp = az vm list-ip-addresses --resource-group irdecode-prod-rg --name nura-prod-vm --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv
Write-Host $publicIp -ForegroundColor Green

# 3. Your IP
Write-Host "`n[3/4] Your Current IP:" -ForegroundColor Yellow
$myIp = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content
Write-Host $myIp -ForegroundColor Green

# 4. NSG Rules
Write-Host "`n[4/4] NSG SSH Rules:" -ForegroundColor Yellow
az network nsg rule list --resource-group irdecode-prod-rg --nsg-name nura-prod-vm-nsg --query "[?destinationPortRange=='22'].{Name:name, Priority:priority, Source:sourceAddressPrefix}" -o table

Write-Host "`n=== SSH Command ===" -ForegroundColor Cyan
Write-Host "ssh azureuser@$publicIp" -ForegroundColor Green

Write-Host "`n=== Fix Command (if needed) ===" -ForegroundColor Cyan
Write-Host "az network nsg rule create --resource-group irdecode-prod-rg --nsg-name nura-prod-vm-nsg --name AllowSSH-Temp --priority 310 --source-address-prefixes `"$myIp/32`" --destination-port-ranges 22 --access Allow --protocol Tcp" -ForegroundColor Yellow