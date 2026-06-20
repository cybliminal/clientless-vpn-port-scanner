#!/usr/bin/env bash
# Tears down both phases in the correct order: phase2 (panos config) must be
# destroyed first, while the firewall is still up and the panos provider can still
# reach it to issue delete calls; phase1 (the firewall VM itself) goes last.
#
# Usage: scripts/destroy.sh [--tfvars-file PATH] [--auto-approve]
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" # terraform/ root

tfvars_file="terraform.tfvars"
destroy_flags=()

while [[ $# -gt 0 ]]; do
  case "$1" in
  --tfvars-file)
    tfvars_file="$2"
    shift 2
    ;;
  --auto-approve)
    destroy_flags+=("-auto-approve")
    shift
    ;;
  *)
    echo "Unknown argument: $1" >&2
    echo "Usage: scripts/destroy.sh [--tfvars-file PATH] [--auto-approve]" >&2
    exit 1
    ;;
  esac
done

if [[ -d phase2-panos-config/.terraform ]] || [[ -f phase2-panos-config/terraform.tfstate ]]; then
  echo "==> [1/2] phase2-panos-config: destroying PAN-OS configuration"
  mgmt_ip=$(terraform -chdir=phase1-infra output -raw firewall_mgmt_public_ip 2>/dev/null || true)
  untrust_ip=$(terraform -chdir=phase1-infra output -raw firewall_untrust_public_ip 2>/dev/null || true)
  public_subnet_cidr=$(terraform -chdir=phase1-infra output -raw public_subnet_cidr 2>/dev/null || true)
  internal_subnet_cidr=$(terraform -chdir=phase1-infra output -raw internal_subnet_cidr 2>/dev/null || true)

  terraform -chdir=phase2-panos-config destroy -input=false \
    -var-file="../${tfvars_file}" \
    -var="firewall_mgmt_ip=${mgmt_ip}" \
    -var="firewall_untrust_ip=${untrust_ip}" \
    -var="public_subnet_cidr=${public_subnet_cidr}" \
    -var="internal_subnet_cidr=${internal_subnet_cidr}" \
    "${destroy_flags[@]}"
else
  echo "==> [1/2] phase2-panos-config: no state found, skipping"
fi

echo "==> [2/2] phase1-infra: destroying Azure infrastructure"
terraform -chdir=phase1-infra destroy -input=false -var-file="../${tfvars_file}" "${destroy_flags[@]}"

echo "Done."
