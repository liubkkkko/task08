variable "name" {
  description = "Name of the ACR"
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

variable "sku" {
  description = "ACR SKU"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "image_name" {
  description = "Docker image name"
  type        = string
}

variable "git_repo_url" {
  description = "Git repository URL"
  type        = string
}

variable "git_pat" {
  description = "Git Personal Access Token"
  type        = string
  sensitive   = true
}