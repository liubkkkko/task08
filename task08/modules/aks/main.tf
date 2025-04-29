data "azurerm_client_config" "current" {} # Потрібен для identity

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name # Використовуємо назву кластера як DNS префікс
  tags                = var.tags

  default_node_pool {
    name           = var.node_pool_name
    node_count     = var.node_count
    vm_size        = var.node_size
    os_disk_type   = var.os_disk_type
    os_disk_size_gb = 70 # Додамо стандартний розмір диска ОС
  }

  # Основний блок identity для призначення UAMI кластеру/вузлам
  identity {
    type = "UserAssigned"
    # Цей identity_id призначає UAMI до кластера/вузлів (Kubelet)
    identity_ids = [var.kubelet_user_assigned_identity_id]
  }

  # Блок key_vault_secrets_provider для ввімкнення CSI драйвера
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
    # --- ВИДАЛЕНО: Немає вкладеного блоку identity тут ---
    # identity {
    #   object_id = var.kubelet_user_assigned_identity_principal_id # ВИДАЛЕНО
    #   user_assigned_identity_id = var.kubelet_user_assigned_identity_id # ВИДАЛЕНО
    # }
    # ----------------------------------------------------
  }

  # Додаємо мережевий профіль згідно з рекомендованими практиками
  network_profile {
      network_plugin = "azure" # Рекомендовано для більшості сценаріїв
      network_policy = "azure" # Рекомендовано для більшості сценаріїв
      outbound_type  = "loadBalancer" # Стандартний вихідний тип
  }

  # --- ВИДАЛЕНО: Непотрібний блок azure_active_directory ---
  # azure_active_directory {} # Порожній блок необхідний для some API calls
  # ----------------------------------------------------------
}