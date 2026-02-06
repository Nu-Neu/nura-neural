output "vm_public_ip" {
  description = "Public IP of nura-prod-vm"
  value       = azurerm_public_ip.vm.ip_address
}

output "vm_private_ip" {
  description = "Private IP of nura-prod-vm"
  value       = azurerm_network_interface.vm.ip_configuration[0].private_ip_address
}

output "vm_ssh_command" {
  description = "Convenience SSH command"
  value       = "ssh ${var.vm_admin_username}@${azurerm_public_ip.vm.ip_address}"
}

output "queue_redis_endpoint" {
  description = "Redis endpoint serving n8n queue traffic"
  value       = "redis://${azurerm_public_ip.vm.ip_address}:${var.queue_redis_port}"
}

# ===========================================
# PostgreSQL Database
# ===========================================
output "postgres_host" {
  description = "PostgreSQL server hostname"
  value       = data.azurerm_postgresql_flexible_server.existing.fqdn
}

output "postgres_port" {
  description = "PostgreSQL server port"
  value       = 5432
}

output "nura_database" {
  description = "Nura application database name"
  value       = azurerm_postgresql_flexible_server_database.nura.name
}

output "miniflux_database" {
  description = "Miniflux database name"
  value       = azurerm_postgresql_flexible_server_database.miniflux.name
}

output "n8n_database" {
  description = "n8n internal database name"
  value       = azurerm_postgresql_flexible_server_database.n8n.name
}

output "postgres_connection_string" {
  description = "PostgreSQL connection string template (add user/password)"
  value       = "postgresql://<USER>:<PASSWORD>@${data.azurerm_postgresql_flexible_server.existing.fqdn}:5432/${azurerm_postgresql_flexible_server_database.nura.name}?sslmode=require"
  sensitive   = false
}

# ===========================================
# Blob Storage
# ===========================================
output "storage_account_name" {
  description = "Storage account name"
  value       = data.azurerm_storage_account.existing.name
}

output "content_container" {
  description = "Blob container for content archives"
  value       = azurerm_storage_container.content.name
}

output "embeddings_container" {
  description = "Blob container for embeddings cache"
  value       = azurerm_storage_container.embeddings.name
}

# ===========================================
# Key Vault References
# ===========================================
output "key_vault_name" {
  description = "Key Vault name for secrets"
  value       = data.azurerm_key_vault.existing.name
}

output "openai_endpoint" {
  description = "Azure OpenAI endpoint URL"
  value       = data.azurerm_cognitive_account.openai.endpoint
}

output "openai_account_name" {
  description = "Azure OpenAI account name"
  value       = data.azurerm_cognitive_account.openai.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = data.azurerm_key_vault.existing.vault_uri
}

# ===========================================
# n8n Credential Configuration Guide
# ===========================================
output "n8n_credential_config" {
  description = "Configuration values for n8n credentials"
  value = {
    postgresql = {
      host     = data.azurerm_postgresql_flexible_server.existing.fqdn
      port     = 5432
      database = azurerm_postgresql_flexible_server_database.nura.name
      ssl      = "require"
      note     = "Get user/password from Key Vault or terraform.tfvars"
    }
    redis = {
      host = azurerm_public_ip.vm.ip_address
      port = var.queue_redis_port
      ssl  = false
      note = "Runs on nura-prod-vm via Docker Compose"
    }
    api = {
      base_url = var.vm_domain_name_label != "" ? "https://${var.vm_domain_name_label}.${data.azurerm_resource_group.existing.location}.cloudapp.azure.com" : "http://${azurerm_public_ip.vm.ip_address}"
      note     = "Front Door should terminate TLS before hitting VM"
    }
  }
}

# ===========================================
# Azure Front Door
# ===========================================
output "frontdoor_endpoint" {
  description = "Front Door endpoint URL"
  value       = azurerm_cdn_frontdoor_endpoint.main.host_name
}

output "frontdoor_url" {
  description = "Full Front Door URL with HTTPS"
  value       = "https://${azurerm_cdn_frontdoor_endpoint.main.host_name}"
}

# ===========================================
# Deployment Summary
# ===========================================
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = <<-EOT

    ╔══════════════════════════════════════════════════════════════╗
    ║              NURA NEURAL - DEPLOYMENT COMPLETE               ║
    ╠══════════════════════════════════════════════════════════════╣
    ║ VM STACK                                                     ║
    ║   VM:        ${local.vm_name} (${var.vm_size})
    ║   Public IP: ${azurerm_public_ip.vm.ip_address}
    ║   Docker:    Redis, Miniflux, RSSHub, FastAPI, Nginx         ║
    ╠══════════════════════════════════════════════════════════════╣
    ║ FRONT DOOR                                                   ║
    ║   Endpoint:   https://${azurerm_cdn_frontdoor_endpoint.main.host_name}
    ║   Miniflux:   https://${azurerm_cdn_frontdoor_endpoint.main.host_name}/miniflux/
    ║   RSSHub:     https://${azurerm_cdn_frontdoor_endpoint.main.host_name}/rsshub/
    ╠══════════════════════════════════════════════════════════════╣
    ║ POSTGRESQL                                                   ║
    ║   Host:       ${data.azurerm_postgresql_flexible_server.existing.fqdn}
    ║   Databases:  miniflux, n8n, nura
    ╠══════════════════════════════════════════════════════════════╣
    ║ BLOB STORAGE                                                 ║
    ║   Account:    ${data.azurerm_storage_account.existing.name}
    ║   Containers: nura-content, nura-embeddings
    ╠══════════════════════════════════════════════════════════════╣
    ║ NEXT STEPS                                                   ║
    ║   1. Apply Flyway migrations from database/migrations/       ║
    ║   2. Configure n8n queue credentials (see outputs)           ║
    ║   3. Import n8n workflows from workflows/*.json              ║
    ║   4. Add RSS feeds to Miniflux via Front Door                ║
    ║   5. Test Front Door routes and caching                      ║
    ╚══════════════════════════════════════════════════════════════╝

  EOT
}