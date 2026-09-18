# PAN-OS Terraform workspace

Environment roots call composed stacks, which call reusable feature modules:

```text
.
├── env/
│   └── lab/                     Runnable lab root and offline tests
├── stacks/
│   ├── lab/
│   │   ├── device_groups/         Device groups, parent hierarchy and membership
│   │   ├── policies/
│   │   │   ├── common/          Future common policies for parent groups
│   │   │   ├── branch/          Future branch policies for child groups
│   │   │   └── hub/             Future hub policies for child groups
│   │   ├── spoke_template/      Templates, stacks and WAN/LAN networking
│   │   └── hub_template/        Placeholder for distinct hub networking
│   └── modules/
│       └── panos/
│           ├── panorama/        Device groups, hierarchy, templates, stacks and variables
│           ├── objects/         Addresses, address groups, services, service groups and tags
│           ├── network/         Ethernet interfaces, zones, virtual routers and IPv4 routes
│           ├── policy/          Security and NAT policies
│           └── operations/      Commit and push actions
└── docs/                        Module contract and deployment workflow
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

## Discover firewall serial numbers

Add a `device` map to the environment root's `env/lab/palo.json`. Keys are your
inventory hostnames and values are firewall management IP addresses:

```json
"device": {
  "pa-a": "192.0.2.10",
  "pa-b": "192.0.2.11"
}
```

Keep the existing Panorama hostname and keyring settings. Replace the example
IPs with real firewall addresses, then run from any directory:

```sh
palo lab serials
```

This connects directly to each firewall over HTTPS using the existing keyring
username/password and `skip_verify_certificate` setting. The account must work
on each firewall and have XML API operational-command access. It reads
[`show system info`](https://docs.paloaltonetworks.com/ngfw/api/getting-started/explore-xmlapi)
and saves `env/lab/serial.json` as a hostname-to-serial map:

```json
{
  "pa-a": "007954000920842",
  "pa-b": "EXAMPLE_SERIAL"
}
```

Serial discovery errors identify the device name/IP, failed API operation, and
sanitized failure reason. Discovery continues with the remaining devices.
Serials remain strings, preserving leading zeros. The file is replaced only
when every device succeeds; failures preserve the previous file and return a
nonzero exit code. The generated file is ignored by Git. Credentials and API
keys are never written to it. This command does not change configuration,
commit/push, or automatically update Terraform inputs.

## Onboard firewalls into Panorama

With the `device` map populated in `env/lab/palo.json`, preview and run:

```sh
palo lab onboard plan
palo lab onboard apply
```

The workflow uses the same keyring administrator credentials on Panorama and
all listed firewalls. It discovers live serials and automatically splits pending
firewalls into batches of 50. Each batch receives one shared registration key
restricted to its serials. Keys are generated as batches start and saved once in
`env/lab/onboarding.json`, adds missing managed-device entries on Panorama,
commits Panorama, installs each firewall's key and Panorama IP, commits each
firewall, and finishes after the commits succeed. The final connection wait is
skipped by default; initial preflight still checks for already-connected devices.
Already-connected devices are skipped. No Security/NAT or template push is run.
Device-group and template-stack assignment remains in Terraform.

To also wait for Panorama to report the devices connected:

```sh
palo lab onboard apply --connection-check
```

Without this flag, saved progress remains `firewall_committed`, not `connected`.
`--timeout` always applies to commit jobs and also applies to the final connection
wait when `--connection-check` is enabled.

`plan` only reads API data and does not create keys, write files, or commit.
`apply` asks for confirmation and performs **full candidate commits on Panorama
and the pending firewalls, including any other pending edits**. It stops on the
first failure after preflight; completed remote changes are not rolled back.
Use `--auto-approve` only when you intend to skip that confirmation.

`serial.json` keeps the hostname-to-serial map. `onboarding.json` contains
a top-level `registration_keys` map keyed by key name (key, permitted serials,
expiry and count),
per-device progress, and pending commit job
IDs. It is plaintext, written atomically with owner-only permissions (`0600`),
and ignored by Git; it is not loaded into Terraform state or saved plans.
Administrator passwords and XML API session keys are never written to it.
Each batch key defaults to a 60-minute lifetime and **100 total registration uses**.
The default 50-device batch leaves capacity for retries:

```sh
palo lab onboard apply --batch-size 50 --lifetime-minutes 120 --key-count 100 --timeout 600
```

Keep every firewall in one `device` map; 1,000 pending devices automatically form
20 batches at the default size. Batches run sequentially: generate/recover the
batch key, register its serials, commit Panorama, then configure and commit its
firewalls. A failure stops later batches. Choose a key lifetime long enough for
a batch's commits and initial connections.

Retries retain valid saved key groups, even when only some devices remain pending.
Already-connected firewalls are skipped. New serials form new batches; expired
keys or a changed `--key-count` cause replacement keys to be generated.
`--batch-size` accepts 1–100 and is capped by `--key-count` (also 1–100).
The former single `registration_key` record is migrated and reused when valid.
Legacy per-device secrets are removed locally once a batch key is saved; old
Panorama keys are not revoked and expire independently.
After interruptions, recorded commit jobs are checked before further writes.
If a saved key is exhausted or revoked, or a recorded commit failed, inspect
Panorama and the saved progress before retrying; the command does not reset
secure communications or silently migrate firewalls from another Panorama.

Onboarding API errors identify the firewall name/IP and failed operation, with
HTTP status or PAN-OS error code and sanitized details. Timeouts, refused/reset
connections, DNS errors, TLS failures and invalid XML have distinct diagnostics.
After restarting a firewall's management server, a timeout or HTTP 503 can mean
its API is not ready yet; retry `palo lab onboard plan` after it recovers.
Preflight failures make no onboarding configuration changes or commits.
Passwords, API keys, registration keys and raw response bodies are not printed.

The Panorama IP defaults to `hostname` in `palo.json`. If that is a DNS name or
API endpoint with a port, add `"panorama_ip": "172.16.1.99"` with the address the
firewalls should use to reach Panorama. Direct HTTPS API access to all devices
and firewall-to-Panorama management connectivity must be available. The helper
currently handles one Panorama server, not HA migration.

References: [Palo Alto onboarding workflow](https://docs.paloaltonetworks.com/panorama/administration/manage-firewalls/add-a-firewall-as-a-managed-device),
[registration key commands](https://docs.paloaltonetworks.com/panorama/administration/troubleshooting/recover-managed-device-connectivity-to-panorama),
and [XML API commits and job status](https://docs.paloaltonetworks.com/ngfw/api/pan-os-xml-api-request-types-and-actions/commit).

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
Common parent policies live in `stacks/lab/policies/common`. Set
`policies.common.parent` in root tfvars with `device_group = "parent"`,
`lan_zone`, `wan_zone`, and `wan_interface`. These common policy inputs are
independent of templates; future site-specific policies may use template inputs. The parent pre-rulebases contain:

- Source NAT for any service exiting the WAN zone/interface, using dynamic IP
  and port translation to the interface address.
- LAN-to-WAN allows for TCP destination port 22 and ICMP/ping, followed by an
  explicit deny for other LAN-to-WAN traffic. The deny precedes child rules.

NAT does not match virtual-router names; routing chooses the outgoing interface.
The rules are inherited by child device groups, including `spoke`. To deploy,
apply candidate changes, commit with `module.deployment.action.panos_commit.all`,
then push the child using
`module.deployment.action.panos_push_to_devices.policies["spoke"]`.
The `branch` and `hub` policy folders remain scaffolds. One module instance must
own each device-group/policy-type/rulebase scope; combine its ordered rules there.


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
palo lab apply -invoke='module.deployment.action.panos_commit.all'
# Push only the intersection of group "spoke" and template entry "spoke":
palo lab apply -invoke='module.deployment.action.panos_push_to_devices.this["spoke/spoke"]'
```

To push every configured target after the commit succeeds:

```sh
palo lab push-all --dry-run
palo lab push-all
```

All environments share the actions and target selection in
`stacks/modules/panos/operations/commit_push`. Each root needs only this wiring
in `actions.tf` (plus any desired command comments):

```hcl
module "deployment" {
  source        = "../../stacks/modules/panos/operations/commit_push"
  device_groups = var.device_groups
  templates     = var.templates
}
```

After committing, push only templates or only policies with:

```sh
palo lab apply -invoke='module.deployment.action.panos_push_to_devices.templates["spoke"]'
palo lab apply -invoke='module.deployment.action.panos_push_to_devices.policies["spoke"]'
```

Use `plan` instead of `apply` to preview. These keys identify a template input
and a device group respectively; targets without assigned serials are excluded.
All action addresses use the `module.deployment` prefix, including commit-all.

`push-all` is a Python CLI command implemented in `src/palo_cli/push_all.py`,
not a Terraform action or a direct Python call to the Panorama API. It invokes
Terraform push actions; the PAN-OS provider performs the API calls.

`push-all` evaluates `module.deployment.deployment_items` using Terraform console, lists the
selected targets and serials, and asks for one confirmation. It pushes targets
sequentially and stops on the first failure. Use `--auto-approve` to skip the
batch prompt. It does not apply resource changes, write variable overrides, or
commit Panorama. Earlier successful pushes are not rolled back on failure.
“All” means this environment's configured group/template intersections, not all
firewalls in Panorama. Complete your configuration apply and commit first.
The command uses default environment variable files; additional Terraform flags
are not accepted, and inherited `TF_CLI_ARGS*` options are ignored.

For a scoped commit, or a combined commit and push:

```sh
palo lab apply -invoke='module.deployment.action.panos_commit.this["spoke/spoke"]'
palo lab apply -invoke='module.deployment.action.panos_commit.commit_and_push["spoke/spoke"]'
```

Scoped commits include the target's parent group, child group, template and stack.
Action keys are `<device-group>/<template-key>`. Only non-empty serial
intersections create deployment targets. Unassigned groups/templates can still
be committed using `module.deployment.action.panos_commit.all`. Shared policy commits can include
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
variable/addressing configuration. They also verify explicit values and pass-through fields, reject duplicate
interface ownership, and allow gateway values without custom subnet restrictions. Action tests verify that only assigned spokes are
eligible for push and that blank serials are rejected. They do not
verify device-side acceptance or perform live commits/pushes.

See [deployment](docs/deployment.md) for the deployment boundary.
Provider reference: https://registry.terraform.io/providers/PaloAltoNetworks/panos/2.0.13/docs

Input validation is limited to repository relationships and ownership: group
hierarchy, unique template/stack ownership, distinct managed interfaces, unique
resource/rule identities and unambiguous locations. Non-empty serial checks remain
because serials select push targets. Network value formats and provider-specific
attribute combinations are left to Terraform/provider validation. Adding a field
to the flexible composition inputs does not require a matching validation rule;
fields consumed by resource expressions must still be supplied.


`.all` performs a full Panorama commit with no administrator, device-group,
template, or stack filters. It includes **all administrators' pending changes**,
including changes outside this Terraform environment, and does not push to
firewalls. `.this["group/template"]` remains a scoped partial commit.
The combined `commit_and_push` action also retains its scoped partial commit.
