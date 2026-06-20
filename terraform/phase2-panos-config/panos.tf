# PAN-OS configuration for the standalone firewall connected to directly (no
# Panorama), using the panos provider (v2.x, Plugin Framework). Covers interfaces,
# zones, virtual router, NAT, security policy, a self-signed certificate, a local
# user + authentication profile, and the GlobalProtect portal/gateway with clientless
# VPN enabled.
#
# Two things this depends on that have no Terraform resource and must be created by
# ../scripts/03-create-dns-proxy.sh and ../scripts/04-create-clientless-app.sh before
# this is applied:
#   - dns_proxy ("${var.name_prefix}-gp-dns-proxy"): panos_dns_proxy's location schema
#     only supports template/template_stack (Panorama-managed), not a standalone NGFW.
#   - clientless app (var.clientless_app_name): the provider has no resource for this
#     object type (vsys1/global-protect/clientless-app) at all.

locals {
  vsys_location   = { vsys = { name = "vsys1" } }
  ngfw_location   = { ngfw = {} }
  default_vr_name = "default"
}

resource "tls_private_key" "gp" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "gp" {
  private_key_pem = tls_private_key.gp.private_key_pem

  subject {
    common_name  = var.firewall_untrust_ip
    organization = "vpn-scanner-test"
  }

  validity_period_hours = 24 * 365
  is_ca_certificate     = true
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "cert_signing",
  ]
}

resource "panos_certificate_import" "gp" {
  location = local.vsys_location
  name     = "${var.name_prefix}-gp-cert"

  local = {
    pem = {
      certificate = tls_self_signed_cert.gp.cert_pem
      private_key = tls_private_key.gp.private_key_pem
    }
  }
}

resource "panos_ssl_tls_service_profile" "gp" {
  location    = { shared = {} }
  name        = "${var.name_prefix}-gp-ssl-profile"
  certificate = panos_certificate_import.gp.name

  protocol_settings = {
    allow_algorithm_aes_128_gcm = true
    allow_algorithm_aes_256_gcm = true
    allow_algorithm_ecdhe       = true
    allow_authentication_sha256 = true
    allow_authentication_sha384 = true
    min_version                 = "tls1-2"
    max_version                 = "tls1-2"
  }
}

resource "panos_ethernet_interface" "untrust" {
  location = { ngfw = {} }
  name     = "ethernet1/1"
  layer3 = {
    dhcp_client = {
      enable               = true
      create_default_route = false
    }
  }
}

resource "panos_ethernet_interface" "trust" {
  location = { ngfw = {} }
  name     = "ethernet1/2"
  layer3 = {
    ips = [{ name = "${cidrhost(var.internal_subnet_cidr, 4)}/${split("/", var.internal_subnet_cidr)[1]}" }]
  }
}

resource "panos_zone" "untrust" {
  location = local.vsys_location
  name     = "untrust"
  network  = { layer3 = [panos_ethernet_interface.untrust.name] }
}

resource "panos_zone" "trust" {
  location = local.vsys_location
  name     = "trust"
  network  = { layer3 = [panos_ethernet_interface.trust.name] }
}

# PAN-OS ships with a virtual router named "default" pre-created on every fresh
# firewall - there's no need to (and the provider has no clean way to) create or
# adopt that object itself. Attach interfaces to it by name instead of owning the
# parent panos_virtual_router resource, avoiding a delete+recreate dance entirely.
resource "panos_virtual_router_interface" "untrust" {
  location       = local.ngfw_location
  virtual_router = local.default_vr_name
  interface      = panos_ethernet_interface.untrust.name
}

resource "panos_virtual_router_interface" "trust" {
  location       = local.ngfw_location
  virtual_router = local.default_vr_name
  interface      = panos_ethernet_interface.trust.name
}

resource "panos_virtual_router_static_route_ipv4" "default_route" {
  location       = local.ngfw_location
  virtual_router = local.default_vr_name
  name           = "default-route"
  destination    = "0.0.0.0/0"
  interface      = panos_ethernet_interface.untrust.name
  nexthop = {
    ip_address = cidrhost(var.public_subnet_cidr, 1)
  }

  depends_on = [panos_virtual_router_interface.untrust]
}

resource "panos_nat_policy_rules" "trust_to_untrust" {
  location = local.vsys_location
  position = { where = "first" }

  rules = [{
    name                  = "snat-trust-to-untrust"
    source_zones          = [panos_zone.trust.name]
    destination_zone      = [panos_zone.untrust.name]
    source_addresses      = ["any"]
    destination_addresses = ["any"]
    service               = "any"

    source_translation = {
      dynamic_ip_and_port = {
        interface_address = {
          interface = panos_ethernet_interface.untrust.name
        }
      }
    }
  }]
}

resource "panos_security_policy_rules" "rules" {
  location = local.vsys_location
  position = { where = "first" }

  rules = [
    {
      name                  = "trust-to-untrust"
      source_zones          = [panos_zone.trust.name]
      destination_zones     = [panos_zone.untrust.name]
      source_addresses      = ["any"]
      destination_addresses = ["any"]
      applications          = ["any"]
      services              = ["application-default"]
      action                = "allow"
    },
    {
      name                  = "gp-clientless-to-trust"
      source_zones          = [panos_zone.untrust.name]
      destination_zones     = [panos_zone.trust.name]
      source_addresses      = ["any"]
      destination_addresses = ["any"]
      applications          = ["any"]
      services              = ["any"]
      action                = "allow"
    },
  ]
}

# panos_local_user's `password` argument writes whatever string you give it
# directly into PAN-OS's phash field instead of hashing it first (confirmed
# provider bug against PAN-OS 11.2 - plaintext ends up stored as the "hash").
# Precompute a real SHA-256-crypt hash ourselves and feed that in as `password`
# instead, since the provider just writes it through verbatim either way.
resource "random_id" "gp_user_salt" {
  byte_length = 6
}

data "external" "gp_user_phash" {
  program = ["python3", "${path.module}/../scripts/panos_password_hash.py"]
  query = {
    salt     = random_id.gp_user_salt.hex
    password = var.gp_user_password
  }
}

resource "panos_local_user" "gp_user" {
  location = local.vsys_location
  name     = var.gp_user_username
  password = data.external.gp_user_phash.result.hash
}

resource "panos_authentication_profile" "gp" {
  location = local.vsys_location
  name     = "${var.name_prefix}-gp-auth-profile"

  allow_list = ["all"]

  method = {
    local_database = {}
  }
}

resource "panos_globalprotect_portal" "portal" {
  location = local.vsys_location
  name     = "${var.name_prefix}-gp-portal"

  portal_config = {
    ssl_tls_service_profile = panos_ssl_tls_service_profile.gp.name
    local_address = {
      interface         = panos_ethernet_interface.untrust.name
      ip_address_family = "ipv4"
      ip = {
        ip = cidrhost(var.public_subnet_cidr, 4)
      }
    }
    client_auth = [
      {
        name                   = "${var.name_prefix}-gp-client-auth"
        authentication_profile = panos_authentication_profile.gp.name
      }
    ]
  }

  clientless_vpn = {
    hostname      = var.firewall_untrust_ip
    security_zone = panos_zone.untrust.name
    dns_proxy     = "${var.name_prefix}-gp-dns-proxy"

    apps_to_user_mapping = [
      {
        name                                       = "${var.name_prefix}-gp-all-users"
        applications                               = [var.clientless_app_name]
        source_user                                = ["any"]
        enable_custom_app_u_r_l_address_bar        = true
        display_global_protect_agent_download_link = false
      }
    ]
  }
}

resource "panos_globalprotect_gateway" "gateway" {
  location = local.vsys_location
  name     = "${var.name_prefix}-gp-gateway"

  ssl_tls_service_profile = panos_ssl_tls_service_profile.gp.name
  tunnel_mode             = false

  client_auth = [
    {
      name                   = "${var.name_prefix}-gp-client-auth"
      authentication_profile = panos_authentication_profile.gp.name
    }
  ]

  local_address = {
    interface         = panos_ethernet_interface.untrust.name
    ip_address_family = "ipv4"
    ip = {
      ip = cidrhost(var.public_subnet_cidr, 4)
    }
  }
}
