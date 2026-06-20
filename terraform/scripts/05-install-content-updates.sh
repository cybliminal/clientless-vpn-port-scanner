#!/usr/bin/env bash
# Installs the dynamic content needed for the GlobalProtect Clientless VPN feature
# to actually serve traffic - this is separate from (and not covered by) the
# GlobalProtect Gateway/Portal license itself. Without it, PAN-OS commits succeed
# but warn "Clientless VPN Content is missing. The feature is not enabled."
#
# Sequence (order matters - the GlobalProtect Clientless VPN content update was
# observed to require Applications and Threats content already installed first):
#   1. Download + install latest "content" (Applications and Threats)
#   2. Download + install latest "global-protect-clientless-vpn" content
#   3. Reboot the firewall - the clientless VPN portal was observed to keep 404ing
#      on /global-protect/login.esp until a full reboot, even after content install
#      and a commit both completed successfully.
#
# Requires PANOS_API_PASSWORD exported in the environment.
#
# Usage: 05-install-content-updates.sh <mgmt_ip> <username>
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib.sh"

mgmt_ip="${1:?Usage: 05-install-content-updates.sh <mgmt_ip> <username>}"
username="${2:?missing username}"
: "${PANOS_API_PASSWORD:?PANOS_API_PASSWORD must be exported}"

export PANOS_API_KEY
PANOS_API_KEY=$(panos_keygen "$mgmt_ip" "$username")

ensure_latest_content_installed "$mgmt_ip" "content"
ensure_latest_content_installed "$mgmt_ip" "global-protect-clientless-vpn"

panos_reboot_and_wait "$mgmt_ip"

echo "Content updates installed and firewall rebooted." >&2
