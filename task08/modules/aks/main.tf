# modules/aks/main.tf

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name
  tags                = var.tags

  # --- Default Node Pool Definition ---
  default_node_pool {
    # Arguments for the node pool itself
    name                = var.node_pool_name
    node_count          = var.node_count
    vm_size             = var.node_size
    os_disk_type        = var.os_disk_type
    os_disk_size_gb     = 70 # Define OS disk size

    # Note: NO user_assigned_identity_id argument belongs directly here.
    # Identity is assigned via top-level identity and kubelet_identity blocks.
  } # --- End of default_node_pool ---


  # --- Top-Level Cluster Identity (Control Plane, Addons) ---
  identity {
    type = "UserAssigned"
    # Assigns the UAMI Resource ID to the cluster itself
    identity_ids = [var.kubelet_user_assigned_identity_id]
  }


  # --- Explicit Kubelet Identity ---
  # This specifically tells the Kubelet on the nodes which identity to use
  kubelet_identity {
    client_id                 = var.kubelet_user_assigned_identity_client_id
    object_id                 = var.kubelet_user_assigned_identity_object_id
    user_assigned_identity_id = var.kubelet_user_assigned_identity_id
  }


  # --- CSI Driver Addon Configuration ---
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
    # No nested identity block needed; it uses the kubelet_identity
  }


  # --- Network Profile ---
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    outbound_type  = "loadBalancer"
  }

  # --- Other Cluster Settings ---
  role_based_access_control_enabled = true
  sku_tier                          = "Free" # Using Free tier as per default behavior

} # --- End of azurerm_kubernetes_cluster ---