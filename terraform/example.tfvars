# Shared tfvars for scripts/deploy.sh, which feeds this same file to both
# phase1-infra and phase2-panos-config via -var-file (each phase just ignores
# variables it doesn't declare - harmless warnings, not errors). Copy this to
# terraform.tfvars (gitignored) and fill in the real values, or pass each
# sensitive value with -var at apply time instead of writing it to disk.

region              = "australiaeast"
resource_group_name = "rg-vpn-scanner-test"
name_prefix         = "vst"

# Narrow this to your own IP/CIDR(s) before applying — default ["*"] exposes the
# firewall's mgmt GUI/SSH to the internet. Add more entries for other places that
# need access (e.g. a CI/sandbox environment running terraform).
admin_source_cidrs = ["*"]

ssh_public_key = "ssh-ed25519 AAAA... you@example.com"

linux_admin_username   = "azureuser"
windows_admin_username = "azureadmin"

# Required, no defaults — supply via terraform.tfvars (gitignored) or -var:
# windows_admin_password = ""
# ad_safe_mode_password  = ""
# panos_admin_password   = ""
# ldap_admin_password    = ""
# redis_password         = ""
# gp_user_password       = ""

ad_domain_name = "example.test"
ldap_domain    = "example.test"

# GlobalProtect clientless VPN portal login (local PAN-OS user database).
gp_user_username = "alice"

vmseries_image_sku     = "bundle2"
vmseries_image_version = "11.2.12"
vmseries_vm_size       = "Standard_D3_v2"
target_vm_size         = "Standard_B2s"

# Clientless App granted to all users (phase2-panos-config + scripts/04-create-clientless-app.sh).
clientless_app_name = "cybliminal"
