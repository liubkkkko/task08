locals {
  rg_name       = var.resource_group_name
  redis_name    = "${var.name_pattern}-redis"
  keyvault_name = "${var.name_pattern}-kv"
  acr_name      = replace("${var.name_pattern}cr", "-", "")
  aks_name      = "${var.name_pattern}-aks"
  aci_name      = "${var.name_pattern}-ci"
  image_tag     = "latest"
}