locals {
  rg_name       = var.resource_group_name
  redis_name    = "${var.name_pattern}-redis"
  keyvault_name = "${var.name_pattern}-kv"
  acr_name      = substr(lower(replace("${var.name_pattern}cr", "-", "")), 0, 50)
  aks_name      = "${var.name_pattern}-aks"
  aci_name      = "${var.name_pattern}-ci"
  image_tag     = "latest"

  # Змінюємо: вказуємо лише відносний шлях до папки контексту
  build_context_relative_path = "application"
}