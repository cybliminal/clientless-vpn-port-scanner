# Copy to terraform.tfvars (gitignored) and fill in the real values, or pass each
# sensitive value with -var at apply time instead of writing it to disk.
#
# name_prefix, panos_admin_username, panos_admin_password must match what you used
# in ../phase1-infra/terraform.tfvars - see ../README.md and ../scripts/deploy.sh,
# which read one shared tfvars file for both phases automatically.
#
# firewall_mgmt_ip, firewall_untrust_ip, public_subnet_cidr, internal_subnet_cidr
# come from phase1-infra's outputs - deploy.sh injects these automatically via -var.
# If running phase2 by hand, get them with:
#   terraform -chdir=../phase1-infra output -raw firewall_mgmt_public_ip
#   terraform -chdir=../phase1-infra output -raw firewall_untrust_public_ip
#   terraform -chdir=../phase1-infra output -raw public_subnet_cidr
#   terraform -chdir=../phase1-infra output -raw internal_subnet_cidr

name_prefix = "vst"

# Required, no defaults — supply via terraform.tfvars (gitignored) or -var:
# panos_admin_password = ""
# gp_user_password      = ""
# firewall_mgmt_ip       = ""
# firewall_untrust_ip    = ""
# public_subnet_cidr     = ""
# internal_subnet_cidr   = ""

gp_user_username    = "alice"
clientless_app_name = "cybliminal"
