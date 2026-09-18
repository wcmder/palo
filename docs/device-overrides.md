# Per-device variable overrides

The shared template keeps `$wan_ip`, `$lan_ip`, and `$default_gateway` set to
`None`. Terraform manages the shared device group, template, stack, interfaces,
and device assignments. The `palo` XML API helper manages the individual
firewall values that appear in **Panorama > Managed Devices > Summary > Variables**.

Create `env/lab/device_overrides.json` using
[`device_overrides.json.example`](../env/lab/device_overrides.json.example):

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
to `spoke-stack` by the Terraform `templates.spoke.serials` list. The shared container names are the key in `device_groups`,
`templates.spoke.name`, and `templates.spoke.stack`. Template defaults
are under `templates.spoke.var`; this JSON file still holds per-device values.
One shared Terraform spoke entry can serve many devices; do not duplicate the template
and stack for each firewall. The lab's local JSON file was populated from
PA-A's existing GUI overrides; it is ignored by Git.

## Commands

From any directory with the workspace CLI activated:

```bash
# Create/update shared configuration and serial assignments first.
palo lab plan
palo lab apply

# Read candidate overrides and preview differences. No configuration writes.
palo lab overrides plan

# Apply and read back changed candidate overrides. No commit or push.
palo lab overrides apply

# Commit and push using the existing Terraform action.
palo lab apply -invoke='module.deployment.action.panos_commit.commit_and_push["spoke/spoke"]'
```

`overrides` is a Python command in `palo`, not a Terraform command or resource.
It reads `device_overrides.json`, not `terraform.tfvars`. `terraform plan` does
not display these API-managed changes. Run override plan/apply after Terraform
configuration changes and before commit/push, because both systems touch the
stack configuration. The helper's comparison is against **candidate** values;
"No changes" does not mean the values have been committed or pushed.

To update one device or use another input file:

```bash
palo lab overrides plan --device paa
palo lab overrides apply --device paa
palo lab overrides plan --file device_overrides.staging.json
```

Relative file paths resolve under `env/lab`, regardless of the shell's current
directory. Absolute paths are also accepted. Each future environment, such as
`lab2`, gets its own `palo.json` and override file.

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

The path was verified against the GUI-created PA-A overrides on the lab Panorama:

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
