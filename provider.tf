# Configure the Azure provider, you can have many
# if you use azurerm provider, it's source is hashicorp/azurerm
# short for registry.terraform.io/hashicorp/azurerm
 
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.12.0"
    }
  }
 
  required_version = ">= 1.9.0"
}
# configures the provider
 
provider "azurerm" {
  features {
    resource_group{
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = "8e5ae5fe-f772-4899-9329-613723128161"
}
