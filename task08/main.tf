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

module "keyvault" {
  source              = "./modules/keyvault"
  name                = local.keyvault_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.key_vault_sku
  tags                = var.tags
  # Module dependency
  depends_on = [azurerm_resource_group.rg]
}

# Grant the new User Assigned Identity access to Key Vault secrets
# This policy is needed for the CSI driver in AKS
resource "azurerm_key_vault_access_policy" "aks_identity_kv_access" {
  key_vault_id = module.keyvault.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  # Use the principal_id of the new UAMI
  object_id = azurerm_user_assigned_identity.aks_kv_identity.principal_id
  secret_permissions = [
    "Get",
    "List"
  ]
  # Resource dependency
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
  build_context_relative_path = local.build_context_relative_path # Use "task08/application"
  # Module dependency
  depends_on = [azurerm_resource_group.rg]
}


module "redis" {
  source                = "./modules/redis"
  name                  = local.redis_name
  resource_group_name   = azurerm_resource_group.rg.name # Use RG name from resource
  location              = azurerm_resource_group.rg.location # Use RG location from resource
  capacity              = var.redis_capacity
  family                = var.redis_family
  sku                   = var.redis_sku
  key_vault_id          = module.keyvault.key_vault_id # Pass Key Vault ID
  redis_url_secret_name = var.redis_url_secret_name
  redis_pwd_secret_name = var.redis_pwd_secret_name
  tags                  = var.tags
  # Module dependency
  # Depends on KV where secrets will be stored
  depends_on = [module.keyvault]
}

# Call the AKS module, passing the necessary UAMI details
module "aks" {
  source                              = "./modules/aks"
  name                                = local.aks_name
  resource_group_name                 = azurerm_resource_group.rg.name
  location                            = azurerm_resource_group.rg.location
  node_count                          = var.aks_node_count
  node_size                           = var.aks_node_size
  os_disk_type                        = var.aks_disk_type
  node_pool_name                      = "system" # Required name
  # Pass the UAMI details needed by the module for kubelet_identity block
  kubelet_user_assigned_identity_id          = azurerm_user_assigned_identity.aks_kv_identity.id         # Pass Resource ID
  kubelet_user_assigned_identity_client_id   = azurerm_user_assigned_identity.aks_kv_identity.client_id # Pass Client ID
  kubelet_user_assigned_identity_object_id   = azurerm_user_assigned_identity.aks_kv_identity.principal_id # Pass Object ID (Principal ID)
  tags                                       = var.tags
  # Module dependency
  depends_on = [azurerm_user_assigned_identity.aks_kv_identity, azurerm_resource_group.rg]
}


# Assign AcrPull role to the Kubelet Identity (the UAMI) to access ACR
# This role is needed for AKS nodes to pull images from ACR using their assigned identity
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = module.acr.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aks_kv_identity.principal_id # Use Principal ID here
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
  image_tag           = local.image_tag # Pass 'latest' tag
  # Pass Redis secret values from Key Vault using redis module outputs
  redis_hostname      = module.redis.redis_hostname
  redis_primary_key   = module.redis.redis_primary_key
  tags                = var.tags
  # Module dependency
  # Depends on initial ACR Task run and Redis secrets being created
  depends_on = [
    module.acr.task_schedule_run_now_id,
    module.redis, # Depends implicitly on secrets within the module being created
  ]
}


# Sleep to allow AKS, CSI driver, Role Assignments, and ACR Task completion/propagation
# This sleep waits for role assignments and identities to propagate
resource "time_sleep" "wait_for_aks_identity_and_permissions" {
  # Resource dependency
  # Depends on AKS creation, ACR Role Assignment, KV Access Policy, ACR initial run
  # Ensures all permissions are set and image is built before deploying to K8s
  depends_on = [
    module.aks.aks_id, # Depend on AKS module completion (using an output)
    azurerm_key_vault_access_policy.aks_identity_kv_access,
    azurerm_role_assignment.aks_acr_pull,
    module.acr.task_schedule_run_now_id # Wait for initial image build completion
  ]
  create_duration = "600s" # 10 minutes for better propagation
}


# Apply SecretProviderClass manifest
resource "kubectl_manifest" "secret_provider" {
  yaml_body = templatefile("./k8s-manifests/secret-provider.yaml.tftpl", {
    # Use client_id for SecretProviderClass manifest
    aks_kv_access_identity_id = azurerm_user_assigned_identity.aks_kv_identity.client_id
    kv_name                   = module.keyvault.key_vault_name
    redis_url_secret_name     = var.redis_url_secret_name
    redis_password_secret_name = var.redis_pwd_secret_name
    tenant_id                 = data.azurerm_client_config.current.tenant_id
  })
  # Resource dependency
  # Depends on Time Sleep (after identity/permissions propagated) and Redis secrets created
  depends_on = [
    time_sleep.wait_for_aks_identity_and_permissions,
    module.redis, # Secrets must be in KV before CSI tries to get them
    # Also depend on the access policy for the UAMI
    azurerm_key_vault_access_policy.aks_identity_kv_access,
  ]
}


# Data source to wait for K8s Secret created by CSI driver
# Terraform will wait until this secret appears in K8s.
# This signals successful CSI connection to KV.
data "kubernetes_secret" "redis_secrets" {
  metadata {
    name      = "redis-secrets" # Name of the Secret the CSI driver creates
    namespace = "default"       # Assuming default namespace
  }
  # Data source dependency
  depends_on = [
    kubectl_manifest.secret_provider,
    # Depend on secrets actually existing in KV (via module.redis)
    module.redis,
    # Also depend on the access policy allowing AKS UAMI to read secrets
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

  # Resource dependency
  # Depends on successful read of k8s secret (implies CSI driver success)
  # AND Role Assignment (so AKS can pull image)
  depends_on = [
    data.kubernetes_secret.redis_secrets, # Wait for CSI & Secret success
    azurerm_role_assignment.aks_acr_pull, # Wait for image pull permissions
  ]

  wait_for_rollout = true # Wait for deployment rollout
  wait_for {
    field {
      key   = "status.availableReplicas"
      value = "1"
      # value_type defaults to "eq", can be omitted
    }
  }
}


# Apply Service manifest
resource "kubectl_manifest" "service" {
  yaml_body = file("./k8s-manifests/service.yaml") # Use file() for static file

  # Resource dependency
  # Depends on successful deployment
  depends_on = [kubectl_manifest.deployment]

  wait_for_rollout = true # Wait for LoadBalancer IP assignment
  wait_for {
    field {
      key        = "status.loadBalancer.ingress.[0].ip"
      value      = "^(\\d+(\\.|$)){4}" # Regex for IPv4
      value_type = "regex"
    }
  }
}


# Additional sleep after service to allow LoadBalancer IP to become fully available
# This sleep ensures the LoadBalancer IP is stable before trying to read it
resource "time_sleep" "wait_for_service_lb_ip" {
  # Resource dependency
  # Depends on Service resource creation/wait
  depends_on = [kubectl_manifest.service]
  create_duration = "60s" # Reduced from 5 minutes, as kubectl wait already polls
}


# Get LoadBalancer IP Data
# Use data source after the time_sleep wait
data "kubernetes_service" "app_service" {
  metadata {
    name      = "redis-flask-app-service"
    namespace = "default"
  }
  # Data source dependency
  # Depend on the time_sleep which waits after service IP detection
  depends_on = [time_sleep.wait_for_service_lb_ip]
}

# Outputs defined in outputs.tf