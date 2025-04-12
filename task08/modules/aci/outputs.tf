output "aci_id" {
  description = "ACI ID"
  value       = azurerm_container_group.aci.id
}

output "aci_ip_address" {
  description = "ACI IP address"
  value       = azurerm_container_group.aci.ip_address
}

output "aci_fqdn" {
  description = "ACI FQDN"
  value       = azurerm_container_group.aci.fqdn
}