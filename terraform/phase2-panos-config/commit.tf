# PAN-OS uses a candidate/running config model: panos_* resources only edit the
# candidate config via the API. Without an explicit commit, those changes are not
# applied to the dataplane and aren't guaranteed durable (a resource that looks
# "created" in Terraform's eyes may not actually be doing anything on the live
# firewall, and refreshes can show it as missing again later).
action "panos_commit" "main" {
  config {
    description = "Terraform managed commit"
    force       = true
  }
}

# Fires the commit whenever ANY panos_* resource changes in ANY way, not just by
# name. A name-keyed `input` map (the first attempt here) missed changes to
# attributes within an already-named resource (e.g. adding protocol_settings to an
# existing ssl_tls_service_profile) since the name itself didn't change - that left
# a real commit-blocking change sitting uncommitted. replace_triggered_by forces
# this resource to be destroyed and recreated (firing after_create) on ANY change
# to any of the referenced resources, regardless of which attribute changed.
resource "terraform_data" "panos_commit_trigger" {
  # Static - replace_triggered_by below is what actually drives recreation.
  input = "panos-commit-trigger"

  lifecycle {
    replace_triggered_by = [
      panos_certificate_import.gp,
      panos_ssl_tls_service_profile.gp,
      panos_ethernet_interface.untrust,
      panos_ethernet_interface.trust,
      panos_zone.untrust,
      panos_zone.trust,
      panos_virtual_router_interface.untrust,
      panos_virtual_router_interface.trust,
      panos_virtual_router_static_route_ipv4.default_route,
      panos_nat_policy_rules.trust_to_untrust,
      panos_security_policy_rules.rules,
      panos_local_user.gp_user,
      panos_authentication_profile.gp,
      panos_globalprotect_portal.portal,
      panos_globalprotect_gateway.gateway,
    ]

    action_trigger {
      events  = [after_create, after_update]
      actions = [action.panos_commit.main]
    }
  }
}
