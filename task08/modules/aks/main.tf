data "azurerm_client_config" "current" {}

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
    # Явно вказуємо менший розмір OS-диска для Ephemeral на Standard_D2ads_v5
    os_disk_size_gb = 70 # Менше ніж 75ГБ тимчасового сховища
  }

  identity {
    type = "SystemAssigned"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  oidc_issuer_enabled = true

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    outbound_type  = "loadBalancer"
  }
}

resource "azurerm_key_vault_access_policy" "aks_kv_access" {
  key_vault_id = var.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].object_id

  secret_permissions = [
    "Get",
    "List"
  ]
}