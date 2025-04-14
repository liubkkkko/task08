output "aks_id" {
  description = "AKS ID"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "kube_config" {
  description = "AKS kubeconfig"
  value       = azurerm_kubernetes_cluster.aks.kube_config
  sensitive   = true
}

output "aks_identity_id" {
  description = "AKS Managed Identity ID"
  value       = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].object_id
}

output "kubelet_identity_id" {
  description = "AKS Kubelet Identity ID"
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
