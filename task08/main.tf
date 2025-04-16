# REMOVE the entire locals {} block from this file

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name # Uses the local defined in locals.tf
  location = var.location
  tags     = var.tags
}

module "keyvault" {
  source              = "./modules/keyvault"
  name                = local.keyvault_name # Uses the local defined in locals.tf
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.key_vault_sku
  tags                = var.tags

  depends_on = [azurerm_resource_group.rg]
}

module "acr" {
  source              = "./modules/acr"
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.acr_sku
  image_name          = var.docker_image_name
  git_repo_url        = var.git_repo_url # Базовий URL для тригера
  git_pat             = var.git_pat
  tags                = var.tags
  # Змінюємо: передаємо відносний шлях
  build_context_relative_path  = local.build_context_relative_path

  depends_on = [azurerm_resource_group.rg]
}

module "redis" {
  source                = "./modules/redis"
  name                  = local.redis_name # Uses the local defined in locals.tf
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  capacity              = var.redis_capacity
  family                = var.redis_family
  sku                   = var.redis_sku
  key_vault_id          = module.keyvault.key_vault_id
  redis_url_secret_name = var.redis_url_secret_name
  redis_pwd_secret_name = var.redis_pwd_secret_name
  tags                  = var.tags

  depends_on = [module.keyvault]
}

module "aks" {
  source              = "./modules/aks"
  name                = local.aks_name # Uses the local defined in locals.tf
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location # Use rg location consistently
  node_count          = var.aks_node_count
  node_size           = var.aks_node_size
  os_disk_type        = var.aks_disk_type
  node_pool_name      = "system"
  key_vault_id        = module.keyvault.key_vault_id
  tags                = var.tags

  depends_on = [module.keyvault]
}

# Role assignment for AKS Kubelet Identity (nodes) to pull images from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = module.acr.acr_id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_identity_id

  depends_on = [module.aks, module.acr]
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
  redis_hostname      = module.redis.redis_hostname
  redis_primary_key   = module.redis.redis_primary_key
  tags                = var.tags
  depends_on          = [module.acr.task_schedule_run_now_id, module.redis]
}

# Optional delay to allow AKS API server to stabilize
resource "time_sleep" "wait_for_aks_api" {
  depends_on      = [module.aks]
  create_duration = "60s"
}

# Apply Kubernetes manifests
resource "kubectl_manifest" "secret_provider" {
  yaml_body = templatefile("./k8s-manifests/secret-provider.yaml.tftpl", {
    aks_kv_access_identity_id  = module.aks.aks_identity_id
    kv_name                    = module.keyvault.key_vault_name
    redis_url_secret_name      = var.redis_url_secret_name
    redis_password_secret_name = var.redis_pwd_secret_name
    tenant_id                  = data.azurerm_client_config.current.tenant_id
  })

  depends_on = [time_sleep.wait_for_aks_api, module.keyvault, module.aks]
}

resource "kubectl_manifest" "deployment" {
  yaml_body = templatefile("./k8s-manifests/deployment.yaml.tftpl", {
    acr_login_server = module.acr.acr_login_server
    app_image_name   = var.docker_image_name
    image_tag        = local.image_tag # Uses the local defined in locals.tf
  })

  depends_on = [kubectl_manifest.secret_provider, azurerm_role_assignment.aks_acr_pull]

  wait_for {
    field {
      key   = "status.availableReplicas"
      value = "1"
    }
  }
}

resource "kubectl_manifest" "service" {
  yaml_body = file("./k8s-manifests/service.yaml")

  depends_on = [kubectl_manifest.deployment]

  wait_for {
    field {
      key        = "status.loadBalancer.ingress.[0].ip"
      value      = "^(\\d{1,3}\\.){3}\\d{1,3}$"
      value_type = "regex"
    }
  }
}

# Data source to get the Load Balancer IP
data "kubernetes_service" "app_service" {
  metadata {
    name = "redis-flask-app-service"
  }
  depends_on = [kubectl_manifest.service]
}