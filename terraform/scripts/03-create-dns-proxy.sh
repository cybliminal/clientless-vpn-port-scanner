#!/usr/bin/env bash
# Creates the dns-proxy object the GlobalProtect portal's clientless_vpn.dns_proxy
# references. panos_dns_proxy's location schema only supports template/template_stack
# (Panorama-managed) in the panos provider version this project uses, not a
# standalone NGFW, so there's no Terraform resource for this - it's created directly
# via the XML API. Idempotent (action=set upserts).
#
# Requires PANOS_API_PASSWORD exported in the environment.
#
# Usage: 03-create-dns-proxy.sh <mgmt_ip> <username> <name_prefix> [primary_dns]
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib.sh"

mgmt_ip="${1:?Usage: 03-create-dns-proxy.sh <mgmt_ip> <username> <name_prefix> [primary_dns]}"
username="${2:?missing username}"
name_prefix="${3:?missing name_prefix}"
primary_dns="${4:-168.63.129.16}" # Azure's recursive DNS resolver
: "${PANOS_API_PASSWORD:?PANOS_API_PASSWORD must be exported}"

export PANOS_API_KEY
PANOS_API_KEY=$(panos_keygen "$mgmt_ip" "$username")

dns_proxy_name="${name_prefix}-gp-dns-proxy"

element_file=$(mktemp)
trap 'rm -f "$element_file"' EXIT
printf '<entry name="%s"><enabled>yes</enabled><default><primary>%s</primary></default></entry>' \
  "$dns_proxy_name" "$primary_dns" >"$element_file"

xpath="/config/devices/entry[@name='localhost.localdomain']/network/dns-proxy"
result=$(panos_api_set "$mgmt_ip" "$xpath" "$element_file")

if ! echo "$result" | grep -q 'status="success"'; then
  echo "Failed to create dns-proxy '${dns_proxy_name}': $result" >&2
  exit 1
fi

echo "dns-proxy '${dns_proxy_name}' set (primary=${primary_dns})" >&2
