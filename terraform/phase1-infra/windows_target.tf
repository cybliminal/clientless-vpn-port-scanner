# Windows scan-target VM behind the firewall's trust interface. Provides
# open ports for: RDP(3389), SMB(445), WinRM(5985 only - no TLS cert configured, so
# not 5986), IIS(80 only - no TLS cert configured, so not 443), and (after AD DS
# forest promotion) DNS(53), LDAP(389/636/3268/3269), Kerberos(88), RPC(135),
# NetBIOS(139 - 137/138 are UDP-only, not TCP), plus Kerberos password change(464),
# RPC over HTTP(593), AD Web Services(9389).
#

resource "azurerm_network_interface" "windows_target" {
  name                = "${var.name_prefix}-windows-target-nic"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.internal.address_prefixes[0], 11)
  }
}

resource "azurerm_windows_virtual_machine" "target" {
  name                = "${var.name_prefix}-win-target"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = var.target_vm_size
  admin_username      = var.windows_admin_username
  admin_password      = var.windows_admin_password

  network_interface_ids = [azurerm_network_interface.windows_target.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

# RDP(3389) is open by the Azure Windows image's default firewall rules already.

# Uses the modern Run Command mechanism (same backend as `az vm run-command
# invoke`) instead of CustomScriptExtension. CustomScriptExtension's
# commandToExecute runs via cmd.exe, which has an ~8KB command-line length limit -
# our base64-encoded script exceeded that once the script grew. Run Command takes
# the script directly without that constraint.
resource "azurerm_virtual_machine_run_command" "bootstrap1" {
  name               = "bootstrap1-iis-sql-winrm"
  location           = azurerm_resource_group.this.location
  virtual_machine_id = azurerm_windows_virtual_machine.target.id

  source {
    script = templatefile("${path.module}/windows-bootstrap1.ps1.tpl", {})
  }

  timeouts {
    create = "1h30m"
    update = "1h30m"
  }
}

resource "azurerm_virtual_machine_run_command" "bootstrap2" {
  name               = "bootstrap2-ad-ds"
  location           = azurerm_resource_group.this.location
  virtual_machine_id = azurerm_windows_virtual_machine.target.id

  source {
    script = templatefile("${path.module}/windows-bootstrap2.ps1.tpl", {
      ad_domain_name        = var.ad_domain_name
      ad_safe_mode_password = var.ad_safe_mode_password
    })
  }

  depends_on = [azurerm_virtual_machine_run_command.bootstrap1]

  # AD DS forest promotion includes a forced restart; give it room too.
  timeouts {
    create = "1h30m"
    update = "1h30m"
  }
}
