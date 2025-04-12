variable "name" {
  description = "Name of the ACI"
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

variable "acr_login_server" {
  description = "ACR login server"
  type        = string
}

variable "acr_admin_username" {
  description = "ACR admin username"
  type        = string
}

variable "acr_admin_password" {
  description = "ACR admin password"
  type        = string
  sensitive   = true
}

variable "image_name" {
  description = "Docker image name"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "redis_hostname" {
  description = "Redis hostname"
  type        = string
}

variable "redis_primary_key" {
  description = "Redis primary key"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}
