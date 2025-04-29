variable "name" {
  description = "Назва кластера AKS"
  type        = string
}

variable "resource_group_name" {
  description = "Назва групи ресурсів"
  type        = string
}

variable "location" {
  description = "Регіон Azure для ресурсів"
  type        = string
}

variable "node_count" {
  description = "Кількість вузлів у пулі вузлів за замовчуванням"
  type        = number
}

variable "node_size" {
  description = "Розмір віртуальної машини для вузлів"
  type        = string
}

variable "os_disk_type" {
  description = "Тип диска ОС для вузлів"
  type        = string
}

variable "node_pool_name" {
  description = "Назва пулу вузлів за замовчуванням"
  type        = string
}

# Додаємо зміну для ідентичності ID Змінна Kubelet
variable "kubelet_user_assigned_identity_id" {
  description = "Ідентифікатор ресурсу призначеного користувача ідентифікатора, який потрібно призначити Kubelet та використовувати для доступу до Key Vault."
  type        = string
}

# --- ВИДАЛЕНО: Ця змінна більше не потрібна в цьому модулі ---
# variable "kubelet_user_assigned_identity_principal_id" {
#   description = "Ідентифікатор принципала призначеної користувачем ідентифікації, який потрібно призначити Kubelet та використовувати для доступу до Key Vault."
#   type        = string
# }
# -------------------------------------------------------------

variable "tags" {
  description = "Теги, які слід застосовувати до ресурсів"
  type        = map(string)
}