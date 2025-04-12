output "redis_hostname" {
  description = "Redis Cache hostname"
  value       = azurerm_redis_cache.redis.hostname
}

output "redis_primary_key" {
  description = "Redis Cache primary access key"
  value       = azurerm_redis_cache.redis.primary_access_key
  sensitive   = true
}