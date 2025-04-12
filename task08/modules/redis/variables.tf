variable "name" {
  description = "Name of the Redis Cache"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "capacity" {
  description = "Redis capacity"
  type        = number
}

variable "family" {
  description = "Redis family"
  type        = string
}

variable "sku" {
  description = "Redis SKU"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault ID to store Redis secrets"
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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}