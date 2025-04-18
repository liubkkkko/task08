output "aks_id" {
  description = "AKS ID"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "kube_config" {
  description = "AKS kubeconfig"
  value       = azurerm_kubernetes_cluster.aks.kube_config
  sensitive   = true
}

# Видаляємо вихід для ідентичності аддону
# output "aks_identity_id" {
#   description = "The Object ID of the AKS Key Vault Secrets Provider addon identity."
#   value = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].object_id
# }

# Виправляємо вихід для Kubelet Identity, тепер це Principal ID нашої UAMI
output "kubelet_identity_id" {
  description = "The Principal ID of the Kubelet Managed Identity"
  # Для UserAssigned, principal_id знаходиться в основному блоці identity
  value = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

# Додаємо вихід для Resource ID ідентичності, використаної Kubelet
output "kubelet_user_assigned_identity_resource_id" {
  description = "The Resource ID of the User Assigned Identity used by Kubelet."
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].user_assigned_identity_id
}