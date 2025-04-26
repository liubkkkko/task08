# main.tf

locals {
  rg_name                     = var.resource_group_name
  redis_name                  = "${var.name_pattern}-redis"
  keyvault_name               = "${var.name_pattern}-kv"
  acr_name                    = substr(lower(replace("${var.name_pattern}cr", "-", "")), 0, 50)
  aks_name                    = "${var.name_pattern}-aks"
  aci_name                    = "${var.name_pattern}-ci"
  image_tag                   = "latest"
  build_context_relative_path = "task08/application"
  # Додаємо ім'я для нової UAMI
  aks_kv_identity_name = "${local.aks_name}-kv-identity"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

# Створюємо User Assigned Managed Identity для взаємодії AKS <-> Key Vault
resource "azurerm_user_assigned_identity" "aks_kv_identity" {
  name                = local.aks_kv_identity_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
}

module "keyvault" {
  source              = "./modules/keyvault"
  name                = local.keyvault_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.key_vault_sku
  tags                = var.tags
  depends_on          = [azurerm_resource_group.rg]
}

# Надаємо новій User Assigned Identity доступ до секретів Key Vault
resource "azurerm_key_vault_access_policy" "aks_identity_kv_access" {
  key_vault_id = module.keyvault.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.aks_kv_identity.principal_id # Використовуємо principal_id нової UAMI

  secret_permissions = [
    "Get",
    "List"
  ]

  # Переконуємося, що KV та ідентичність існують перед створенням політики
  depends_on = [module.keyvault, azurerm_user_assigned_identity.aks_kv_identity]
}

module "acr" {
  source                      = "./modules/acr"
  name                        = local.acr_name
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  sku                         = var.acr_sku
  image_name                  = var.docker_image_name
  git_repo_url                = var.git_repo_url
  git_pat                     = var.git_pat
  tags                        = var.tags
  build_context_relative_path = local.build_context_relative_path
  depends_on                  = [azurerm_resource_group.rg]
}

module "redis" {
  source                = "./modules/redis"
  name                  = local.redis_name
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  capacity              = var.redis_capacity
  family                = var.redis_family
  sku                   = var.redis_sku
  key_vault_id          = module.keyvault.key_vault_id
  redis_url_secret_name = var.redis_url_secret_name
  redis_pwd_secret_name = var.redis_pwd_secret_name
  tags                  = var.tags
  depends_on            = [module.keyvault] # Залежність від KV, куди будуть записані секрети
}

module "aks" {
  source                            = "./modules/aks"
  name                              = local.aks_name
  resource_group_name               = azurerm_resource_group.rg.name
  location                          = azurerm_resource_group.rg.location
  node_count                        = var.aks_node_count
  node_size                         = var.aks_node_size
  os_disk_type                      = var.aks_disk_type
  node_pool_name                    = "system"
  kubelet_user_assigned_identity_id = azurerm_user_assigned_identity.aks_kv_identity.id # Pass the UAMI ID
  tags                              = var.tags
  depends_on                        = [azurerm_user_assigned_identity.aks_kv_identity]
}

# Призначення ролі для Kubelet Identity (тепер це нова UAMI) для доступу до ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = module.acr.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aks_kv_identity.principal_id
  depends_on           = [module.aks, module.acr, azurerm_user_assigned_identity.aks_kv_identity]
}

module "aci" {
  source              = "./modules/aci"
  name                = local.aci_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  acr_login_server    = module.acr.acr_login_server
  acr_admin_username  = module.acr.admin_username
  acr_admin_password  = module.acr.admin_password
  image_name          = var.docker_image_name
  image_tag           = local.image_tag
  # Передаємо значення секретів Redis з Key Vault, використовуючи виходи модуля redis
  redis_hostname      = module.redis.redis_hostname
  redis_primary_key   = module.redis.redis_primary_key
  tags                = var.tags
  # Залежність від початкового запуску ACR Task та від створення секретів Redis
  depends_on          = [module.acr.task_schedule_run_now_id, module.redis.redis_primary_key, module.redis.redis_hostname]
}

# Додаткова затримка для стабілізації API AKS та CSI driver
resource "time_sleep" "wait_for_aks_api" {
  depends_on      = [module.aks, azurerm_key_vault_access_policy.aks_identity_kv_access, azurerm_role_assignment.aks_acr_pull]
  create_duration = "420s" # Збільшено до 7 хвилин на стабілізацію AKS, прав та CSI
}

# Застосовуємо маніфест SecretProviderClass
resource "kubectl_manifest" "secret_provider" {
  yaml_body = templatefile("./k8s-manifests/secret-provider.yaml.tftpl", {
    aks_kv_access_identity_id  = azurerm_user_assigned_identity.aks_kv_identity.client_id # Використовуємо client_id для manifest
    kv_name                    = module.keyvault.key_vault_name
    redis_url_secret_name      = var.redis_url_secret_name
    redis_password_secret_name = var.redis_pwd_secret_name
    tenant_id                  = data.azurerm_client_config.current.tenant_id
  })

  # Застосовуємо після стабілізації AKS та прав до KV
  depends_on = [time_sleep.wait_for_aks_api]
}

# --- НОВИЙ DATA SOURCE ДЛЯ ОЧІКУВАННЯ K8S SECRET ---
data "kubernetes_secret" "redis_secrets" {
  metadata {
    name      = "redis-secrets" # Ім'я Secret, який створює CSI driver
    namespace = "default"     # Припускаємо default namespace, якщо не вказано інше
  }

  # Залежність від створення SecretProviderClass.
  # Terraform буде чекати, поки цей Secret з'явиться.
  depends_on = [
    kubectl_manifest.secret_provider,
  ]
}
# --- КІНЕЦЬ НОВОГО DATA SOURCE ---


# Застосовуємо маніфест Deployment
resource "kubectl_manifest" "deployment" {
  yaml_body = templatefile("./k8s-manifests/deployment.yaml.tftpl", {
    acr_login_server = module.acr.acr_login_server
    app_image_name   = var.docker_image_name
    image_tag        = local.image_tag
  })

  depends_on = [
    # Залежимо від того, що Kubernetes Secret з'явився (через data source)
    data.kubernetes_secret.redis_secrets,
    # Залежимо від того, що ідентичність AKS має право тягнути образ з ACR
    azurerm_role_assignment.aks_acr_pull,
    # Залежимо від того, що ACR Task завершив початкову збірку
    module.acr.task_schedule_run_now_id,
  ]

  wait_for_rollout = true # Чекаємо на успішне розгортання Deployment

  # Додатково чекаємо, поки буде доступний хоча б один репліка
  wait_for {
    field {
      key   = "status.availableReplicas"
      value = "1"
    }
  }
}

# Застосовуємо маніфест Service
resource "kubectl_manifest" "service" {
  yaml_body = file("./k8s-manifests/service.yaml")

  depends_on = [kubectl_manifest.deployment]

  # Чекаємо на отримання зовнішнього IP для Load Balancer
  wait_for {
    field {
      key        = "status.loadBalancer.ingress.[0].ip"
      value      = "^(\\d+(\\.|$)){4}"
      value_type = "regex"
    }
  }
}

# Додаткова затримка після Deployment (можливо, вже не потрібна з wait_for_rollout)
# Можна залишити, якщо потрібно дати час Service отримати IP після Deployment
resource "time_sleep" "wait_for_deployment" {
  depends_on      = [kubectl_manifest.deployment] # Змінено залежність на deployment
  create_duration = "180s" # Зменшено до 3 хвилин, бо wait_for_rollout вже чекає
}

# Отримуємо IP Load Balancer
data "kubernetes_service" "app_service" {
  metadata {
    name = "redis-flask-app-service"
    namespace = "default" # Припускаємо default namespace
  }
  depends_on = [kubectl_manifest.service] # Залежимо від Service
}


output "aci_fqdn" {
  description = "FQDN of App in Azure Container Instance"
  value       = module.aci.aci_fqdn
}

output "aks_lb_ip" {
  description = "Load Balancer IP address of APP in AKS"
  # Використовуємо can() для безпечного доступу, якщо LoadBalancer IP ще не призначено
  value       = can(data.kubernetes_service.app_service.status.0.load_balancer.0.ingress.0.ip) ? data.kubernetes_service.app_service.status.0.load_balancer.0.ingress.0.ip : "Load Balancer IP not yet assigned or service not ready"
}