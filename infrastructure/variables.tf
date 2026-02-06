# ===========================================
# Required Variables
# ===========================================

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "project_name" {
  description = "Project name prefix for new resources"
  type        = string
  default     = "nura"
}

# ===========================================
# Existing Infrastructure References
# ===========================================

variable "existing_resource_group" {
  description = "Name of existing resource group"
  type        = string
  default     = "irdecode-prod-rg"
}

variable "existing_aca_environment" {
  description = "Name of existing Container Apps environment"
  type        = string
  default     = "irdecode-prod-n8n-env"
}

variable "existing_postgres_server" {
  description = "Name of existing PostgreSQL Flexible Server"
  type        = string
  default     = "irdecode-prod-psql"
}

variable "existing_storage_account" {
  description = "Name of existing Storage Account"
  type        = string
  default     = "irdecodeprodst"
}

variable "existing_key_vault" {
  description = "Name of existing Key Vault"
  type        = string
  default     = "irdecode-prod-kv"
}

variable "existing_openai_account" {
  description = "Name of existing Azure OpenAI Cognitive Services account"
  type        = string
  default     = "irdecode-prod-openai"
}

# ===========================================
# PostgreSQL Credentials
# ===========================================

variable "postgres_user" {
  description = "PostgreSQL admin username"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

# ===========================================
# Miniflux Configuration
# ===========================================

variable "miniflux_admin_user" {
  description = "Miniflux admin username"
  type        = string
  default     = "admin"
}

variable "miniflux_admin_password" {
  description = "Miniflux admin password"
  type        = string
  sensitive   = true
}

# ===========================================
# API Keys
# ===========================================

variable "twitterapi_io_key" {
  description = "TwitterAPI.io API key"
  type        = string
  sensitive   = true
  default     = ""
}

# ===========================================
# VM + Docker Stack Configuration
# ===========================================

variable "vm_name" {
  description = "Override for VM name (defaults to <project>-prod-vm)"
  type        = string
  default     = ""
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 64
}

variable "vm_admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "vm_admin_ssh_public_key" {
  description = "SSH public key to provision on the VM"
  type        = string
}

variable "vm_domain_name_label" {
  description = "Optional DNS label for the VM public IP"
  type        = string
  default     = ""
}

variable "vm_vnet_cidr" {
  description = "Address space for the VM vNET"
  type        = string
  default     = "10.90.0.0/24"
}

variable "vm_subnet_cidr" {
  description = "Address prefix for the VM subnet"
  type        = string
  default     = "10.90.0.0/25"
}

variable "vm_allowed_ssh_cidrs" {
  description = "CIDR ranges allowed to SSH (22) into the VM"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vm_allowed_http_cidrs" {
  description = "CIDR ranges allowed to reach HTTP/HTTPS on the VM"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vm_allowed_redis_cidrs" {
  description = "CIDR ranges allowed to reach Redis on the VM"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "redis_container_image" {
  description = "Docker image for Redis"
  type        = string
  default     = "redis:7-alpine"
}

variable "miniflux_container_image" {
  description = "Docker image for Miniflux"
  type        = string
  default     = "miniflux/miniflux:latest"
}

variable "rsshub_container_image" {
  description = "Docker image for RSSHub"
  type        = string
  default     = "diygod/rsshub:latest"
}

variable "fastapi_container_image" {
  description = "Docker image for the FastAPI service"
  type        = string
  default     = "tiangolo/uvicorn-gunicorn-fastapi:python3.11-slim"  # Placeholder until custom image is built
}

variable "nginx_container_image" {
  description = "Docker image for Nginx reverse proxy"
  type        = string
  default     = "nginx:stable-alpine"
}

variable "fastapi_environment" {
  description = "Environment label injected into the FastAPI container"
  type        = string
  default     = "production"
}

# ===========================================
# n8n Queue Mode Configuration
# ===========================================

variable "n8n_container_app_name" {
  description = "Name of the n8n Container App"
  type        = string
  default     = "irdecode-prod-n8n"
}

variable "n8n_container_image" {
  description = "Container image for n8n"
  type        = string
  default     = "docker.n8n.io/n8nio/n8n:1.65.1"
}

variable "n8n_cpu" {
  description = "vCPU requested by the n8n container"
  type        = number
  default     = 1
}

variable "n8n_memory" {
  description = "Memory requested by the n8n container"
  type        = string
  default     = "2Gi"
}

variable "n8n_min_replicas" {
  description = "Minimum replicas for n8n"
  type        = number
  default     = 1
}

variable "n8n_max_replicas" {
  description = "Maximum replicas for n8n"
  type        = number
  default     = 1
}

variable "n8n_ingress_target_port" {
  description = "Port exposed by the n8n container"
  type        = number
  default     = 5678
}

variable "n8n_encryption_key" {
  description = "Encryption key for n8n credentials"
  type        = string
  sensitive   = true
}

variable "n8n_basic_auth_user" {
  description = "Optional basic auth user for the n8n UI"
  type        = string
  default     = ""
}

variable "n8n_basic_auth_password" {
  description = "Optional basic auth password for the n8n UI"
  type        = string
  sensitive   = true
  default     = ""
}

variable "queue_redis_port" {
  description = "Port exposed by Redis for queue processing"
  type        = number
  default     = 6379
}

# ===========================================
# Tags
# ===========================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    project     = "nura-neural"
    environment = "dev"
    managed_by  = "terraform"
  }
}
