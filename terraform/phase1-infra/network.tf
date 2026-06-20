resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.region
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.name_prefix}-vnet"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = ["10.0.0.0/16"]
}

# --- management subnet: PAN-OS GUI/API/SSH access for operators ---

resource "azurerm_subnet" "mgmt" {
  name                 = "${var.name_prefix}-mgmt-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.0.0/28"]
}

resource "azurerm_network_security_group" "mgmt" {
  name                = "${var.name_prefix}-mgmt-nsg"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  security_rule {
    name                       = "allow-https-mgmt"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.admin_source_cidrs
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ssh-mgmt"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.admin_source_cidrs
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "mgmt" {
  subnet_id                 = azurerm_subnet.mgmt.id
  network_security_group_id = azurerm_network_security_group.mgmt.id
}

# --- public/untrust subnet: firewall's internet-facing interface, GlobalProtect portal/gateway ---

resource "azurerm_subnet" "public" {
  name                 = "${var.name_prefix}-public-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "public" {
  name                = "${var.name_prefix}-public-nsg"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  security_rule {
    name                       = "allow-globalprotect"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.public.id
}

# --- internal/trust subnet: scan-target VMs, reachable only via the firewall ---

resource "azurerm_subnet" "internal" {
  name                 = "${var.name_prefix}-internal-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "internal" {
  name                = "${var.name_prefix}-internal-nsg"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  security_rule {
    name                       = "deny-internet-inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "internal" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.internal.id
}

# NAT gateway gives the internal subnet outbound internet access (apt/choco package
# installs during VM provisioning) without needing the firewall's NAT rules configured
# first.
resource "azurerm_public_ip" "natgw" {
  name                = "${var.name_prefix}-natgw-pip"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "internal" {
  name                = "${var.name_prefix}-natgw"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "internal" {
  nat_gateway_id       = azurerm_nat_gateway.internal.id
  public_ip_address_id = azurerm_public_ip.natgw.id
}

resource "azurerm_subnet_nat_gateway_association" "internal" {
  subnet_id      = azurerm_subnet.internal.id
  nat_gateway_id = azurerm_nat_gateway.internal.id
}
