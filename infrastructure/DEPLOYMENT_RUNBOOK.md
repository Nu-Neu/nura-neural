# Infrastructure Deployment Runbook

## Pre-deployment Checklist

1. **Verify Azure access** (PIM roles active):
   ```powershell
   ..\scripts\check-azure-access.ps1
   ```

2. **Review terraform.tfvars**:
   - Set a real SSH public key for `vm_admin_ssh_public_key`
   - Generate a secure 32-character `n8n_encryption_key`
   - Review CIDR restrictions for `vm_allowed_ssh_cidrs` (tighten from 0.0.0.0/0)
   - Set credentials from Key Vault

3. **Initialize Terraform** (first time only):
   ```powershell
   cd infrastructure
   terraform init
   ```

## Deployment Steps

### Step 1: Import Existing n8n Container App

Before applying changes, import the existing `irdecode-prod-n8n` Container App so Terraform can update it instead of trying to recreate it:

```powershell
terraform import azurerm_container_app.n8n "/subscriptions/0029263c-cf9e-4e08-b543-2eeea360c7fc/resourceGroups/irdecode-prod-rg/providers/Microsoft.App/containerApps/irdecode-prod-n8n"
```

**Verify the import succeeded**:
```powershell
terraform state show azurerm_container_app.n8n
```

### Step 2: Plan the Changes

Review what Terraform will create/destroy/modify:

```powershell
terraform plan -out=tfplan
```

**Expected changes**:
- ✅ **Create**: VM, VNet, subnet, NSG, public IP, NIC
- ✅ **Update**: `azurerm_container_app.n8n` (queue mode env vars)
- ❌ **Destroy**: None (Azure Search/redis/miniflux Container Apps were already removed from state)

### Step 3: Apply Infrastructure Changes

```powershell
terraform apply tfplan
```

**Note**: The VM will take 5-10 minutes to provision, then cloud-init will install Docker and start the Compose stack (additional 3-5 minutes).

### Step 4: Verify VM Stack is Running

SSH into the VM:
```powershell
$vmIP = terraform output -raw vm_public_ip
ssh azureuser@$vmIP
```

Check Docker containers:
```bash
docker ps
# Expected: redis, miniflux, rsshub, fastapi, nginx
```

Check container logs:
```bash
docker logs redis
docker logs miniflux
docker logs fastapi
```

Test Redis connectivity (from VM):
```bash
redis-cli ping
# Expected: PONG
```

### Step 5: Update n8n Workflows

The n8n Container App will now be running in **queue mode** and needs Redis credentials updated.

1. Access n8n UI:
   ```powershell
   $n8nURL = az containerapp show --name irdecode-prod-n8n --resource-group irdecode-prod-rg --query properties.configuration.ingress.fqdn -o tsv
   start "https://$n8nURL"
   ```

2. Update credentials:
   - Redis: Host = `<VM_PUBLIC_IP>`, Port = `6379`
   - PostgreSQL: Existing creds (no change)
   - Remove any Azure AI Search credentials (no longer used)

3. Re-import workflows:
   ```powershell
   ..\scripts\import-n8n-workflows.ps1
   ```

### Step 6: Update Front Door Backend

Point Azure Front Door to the new VM endpoints:

```powershell
# Get VM IP
$vmIP = terraform output -raw vm_public_ip

# Update Front Door origin (replace with actual origin name)
az afd origin update `
  --resource-group irdecode-prod-rg `
  --profile-name irdecode-prod-fd `
  --origin-group-name nura-api-origins `
  --origin-name nura-vm `
  --host-name $vmIP `
  --origin-host-header $vmIP `
  --http-port 80 `
  --https-port 443 `
  --priority 1 `
  --weight 1000 `
  --enabled-state Enabled
```

## Post-Deployment Verification

### 1. Test API Endpoints

```powershell
$vmIP = terraform output -raw vm_public_ip

# Test Nginx proxy
curl "http://$vmIP/api/health"

# Test Miniflux
curl "http://$vmIP/miniflux/"

# Test RSSHub
curl "http://$vmIP/rsshub/"
```

### 2. Test n8n Queue Mode

1. Trigger a test workflow in n8n
2. Check Redis queue activity:
   ```bash
   ssh azureuser@$vmIP
   redis-cli KEYS "bull:*"
   ```

### 3. Monitor Logs

```bash
# On the VM
docker logs -f fastapi
docker logs -f miniflux
docker logs -f nginx
```

## Rollback Plan

If issues arise, you can:

1. **Revert n8n to non-queue mode** (manual in Azure Portal):
   - Remove `N8N_EXECUTIONS_MODE=queue` env var
   - Remove Redis env vars
   - Restart the container app

2. **Stop the VM** without destroying:
   ```powershell
   az vm stop --name nura-prod-vm --resource-group irdecode-prod-rg
   ```

3. **Destroy new infrastructure** (last resort):
   ```powershell
   # Remove VM resources only
   terraform destroy -target=azurerm_linux_virtual_machine.vm
   terraform destroy -target=azurerm_virtual_network.vm
   ```

## Troubleshooting

### VM Cloud-Init Failed

Check cloud-init logs:
```bash
ssh azureuser@$vmIP
sudo cat /var/log/cloud-init-output.log
sudo cloud-init status
```

### Docker Containers Not Starting

```bash
cd /opt/nura
docker compose logs
docker compose ps
```

### n8n Cannot Connect to Redis

1. Check NSG allows traffic from Container App subnet
2. Verify Redis is listening:
   ```bash
   docker exec redis redis-cli ping
   ```
3. Test from n8n container (if you can exec into it):
   ```bash
   nc -zv <VM_IP> 6379
   ```

### Database Connection Issues

Check that the VM's outbound IP is allowed in PostgreSQL firewall rules:
```powershell
az postgres flexible-server firewall-rule list `
  --resource-group irdecode-prod-rg `
  --name irdecode-prod-psql
```

Add the VM public IP if needed:
```powershell
$vmIP = terraform output -raw vm_public_ip
az postgres flexible-server firewall-rule create `
  --resource-group irdecode-prod-rg `
  --name irdecode-prod-psql `
  --rule-name AllowNuraVM `
  --start-ip-address $vmIP `
  --end-ip-address $vmIP
```

## Cost Validation

After deployment, verify expected cost savings (~$270/month):

```powershell
# Check current month's cost
az consumption usage list `
  --resource-group irdecode-prod-rg `
  --start-date (Get-Date -Format "yyyy-MM-01") `
  --end-date (Get-Date) `
  --query "[].{Name:instanceName, Cost:pretaxCost}" `
  --output table
```

Expected resources **removed** from billing:
- ❌ nura-search (Azure AI Search)
- ❌ nura-redis (Container App)
- ❌ nura-miniflux (Container App)

Expected **new** resources:
- ✅ nura-prod-vm (Standard_B2s) ~$30/month
- ✅ VM Public IP (Standard) ~$4/month
- ✅ VM managed disk (64GB Standard) ~$3/month
