# Copy to terraform.tfvars (gitignored) and fill in the real values, or pass each
# sensitive value with -var at apply time instead of writing it to disk.
#
# This file is shared with ../phase2-panos-config/example.tfvars for the variables
# both phases need (name_prefix, panos_admin_username/password) - keep them in sync,
# or just point both `terraform apply` invocations at one shared tfvars file (see
# ../README.md and ../scripts/deploy.sh, which does this automatically).

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

ad_domain_name = "example.test"
ldap_domain    = "example.test"

vmseries_image_sku     = "bundle2"
vmseries_image_version = "11.2.12"
vmseries_vm_size       = "Standard_D3_v2"
target_vm_size         = "Standard_B2s"
