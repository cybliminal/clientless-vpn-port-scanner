output "firewall_mgmt_public_ip" {
  description = "PAN-OS GUI/SSH/API address. Feed this into phase2-panos-config's firewall_mgmt_ip variable and into the automation scripts."
  value       = azurerm_public_ip.fw_mgmt.ip_address
}

output "firewall_untrust_public_ip" {
  description = "GlobalProtect clientless VPN portal/gateway address — what end users browse to. Feed this into phase2-panos-config's firewall_untrust_ip variable."
  value       = azurerm_public_ip.fw_untrust.ip_address
}

output "globalprotect_clientless_portal_url" {
  description = "URL to log into the GlobalProtect clientless VPN portal."
  value       = "https://${azurerm_public_ip.fw_untrust.ip_address}/"
}

output "public_subnet_cidr" {
  description = "Untrust subnet CIDR. Feed this into phase2-panos-config's public_subnet_cidr variable (it derives the untrust interface/gateway IPs via cidrhost())."
  value       = azurerm_subnet.public.address_prefixes[0]
}

output "internal_subnet_cidr" {
  description = "Trust subnet CIDR. Feed this into phase2-panos-config's internal_subnet_cidr variable (it derives the trust interface IP via cidrhost())."
  value       = azurerm_subnet.internal.address_prefixes[0]
}

output "linux_target_internal_ip" {
  description = "Internal IP of the Linux scan-target VM, reachable only via the firewall's trust interface."
  value       = azurerm_network_interface.linux_target.private_ip_address
}

output "windows_target_internal_ip" {
  description = "Internal IP of the Windows scan-target VM, reachable only via the firewall's trust interface."
  value       = azurerm_network_interface.windows_target.private_ip_address
}

output "known_open_ports" {
  description = "Ground-truth open ports per target VM, confirmed via `ss`/`Get-NetTCPConnection` on the live VMs (not just assumed from what the bootstrap scripts install) - for validating scanner results."
  value = {
    linux_target = {
      ip = azurerm_network_interface.linux_target.private_ip_address
      # 443 deliberately excluded: nginx has no TLS binding configured, only port 80
      # actually listens.
      ports = [22, 53, 80, 111, 389, 636, 5432, 6379]
    }
    windows_target = {
      ip = azurerm_network_interface.windows_target.private_ip_address
      # 443/5986 excluded: no cert configured for IIS HTTPS or WinRM HTTPS, neither
      # actually listens. 137/138 excluded: NetBIOS Name/Datagram service are UDP-only
      # - only 139 (NetBIOS Session Service) is real TCP. 464/593/9389 added: real
      # listeners from AD DS (Kerberos password change, RPC over HTTP, AD Web
      # Services) that were missing from the original assumed list.
      ports = [53, 80, 88, 135, 139, 389, 445, 464, 593, 636, 3268, 3269, 3389, 5985, 9389]
    }
  }
}
