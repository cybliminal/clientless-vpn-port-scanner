#!/usr/bin/env bash
# Accepts the Azure Marketplace legal terms for the VM-Series image plan. Required
# once per subscription+sku before the firewall VM can be created at all. Idempotent
# - accepting already-accepted terms is harmless.
#
# Usage: 01-accept-marketplace-terms.sh <sku>
set -euo pipefail

sku="${1:?Usage: 01-accept-marketplace-terms.sh <sku>}"

echo "Accepting marketplace terms for paloaltonetworks/vmseries-flex/${sku}..." >&2
az vm image terms accept --publisher paloaltonetworks --offer vmseries-flex --plan "$sku"
