# Linux scan-target VM behind the firewall's trust interface. Provides 
# open ports for: ssh(22), nginx(80 only - no TLS cert configured, so not 443),
# postgresql(5432), redis(6379), openldap(389/636), bind9(53), rpcbind(111).

resource "azurerm_network_interface" "linux_target" {
  name                = "${var.name_prefix}-linux-target-nic"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.internal.address_prefixes[0], 10)
  }
}

resource "azurerm_linux_virtual_machine" "target" {
  name                = "${var.name_prefix}-linux-target"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = var.target_vm_size
  admin_username      = var.linux_admin_username

  network_interface_ids = [azurerm_network_interface.linux_target.id]

  admin_ssh_key {
    username   = var.linux_admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/linux-cloud-init.yaml.tpl", {
    ldap_admin_password = var.ldap_admin_password
    ldap_domain         = var.ldap_domain
    redis_password      = var.redis_password
  }))
}
