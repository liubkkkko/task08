data "azurerm_client_config" "current" {}

# REMOVED: resource "azurerm_user_assigned_identity" "aks_identity" { ... }

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name
  tags                = var.tags

  default_node_pool {
    name         = var.node_pool_name
    node_count   = var.node_count
    vm_size      = var.node_size
    os_disk_type = var.os_disk_type
    # Added based on task requirements for Ephemeral disks
    os_disk_size_gb        = 128                                             # Example size, adjust if needed for Ephemeral
    enable_host_encryption = (var.os_disk_type == "Ephemeral") ? true : null # Often needed for ephemeral
  }

  identity {
    # Using SystemAssigned as per original code, ensure this is intended
    type = "SystemAssigned"
  }

  # Enable Azure Key Vault Provider for Secrets Store CSI Driver
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m" # Example interval
  }

  # Enable OIDC issuer for potential future workload identity use
  oidc_issuer_enabled = true

  # Ensure network profile allows outbound access if needed
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    outbound_type  = "loadBalancer" # Default, usually fine
  }
}

# REMOVED: resource "azurerm_role_assignment" "acr_pull" { ... }

# Access policy for the CSI driver's identity to access Key Vault
resource "azurerm_key_vault_access_policy" "aks_kv_access" {
  key_vault_id = var.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  # This targets the identity created *by* the key_vault_secrets_provider block
  object_id = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].object_id

  secret_permissions = [
    "Get",
    "List" # List is sometimes needed depending on how secrets are fetched
  ]
}