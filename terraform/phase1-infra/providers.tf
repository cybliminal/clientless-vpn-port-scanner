# Phase 1: Azure infrastructure only (network, firewall VM, scan-target VMs). No
# panos provider here - it needs the firewall's mgmt IP, which doesn't exist until
# this phase finishes, so PAN-OS configuration lives entirely in ../phase2-panos-config
# as a separate Terraform root with its own state. See ../README.md for why.

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Authenticates using the ambient `az login` session (no explicit credentials block).
provider "azurerm" {
  features {}
}
