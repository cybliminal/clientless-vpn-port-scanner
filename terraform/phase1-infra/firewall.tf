# VM-Series firewall: GlobalProtect clientless VPN gateway fronting the internal
# scan-target subnet. Built from PaloAltoNetworks/terraform-azurerm-swfw-modules
# `modules/vmseries` (pinned to v3.5.1), called directly rather than through the
# examples/vmseries_standalone wrapper since this environment's networking
# (network.tf) is hand-rolled to match the mgmt/public/internal subnet split.
#
# No bootstrap.xml / bootstrap storage account is used here: the `panos` Terraform
# provider (panos.tf) covers interfaces, zones, virtual router, NAT, security policy,
# certificate import, and GlobalProtect portal/gateway well enough that doing that
# configuration as typed Terraform resources post-boot is more reliable than hand-
# authoring raw PAN-OS XML blind. The only thing this VM needs at first boot is an
# initial admin password, which the `authentication` block below sets via the
# Azure VM admin-credential bootstrap path (the same mechanism the upstream module's
# examples use), and DHCP-assigned interface addressing.

resource "azurerm_public_ip" "fw_mgmt" {
  name                = "${var.name_prefix}-fw-mgmt-pip"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "fw_untrust" {
  name                = "${var.name_prefix}-fw-untrust-pip"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

module "vmseries" {
  source = "github.com/PaloAltoNetworks/terraform-azurerm-swfw-modules//modules/vmseries?ref=v3.5.1"

  name                = "${var.name_prefix}-fw"
  region              = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  authentication = {
    username                        = var.panos_admin_username
    password                        = var.panos_admin_password
    disable_password_authentication = false
  }

  image = {
    version                 = var.vmseries_image_version
    publisher               = "paloaltonetworks"
    offer                   = "vmseries-flex"
    sku                     = var.vmseries_image_sku
    enable_marketplace_plan = true
  }

  virtual_machine = {
    size              = var.vmseries_vm_size
    zone              = null
    disk_name         = "${var.name_prefix}-fw-osdisk"
    bootstrap_options = "type=dhcp-client"
  }

  interfaces = [
    {
      name      = "${var.name_prefix}-fw-mgmt"
      subnet_id = azurerm_subnet.mgmt.id
      ip_configurations = {
        primary = {
          primary          = true
          create_public_ip = false
          public_ip_id     = azurerm_public_ip.fw_mgmt.id
        }
      }
    },
    {
      name      = "${var.name_prefix}-fw-untrust"
      subnet_id = azurerm_subnet.public.id
      ip_configurations = {
        primary = {
          primary            = true
          create_public_ip   = false
          public_ip_id       = azurerm_public_ip.fw_untrust.id
          private_ip_address = cidrhost(azurerm_subnet.public.address_prefixes[0], 4)
        }
      }
    },
    {
      name      = "${var.name_prefix}-fw-trust"
      subnet_id = azurerm_subnet.internal.id
      ip_configurations = {
        primary = {
          primary            = true
          create_public_ip   = false
          private_ip_address = cidrhost(azurerm_subnet.internal.address_prefixes[0], 4)
        }
      }
    },
  ]

  tags = {
    environment = "vpn-scanner-test"
  }
}
