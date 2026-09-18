# PAN-OS Terraform workspace

Environment roots call composed stacks, which call reusable feature modules:

```text
env/lab/                       Runnable lab root and offline tests
stacks/lab/device_grps/          Device groups, parent hierarchy and membership
stacks/lab/policies/
  common/                      Future common policies for parent groups
  branch/                      Future branch policies for child groups
  hub/                         Future hub policies for child groups
stacks/lab/spoke_template/      Explicit templates, stacks and WAN/LAN networking
stacks/lab/hub_template/        Placeholder for future distinct hub networking
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

## Independent policy and network inputs

`device_groups` defines device groups by name, their `parent`, and firewall
`serials`. `templates` defines network templates/stacks and their independent
`serials`. A firewall belongs directly to one device group and one template stack.
A parent provides inherited policy to its children; do not repeat child serials
on the parent.

```hcl
device_groups = {
  parent_a   = { parent = null, serials = [] }
  parent_b   = { parent = null, serials = [] }
  branches_a = { parent = "parent_a", serials = ["PA_A_SERIAL"] }
  hubs_a     = { parent = "parent_a", serials = ["HUB_A_SERIAL"] }
  branches_b = { parent = "parent_b", serials = ["PA_B_SERIAL"] }
}
```

This supports multiple parent families, each with many firewalls. The root
validates one parent tier plus child groups. Define each parent with
`parent = null`; omitting `parent` leaves its existing hierarchy unmanaged.
Native `panos_device_group_parent` resources manage explicit parent assignments.
The provider runs a Panorama move-device-group job during apply for hierarchy
changes; removing a managed relationship moves that group back under Shared.

See [terraform.tfvars.example](env/lab/terraform.tfvars.example) for a complete
three-parent example sharing one spoke network, plus a separate hub network.
Existing lab values are preserved in `terraform.tfvars`; choose real parent
names before adding a hierarchy to that lab group.

Composition variables use `type = any`; resource modules retain typed inputs.
The template module still explicitly defines WAN/LAN interfaces, zones, variables,
a router and default route. Set all network values in `templates.<key>.var`.
To add a DMZ, add its values there and explicit resource entries in spoke_template/main.tf;
there is no need to duplicate the input schema across parent modules.
Use `"None"` for unassigned IPs/gateway and `null` for unused prefixes.
Assign device IP overrides with `palo lab overrides plan` and
`palo lab overrides apply`; see [per-device overrides](docs/device-overrides.md).
Security/NAT rule creation remains future work in `stacks/lab/policies/common`,
`branch`, and `hub`. These folders currently contain scaffolds only; the root does
not call them or create policy rules. When implemented, the root will pass target
names from `module.device_grp.names`. Parent/child relationships remain entirely
in `device_groups`, independent of these folders. One module instance must own
each device-group/policy-type/rulebase scope; combine its ordered rules there.

`hub_template` is also a scaffold. Hub devices with the same WAN/LAN resource
layout can already use another `templates` entry. Implement a separate hub module
only when its resource structure differs.

## Commit to Panorama and push to firewalls

```sh
palo lab init
palo lab plan
palo lab apply
palo lab overrides plan
palo lab overrides apply
# Commit all configured policy groups, templates and stacks:
palo lab apply -invoke='action.panos_commit.all'
# Push only the intersection of group "spoke" and template entry "spoke":
palo lab apply -invoke='module.deployment.action.panos_push_to_devices.this["spoke/spoke"]'
```

For a scoped commit, or a combined commit and push:

```sh
palo lab apply -invoke='module.deployment.action.panos_commit.this["spoke/spoke"]'
palo lab apply -invoke='module.deployment.action.panos_commit.commit_and_push["spoke/spoke"]'
```

Scoped commits include the target's parent group, child group, template and stack.
Action keys are `<device-group>/<template-key>`. Only non-empty serial
intersections create deployment targets. Unassigned groups/templates can still
be committed using `action.panos_commit.all`. Shared policy commits can include
changes affecting other children; push each affected target deliberately.
Normal apply does not invoke commit/push actions.

The root `moved.tf` migrates existing policy/template resource addresses. Run
`palo lab plan` and review the moves before applying; do not apply an old saved
plan. No state migration occurs until you apply. Root outputs remain commented
out; modules expose `name_id` maps.

## Offline checks

```sh
scripts/venv/bin/python3 -m unittest discover -s scripts -p "test_*.py"
terraform fmt -check -recursive
terraform -chdir=env/lab init -backend=false
terraform -chdir=env/lab validate
terraform -chdir=env/lab test
```

Mock-provider tests exercise two instances of every feature module, decoded
identifier names, policy order, multi-spoke
variable/addressing configuration. They also verify explicit values and pass-through fields, reject duplicate interfaces,
invalid prefixes, and off-subnet gateways. Action tests verify that only assigned spokes are
eligible for push and that blank serials are rejected. They do not
verify device-side acceptance or perform live commits/pushes.

See [deployment](docs/deployment.md) for the deployment boundary.
Provider reference: https://registry.terraform.io/providers/PaloAltoNetworks/panos/2.0.13/docs

