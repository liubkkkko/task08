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
  description = "Node count for default node pool"
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

# Variable for the UAMI *Resource ID* (used in top-level identity block and kubelet_identity block)
variable "kubelet_user_assigned_identity_id" {
  description = "The Resource ID of the User Assigned Identity to assign to Kubelet."
  type        = string
}

# >>> NEW: Variable for the UAMI *Client ID* (used in kubelet_identity block) <<<
variable "kubelet_user_assigned_identity_client_id" {
  description = "The Client ID of the User Assigned Identity assigned to Kubelet."
  type        = string
}

# >>> NEW: Variable for the UAMI *Object ID* (used in kubelet_identity block) <<<
variable "kubelet_user_assigned_identity_object_id" {
  description = "The Object ID (Principal ID) of the User Assigned Identity assigned to Kubelet."
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}