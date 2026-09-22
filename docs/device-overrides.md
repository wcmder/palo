# Per-device variable overrides

The shared template takes explicit defaults for `$wan_ip`, `$lan_ip`,
`$mgmt_ip`, and `$default_gateway` from root tfvars. Interface addresses
are complete address/prefix strings or `"None"` for unassigned variables.
They pass through directly; missing address fields fail evaluation.
Terraform manages the shared device group, template, stack, interfaces,
and device assignments. The `palo` XML API helper manages the individual
firewall values that appear in **Panorama > Managed Devices > Summary >
Variables**.

Create `env/dev/device_overrides.json` using the following structure:

```json
{
  "paa": {
    "serial": "PA_A_SERIAL",
    "template_stack": "spoke-stack",
    "var": {
      "wan_ip": "10.0.1.2/24",
      "lan_ip": "10.1.1.2/24",
      "default_gateway": "10.0.1.1"
    }
  },
  "pab": {
    "serial": "PA_B_SERIAL",
    "template_stack": "spoke-stack",
    "var": {
      "wan_ip": "10.0.2.2/24",
      "lan_ip": "10.2.1.2/24",
      "default_gateway": "10.0.2.1"
    }
  }
}
```

Replace example serials and addresses. Both serials must already be assigned
to `spoke-stack` by the Terraform `template_stacks.spoke.serials` list. The
shared container names are the key in `device_groups`,
`templates.<role>.name`, and `template_stacks.spoke.name`. Template defaults
are under `templates.<role>.var`; this JSON file still holds per-device values.
A stack can serve many devices, and multiple stacks can reference the same
owning role template. The JSON selects the stack and serial for each override.
The dev's local JSON file was populated from
PA-A's existing GUI overrides; it is ignored by Git.

## Commands

From any directory with the workspace CLI activated:

```bash
# Create/update shared configuration and serial assignments first.
palo dev plan
palo dev apply

# Read candidate overrides and preview differences. No configuration writes.
palo dev overrides plan

# Apply and read back changed candidate overrides. No commit or push.
palo dev overrides apply

# Commit and push using the existing Terraform action.
palo dev apply -invoke='module.deployment.action.panos_commit.commit_and_push["spoke/spoke"]'
```

`overrides` is a Python command in `palo`, not a Terraform command or resource.
It reads `device_overrides.json`, not Terraform `.auto.tfvars` inputs.
`terraform plan` does
not display these API-managed changes. Run override plan/apply after Terraform
configuration changes and before commit/push, because both systems touch the
stack configuration. The helper's comparison is against **candidate** values;
"No changes" does not mean the values have been committed or pushed.

To update one device or use another input file:

```bash
palo dev overrides plan --device paa
palo dev overrides apply --device paa
palo dev overrides plan --file device_overrides.staging.json
```

Relative file paths resolve under `env/dev`, regardless of the shell's current
directory. Absolute paths are also accepted. Each future environment, such as
`dev2`, gets its own `palo.json` and override file.

`--device paa` limits **override writes only**. The existing `spoke` commit/push
action still targets every serial in that Terraform entry. Use Panorama's
push selection if you need to push to just one of those devices.

## Updates and resets

Only listed variables are managed. Omitting a variable or removing a device
from the JSON file leaves its existing override unchanged. To explicitly
remove an override and resume inheritance, use JSON `null`, for example:

```json
"var": { "wan_ip": null }
```

If the inherited template value is `None`, the reset leaves that variable
unassigned. Supply the required values before pushing. Override IPs require
CIDR notation; the gateway is an IPv4 address. When both WAN IP and gateway
are provided, the helper checks they are different addresses in the same subnet.

The helper validates every selected target before writing, checks that the
serial belongs to the stack and the variable is defined as IP Netmask, then
updates only the selected variable entries. It rechecks each old value before
writing and reads back each result. This is not an atomic transaction or a
Panorama configuration lock. If a write or verification fails, earlier writes
may remain in candidate configuration. Run `overrides plan` again to reconcile;
there is no automatic retry, commit, push, or rollback.

## API and authentication

The path was verified against the GUI-created PA-A overrides on the dev
Panorama:

```text
/config/devices/entry[@name='localhost.localdomain']/template-stack/entry[@name='spoke-stack']/devices/entry[@name='SERIAL']/variable/entry[@name='$wan_ip']
```

The helper uses HTTPS POST to `/api/`, obtains its credentials from the same
OS keyring configuration as the Terraform launcher, generates an API key in
memory, and sends that key in `X-PAN-KEY`. Credentials/keys are not written to
Terraform state, saved plans, command arguments, or configuration files. API
access requires the account's XML API configuration permissions. The helper
honors `skip_verify_certificate` from the environment's `palo.json`.

- [PAN-OS configuration API](https://docs.paloaltonetworks.com/ngfw/api/pan-os-xml-api-request-types-and-actions/configuration-api)
- [API authentication](https://docs.paloaltonetworks.com/ngfw/api/api-authentication-and-security)

## GRE variables

The override helper also accepts `tunnel_ip`, `spoke_a_tunnel_ip`,
and `spoke_b_tunnel_ip`.

Tunnel interface addresses require prefixes. GRE sources use the WAN
interface's `wan_ip` address/prefix override. See [GRE setup](gre.md) for per-device assignments.
