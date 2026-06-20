variable "region" {
  description = "Azure region for all resources."
  type        = string
  default     = "australiaeast"
}

variable "resource_group_name" {
  description = "Resource group name for the test environment."
  type        = string
  default     = "rg-vpn-scanner-test"
}

variable "name_prefix" {
  description = "Prefix applied to all resource names. Must match what's passed to phase2-panos-config."
  type        = string
  default     = "vst"
}

variable "admin_source_cidrs" {
  description = "CIDRs allowed to reach the firewall's mgmt interface (HTTPS GUI/API, SSH). Narrow this to your own IP/CIDR(s) rather than leaving it open to the internet."
  type        = list(string)
  default     = ["*"]
}

variable "ssh_public_key" {
  description = "SSH public key (e.g. contents of ~/.ssh/id_ed25519.pub) used for the Linux target VM's admin user."
  type        = string
}

variable "linux_admin_username" {
  description = "Admin username for the Linux target VM."
  type        = string
  default     = "azureuser"
}

variable "windows_admin_username" {
  description = "Admin username for the Windows target VM."
  type        = string
  default     = "azureadmin"
}

variable "windows_admin_password" {
  description = "Admin password for the Windows target VM. Must meet Azure complexity requirements."
  type        = string
  sensitive   = true
}

variable "ad_safe_mode_password" {
  description = "DSRM/Safe Mode administrator password used when promoting the Windows VM to an Active Directory forest."
  type        = string
  sensitive   = true
}

variable "panos_admin_username" {
  description = "PAN-OS admin username, set via the Azure VM admin-credential bootstrap path. Must match what's passed to phase2-panos-config (the panos provider logs in with these same credentials)."
  type        = string
  default     = "panadmin"
}

variable "panos_admin_password" {
  description = "PAN-OS admin password. Must match what's passed to phase2-panos-config."
  type        = string
  sensitive   = true
}

variable "vmseries_image_sku" {
  description = "VM-Series marketplace image SKU. bundle2 includes GlobalProtect (bundle1 doesn't, which is why clientless VPN won't actually serve traffic on bundle1); confirm the exact id with `az vm image list-skus --publisher paloaltonetworks --offer vmseries-flex -l <region>` since Palo Alto periodically renames SKUs."
  type        = string
  default     = "bundle2"
}

variable "vmseries_image_version" {
  description = "VM-Series PAN-OS image version."
  type        = string
  default     = "11.2.12"
}

variable "vmseries_vm_size" {
  description = "VM size for the VM-Series firewall (D3_v2 is the minimum size PAN-OS supports)."
  type        = string
  default     = "Standard_D3_v2"
}

variable "target_vm_size" {
  description = "VM size for the Linux/Windows scan-target VMs."
  type        = string
  default     = "Standard_B2s"
}

variable "ldap_admin_password" {
  description = "Admin password for the Linux target VM's OpenLDAP directory."
  type        = string
  sensitive   = true
}

variable "ldap_domain" {
  description = "Domain used to seed the OpenLDAP directory on the Linux target VM (e.g. example.test)."
  type        = string
  default     = "example.test"
}

variable "redis_password" {
  description = "requirepass value for the Linux target VM's Redis instance."
  type        = string
  sensitive   = true
}

variable "ad_domain_name" {
  description = "Fully-qualified Active Directory domain name to create when promoting the Windows target VM to a forest (e.g. example.test)."
  type        = string
  default     = "example.test"
}
