resource "azurerm_container_registry" "acr" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = true
  tags                = var.tags
}

resource "azurerm_container_registry_task" "build_task" {
  name                  = "${var.name}-build-task"
  container_registry_id = azurerm_container_registry.acr.id
  platform {
    os = "Linux"
  }

  docker_step {
    dockerfile_path = "application/Dockerfile"
    context_path    = "application"
    image_names     = ["${var.image_name}:latest"]
  }

  source_trigger {
    name           = "source-trigger"
    events         = ["commit"]
    repository_url = var.git_repo_url
    source_type    = "Github"
    branch         = "main"
    
    authentication {
      token      = var.git_pat
      token_type = "PAT"
    }
  }

  timer_trigger {
    name     = "daily-trigger"
    schedule = "0 0 * * *"
    enabled  = true
  }
}