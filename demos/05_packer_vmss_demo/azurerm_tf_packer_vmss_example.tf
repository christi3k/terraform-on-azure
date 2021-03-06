# This is an example of a basic Terraform configuration file that sets up a new demo resource group,
# and creates a new demo network with a virtual machine scale set using a custom image generated by
# packer in a public subnet behind a load balancer.

# IMPORTANT: Make sure subscription_id, client_id, client_secret, and tenant_id are configured!

/* REQUIREMENTS:
Use code to deploy a provided java application in a manner that is easily scalable.
*/

# Configure the Azure Provider
provider "azurerm" {}

# Create a resource group
resource "azurerm_resource_group" "demo05_resource_group" {
  name     = "demo05_resource_group"
  location = "westus2"

  tags {
    environment = "demo"
    build       = "demo05"
  }
}

module "network" "demo05_network" {
  source              = "Azure/network/azurerm"
  resource_group_name = "${azurerm_resource_group.demo05_resource_group.name}"
  location            = "${azurerm_resource_group.demo05_resource_group.location}"
  address_space       = "10.0.0.0/16"
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24"]
  subnet_names        = ["demo05_public_subnet", "demo05_private_subnet"]
  vnet_name           = "demo05_network"

  tags {
    environment = "demo"
    build       = "demo05"
  }
}

resource "azurerm_subnet" "demo05_public_subnet" {
  name                      = "demo05_public_subnet"
  address_prefix            = "10.0.1.0/24"
  resource_group_name       = "${azurerm_resource_group.demo05_resource_group.name}"
  virtual_network_name      = "demo05_network"
  network_security_group_id = "${azurerm_network_security_group.demo05_public_security_group.id}"
}

resource "azurerm_network_security_group" "demo05_public_security_group" {
  depends_on          = ["module.network"]
  name                = "demo05_public_security_group"
  location            = "${azurerm_resource_group.demo05_resource_group.location}"
  resource_group_name = "${azurerm_resource_group.demo05_resource_group.name}"

  security_rule {
    name                       = "demo05_allow_web"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
    environment = "demo"
    build       = "demo05"
  }
}

module "loadbalancer" "demo05_load_balancer" {
  source              = "Azure/loadbalancer/azurerm"
  resource_group_name = "${azurerm_resource_group.demo05_resource_group.name}"
  location            = "${azurerm_resource_group.demo05_resource_group.location}"
  prefix              = "demo05"

  lb_port = {
    http = ["80", "Tcp", "8080"]
  }

  frontend_name = "demo05-public-vip"

  tags {
    environment = "demo"
    build       = "demo05"
  }
}

module "computegroup" "demo05_computegroup" {
  source                                 = "Azure/computegroup/azurerm"
  vmscaleset_name                        = "demo05_vmscaleset"
  resource_group_name                    = "${azurerm_resource_group.demo05_resource_group.name}"
  location                               = "${azurerm_resource_group.demo05_resource_group.location}"
  vm_size                                = "Standard_B1S"
  admin_username                         = "azureuser"
  admin_password                         = "BestPasswordEver"
  ssh_key                                = "~/.ssh/id_rsa.pub"
  nb_instance                            = 3
  vnet_subnet_id                         = "${module.network.vnet_subnets[0]}"
  load_balancer_backend_address_pool_ids = "${module.loadbalancer.azurerm_lb_backend_address_pool_id}"

  #vm_os_simple                           = "UbuntuServer"

  # Using the custom packer-todo-demo image I created from the 'demo_image.json' file using Packer
  vm_os_id = "/subscriptions/d7e02429-9aef-419e-b1e3-a9ca66b40864/resourceGroups/PACKERDEMO/providers/Microsoft.Compute/images/packer-todo-demo"
  tags = {
    environment = "demo"
    build       = "demo05"
  }
}

output "azurerm_public_ip_address" {
  value = "${module.loadbalancer.azurerm_public_ip_address}"
}
