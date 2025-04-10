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
  kind                = "Linux"
  reserved            = true
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
  
  site_config {
  linux_fx_version = "PYTHON|3.10"
  always_on        = true
  }

  connection_string {
    name  = "Database"
    type  = "SQLServer"
    value = "Server=tcp:proj2-sql.database.windows.net,1433;Initial Catalog=proj2-db;User ID=proj1_admin;Password=Proj@123#12;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
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

resource "azurerm_app_service_virtual_network_swift_connection" "integration" {
  app_service_id = azurerm_app_service.as.id
  subnet_id      = azurerm_subnet.subnet1.id
}

resource "azurerm_app_service_source_control" "webapp_source" {
  app_id             = azurerm_app_service.as.id
  repo_url           = "https://github.com/Veekshitha04/webapp_py"
  branch             = "main"
  use_manual_integration = true
  use_mercurial      = false
}


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
resource "azurerm_private_dns_zone" "sql_dns" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet_link" {
  name                  = "${var.prefix}-dns-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "sql_a_record" {
  name                = azurerm_sql_server.server.name
  zone_name           = azurerm_private_dns_zone.sql_dns.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.conn.private_service_connection[0].private_ip_address]
}

resource "azurerm_public_ip" "vm_pip" {
  name                = "${var.prefix}-vm-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "proj2-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.prefix}-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("C:/Users/mureddy/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.prefix}-osdisk"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  disable_password_authentication = true
}
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "${var.prefix}-vm-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # 👈 Change this to your IP for better security
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowAppPort5000"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

resource "azurerm_network_interface_security_group_association" "vm_nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

#bastion subnet
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet" # Must use this exact name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.128/27"]
}

# Public IP for Bastion
resource "azurerm_public_ip" "bastion_ip" {
  name                = "${var.prefix}-bastion-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Azure Bastion Resource
resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-host"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"

  ip_configuration {
    name                 = "bastion-config"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_ip.id
  }
}

