#!/usr/bin/env bash
# Creates a Clientless App object (vsys1/global-protect/clientless-app) and grants
# it to all users via apps_to_user_mapping in phase2-panos-config (which references
# it by name). The provider has no dedicated resource for this object type at all,
# so it's created directly via the XML API. Idempotent (action=set upserts).
#
# Without at least one Clientless App, GlobalProtect's clientless VPN feature has
# nothing to attach an apps_to_user_mapping entry to resulting in an error when
# trying to access the VPN.
#
# Requires PANOS_API_PASSWORD exported in the environment.
#
# Usage: 04-create-clientless-app.sh <mgmt_ip> <username> <app_name> [app_home_url]
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib.sh"

mgmt_ip="${1:?Usage: 04-create-clientless-app.sh <mgmt_ip> <username> <app_name> [app_home_url]}"
username="${2:?missing username}"
app_name="${3:?missing app_name}"
app_home_url="${4:-www.cybliminal.com}"
: "${PANOS_API_PASSWORD:?PANOS_API_PASSWORD must be exported}"

export PANOS_API_KEY
PANOS_API_KEY=$(panos_keygen "$mgmt_ip" "$username")

element_file=$(mktemp)
trap 'rm -f "$element_file"' EXIT
printf '<entry name="%s"><application-home-url>%s</application-home-url></entry>' \
    "$app_name" "$app_home_url" >"$element_file"

xpath="/config/devices/entry[@name='localhost.localdomain']/vsys/entry[@name='vsys1']/global-protect/clientless-app"
result=$(panos_api_set "$mgmt_ip" "$xpath" "$element_file")

if ! echo "$result" | grep -q 'status="success"'; then
    echo "Failed to create clientless-app '${app_name}': $result" >&2
    exit 1
fi

echo "clientless-app '${app_name}' set (home-url=${app_home_url})" >&2
