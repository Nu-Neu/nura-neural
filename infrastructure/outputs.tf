# ===========================================
# Outputs
# ===========================================

# Azure AI Search
output "search_endpoint" {
  description = "Azure AI Search endpoint URL"
  value       = "https://${azurerm_search_service.nura.name}.search.windows.net"
}

output "search_admin_key" {
  description = "Azure AI Search admin key"
  value       = azurerm_search_service.nura.primary_key
  sensitive   = true
}

# Container Apps URLs
output "miniflux_url" {
  description = "Miniflux RSS aggregator URL"
  value       = "https://${azurerm_container_app.miniflux.ingress[0].fqdn}"
}

output "rsshub_internal_url" {
  description = "RSSHub internal URL (for n8n)"
  value       = "http://${azurerm_container_app.rsshub.name}"
}

output "smry_internal_url" {
  description = "SMRY text extractor internal URL (for n8n)"
  value       = "http://${azurerm_container_app.smry.name}:3000"
}

output "redis_internal_url" {
  description = "Redis internal URL (for RSSHub)"
  value       = "redis://${azurerm_container_app.redis.name}:6379"
}

# Database
output "postgres_host" {
  description = "PostgreSQL server hostname"
  value       = data.azurerm_postgresql_flexible_server.existing.fqdn
}

output "nura_database" {
  description = "Nura application database name"
  value       = azurerm_postgresql_flexible_server_database.nura.name
}

output "miniflux_database" {
  description = "Miniflux database name"
  value       = azurerm_postgresql_flexible_server_database.miniflux.name
}

# Storage
output "content_container" {
  description = "Blob container for content archives"
  value       = azurerm_storage_container.content.name
}

output "embeddings_container" {
  description = "Blob container for embeddings cache"
  value       = azurerm_storage_container.embeddings.name
}

# Summary
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = <<-EOT
    
    ╔══════════════════════════════════════════════════════════════╗
    ║              NURA NEURAL - DEPLOYMENT COMPLETE               ║
    ╠══════════════════════════════════════════════════════════════╣
    ║ Azure AI Search:  ${azurerm_search_service.nura.name}
    ║ Miniflux:         https://${azurerm_container_app.miniflux.ingress[0].fqdn}
    ║ RSSHub:           ${azurerm_container_app.rsshub.name} (internal)
    ║ SMRY Extractor:   ${azurerm_container_app.smry.name} (internal)
    ║ Redis:            ${azurerm_container_app.redis.name} (internal)
    ║ PostgreSQL DBs:   miniflux, nura
    ║ Blob Containers:  nura-content, nura-embeddings
    ╠══════════════════════════════════════════════════════════════╣
    ║ Next Steps:                                                  ║
    ║ 1. Build & push nura-smry image to ACR                       ║
    ║ 2. Configure n8n workflows                                   ║
    ║ 3. Add RSS feeds to Miniflux                                 ║
    ║ 4. Create Azure AI Search indexes                            ║
    ║ 5. Deploy widgets to Cloudflare Pages                        ║
    ╚══════════════════════════════════════════════════════════════╝
  EOT
}
