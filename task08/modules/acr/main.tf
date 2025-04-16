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
  enabled               = true

  platform {
    os = "Linux"
  }

   docker_step {
    dockerfile_path      = "Dockerfile" # Шлях до Dockerfile відносно context_path
    # Змінюємо: використовуємо відносний шлях
    context_path         = var.build_context_relative_path
    image_names          = ["${var.image_name}:latest", "${var.image_name}:{{.Run.ID}}"]
    context_access_token = var.git_pat
  }

  source_trigger {
    name           = "github-commit-trigger"
    events         = ["commit"]
    repository_url = var.git_repo_url
    source_type    = "Github"
    branch         = "main"

    authentication {
      token      = var.git_pat
      token_type = "PAT"
    }
    enabled = true
  }

  timer_trigger {
    name     = "daily-nightly-build"
    schedule = "0 2 * * *"
    enabled  = true
  }

  tags = var.tags
}

# Ресурс для негайного запуску завдання після його створення
resource "azurerm_container_registry_task_schedule_run_now" "initial_run" {
  # REMOVE: name                      = "${azurerm_container_registry_task.build_task.name}-initial-run"
  container_registry_task_id = azurerm_container_registry_task.build_task.id

  # Залежність від самого завдання гарантує, що воно існує перед спробою запуску
  depends_on = [azurerm_container_registry_task.build_task]
}