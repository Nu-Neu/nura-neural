# ===========================================
# Outputs - Nura Neural Infrastructure
# ===========================================

# ===========================================
# Azure AI Search
# ===========================================
output "search_service_name" {
  description = "Azure AI Search service name"
  value       = azurerm_search_service.nura.name
}

output "search_endpoint" {
  description = "Azure AI Search endpoint URL"
  value       = "https://${azurerm_search_service.nura.name}.search.windows.net"
}

output "search_admin_key" {
  description = "Azure AI Search admin key (sensitive)"
  value       = azurerm_search_service.nura.primary_key
  sensitive   = true
}

# ===========================================
# Container Apps URLs
# ===========================================
output "miniflux_url" {
  description = "Miniflux RSS aggregator URL (external)"
  value       = "https://${azurerm_container_app.miniflux.ingress[0].fqdn}"
}

output "redis_internal_url" {
  description = "Redis internal URL (for caching)"
  value       = "redis://${azurerm_container_app.redis.name}:6379"
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
    azure_ai_search = {
      endpoint = "https://${azurerm_search_service.nura.name}.search.windows.net"
      note     = "Get API key from Key Vault secret: nura-search-api-key"
    }
    redis = {
      host = azurerm_container_app.redis.name
      port = 6379
      ssl  = false
    }
    miniflux = {
      url  = "https://${azurerm_container_app.miniflux.ingress[0].fqdn}"
      note = "API key available in Miniflux settings after first login"
    }
    # smry = {
    #   url = "http://${azurerm_container_app.smry.name}:3000"
    # }
  }
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
    ║ AZURE AI SEARCH                                              ║
    ║   Service:    ${azurerm_search_service.nura.name}
    ║   Endpoint:   https://${azurerm_search_service.nura.name}.search.windows.net
    ║   SKU:        ${azurerm_search_service.nura.sku}
    ╠══════════════════════════════════════════════════════════════╣
    ║ CONTAINER APPS                                               ║
    ║   Miniflux:   https://${azurerm_container_app.miniflux.ingress[0].fqdn}
    ║   RSSHub:     ${azurerm_container_app.rsshub.name} (internal)
    ║   Redis:      ${azurerm_container_app.redis.name}:6379 (internal)
    ║   SMRY:       (commented - requires custom Docker build)     ║
    ╠══════════════════════════════════════════════════════════════╣
    ║ POSTGRESQL                                                   ║
    ║   Host:       ${data.azurerm_postgresql_flexible_server.existing.fqdn}
    ║   Databases:  miniflux, nura
    ╠══════════════════════════════════════════════════════════════╣
    ║ BLOB STORAGE                                                 ║
    ║   Account:    ${data.azurerm_storage_account.existing.name}
    ║   Containers: nura-content, nura-embeddings
    ╠══════════════════════════════════════════════════════════════╣
    ║ NEXT STEPS                                                   ║
    ║   1. Apply database schema: psql -f database/schema.sql      ║
    ║   2. Create AI Search indexes: ./create-search-indexes.ps1   ║
    ║   3. Configure n8n credentials (see n8n_credential_config)   ║
    ║   4. Import n8n workflows from workflows/*.json              ║
    ║   5. Add RSS feeds to Miniflux                               ║
    ║   6. Deploy SMRY: Build & push custom Docker image to ACR    ║
    ╚══════════════════════════════════════════════════════════════╝

  EOT
}