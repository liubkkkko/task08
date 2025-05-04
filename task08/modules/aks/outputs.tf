output "aks_id" {
  description = "AKS ID"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "kube_config" {
  description = "AKS kubeconfig"
  value       = azurerm_kubernetes_cluster.aks.kube_config
  sensitive   = true
}

# This output might be less directly relevant now, as we explicitly define the kubelet identity via inputs.
# You could keep it or remove it. Let's output the identity info confirmed to be applied.
output "aks_applied_kubelet_identity" {
  description = "Details of the identity explicitly configured for the Kubelet."
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0] # Access the first (and only) element
}

# Remove the previous confusing outputs like kubelet_identity_id and kubelet_user_assigned_identity_resource_id
# if they were just reflecting the identity block assignment.