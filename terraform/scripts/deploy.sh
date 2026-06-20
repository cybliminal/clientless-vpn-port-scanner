#!/usr/bin/env bash
# Master orchestrator for the full environment: Azure marketplace terms -> phase1
# infra apply -> wait for PAN-OS -> manual-step replacements (dns-proxy, clientless
# app, content updates + reboot) -> phase2 panos-config apply (which creates the
# GlobalProtect config and commits it).
#
# This sequence exists because of three hard dependencies discovered the hard way:
#   1. The panos provider needs the firewall's mgmt IP, which doesn't exist until
#      phase1 is applied - hence two separate Terraform roots/states, not one.
#   2. panos_dns_proxy and the Clientless App object have no Terraform resource at
#      all in this provider version - they must exist before phase2's commit, so
#      they're created via the API in between the two terraform applies.
#   3. The GlobalProtect Clientless VPN content update needs Apps and Threats
#      content installed first, and the feature doesn't actually start serving
#      traffic until the firewall is rebooted afterward - both before phase2 (so
#      the eventual commit's "Clientless VPN Content is missing" warning doesn't
#      show up, and so the portal is actually live when you go test it).
#
# Usage: scripts/deploy.sh [--tfvars-file PATH] [--auto-approve]
#
# By default this asks for confirmation at each `terraform apply` (the normal
# Terraform prompt), since these are real cloud resources with real cost. Pass
# --auto-approve for a genuinely unattended run.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" # terraform/ root

tfvars_file="terraform.tfvars"
apply_flags=()

while [[ $# -gt 0 ]]; do
    case "$1" in
    --tfvars-file)
        tfvars_file="$2"
        shift 2
        ;;
    --auto-approve)
        apply_flags+=("-auto-approve")
        shift
        ;;
    *)
        echo "Unknown argument: $1" >&2
        echo "Usage: scripts/deploy.sh [--tfvars-file PATH] [--auto-approve]" >&2
        exit 1
        ;;
    esac
done

if [[ ! -f "$tfvars_file" ]]; then
    echo "tfvars file not found: $tfvars_file (copy phase1-infra/example.tfvars + phase2-panos-config/example.tfvars into one file and fill in real values)" >&2
    exit 1
fi

for bin in terraform az python3 openssl curl; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "Required tool not found in PATH: $bin" >&2
        exit 1
    fi
done

# Only handles simple `key = "value"` scalars (quoted or bare) - good enough for
# what's extracted below. Don't use this on list/map-valued variables like
# admin_source_cidrs; it won't parse them correctly.
tfvar_get() {
    # `|| true` matters: grep exits 1 when a variable isn't set in the tfvars file
    # (relying on its Terraform-side default instead, e.g. panos_admin_username),
    # and pipefail+set -e would otherwise abort the whole script on that, not just
    # this one lookup.
    grep -E "^[[:space:]]*$1[[:space:]]*=" "$tfvars_file" | head -1 |
        sed -E 's/^[^=]*=[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/' || true
}

vmseries_image_sku=$(tfvar_get vmseries_image_sku)
name_prefix=$(tfvar_get name_prefix)
panos_admin_username=$(tfvar_get panos_admin_username)
gp_user_username=$(tfvar_get gp_user_username)
clientless_app_name=$(tfvar_get clientless_app_name)

vmseries_image_sku="${vmseries_image_sku:-bundle2}"
name_prefix="${name_prefix:-vst}"
panos_admin_username="${panos_admin_username:-panadmin}"
gp_user_username="${gp_user_username:-alice}"
clientless_app_name="${clientless_app_name:-cybliminal}"

# Exported (not written to disk) so the scripts below can read it without it ever
# appearing in argv/process listings - see scripts/lib.sh for how it's then piped
# into curl rather than interpolated into a command line.
export PANOS_API_PASSWORD
PANOS_API_PASSWORD=$(tfvar_get panos_admin_password)
trap 'unset PANOS_API_PASSWORD PANOS_API_KEY' EXIT

echo "==> [1/7] Accepting marketplace terms for ${vmseries_image_sku}"
scripts/01-accept-marketplace-terms.sh "$vmseries_image_sku"

echo "==> [2/7] phase1-infra: applying Azure infrastructure"
terraform -chdir=phase1-infra init -input=false
terraform -chdir=phase1-infra apply -input=false -var-file="../${tfvars_file}" "${apply_flags[@]}"

mgmt_ip=$(terraform -chdir=phase1-infra output -raw firewall_mgmt_public_ip)
untrust_ip=$(terraform -chdir=phase1-infra output -raw firewall_untrust_public_ip)
public_subnet_cidr=$(terraform -chdir=phase1-infra output -raw public_subnet_cidr)
internal_subnet_cidr=$(terraform -chdir=phase1-infra output -raw internal_subnet_cidr)

echo "==> [3/7] Waiting for PAN-OS mgmt API at ${mgmt_ip}"
scripts/02-wait-for-panos-mgmt.sh "$mgmt_ip"

echo "==> [4/7] Creating dns-proxy object"
scripts/03-create-dns-proxy.sh "$mgmt_ip" "$panos_admin_username" "$name_prefix"

echo "==> [5/7] Creating clientless app '${clientless_app_name}'"
scripts/04-create-clientless-app.sh "$mgmt_ip" "$panos_admin_username" "$clientless_app_name"

echo "==> [6/7] Installing content updates (Apps/Threats, GlobalProtect Clientless VPN) + reboot"
scripts/05-install-content-updates.sh "$mgmt_ip" "$panos_admin_username"

echo "==> [7/7] phase2-panos-config: applying PAN-OS GlobalProtect configuration"
terraform -chdir=phase2-panos-config init -input=false
terraform -chdir=phase2-panos-config apply -input=false \
    -var-file="../${tfvars_file}" \
    -var="firewall_mgmt_ip=${mgmt_ip}" \
    -var="firewall_untrust_ip=${untrust_ip}" \
    -var="public_subnet_cidr=${public_subnet_cidr}" \
    -var="internal_subnet_cidr=${internal_subnet_cidr}" \
    "${apply_flags[@]}"

echo
echo "Done."
echo "Firewall Management: https://${mgmt_ip}/"
echo "Log in as '${panos_admin_username}' (password in ${tfvars_file})."
echo "GlobalProtect clientless VPN portal: https://${untrust_ip}/"
echo "Log in as '${gp_user_username}' (password in ${tfvars_file})."
