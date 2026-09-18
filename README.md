# PAN-OS Terraform workspace

Environment roots call composed stacks, which call reusable feature modules:

```text
env/lab/                       Runnable lab root and offline tests
stacks/lab/panorama/            Multi-site Panorama foundation
stacks/lab/spoke/               Policy and template module composition
  template/main.tf             Templates, stacks, variables, and WAN/LAN networking
  policy/main.tf               Device groups; future security and NAT rules
stacks/modules/panos/
  panorama/                    device_group, template, template_stack, template_variable
  objects/                     address, address_group, service, service_group, tag
  network/                     ethernet, zone, virtual_router, static_route_ipv4
  policy/                      security, nat
docs/                          Module contract and deployment workflow
```

The lab requires Terraform >= 1.14 for commit/push actions and pins PaloAltoNetworks/panos 2.0.13 and includes its
lock file. Provider configuration lives in the environment root.

## Module contract

Every feature module accepts `items`, a typed map keyed by stable logical keys,
and uses `for_each` to create multiple resources. An empty map creates none.
Each item supplies a location. Modules expose:

- `name_id`: resource name → base64 JSON import identifier.
- `names`: logical input key → resource name, for wiring dependencies.

PAN-OS v2 resources do not expose `.id`. These identifiers use the provider's
import format; they are not device UUIDs. Whole security/NAT policies have no
container name: their `name_id` keys are input keys, and their identifiers
include the ordered rule names. Their `names` values are lists of rule names.
Composed stacks group `name_id` maps by resource type/site to avoid collisions.

```hcl
module "addresses" {
  source = "../../stacks/modules/panos/objects/address"
  items = {
    lan = {
      name       = "branch-lan"
      ip_netmask = "192.0.2.0/24"
      location   = { device_group = { name = "lab-branch01" } }
    }
    server = {
      name       = "branch-server"
      ip_netmask = "198.51.100.10/32"
      location   = { device_group = { name = "lab-branch01" } }
    }
  }
}
# module.addresses.names["lan"]
# module.addresses.name_id["branch-lan"]
```

Names must be unique within a feature-module call. Use separate calls for the
same name in different scopes. Security and NAT modules own entire policies;
never overlap ownership of the same rulebase across items, calls or states.
Use ordered lists for rules and template precedence.

## Start the lab

`palo` runs from any directory and selects a Terraform root by environment name:

```sh
palo lab init
palo lab plan -out=lab.tfplan
palo lab apply lab.tfplan
```

The editable package installation resolves the workspace from its source location. Paths in Terraform arguments (such as a saved plan
or var file) are relative to `env/lab`, regardless of your shell directory.

One-time setup from the workspace root:

```sh
python3 -m venv scripts/venv
scripts/venv/bin/python3 -m pip install -e .
cp env/lab/terraform.tfvars.example env/lab/terraform.tfvars
```

Set `hostname` in `env/lab/palo.json` to your Panorama hostname or IP. The
`keyring_service` defaults to the existing `panos_api_admin` service. Set
`keyring_username` if multiple accounts share that service; otherwise the
launcher discovers the username from keyring. This JSON file holds only
connection metadata, never passwords. Set the hostname for the Panorama instance you intend to manage.

`pyproject.toml` declares the `palo = "palo_cli.cli:main"` console entry point
and its keyring dependency. `pip install -e .` generates `scripts/venv/bin/palo`;
source edits take effect without reinstalling. Reinstall when package metadata
or dependencies change.

No global `palo` symlink is installed. Activate the virtual environment with
`source scripts/venv/bin/activate` from the workspace root to use `palo` from
any directory in that shell, or invoke `scripts/venv/bin/palo` by its absolute
path. For a non-editable
(wheel) installation, set `PALO_WORKSPACE` to the absolute checkout path. You
can also use that variable to explicitly select a different checkout.

For connected commands, the launcher reads keyring and sets PANOS_HOSTNAME,
PANOS_USERNAME and PANOS_PASSWORD only for Terraform's process. It replaces
inherited PANOS_* settings so another environment's API key or target serial
cannot override the selected environment. Your parent shell is unchanged.
`init`, `validate`, `fmt`, `test`, `version`, and `providers` skip keyring.
The current `test` suite uses mock providers; future live tests need their own
explicit authentication setup.

Terraform uses `provider "panos" {}` and no credential data source. Authentication
credentials from this launcher are not stored as Terraform data-source or
variable values in state or saved plans. They exist in process memory and its
environment. Other managed resource secrets may still be stored by Terraform.
Existing state backups or saved plans from the former external-data-source
workflow are not cleaned up by this change; don't apply old saved plans.

## Save Panorama credentials in keyring

After installing the package, activate its virtual environment from the workspace
root:

```sh
source scripts/venv/bin/activate
```

Save your Panorama account using the service name configured for the lab.
Replace `YOUR_USERNAME` with your actual Panorama administrator username:

```sh
python -m keyring set panos_api_admin YOUR_USERNAME
```

The command prompts for the password without echoing it. Enter the password at
that prompt, not as a command-line argument. On macOS, keyring uses the macOS
Keychain by default. If prompted by macOS, allow the Python process to access
this credential.

Match the service and account in `env/lab/palo.json`:

```json
{
  "hostname": "panorama.example.com",
  "keyring_service": "panos_api_admin",
  "keyring_username": "YOUR_USERNAME"
}
```

Replace the example hostname with your Panorama hostname or IP, without
`https://`. The service is a lookup label; it does not need to match the hostname.
The service and username must match the values used in the `keyring set`
command. You can leave `keyring_username` empty to discover the account, but
specify it when multiple accounts share the same service.

If the credential is already saved under another service, set `keyring_service`
and `keyring_username` to that existing entry instead of saving another copy.
To update a saved password, run the same `keyring set` command again.

With the hostname, credential and lab inputs configured, verify the connection:

```sh
palo lab init
palo lab plan
```

The launcher retrieves the credential without printing it and supplies it to
the PAN-OS provider through the Terraform process environment. Do not put the
password in `palo.json` or Terraform variable files.

## Self-signed Panorama certificates

Set this optional boolean in the environment's `palo.json`:

```json
"skip_verify_certificate": true
```

The launcher passes it as `PANOS_SKIP_VERIFY_CERTIFICATE` to the PAN-OS
provider. It is enabled for `env/lab/palo.json`. Other environments verify
certificates by default when this field is omitted or set to `false`.
Use a JSON boolean, not the string `"true"`.

HTTPS remains enabled, but `true` disables certificate verification, including
server identity checks. Set it to `false` when Panorama has a trusted certificate.
This setting applies when running through `palo`; direct Terraform invocations
do not read `palo.json`.

## Add another environment

Create `env/lab2` with its own root `.tf` files and a `palo.json`, for example:

```json
{
  "hostname": "panorama-lab2.example.com",
  "keyring_service": "panos_lab2",
  "keyring_username": "terraform-admin"
}
```

With the virtual environment activated, save the separate account:

```sh
python -m keyring set panos_lab2 terraform-admin
```

Then run `palo lab2 init` and `palo lab2 plan` from anywhere in that shell.
Reuse the shared modules. Give each root its own state/backend key. Copy only
source configuration when creating a new environment, never `.terraform`,
state, or saved plans. No launcher changes are required.

## Spoke lab inputs

Each entry groups its settings into `policy` and `template`, with `serials`
shared by both:

```hcl
spokes = {
  spoke = {
    serials = ["PA_A_SERIAL", "PA_B_SERIAL"]
    policy = {
      device_group = "spoke"
    }
    template = {
      name  = "spoke-network"
      stack = "spoke-stack"
      description = "Terraform-managed spoke"
      var = {
        wan_interface     = "ethernet1/1"
        lan_interface     = "ethernet1/2"
        wan_zone = "wan"
        lan_zone = "lan"
        wan_ip            = "None"
        wan_prefix_length = null
        lan_ip            = "None"
        lan_prefix_length = null
        default_gateway   = "None"
        virtual_router    = "spoke-vr"
      }
    }
  }
}
```

The root and composition inputs use `type = any` instead of repeating every
field's schema. Parent modules pass through child objects with `merge`.
`template/main.tf` explicitly defines the WAN/LAN interfaces, zones, three
Panorama variables, virtual router, and default route. Resource modules retain
typed schemas. The template module validates current addressing inputs once.

Template inputs are explicit: set `description` in `template`, and provide
`wan_ip`, `wan_prefix_length`, `lan_ip`, `lan_prefix_length`, `default_gateway`,
`virtual_router`, `wan_zone`, and `lan_zone` inside `template.var`, along with
the interface names. Use the literal string `"None"` for unassigned IPs/gateway
and `null` for their unused prefixes. There is no local defaults/merge block
in the template module. Serial assignments are passed in by the parent.

To add a DMZ, add its input values in tfvars and the explicit resource entries
in `template/main.tf`. You do not need to mirror those new fields in all parent
`variables.tf` files. An unused input alone does not create a resource.

See [terraform.tfvars.example](env/lab/terraform.tfvars.example) for complete
examples. Multiple entries can share a device group; each entry owns its own
template/stack. For shared templates and stacks, list multiple serials in one
entry and assign device-specific IP values using `palo lab overrides plan` and
`palo lab overrides apply`, or Panorama's Managed Devices view. See
[per-device overrides](docs/device-overrides.md).

The separate foundation-only `sites` map keeps its existing schema. Security
and NAT policies are not created yet. State is local initially and ignored by
Git; keep `.terraform.lock.hcl` in version control.

## Commit to Panorama and push to firewalls

After a successful candidate-configuration apply, explicitly invoke each step:

```sh
palo lab apply -invoke='module.deployment.action.panos_commit.this["spoke01"]'
# Run only after the commit succeeds and real serials have been assigned:
palo lab apply -invoke='module.deployment.action.panos_push_to_devices.this["spoke01"]'
```

`env/lab/actions.tf` calls the reusable `operations/commit_push` module as
`module.deployment`. Normal apply does not
invoke them. Commit is scoped to the spoke's device group, template and stack.
Push includes template configuration and targets only the spoke's serials.
Spokes with `serials = []` have no push action. The actions cover `spokes`, not
legacy `sites`. See [deployment](docs/deployment.md) for the full sequence,
action previews, and retry behavior.

Alternatively, after candidate apply, commit and push together:

```sh
palo lab apply -invoke='module.deployment.action.panos_commit.commit_and_push["spoke01"]'
```

This combined action also requires non-empty `serials`.

## Offline checks

```sh
scripts/venv/bin/python3 -m unittest discover -s scripts -p "test_*.py"
terraform fmt -check -recursive
terraform -chdir=env/lab init -backend=false
terraform -chdir=env/lab validate
terraform -chdir=env/lab test
```

Mock-provider tests exercise two instances of every feature module, decoded
identifier names, policy order, two-site stack composition, and multi-spoke
variable/addressing configuration. They also verify explicit values and pass-through fields, reject duplicate interfaces,
invalid prefixes, and off-subnet gateways. Action tests verify that only assigned spokes are
eligible for push and that blank serials are rejected. They do not
verify device-side acceptance or perform live commits/pushes.

See [deployment](docs/deployment.md) for the deployment boundary.
Provider reference: https://registry.terraform.io/providers/PaloAltoNetworks/panos/2.0.13/docs

The lab's `moved.tf` preserves the existing PA-A device-group resource when
switching from per-spoke keys to shared group-name keys. Run `palo lab plan`
and review the move before applying. The actual lab tfvars keeps PA-A active;
PA-B is a commented example awaiting its real network values.
