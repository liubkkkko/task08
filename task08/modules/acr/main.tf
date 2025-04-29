resource "azurerm_container_registry" "acr" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = true # Необхідно для отримання admin credentials для ACI
  tags                = var.tags
}

resource "azurerm_container_registry_task" "build_task" {
  name                  = "${var.name}-build-task"
  container_registry_id = azurerm_container_registry.acr.id
  enabled               = true
  tags                  = var.tags # Apply tags to ACR Task

  platform {
    os = "Linux"
  }

  docker_step {
    dockerfile_path = "Dockerfile" # Шлях до Dockerfile відносно context_path
    # ВИПРАВЛЕНО: Комбінуємо URL-репозиторій, гілку та відносний шлях контекст_шлях
    context_path         = "${var.git_repo_url}#main:${var.build_context_relative_path}"
    context_access_token = var.git_pat
    image_names          = ["${var.image_name}:latest", "${var.image_name}:{{.Run.ID}}"]
  }

  # Використовуємо лише тригер джерела (Git commit) згідно з завданням
  source_trigger {
    name           = "github-commit-trigger"
    events         = ["commit"]
    repository_url = var.git_repo_url
    source_type    = "Github"
    branch         = "main" # Використовуємо гілку 'main'
    authentication {
      token      = var.git_pat
      token_type = "PAT"
    }
    enabled = true
  }

  # Завдання не вимагає таймерного тригера, видаляємо його.
  # timer_trigger {
  #   name     = "daily-nightly-build"
  #   schedule = "0 2 * * *"
  #   enabled  = true
  # }
}

# Ресурс для повторного запуску завдання після його створення
# Це гарантує, що образ буде побудовано під час першого apply
resource "azurerm_container_registry_task_schedule_run_now" "initial_run" {
  # Ім'я не потрібне, Terraform згенерує його
  # name = "${azurerm_container_registry_task.build_task.name}-initial-run" # ВИДАЛЕНО
  container_registry_task_id = azurerm_container_registry_task.build_task.id
  # Залежність для РЕСУРСУ - використовуємо depends_on
  # Належність від самого завдання гарантує, що воно існує перед спробою запуску
  depends_on = [azurerm_container_registry_task.build_task]
}