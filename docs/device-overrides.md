# Per-device variable overrides

Each role template takes explicit defaults for `$wan_ip`, `$lan_ip`,
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
`prod`, gets its own `palo.json` and override file.

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
unassigned. Supply the required values before pushing.

Variable names are discovered from the assigned stack and its templates.
JSON keys omit the `$` prefix. Stack definitions take precedence, followed by
member templates in their configured order. A new variable such as
`loopback_ip` requires no Python change: create it in Terraform, apply its
Panorama definition, and add the device value to the JSON file.

Validation uses the inherited type, not the variable's name:

- `ip-netmask`: IPv4 or IPv6 host addresses, with or without a prefix.
- `as-number`: decimal strings from `"1"` to `"4294967294"`.
- `null`: remove the existing override and inherit the template value.

Unknown names, unsupported types, malformed values, and existing overrides
whose types conflict with their definitions fail before writes. Other types,
including secret or structured variables, are not supported by this helper.
The literal string `"None"` is not accepted as an IP/ASN override value.

IP Netmask metadata does not distinguish interface addresses from peer IPs or
router IDs. Supply prefixes for interfaces (typically `/32` for IPv4 loopbacks)
and bare addresses for router IDs or peers as required by their consumers.
Panorama validates those usage constraints. The helper no longer infers them
from field names or enforces a relationship between WAN and gateway fields.

The helper validates every selected target and its stack assignment before
writing, then repeats the preview to detect definition/value changes. It also
rechecks each old value before writing and reads back each result. This is not
an atomic transaction or a Panorama configuration lock. If a write or
verification fails, earlier writes may remain in candidate configuration.
Run `overrides plan` again to reconcile; there is no automatic retry, commit,
push, or rollback.

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
interface's `wan_ip` address/prefix override. See [GRE setup](gre.md) for
per-device assignments.

## BGP variables

The current templates define AS Number variables named `local_bgp_asn`,
`remote_bgp_asn`, `spoke_a_remote_bgp_asn`, and `spoke_b_remote_bgp_asn`.
It writes these with Panorama's `as-number` type and rejects a mismatched
existing override type. Values must be strings from `"1"` to `"4294967294"`.

`bgp_router_id`, `remote_bgp_peer_ip`, `spoke_a_remote_bgp_peer_ip`, and
`spoke_b_remote_bgp_peer_ip` require bare IPv4 addresses. The tunnel variables
still require prefixes and supply BGP's local interface addresses directly.
`bgp_password` belongs in the Terraform network inputs, not this JSON file.
See [BGP over GRE](gre.md#bgp-over-gre) for the peer layout and ASN assignments.
