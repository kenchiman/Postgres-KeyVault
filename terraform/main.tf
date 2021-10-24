data "azurerm_client_config" "current" {}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "example-rg"
  location = "eastus"
}

#Create KeyVault ID
resource "random_id" "kvname" {
  byte_length = 5
  prefix = "keyvault"
}

#Keyvault Creation
resource "azurerm_key_vault" "kv1" {
  name                        = random_id.kvname.hex
  location                    = azurerm_resource_group.example.location
  resource_group_name         = azurerm_resource_group.example.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name = "standard"
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    key_permissions = [
      "create", "get",
    ]
    secret_permissions = [
      "get", "backup", "delete", "list", "purge", "recover", "restore", "set",
    ]
    storage_permissions = [
      "get",
    ]
  }
}

#Create KeyVault DB password
resource "random_password" "dbpassword" {
  length = 20
  special = true
}

#Create Key Vault Secret
resource "azurerm_key_vault_secret" "dbpassword" {
  name         = "dbpassword"
  value        = random_password.dbpassword.result
  key_vault_id = azurerm_key_vault.kv1.id
  depends_on = [ azurerm_key_vault.kv1 ]
}

resource "azurerm_postgresql_server" "example" {
  name                = "exaple-psqlsv"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  administrator_login          = "psqladminun"
  administrator_login_password = azurerm_key_vault_secret.dbpassword.value

  sku_name   = "GP_Gen5_2"
  version    = "11"
  storage_mb = 32768

  backup_retention_days        = 7
  geo_redundant_backup_enabled = true
  auto_grow_enabled            = true
  ssl_enforcement_enabled          = false
  public_network_access_enabled    = true
}

resource "azurerm_postgresql_firewall_rule" "example" {
  name                = "office"
  resource_group_name = azurerm_resource_group.example.name
  server_name         = azurerm_postgresql_server.example.name
  start_ip_address    = "27.83.25.30"
  end_ip_address      = "27.83.25.30"
}

resource "azurerm_postgresql_database" "example-db" {
  name                = "example-db"
  resource_group_name = azurerm_resource_group.example.name
  server_name         = azurerm_postgresql_server.example.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}