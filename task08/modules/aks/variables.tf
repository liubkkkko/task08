variable "name" {
  description = "Name of the AKS cluster"
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

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
}

variable "node_size" {
  description = "VM size for nodes (e.g., Standard_D2ads_v5)"
  type        = string
}

variable "os_disk_type" {
  description = "OS disk type for nodes (e.g., Managed, Ephemeral)"
  type        = string
}

variable "node_pool_name" {
  description = "Name of the default node pool"
  type        = string
}

# REMOVED - Role assignment moved to root
# variable "acr_id" {
#   description = "ACR ID for pull access"
#   type        = string
# }

variable "key_vault_id" {
  description = "Key Vault ID that AKS CSI driver needs access to"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}