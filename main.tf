variable "prefix" {
 default = "proj2"
 type = string
}

resource "azurerm_resource_group" "rg" {
    name = "${var.prefix}-rg"
    location = "canadacentral"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "subnet1" {
  name                 = "${var.prefix}-s1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/26"]

  delegation {
    name = "delegation-to-web-serverfarms"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "subnet2" {
  name                 = "${var.prefix}-s2"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.64/26"]

#   service_endpoints = ["Microsoft.Sql"]
}

resource "azurerm_app_service_plan" "asp" {
  name                = "${var.prefix}-asp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "as" {
  name                = "${var.prefix}-as"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id

  connection_string {
    name  = "Database"
    type  = "SQLServer"
    value = "Server=tcp:proj2-sql.database.windows.net,1433;Initial Catalog=proj2-db;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication='Active Directory Default';"
  }
}

/*
resource "azurerm_app_service_slot" "slot" {
  name                = "${var.prefix}-staging"
  app_service_name    = azurerm_app_service.as.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id
}

resource "azurerm_app_service_slot_virtual_network_swift_connection" "connect" {
  slot_name      = azurerm_app_service_slot.slot.name
  app_service_id = azurerm_app_service.as.id
  subnet_id      = azurerm_subnet.subnet1.id
}
*/

resource "azurerm_sql_server" "server" {
    name = "${var.prefix}-sql"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    version = "12.0"
    administrator_login = "proj1_admin"
    administrator_login_password = "Proj@123#12"
    
}

resource "azurerm_sql_database" "db" {
  name                = "${var.prefix}-db"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  server_name         = azurerm_sql_server.server.name 
}

# resource "azurerm_sql_virtual_network_rule" "conn" {
#   name                = "${var.prefix}-conn"
#   resource_group_name = azurerm_resource_group.rg.name
#   server_name         = azurerm_sql_server.server.name
#   subnet_id           = azurerm_subnet.subnet2.id
# }

resource "azurerm_private_endpoint" "conn" {
  name                = "${var.prefix}-conn"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = azurerm_subnet.subnet2.id
 
  private_service_connection {
    name                           = "example-sql-connection"
    private_connection_resource_id = azurerm_sql_server.server.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }
}
