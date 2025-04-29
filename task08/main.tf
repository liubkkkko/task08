# main.tf
# локальні значення визначено в locals.tf
# виходи визначено в outputs.tf

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

# Створюємо призначену користувачем керовану ідентифікацію для взаємодії AKS <-> Key Vault
resource "azurerm_user_assigned_identity" "aks_kv_identity" {
  name                = local.aks_kv_identity_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags

  # Явна залежність для РЕСУРСУ - використовуємо depends_on
  depends_on = [azurerm_resource_group.rg]
}


module "keyvault" {
  source              = "./modules/keyvault"
  name                = local.keyvault_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.key_vault_sku
  tags                = var.tags
  # Залежність для МОДУЛЯ - використовуємо depends_on
  depends_on = [azurerm_resource_group.rg]
}

# Надаємо новому Призначеному ідентифікатору користувача доступ до секретів Key Vault
# Ця політика потрібна для CSI драйвера в AKS
resource "azurerm_key_vault_access_policy" "aks_identity_kv_access" {
  key_vault_id = module.keyvault.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  # Використовуємо principal_id нової UAMI
  object_id = azurerm_user_assigned_identity.aks_kv_identity.principal_id
  secret_permissions = [
    "Get",
    "List"
  ]
  # Залежність для РЕСУРСУ - використовуємо depends_on
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
  build_context_relative_path = local.build_context_relative_path # ВИКОРИСТОВУЄМО "task08/application"
  # Залежність для МОДУЛЯ - використовуємо depends_on
  depends_on = [azurerm_resource_group.rg]
}


module "redis" {
  source              = "./modules/redis"
  name                = local.redis_name
  resource_group_name = azurerm_resource_group.rg.name # Використовуємо ім'я РГ з ресурсу
  location            = azurerm_resource_group.rg.location # Використовуємо розташування РГ з ресурсу
  capacity            = var.redis_capacity
  family              = var.redis_family
  sku                 = var.redis_sku
  key_vault_id        = module.keyvault.key_vault_id # Передаємо ID Key Vault
  redis_url_secret_name = var.redis_url_secret_name
  redis_pwd_secret_name = var.redis_pwd_secret_name
  tags                = var.tags
  # Залежність для МОДУЛЯ - використовуємо depends_on
  # Залежність від KV, куди будуть записані секрети
  depends_on = [module.keyvault]
}

module "aks" {
  source              = "./modules/aks"
  name                = local.aks_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  node_count          = var.aks_node_count
  node_size           = var.aks_node_size
  os_disk_type        = var.aks_disk_type
  node_pool_name      = "system"
  # Передайте ідентифікатори UAMI
  kubelet_user_assigned_identity_id = azurerm_user_assigned_identity.aks_kv_identity.id
  # Principal ID потрібен був би, якби ми конфігурували identity ВНУТРІ key_vault_secrets_provider,
  # але це невірний підхід. Видаляємо його передачу тут.
  # kubelet_user_assigned_identity_principal_id = azurerm_user_assigned_identity.aks_kv_identity.principal_id # ВИДАЛЕНО
  tags                                        = var.tags
  # Залежність для МОДУЛЯ - використовуємо depends_on
  # Залежність від створення UAMI та групи ресурсів
  depends_on = [azurerm_user_assigned_identity.aks_kv_identity, azurerm_resource_group.rg]
}


# Призначення ролі AcrPull для Kubelet Identity (тепер це нова UAMI) для доступу до ресурсу ACR
# Ця роль потрібна, щоб вузли AKS могли витягувати образ з ACR, використовуючи призначену їм ідентифікацію
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = module.acr.acr_id
  role_definition_name = "AcrPull"
  # Призначаємо роль Principal ID нашої UAMI
  principal_id = azurerm_user_assigned_identity.aks_kv_identity.principal_id
  # Залежність для РЕСУРСУ - використовуємо depends_on
  depends_on = [module.aks, module.acr, azurerm_user_assigned_identity.aks_kv_identity]
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
  image_tag           = local.image_tag # Передаємо latest
  # Передаємо значення секретів Redis з Key Vault, використовуючи вихід модуля redis
  redis_hostname      = module.redis.redis_hostname
  redis_primary_key   = module.redis.redis_primary_key
  tags                = var.tags
  # Залежність для МОДУЛЯ - використовуємо depends_on
  # Залежність від початкового запуску ACR Task та від створення секретів Redis
  depends_on = [
    module.acr.task_schedule_run_now_id,
    module.redis.redis_primary_key,
    module.redis.redis_hostname,
    # Можна додати залежність від групи ресурсів, хоча вона вже є у модулів
    # azurerm_resource_group.rg
  ]
}


# Підтримка для стабілізації AKS, CSI driver, Role Assignments та завершення ACR Task
# Цей time_sleep чекає, поки присвоєння ролей та ідентифікації поширяться
resource "time_sleep" "wait_for_aks_identity_and_permissions" {
  # Залежність для РЕСУРСУ - використовуємо depends_on
  # Залежність від створення AKS, ACR Role Assignment, KV Access Policy, ACR initial run
  # Це гарантує, що всі дозволи налаштовано і образ побудовано перед розгортанням в K8s
  depends_on = [
    module.aks,
    azurerm_key_vault_access_policy.aks_identity_kv_access,
    azurerm_role_assignment.aks_acr_pull,
    module.acr.task_schedule_run_now_id # Чекаємо завершення початкової збірки образу
  ]
  create_duration = "300s" # 5 хвилин очікування для поширення
}


# Застосовуємо маніфест SecretProviderClass
resource "kubectl_manifest" "secret_provider" {
  yaml_body = templatefile("./k8s-manifests/secret-provider.yaml.tftpl", {
    # Використовуємо client_id для маніфесту SecretProviderClass
    aks_kv_access_identity_id = azurerm_user_assigned_identity.aks_kv_identity.client_id
    kv_name                   = module.keyvault.key_vault_name
    redis_url_secret_name     = var.redis_url_secret_name
    redis_password_secret_name = var.redis_pwd_secret_name
    tenant_id                 = data.azurerm_client_config.current.tenant_id
  })
  # Залежність для РЕСУРСУ - використовуємо depends_on
  # Залежність від Time Sleep (після поширення ідентичності/дозволів) та створення секретів Redis
  depends_on = [
    time_sleep.wait_for_aks_identity_and_permissions,
    module.redis.redis_hostname, # Секрети мають бути в KV перед тим, як CSI спробує їх отримати
    module.redis.redis_primary_key,
    # Також залежимо від політики доступу для UAMI
    azurerm_key_vault_access_policy.aks_identity_kv_access,
  ]
}


# Джерело даних для очікування K8s Secret, який створює дані драйвера CSI
# Terraform буде чекати, поки цей секрет з'явиться в K8s.
# Це сигналізує про успішне підключення CSI до KV.
data "kubernetes_secret" "redis_secrets" {
  metadata {
    name      = "redis-secrets" # Ім'я Secret,який створює CSI driver
    namespace = "default" # Припускаємо простір імен за замовчуванням, якщо не показано інше
  }
  # Залежність для ДЖЕРЕЛА ДАНИХ - використовуємо depends_on
  depends_on = [
    kubectl_manifest.secret_provider,
    # Залежимо від того, що секрети справді існують у KV (через модуль redis)
    module.redis.redis_hostname,
    module.redis.redis_primary_key,
    # Також залежимо від політики доступу, яка дозволяє AKS UAMI читати секрети
    azurerm_key_vault_access_policy.aks_identity_kv_access,
  ]
}


# Застосовуємо маніфест Ресурс розгортання
resource "kubectl_manifest" "deployment" {
  yaml_body = templatefile("./k8s-manifests/deployment.yaml.tftpl", {
    acr_login_server = module.acr.acr_login_server
    app_image_name   = var.docker_image_name
    image_tag        = local.image_tag
  })

  # Залежність для РЕСУРСУ - використовуємо depends_on
  # Залежність від успішного читання k8s secret (означає успіх CSI драйвера)
  # та від Role Assignment (щоб AKS міг витягувати образ)
  depends_on = [
    data.kubernetes_secret.redis_secrets, # Чекаємо успіху CSI та Secret
    azurerm_role_assignment.aks_acr_pull, # Чекаємо права на витягування образу
  ]

  wait_for_rollout = true # Чекаємо розгортання
  wait_for {
    field {
      key   = "status.availableReplicas"
      value = "1"
      # value_type = "eq" # 'eq' - значення за замовчуванням, можна прибрати
    }
  }
}


# Застосовуємо маніфест Ресурс служби
resource "kubectl_manifest" "service" {
  yaml_body = file("./k8s-manifests/service.yaml") # Використовуємо file() для статичного файлу

  # Залежність для РЕСУРСУ - використовуємо depends_on
  # Залежність від успішного розгортання
  depends_on = [kubectl_manifest.deployment]

  wait_for_rollout = true # Хоча для служби це не типово, можна чекати створення LB IP
  wait_for {
    field {
      key        = "status.loadBalancer.ingress.[0].ip"
      value      = "^(\\d+(\\.|$)){4}" # Регулярний вираз для IPv4
      value_type = "regex"
    }
  }
}


# Додаткова підтримка після служби для створення IP-ресурсу LoadBalancer
# Цей sleep чекає, щоб IP LoadBalancer точно був призначений і доступний
resource "time_sleep" "wait_for_service_lb_ip" {
  # Залежність для РЕСУРСУ - використовуємо depends_on
  # Залежність від створення ресурсу Service
  depends_on = [kubectl_manifest.service]
  create_duration = "300s" # 5 хвилин
}


# Отримуємо Дані балансувальника IP-навантаження
# Використовуємо data source після очікування time_sleep
data "kubernetes_service" "app_service" {
  metadata {
    name      = "redis-flask-app-service"
    namespace = "default"
  }
  # Залежність для ДЖЕРЕЛА ДАНИХ - використовуємо depends_on
  # Залежимо від time_sleep, який чекає призначення IP
  depends_on = [time_sleep.wait_for_service_lb_ip]
}

# Виходи визначено в outputs.tf