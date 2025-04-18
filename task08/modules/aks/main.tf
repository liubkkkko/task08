data "azurerm_client_config" "current" {}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name
  tags                = var.tags

  default_node_pool {
    name              = var.node_pool_name
    node_count        = var.node_count
    vm_size           = var.node_size
    os_disk_type      = var.os_disk_type
    os_disk_size_gb   = 70
    # НЕМАЄ окремого блоку kubelet_identity для UserAssigned
  }

  # Основна ідентичність кластера = User Assigned
  identity {
    type = "UserAssigned"
    # Вказуємо ID створеної нами ідентичності
    identity_ids = [var.kubelet_user_assigned_identity_id] # Потрібен список ID
  }

  # Вмикаємо аддон, він буде використовувати ідентичність кластера (UAMI),
  # якщо вона призначена і має доступи до KV
  key_vault_secrets_provider {
    secret_rotation_enabled = true
    secret_rotation_interval = "2m"
  }

  oidc_issuer_enabled = true

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    outbound_type  = "loadBalancer"
  }
}

# Видаляємо створення політики доступу зсередини модуля
# resource "azurerm_key_vault_access_policy" "aks_kv_access" { ... }