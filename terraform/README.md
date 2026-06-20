# Test environment: Azure VM-Series GlobalProtect clientless VPN + scan targets

Stands up an Azure VM-Series firewall configured as a GlobalProtect clientless
VPN gateway, with a Linux and a Windows VM with a spread of common services.

## Prerequisites

- An Azure subscription, and the
  [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) logged in
  (`az login`) as a user with permission to create resource groups, VMs, and
  networking in that subscription.
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.9 (the
  `panos_commit` action used here needs Terraform's action support).
- `python3`, `openssl`, `curl` on the machine running the scripts.
- An SSH key pair (for the Linux target VM's admin login).
- Your own public IP/CIDR (or wherever you'll run `terraform`/the scripts from)
  - the firewall's mgmt interface is locked down to an explicit allow-list.

You don't need to manually accept the Azure Marketplace terms for the VM-Series
image beforehand - `scripts/deploy.sh` does that for you as its first step.

## Quick start

```sh
cp example.tfvars terraform.tfvars   # fill in the real values (see below)
./scripts/deploy.sh                   # asks for confirmation at each terraform apply
./scripts/deploy.sh --auto-approve    # fully unattended
```

`deploy.sh` accepts marketplace terms, stands up the Azure infrastructure, waits
for PAN-OS to finish booting, creates the couple of PAN-OS objects that have no
Terraform resource, installs the GlobalProtect Clientless VPN content update and
reboots the firewall, then applies the PAN-OS configuration (zones, NAT,
security policy, GlobalProtect) and commits it.

It takes a while end to end - mostly waiting on the firewall's first boot and
the Windows VM's AD DS promotion (each can take 10-20 minutes).

To tear everything down:
`./scripts/destroy.sh` (same `--auto-approve` flag available).

## Configuration

Fill in `terraform.tfvars` from `example.tfvars`.
At minimum, set:

| Variable | What it's for |
|---|---|
| `admin_source_cidrs` | CIDR(s) allowed to reach the firewall's mgmt GUI/API/SSH. Narrow this to your own IP - the default in `example.tfvars` may be wide open. |
| `ssh_public_key` | Your SSH public key, for the Linux target VM. |

No defaults are set for these secrets - supply them via `terraform.tfvars` or
`-var`:

- `ssh_public_key`
- `windows_admin_password`
- `ad_safe_mode_password`
- `panos_admin_password`
- `ldap_admin_password`
- `redis_password`
- `gp_user_password` (GlobalProtect clientless VPN login for `gp_user_username`,
  default `alice`)

Default usernames (override via the matching `*_username` variable):

| What | Variable | Default |
|---|---|---|
| PAN-OS admin (GUI/SSH/API) | `panos_admin_username` | `panadmin` |
| Linux target VM admin | `linux_admin_username` | `azureuser` |
| Windows target VM admin | `windows_admin_username` | `azureadmin` |
| GlobalProtect clientless VPN login | `gp_user_username` | `alice` |

## Layout

- `phase1-infra/` - Azure network, firewall VM, scan-target VMs.
  Its own Terraform state.
- `phase2-panos-config/` - PAN-OS zones, NAT, security policy, GlobalProtect
  portal/gateway, and the commit that applies it all.
  Its own state, separate from phase 1, because the `panos` provider needs the
  firewall's mgmt IP as an input (which doesn't exist until phase 1 finishes)
  rather than a cross-resource reference within one state.
- `scripts/` - `deploy.sh`/`destroy.sh` orchestrate both phases plus a few
  PAN-OS setup steps that have no Terraform resource (a DNS proxy object and a
  Clientless App object) and the GlobalProtect Clientless VPN content update.
  `lib.sh` holds the shared PAN-OS XML API helpers; credentials travel as
  exported environment variables, piped into `curl` via stdin, never as a
  literal value in argv, to keep them out of shell history/process listings.

## After deploying

`terraform -chdir=phase1-infra output` shows the firewall's mgmt/untrust public
IPs, the portal URL, both target VMs' internal IPs, and `known_open_ports` - the
confirmed (not just assumed) ground-truth port list for each target VM, useful
for checking scanner results against.
Log into the GlobalProtect portal at `globalprotect_clientless_portal_url` as
`gp_user_username` to confirm clientless VPN is actually serving traffic before
relying on this environment for testing.
