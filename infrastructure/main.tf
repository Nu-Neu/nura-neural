# Nura Neural - Azure Infrastructure
# Deploys NEW services into EXISTING irdecode-prod-rg infrastructure

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# ===========================================
# DATA SOURCES - Reference Existing Resources
# ===========================================

data "azurerm_resource_group" "existing" {
  name = var.existing_resource_group
}

data "azurerm_container_app_environment" "existing" {
  name                = var.existing_aca_environment
  resource_group_name = var.existing_resource_group
}

data "azurerm_postgresql_flexible_server" "existing" {
  name                = var.existing_postgres_server
  resource_group_name = var.existing_resource_group
}

data "azurerm_storage_account" "existing" {
  name                = var.existing_storage_account
  resource_group_name = var.existing_resource_group
}

data "azurerm_key_vault" "existing" {
  name                = var.existing_key_vault
  resource_group_name = var.existing_resource_group
}

# ===========================================
# NEW RESOURCES - Azure AI Search
# ===========================================

resource "azurerm_search_service" "nura" {
  name                = "${var.project_name}-search"
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = data.azurerm_resource_group.existing.location
  sku                 = var.search_sku # "basic" for Dev, "standard" for MVP
  replica_count       = 1
  partition_count     = 1

  tags = var.tags
}

# ===========================================
# NEW CONTAINER APPS - Into Existing Environment
# ===========================================

# Redis Container App (for RSSHub caching)
resource "azurerm_container_app" "redis" {
  name                         = "${var.project_name}-redis"
  container_app_environment_id = data.azurerm_container_app_environment.existing.id
  resource_group_name          = data.azurerm_resource_group.existing.name
  revision_mode                = "Single"

  template {
    container {
      name   = "redis"
      image  = "redis:7-alpine"
      cpu    = 0.25
      memory = "0.5Gi"
      
      command = ["redis-server", "--save", "60", "1", "--loglevel", "warning"]
    }
    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    external_enabled = false
    target_port      = 6379
    transport        = "tcp"
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = var.tags
}

# RSSHub Container App (Internal - feeds generator)
resource "azurerm_container_app" "rsshub" {
  name                         = "${var.project_name}-rsshub"
  container_app_environment_id = data.azurerm_container_app_environment.existing.id
  resource_group_name          = data.azurerm_resource_group.existing.name
  revision_mode                = "Single"

  template {
    container {
      name   = "rsshub"
      image  = "diygod/rsshub:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "CACHE_TYPE"
        value = "redis"
      }
      env {
        name  = "REDIS_URL"
        value = "redis://${azurerm_container_app.redis.name}:6379"
      }
      env {
        name  = "NODE_ENV"
        value = "production"
      }
    }
    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    external_enabled = false
    target_port      = 1200
    transport        = "http"
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = var.tags

  depends_on = [azurerm_container_app.redis]
}

# Miniflux Container App (RSS Aggregator)
resource "azurerm_container_app" "miniflux" {
  name                         = "${var.project_name}-miniflux"
  container_app_environment_id = data.azurerm_container_app_environment.existing.id
  resource_group_name          = data.azurerm_resource_group.existing.name
  revision_mode                = "Single"

  template {
    container {
      name   = "miniflux"
      image  = "miniflux/miniflux:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "DATABASE_URL"
        value = "postgres://${var.postgres_user}:${var.postgres_password}@${data.azurerm_postgresql_flexible_server.existing.fqdn}:5432/miniflux?sslmode=require"
      }
      env {
        name  = "RUN_MIGRATIONS"
        value = "1"
      }
      env {
        name  = "CREATE_ADMIN"
        value = "1"
      }
      env {
        name  = "ADMIN_USERNAME"
        value = var.miniflux_admin_user
      }
      env {
        name  = "ADMIN_PASSWORD"
        value = var.miniflux_admin_password
      }
    }
    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "http"
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = var.tags
}

# SMRY Text Extractor Container App (COMMENTED - requires custom Docker build or public image)
# resource "azurerm_container_app" "smry" {
#   name                         = "${var.project_name}-smry"
#   container_app_environment_id = data.azurerm_container_app_environment.existing.id
#   resource_group_name          = data.azurerm_resource_group.existing.name
#   revision_mode                = "Single"
#
#   template {
#     container {
#       name   = "smry"
#       image  = "docker.io/mrmps/smry:latest"
#       cpu    = 0.25
#       memory = "0.5Gi"
#
#       env {
#         name  = "PORT"
#         value = "3000"
#       }
#     }
#     min_replicas = 1
#     max_replicas = 2
#   }
#
#   ingress {
#     external_enabled = false
#     target_port      = 3000
#     transport        = "http"
#     traffic_weight {
#       percentage      = 100
#       latest_revision = true
#     }
#   }
#
#   identity {
#     type = "SystemAssigned"
#   }
#
#   tags = var.tags
# }

# ===========================================
# PostgreSQL Databases (in existing server)
# ===========================================

resource "azurerm_postgresql_flexible_server_database" "miniflux" {
  name      = "miniflux"
  server_id = data.azurerm_postgresql_flexible_server.existing.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_database" "nura" {
  name      = "nura"
  server_id = data.azurerm_postgresql_flexible_server.existing.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# ===========================================
# Blob Containers for content archives
# ===========================================

resource "azurerm_storage_container" "content" {
  name                  = "nura-content"
  storage_account_name  = data.azurerm_storage_account.existing.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "embeddings" {
  name                  = "nura-embeddings"
  storage_account_name  = data.azurerm_storage_account.existing.name
  container_access_type = "private"
}

# ===========================================
# Key Vault Secrets
# ===========================================

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault_secret" "search_api_key" {
  name         = "nura-search-api-key"
  value        = azurerm_search_service.nura.primary_key
  key_vault_id = data.azurerm_key_vault.existing.id
}

resource "azurerm_key_vault_secret" "twitter_api_key" {
  name         = "nura-twitterapi-io-key"
  value        = var.twitterapi_io_key
  key_vault_id = data.azurerm_key_vault.existing.id
}
