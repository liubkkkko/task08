# variables.tf

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  # default     = "West Europe" # Keep default or remove if always provided in tfvars
}

variable "name_pattern" {
  description = "Naming pattern for resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "git_pat" {
  description = "Git Personal Access Token for ACR task"
  type        = string
  sensitive   = true
}

# Додайте цю змінну
variable "git_repo_url" {
  description = "HTTPS URL of the Git repository containing the application source code"
  type        = string
}

variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
}

variable "docker_image_name" {
  description = "Docker image name"
  type        = string
}

variable "redis_capacity" {
  description = "Capacity for Redis Cache"
  type        = number
}

variable "redis_sku" {
  description = "SKU for Redis Cache"
  type        = string
}

variable "redis_family" {
  description = "Family for Redis Cache"
  type        = string
}

variable "key_vault_sku" {
  description = "SKU for Azure Key Vault"
  type        = string
}

variable "aks_node_count" {
  description = "Node count for default AKS node pool"
  type        = number
}

variable "aks_node_size" {
  description = "VM size for AKS nodes"
  type        = string
}

variable "aks_disk_type" {
  description = "OS disk type for AKS nodes"
  type        = string
}

variable "redis_url_secret_name" {
  description = "Secret name for Redis hostname"
  type        = string
}

variable "redis_pwd_secret_name" {
  description = "Secret name for Redis primary key"
  type        = string
}