# Phase 2: PAN-OS configuration (zones, interfaces, NAT, security policy,
# GlobalProtect portal/gateway, commit). Separate Terraform root/state from
# ../phase1-infra on purpose: the panos provider needs the firewall's mgmt IP,
# which doesn't exist until phase 1 finishes, and Terraform can't plan a provider
# whose connection details come from a resource created in the same run. Splitting
# into two roots turns that into a plain input variable instead of a chicken-and-egg
# problem. See ../README.md and ../scripts/deploy.sh for the full sequence.

terraform {
  required_version = ">= 1.5"

  required_providers {
    panos = {
      source  = "PaloAltoNetworks/panos"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

# skip_verify_certificate is set because PAN-OS ships with a self-signed mgmt cert
# that has no IP SAN for the firewall's public IP. Acceptable for this throwaway test
# lab; do not carry this into a real environment without importing a proper cert.
provider "panos" {
  hostname                = var.firewall_mgmt_ip
  username                = var.panos_admin_username
  password                = var.panos_admin_password
  skip_verify_certificate = true
}
