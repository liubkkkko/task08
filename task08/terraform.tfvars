resource_group_name   = "cmtr-13f58f43-mod8-rg"
location              = "East US" # Змінено регіон
name_pattern          = "cmtr-13f58f43-mod8"
git_repo_url          = "https://github.com/liubkkkko/task08.git"
acr_sku               = "Basic"
docker_image_name     = "cmtr-13f58f43-mod8-app"
redis_capacity        = 2
redis_sku             = "Basic"
redis_family          = "C"
key_vault_sku         = "standard"
aks_node_count        = 1
aks_node_size         = "Standard_D2ads_v5"
aks_disk_type         = "Ephemeral"
redis_url_secret_name = "redis-hostname"
redis_pwd_secret_name = "redis-primary-key"

tags = {
  Creator = "liubomyr_puliak@epam.com"
}