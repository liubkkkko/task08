output "aks_id" {
  description = "AKS ID"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "kube_config" {
  description = "AKS kubeconfig"
  value       = azurerm_kubernetes_cluster.aks.kube_config
  sensitive   = true
}

output "kubelet_identity_id" {
  description = "The Principal ID of the User Assigned Managed Identity assigned to the cluster/kubelet"
  # Principal ID все ще доступний через індекс, оскільки блок identity - це список
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "kubelet_user_assigned_identity_resource_id" {
  description = "The Resource ID of the User Assigned Identity used by the cluster/Kubelet."
  # Використовуємо one() для отримання єдиного елемента з множини identity_ids
  value       = one(azurerm_kubernetes_cluster.aks.identity[0].identity_ids)
}