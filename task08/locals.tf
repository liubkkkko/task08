locals {
  rg_name       = var.resource_group_name
  redis_name    = "${var.name_pattern}-redis"
  keyvault_name = "${var.name_pattern}-kv"
  # Ensure ACR name is compliant (alphanumeric, lowercase, max length typically 50)
  acr_name  = substr(lower(replace("${var.name_pattern}cr", "-", "")), 0, 50)
  aks_name  = "${var.name_pattern}-aks"
  aci_name  = "${var.name_pattern}-ci"
  image_tag = "latest"

  # Construct the context path for ACR Task Docker step
  # Format: <repository_url>#<branch>:<relative_path_to_context_folder>
  # Assuming 'application' folder is at the root of the 'main' branch
  git_repo_context_path = "${var.git_repo_url}#main:application"
}