variable "name_prefix" {
  description = "Prefix applied to all resource names. Must match what was passed to phase1-infra."
  type        = string
  default     = "vst"
}

variable "panos_admin_username" {
  description = "PAN-OS admin username. Must match what was passed to phase1-infra (that's how the initial admin account got its password)."
  type        = string
  default     = "panadmin"
}

variable "panos_admin_password" {
  description = "PAN-OS admin password. Must match what was passed to phase1-infra."
  type        = string
  sensitive   = true
}

variable "firewall_mgmt_ip" {
  description = "Firewall mgmt public IP - from phase1-infra's firewall_mgmt_public_ip output."
  type        = string
}

variable "firewall_untrust_ip" {
  description = "Firewall untrust public IP - from phase1-infra's firewall_untrust_public_ip output."
  type        = string
}

variable "public_subnet_cidr" {
  description = "Untrust subnet CIDR - from phase1-infra's public_subnet_cidr output. Used to derive the untrust interface/gateway IPs via cidrhost()."
  type        = string
}

variable "internal_subnet_cidr" {
  description = "Trust subnet CIDR - from phase1-infra's internal_subnet_cidr output. Used to derive the trust interface IP via cidrhost()."
  type        = string
}

variable "gp_user_username" {
  description = "Local PAN-OS user database username for logging into the GlobalProtect clientless VPN portal."
  type        = string
  default     = "alice"
}

variable "gp_user_password" {
  description = "Password for the GlobalProtect local user (var.gp_user_username)."
  type        = string
  sensitive   = true
}

variable "clientless_app_name" {
  description = "Name of the Clientless App object (created by ../scripts/04-create-clientless-app.sh, no Terraform resource exists for this object type) to grant all users access to."
  type        = string
  default     = "cybliminal"
}
