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

data "azurerm_cognitive_account" "openai" {
  name                = var.existing_openai_account
  resource_group_name = var.existing_resource_group
}

# ===========================================
# Locals - Render Docker Compose + cloud-init
# ===========================================

locals {
  vm_name        = var.vm_name != "" ? var.vm_name : "${var.project_name}-prod-vm"
  vm_vnet_name   = "${var.project_name}-vm-vnet"
  vm_subnet_name = "${var.project_name}-vm-subnet"

  docker_compose_yaml = templatefile("${path.module}/templates/docker-compose.tpl", {
    redis_image    = var.redis_container_image
    miniflux_image = var.miniflux_container_image
    rsshub_image   = var.rsshub_container_image
    fastapi_image  = var.fastapi_container_image
    nginx_image    = var.nginx_container_image
  })

  docker_compose_env = templatefile("${path.module}/templates/compose-env.tpl", {
    postgres_host           = data.azurerm_postgresql_flexible_server.existing.fqdn
    postgres_user           = var.postgres_user
    postgres_password       = var.postgres_password
    nura_database           = azurerm_postgresql_flexible_server_database.nura.name
    miniflux_database       = azurerm_postgresql_flexible_server_database.miniflux.name
    miniflux_admin_user     = var.miniflux_admin_user
    miniflux_admin_password = var.miniflux_admin_password
    fastapi_environment     = var.fastapi_environment
  })

  nginx_conf = templatefile("${path.module}/templates/nginx.conf.tpl", {})

  vm_cloud_init = templatefile("${path.module}/templates/cloud-init.tpl", {
    compose_yaml = local.docker_compose_yaml
    compose_env  = local.docker_compose_env
    nginx_conf   = local.nginx_conf
    admin_username = var.vm_admin_username
  })
}

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

resource "azurerm_postgresql_flexible_server_database" "n8n" {
  name      = "n8n"
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
# Networking + VM for Redis/Miniflux/RSSHub/FastAPI/Nginx
# ===========================================

resource "azurerm_virtual_network" "vm" {
  name                = local.vm_vnet_name
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  address_space       = [var.vm_vnet_cidr]

  tags = var.tags
}

resource "azurerm_subnet" "vm" {
  name                 = local.vm_subnet_name
  resource_group_name  = data.azurerm_resource_group.existing.name
  virtual_network_name = azurerm_virtual_network.vm.name
  address_prefixes     = [var.vm_subnet_cidr]
}

resource "azurerm_network_security_group" "vm" {
  name                = "${local.vm_name}-nsg"
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.vm_allowed_ssh_cidrs
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefixes    = var.vm_allowed_http_cidrs
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.vm_allowed_http_cidrs
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Redis"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.queue_redis_port)
    source_address_prefixes    = var.vm_allowed_redis_cidrs
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_public_ip" "vm" {
  name                = "${local.vm_name}-pip"
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.vm_domain_name_label != "" ? var.vm_domain_name_label : null

  tags = var.tags
}

resource "azurerm_network_interface" "vm" {
  name                = "${local.vm_name}-nic"
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }

  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = local.vm_name
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  size                = var.vm_size
  admin_username      = var.vm_admin_username
  network_interface_ids = [
    azurerm_network_interface.vm.id
  ]
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = var.vm_admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.vm_os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(local.vm_cloud_init)

  tags = var.tags
}

# ===========================================
# n8n Container App (Queue Mode)
# ===========================================

resource "azurerm_container_app" "n8n" {
  name                         = var.n8n_container_app_name
  resource_group_name          = data.azurerm_resource_group.existing.name
  container_app_environment_id = data.azurerm_container_app_environment.existing.id
  revision_mode                = "Single"

  template {
    min_replicas = var.n8n_min_replicas
    max_replicas = var.n8n_max_replicas

    container {
      name   = "n8n"
      image  = var.n8n_container_image
      cpu    = var.n8n_cpu
      memory = var.n8n_memory

      env {
        name  = "DB_TYPE"
        value = "postgresdb"
      }
      env {
        name  = "DB_POSTGRESDB_HOST"
        value = data.azurerm_postgresql_flexible_server.existing.fqdn
      }
      env {
        name  = "DB_POSTGRESDB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_POSTGRESDB_DATABASE"
        value = azurerm_postgresql_flexible_server_database.n8n.name
      }
      env {
        name  = "DB_POSTGRESDB_USER"
        value = var.postgres_user
      }
      env {
        name  = "DB_POSTGRESDB_PASSWORD"
        value = var.postgres_password
      }
      env {
        name  = "N8N_ENCRYPTION_KEY"
        value = var.n8n_encryption_key
      }
      env {
        name  = "N8N_EXECUTIONS_MODE"
        value = "queue"
      }
      env {
        name  = "N8N_QUEUE_BULL_REDIS_HOST"
        value = azurerm_public_ip.vm.ip_address
      }
      env {
        name  = "N8N_QUEUE_BULL_REDIS_PORT"
        value = tostring(var.queue_redis_port)
      }
      env {
        name  = "QUEUE_BULL_REDIS_HOST"
        value = azurerm_public_ip.vm.ip_address
      }
      env {
        name  = "QUEUE_BULL_REDIS_PORT"
        value = tostring(var.queue_redis_port)
      }
      env {
        name  = "N8N_REDIS_HOST"
        value = azurerm_public_ip.vm.ip_address
      }
      env {
        name  = "N8N_REDIS_PORT"
        value = tostring(var.queue_redis_port)
      }
      env {
        name  = "N8N_BASIC_AUTH_ACTIVE"
        value = var.n8n_basic_auth_user != "" ? "true" : "false"
      }
      env {
        name  = "N8N_BASIC_AUTH_USER"
        value = var.n8n_basic_auth_user
      }
      env {
        name  = "N8N_BASIC_AUTH_PASSWORD"
        value = var.n8n_basic_auth_password
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = var.n8n_ingress_target_port
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = var.tags

  depends_on = [
    azurerm_linux_virtual_machine.vm
  ]
}

# ===========================================
# Azure Front Door
# ===========================================

resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = "${var.project_name}-prod-fd"
  resource_group_name = data.azurerm_resource_group.existing.name
  sku_name            = "Standard_AzureFrontDoor"

  tags = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "${var.project_name}-prod"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  tags = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "vm" {
  name                     = "vm-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }

  health_probe {
    protocol            = "Http"
    path                = "/"
    request_type        = "HEAD"
    interval_in_seconds = 100
  }
}

resource "azurerm_cdn_frontdoor_origin" "vm" {
  name                          = "vm-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.vm.id

  enabled                        = true
  host_name                      = azurerm_public_ip.vm.ip_address
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_public_ip.vm.ip_address
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = false
}

resource "azurerm_cdn_frontdoor_route" "default" {
  name                          = "default-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.vm.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.vm.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpOnly"
  link_to_default_domain = true
  https_redirect_enabled = true

  cache {
    query_string_caching_behavior = "IgnoreQueryString"
    compression_enabled           = true
    content_types_to_compress = [
      "application/json",
      "application/xml",
      "text/css",
      "text/html",
      "text/javascript",
      "text/plain"
    ]
  }
}

resource "azurerm_cdn_frontdoor_route" "miniflux" {
  name                          = "miniflux-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.vm.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.vm.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/miniflux/*"]
  forwarding_protocol    = "HttpOnly"
  link_to_default_domain = true
  https_redirect_enabled = true

  cache {
    query_string_caching_behavior = "UseQueryString"
    compression_enabled           = false
  }
}

resource "azurerm_cdn_frontdoor_route" "rsshub" {
  name                          = "rsshub-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.vm.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.vm.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/rsshub/*"]
  forwarding_protocol    = "HttpOnly"
  link_to_default_domain = true
  https_redirect_enabled = true

  cache {
    query_string_caching_behavior = "UseQueryString"
    compression_enabled           = true
    content_types_to_compress = [
      "application/json",
      "application/xml",
      "text/xml"
    ]
  }
}

# ===========================================
# Key Vault Secrets
# ===========================================

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault_secret" "twitter_api_key" {
  name         = "nura-twitterapi-io-key"
  value        = var.twitterapi_io_key
  key_vault_id = data.azurerm_key_vault.existing.id
}
