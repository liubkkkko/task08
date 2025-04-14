output "acr_id" {
  description = "ACR ID"
  value       = azurerm_container_registry.acr.id
}

output "acr_login_server" {
  description = "ACR login server"
  value       = azurerm_container_registry.acr.login_server
}

output "admin_username" {
  description = "ACR admin username"
  # Check if admin_enabled is true, otherwise these might be null
  value = azurerm_container_registry.acr.admin_enabled ? azurerm_container_registry.acr.admin_username : null
}

output "admin_password" {
  description = "ACR admin password"
  # Check if admin_enabled is true, otherwise these might be null
  value     = azurerm_container_registry.acr.admin_enabled ? azurerm_container_registry.acr.admin_password : null
  sensitive = true
}

# Add this output
output "build_task_id" {
  description = "The ID of the ACR build task definition"
  value       = azurerm_container_registry_task.build_task.id
}