terraform {
  required_version = ">= 1.5.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.110.0, < 4.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.1" # Uses 0.9.2 after init -upgrade
    }
  }
}

provider "azurerm" {
  features {}
}

# Configure Kubernetes provider using individual attributes from the module output
# This provider does NOT support load_config_file = false directly
provider "kubernetes" {
  host                   = module.aks.kube_config[0].host
  client_certificate     = base64decode(module.aks.kube_config[0].client_certificate)
  client_key             = base64decode(module.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(module.aks.kube_config[0].cluster_ca_certificate)
  # REMOVED: load_config_file = false
}

# Configure Kubectl provider using individual attributes from the module output
# Add load_config_file = false here as discussed in the GitHub issue
provider "kubectl" {
  host                   = module.aks.kube_config[0].host
  client_certificate     = base64decode(module.aks.kube_config[0].client_certificate)
  client_key             = base64decode(module.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(module.aks.kube_config[0].cluster_ca_certificate)
  load_config_file       = false # <<< KEPT: Prevent loading external kubeconfig for THIS provider
}

# Add time provider block
provider "time" {}