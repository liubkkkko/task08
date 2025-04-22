data "azurerm_client_config" "current" {}
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name
  tags                = var.tags

  default_node_pool {
    name            = var.node_pool_name
    node_count      = var.node_count
    vm_size         = var.node_size
    os_disk_type    = var.os_disk_type
    os_disk_size_gb = 70
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.kubelet_user_assigned_identity_id] # Use the variable passed from the root module
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    outbound_type  = "loadBalancer"
  }
}