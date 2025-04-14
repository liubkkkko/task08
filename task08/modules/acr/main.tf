resource "azurerm_container_registry" "acr" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = true # Required for ACI login using admin credentials
  tags                = var.tags
}

resource "azurerm_container_registry_task" "build_task" {
  name                  = "${var.name}-build-task" # Task name
  container_registry_id = azurerm_container_registry.acr.id
  # REMOVE: resource_group_name   = var.resource_group_name # Explicitly set RG name for task
  # REMOVE: location              = var.location            # Explicitly set location for task
  enabled               = true                    # Ensure task is enabled

  platform {
    os = "Linux"
    # architecture = "amd64" # Optional: specify architecture if needed
  }

  # Define the Docker build step
  docker_step {
    dockerfile_path = "Dockerfile"                       # Path relative to context
    context_path    = var.build_context_path             # Use the combined context path variable
    image_names     = ["${var.image_name}:latest", "${var.image_name}:{{.Run.ID}}"] # Tag with latest and Run ID
    # Use PAT for accessing the context (source code)
    context_access_token = var.git_pat
    # Set arguments if your Dockerfile needs them
    # arguments = {
    #   arg1 = "value1"
    # }
    # Ensure build runs even if base image isn't updated recently
    # no_cache = true # Optional: uncomment if needed
  }

  # Define triggers
  source_trigger {
    name           = "github-commit-trigger"
    events         = ["commit"]
    repository_url = var.git_repo_url # Base repo URL
    source_type    = "Github"
    branch         = "main" # Or the branch you want to trigger from

    authentication {
      token      = var.git_pat
      token_type = "PAT" # Personal Access Token
    }
    enabled = true # Ensure trigger is enabled
  }

  # Define a timer trigger (e.g., daily build)
  timer_trigger {
    name     = "daily-nightly-build"
    schedule = "0 2 * * *" # Example: Run every day at 2:00 AM UTC
    enabled  = true        # Set to false if you don't want a timer trigger
  }

  # agent_setting { # Optional: configure CPU if needed
  #   cpu = 2
  # }

  # timeout_in_seconds = 3600 # Optional: Increase timeout if needed

  tags = var.tags # Tags can often be applied to the task itself
}