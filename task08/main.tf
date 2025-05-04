# main.tf
# Local values defined in locals.tf
# Outputs defined in outputs.tf

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

# Create User Assigned Managed Identity for AKS <-> Key Vault interaction
resource "azurerm_user_assigned_identity" "aks_kv_identity" {
  name                = local.aks_kv_identity_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
}

# --- NEW: Grant the UAMI Managed Identity Operator role scoped to itself ---
# This is required for the AKS control plane (using this same UAMI)
# to assign this identity to the Kubelet.
resource "azurerm_role_assignment" "aks_identity_operator" {
  scope                = azurerm_user_assigned_identity.aks_kv_identity.id         # Scope: The UAMI itself
  role_definition_name = "Managed Identity Operator"                               # Role Name
  principal_id         = azurerm_user_assigned_identity.aks_kv_identity.principal_id # Assignee: The UAMI's principal
  # Depends on the UAMI being created
  depends_on = [azurerm_user_assigned_identity.aks_kv_identity]
}
# --- End of NEW Role Assignment ---

module "keyvault" {
  source              = "./modules/keyvault"
  name                = local.keyvault_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.key_vault_sku
  tags                = var.tags
  depends_on          = [azurerm_resource_group.rg]
}

# Grant the UAMI access to Key Vault secrets for CSI driver
resource "azurerm_key_vault_access_policy" "aks_identity_kv_access" {
  key_vault_id       = module.keyvault.key_vault_id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_user_assigned_identity.aks_kv_identity.principal_id
  secret_permissions = ["Get", "List"]
  depends_on         = [module.keyvault, azurerm_user_assigned_identity.aks_kv_identity]
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
  depends_on            = [module.keyvault]
}

# Call the AKS module
module "aks" {
  source                                   = "./modules/aks"
  name                                     = local.aks_name
  resource_group_name                      = azurerm_resource_group.rg.name
  location                                 = azurerm_resource_group.rg.location
  node_count                               = var.aks_node_count
  node_size                                = var.aks_node_size
  os_disk_type                             = var.aks_disk_type
  node_pool_name                           = "system"
  kubelet_user_assigned_identity_id        = azurerm_user_assigned_identity.aks_kv_identity.id
  kubelet_user_assigned_identity_client_id = azurerm_user_assigned_identity.aks_kv_identity.client_id
  kubelet_user_assigned_identity_object_id = azurerm_user_assigned_identity.aks_kv_identity.principal_id
  tags                                     = var.tags
  # --- UPDATED Dependency ---
  # AKS cluster creation must wait for the Managed Identity Operator role assignment
  depends_on = [
    azurerm_user_assigned_identity.aks_kv_identity,
    azurerm_resource_group.rg,
    azurerm_role_assignment.aks_identity_operator # Add dependency on the new role assignment
  ]
  # --- End UPDATED Dependency ---
}

# Assign AcrPull role to the UAMI for pulling images
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
  redis_hostname      = module.redis.redis_hostname
  redis_primary_key   = module.redis.redis_primary_key
  tags                = var.tags
  depends_on = [
    module.acr.task_schedule_run_now_id,
    module.redis,
  ]
}

# Sleep to allow permissions propagation
resource "time_sleep" "wait_for_aks_identity_and_permissions" {
  # --- UPDATED Dependency ---
  # Wait for AKS, *all* relevant role assignments/policies, and ACR initial build
  depends_on = [
    module.aks.aks_id,
    azurerm_key_vault_access_policy.aks_identity_kv_access, # KV Access
    azurerm_role_assignment.aks_acr_pull,                   # ACR Pull Access
    azurerm_role_assignment.aks_identity_operator,          # Managed Identity Operator Role
    module.acr.task_schedule_run_now_id                     # Image build
  ]
  # --- End UPDATED Dependency ---
  create_duration = "600s" # Keep 10 minutes
}

# Apply SecretProviderClass manifest
resource "kubectl_manifest" "secret_provider" {
  yaml_body = templatefile("./k8s-manifests/secret-provider.yaml.tftpl", {
    aks_kv_access_identity_id = azurerm_user_assigned_identity.aks_kv_identity.client_id
    kv_name                   = module.keyvault.key_vault_name
    redis_url_secret_name     = var.redis_url_secret_name
    redis_password_secret_name = var.redis_pwd_secret_name
    tenant_id                 = data.azurerm_client_config.current.tenant_id
  })
  depends_on = [
    time_sleep.wait_for_aks_identity_and_permissions,
    module.redis,
    azurerm_key_vault_access_policy.aks_identity_kv_access,
  ]
}

# Data source to wait for K8s Secret created by CSI driver
data "kubernetes_secret" "redis_secrets" {
  metadata {
    name      = "redis-secrets"
    namespace = "default"
  }
  depends_on = [
    kubectl_manifest.secret_provider,
    module.redis,
    azurerm_key_vault_access_policy.aks_identity_kv_access,
  ]
}

# Apply Deployment manifest
resource "kubectl_manifest" "deployment" {
  yaml_body = templatefile("./k8s-manifests/deployment.yaml.tftpl", {
    acr_login_server = module.acr.acr_login_server
    app_image_name   = var.docker_image_name
    image_tag        = local.image_tag
  })
  depends_on = [
    data.kubernetes_secret.redis_secrets,
    azurerm_role_assignment.aks_acr_pull,
  ]
  wait_for_rollout = true
  wait_for {
    field {
      key   = "status.availableReplicas"
      value = "1"
    }
  }
}

# Apply Service manifest
resource "kubectl_manifest" "service" {
  yaml_body = file("./k8s-manifests/service.yaml")
  depends_on = [kubectl_manifest.deployment]
  wait_for_rollout = true
  wait_for {
    field {
      key        = "status.loadBalancer.ingress.[0].ip"
      value      = "^(\\d+(\\.|$)){4}"
      value_type = "regex"
    }
  }
}

# Additional sleep after service
resource "time_sleep" "wait_for_service_lb_ip" {
  depends_on      = [kubectl_manifest.service]
  create_duration = "60s"
}

# Get LoadBalancer IP Data
data "kubernetes_service" "app_service" {
  metadata {
    name      = "redis-flask-app-service"
    namespace = "default"
  }
  depends_on = [time_sleep.wait_for_service_lb_ip]
}

# Outputs defined in outputs.tf