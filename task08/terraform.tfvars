resource_group_name   = "cmtr-13f58f43-mod8-rg"
location              = "West Europe"
name_pattern          = "cmtr-13f58f43-mod8"
acr_sku               = "Standard"
docker_image_name     = "cmtr-13f58f43-mod8-app"
redis_capacity        = 2
redis_sku             = "Basic"
redis_family          = "C"
key_vault_sku         = "standard"
aks_node_count        = 1
aks_node_size         = "Standard_D2s_v3"
aks_disk_type         = "Managed"
redis_url_secret_name = "redis-hostname"
redis_pwd_secret_name = "redis-primary-key"

tags = {
  Creator = "liubomyr_puliak@epam.com"
}