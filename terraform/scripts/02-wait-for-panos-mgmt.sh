#!/usr/bin/env bash
# Waits for the firewall's mgmt HTTPS API to respond. PAN-OS first boot commonly
# takes 10-20+ minutes even though the Azure VM itself shows as "running" well
# before that.
#
# Usage: 02-wait-for-panos-mgmt.sh <mgmt_ip>
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib.sh"

mgmt_ip="${1:?Usage: 02-wait-for-panos-mgmt.sh <mgmt_ip>}"

wait_for_panos_mgmt "$mgmt_ip" 90 10
