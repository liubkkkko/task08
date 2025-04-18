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
  description = "VM size for nodes"
  type        = string
}

variable "os_disk_type" {
  description = "OS disk type for nodes"
  type        = string
}

variable "node_pool_name" {
  description = "Name of the default node pool"
  type        = string
}

# Видаляємо непотрібну змінну
# variable "key_vault_id" {
#   description = "Key Vault ID that AKS CSI driver needs access to"
#   type        = string
# }

# Додаємо змінну для ID ідентичності Kubelet
variable "kubelet_user_assigned_identity_id" {
  description = "The Resource ID of the User Assigned Identity to assign to the Kubelet and use for Key Vault access."
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}