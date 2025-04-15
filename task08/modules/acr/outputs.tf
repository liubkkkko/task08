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
  value       = azurerm_container_registry.acr.admin_enabled ? azurerm_container_registry.acr.admin_username : null
}

output "admin_password" {
  description = "ACR admin password"
  value       = azurerm_container_registry.acr.admin_enabled ? azurerm_container_registry.acr.admin_password : null
  sensitive   = true
}

output "build_task_id" {
  description = "The ID of the ACR build task definition"
  value       = azurerm_container_registry_task.build_task.id
}

# Додаємо вихід для ресурсу негайного запуску
output "task_schedule_run_now_id" {
  description = "The ID of the resource triggering the initial task run"
  # Важливо: сам ресурс run_now не має стабільного ID в Azure,
  # але його наявність у стані Terraform вказує на те, що запуск було ініційовано.
  # Використовуємо ID завдання як проксі-значення для залежності.
  # Альтернативно, можна використати time_sleep, який залежить від run_now.
  value = azurerm_container_registry_task_schedule_run_now.initial_run.id
}