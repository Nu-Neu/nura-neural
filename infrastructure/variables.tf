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

variable "existing_acr_name" {
  description = "Name of existing Azure Container Registry"
  type        = string
  default     = "irdecodeprodacr"
}

# ===========================================
# Azure AI Search Configuration
# ===========================================

variable "search_sku" {
  description = "Azure AI Search SKU (basic for Dev, standard for MVP)"
  type        = string
  default     = "basic"
  validation {
    condition     = contains(["basic", "standard", "standard2", "standard3"], var.search_sku)
    error_message = "search_sku must be basic, standard, standard2, or standard3"
  }
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
