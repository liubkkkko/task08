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
  description = "Docker image name (without tag)"
  type        = string
}

variable "git_repo_url" {
  description = "Git repository URL (e.g., https://github.com/user/repo.git)"
  type        = string
}

variable "git_pat" {
  description = "Git Personal Access Token for source trigger and context access"
  type        = string
  sensitive   = true
}

# Add this variable
variable "build_context_path" {
  description = "Build context path for ACR task (e.g., https://github.com/user/repo.git#main:folder)"
  type        = string
}