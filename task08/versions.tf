terraform {
  required_version = ">= 1.5.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.110.0, < 4.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0" # Переконайтеся, що версія сумісна з вашим кластером AKS
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.0" # Переконайтеся, що версія сумісна з вашим кластером AKS
    }
    time = { # Додайте провайдер time для time_sleep
      source = "hashicorp/time"
      version = "~> 0.9.1"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  host                   = module.aks.kube_config[0].host
  client_certificate     = base64decode(module.aks.kube_config[0].client_certificate)
  client_key             = base64decode(module.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(module.aks.kube_config[0].cluster_ca_certificate)
  # ВИДАЛЕНО: load_config_file = false - не підтримується при явному налаштуванні
}

provider "kubectl" {
  host                   = module.aks.kube_config.0.host
  client_certificate     = base64decode(module.aks.kube_config.0.client_certificate)
  client_key             = base64decode(module.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(module.aks.kube_config.0.cluster_ca_certificate)
  # ВИДАЛЕНО: load_config_file = false - не підтримується при явному налаштуванні
}

# Додайте провайдер time
provider "time" {}