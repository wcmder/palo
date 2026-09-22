# PAN-OS Terraform workspace

Repository conventions: [structure.md](structure.md). Read this before changing
Terraform.

Manage Palo Alto Networks firewalls through Panorama using reusable Terraform
modules and the `palo` Python CLI. This project provides a development
environment for building shared policies, configuring firewall networking, and
deploying changes across multiple devices.

Supported features include:

- Firewall onboarding to Panorama: discover serial numbers, generate shared
  registration keys per batch, register firewalls, configure their Panorama
  connection, and commit the changes. Saved progress supports retries, with
  optional device connection checks.
- Device groups, parent/child hierarchy, and firewall membership.
- Templates, template stacks, template variables, and per-device variable
  overrides through the XML API helper.
- WAN/LAN interfaces, zones, virtual routers, IPv4 static routes, and zone
  protection profiles.
- Address and service objects, groups, tags, Security and NAT policies, and
  default security rule overrides.
- Full or scoped Panorama commits, separate policy/template pushes, and a
  Python command that pushes all configured combined deployment targets.
- OS keyring authentication and separate environment inputs and state.

The included `dev` configuration implements spoke networking and common parent
policies. Branch-specific policies, hub-specific policies, and distinct hub
networking remain scaffolds. Normal Terraform apply writes candidate
configuration; commits and pushes are explicit operations.

Environment roots call composed stacks, which call reusable feature modules:

```text
.
├── env/
│   └── dev/                     Runnable dev root and offline tests
├── stacks/
│   ├── dev/
│   │   ├── device_groups/       Device groups, parent hierarchy and membership
│   │   ├── policies/
│   │   │   ├── common/          Common parent Security, NAT and default rules
│   │   │   ├── branch/          Future branch policies for child groups
│   │   │   └── hub/             Future hub policies for child groups
│   │   ├── templates/
│   │   │   ├── shared/common/   Shared network and settings template
│   │   │   └── spoke/
│   │   │       └── stacks/     Ordered template membership and devices
│   │   └── hub_template/        Placeholder for distinct hub networking
│   └── modules/
│       └── panos/
│           ├── panorama/        Groups, hierarchy, templates and variables
│           ├── objects/         Addresses, services, groups and tags
│           ├── network/         Interfaces, zones, routers and routes
│           ├── policy/          Security and NAT policies
│           └── operations/      Commit and push actions
└── docs/                        Module contract and deployment workflow
```

The dev requires Terraform >= 1.14 for commit/push actions and pins
PaloAltoNetworks/panos 2.0.13 and includes its lock file. Provider configuration
lives in the environment root.

## Module contract

Every feature module accepts `items`, a typed map keyed by stable logical keys,
and uses `for_each` to create multiple resources. An empty map creates none.
Each item supplies a location. Reusable modules retain their `names` output
as a stable contract, even without a current caller. Other outputs are kept
when used by callers, tests, or documented workflows:

- `names`: logical input key → resource name, for wiring dependencies.
- Focused settings outputs where callers or tests need them.

Security and NAT `names` outputs map logical keys to ordered rule names.
Import identifiers are not exposed as module outputs.

```hcl
module "addresses" {
  source = "../../stacks/modules/panos/objects/address"
  items = {
    lan = {
      name       = "branch-lan"
      ip_netmask = "192.0.2.0/24"
      location   = { device_group = { name = "dev-branch01" } }
    }
    server = {
      name       = "branch-server"
      ip_netmask = "198.51.100.10/32"
      location   = { device_group = { name = "dev-branch01" } }
    }
  }
}
# module.addresses.names["lan"]
```

Names must be unique within a feature-module call. Use separate calls for the
same name in different scopes. Security and NAT modules own entire policies;
never overlap ownership of the same rulebase across items, calls or states. Use
ordered lists for rules and template precedence.

## Start the dev

One-time setup from the workspace root:

```sh
python3 -m venv scripts/venv
scripts/venv/bin/python3 -m pip install -e .
cp env/dev/device_groups.auto.tfvars.example env/dev/device_groups.auto.tfvars
cp env/dev/templates.auto.tfvars.example env/dev/templates.auto.tfvars
cp env/dev/policies.auto.tfvars.example env/dev/policies.auto.tfvars
```

Python requirements are declared in `pyproject.toml`:

- Python **3.9 or newer**, with `pip` and `venv` available.
- `keyring>=25.0.0,<26.0.0` for OS credential storage and retrieval.
- `setuptools>=68` as the package build backend.

The editable install command above installs the declared dependencies and their
dependencies automatically; no separate `requirements.txt` is needed. Keyring
needs an available, unlocked OS credential backend. The API helpers use Python's
standard-library HTTPS and XML modules, so no separate HTTP client or PAN-OS
Python SDK is required. Python tests use the built-in `unittest` module:

```sh
scripts/venv/bin/python3 -m unittest discover -s scripts -p 'test_*.py'
```

Terraform is a separate executable, not a Python dependency. Install Terraform
**1.14 or newer** and make sure `terraform` is available on your `PATH`.

Before running connected commands,
[save your Panorama credentials in keyring][keyring-setup] and set the matching
service and username in `env/dev/palo.json`.

`palo` runs from any directory and selects a Terraform root by environment name:

```sh
palo dev init
palo dev plan
palo dev apply
```

Saving a plan file is optional. To save and then apply that specific plan:

```sh
palo dev plan -out=dev.tfplan
palo dev apply dev.tfplan
```

The editable package installation resolves the workspace from its source
location. Paths in Terraform arguments (such as a saved plan or var file) are
relative to `env/dev`, regardless of your shell directory.

Set `hostname` in `env/dev/palo.json` to your Panorama hostname or IP. Set
`keyring_service` to `panos_api_admin` (or your existing service label). Set
`keyring_username` if multiple accounts share that service; otherwise the
launcher discovers the username from keyring. This JSON file holds only
connection metadata, never passwords. Set the hostname for the Panorama instance
you intend to manage.

`pyproject.toml` declares the `palo = "palo_cli.cli:main"` console entry point
and its keyring dependency. `pip install -e .` generates
`scripts/venv/bin/palo`; source edits take effect without reinstalling.
Reinstall when package metadata or dependencies change.

No global `palo` symlink is installed. Activate the virtual environment with
`source scripts/venv/bin/activate` from the workspace root to use `palo` from
any directory in that shell, or invoke `scripts/venv/bin/palo` by its absolute
path. For a non-editable (wheel) installation, set `PALO_WORKSPACE` to the
absolute checkout path. You can also use that variable to explicitly select a
different checkout.

For connected commands, the launcher reads keyring and sets PANOS_HOSTNAME,
PANOS_USERNAME and PANOS_PASSWORD only for Terraform's process. It replaces
inherited PANOS_* settings so another environment's API key or target serial
cannot override the selected environment. Your parent shell is unchanged.
`init`, `validate`, `fmt`, `test`, `version`, and `providers` skip keyring. The
current `test` suite uses mock providers; future live tests need their own
explicit authentication setup.

Terraform uses `provider "panos" {}` and no credential data source.
Authentication credentials from this launcher are not stored as Terraform
data-source or variable values in state or saved plans. They exist in process
memory and its environment. Other managed resource secrets may still be stored
by Terraform. Existing state backups or saved plans from the former
external-data-source workflow are not cleaned up by this change; don't apply old
saved plans.

## Save and retrieve Panorama credentials with keyring

After installing the package, activate its virtual environment from the
workspace root:

```sh
source scripts/venv/bin/activate
```

Save your Panorama account using the service name configured for the dev.
Replace `YOUR_USERNAME` with your actual Panorama administrator username:

```sh
python -m keyring set panos_api_admin YOUR_USERNAME
```

The command prompts for the password without echoing it. Enter the password at
that prompt, not as a command-line argument. On macOS, keyring uses the macOS
Keychain by default. If prompted by macOS, allow the Python process to access
this credential.

Match the service and account in `env/dev/palo.json`:

```json
{
  "hostname": "panorama.example.com",
  "keyring_service": "panos_api_admin",
  "keyring_username": "YOUR_USERNAME"
}
```

Replace the example hostname with your Panorama hostname or IP, without
`https://`. The service is a lookup label; it does not need to match the
hostname. The service and username must match the values used in the
`keyring set` command. You can leave `keyring_username` empty to discover the
account, but specify it when multiple accounts share the same service.

If the credential is already saved under another service, set `keyring_service`
and `keyring_username` to that existing entry instead of saving another copy. To
update a saved password, run the same `keyring set` command again.

With the hostname, credential and dev inputs configured, verify the connection:

```sh
palo dev init
palo dev plan
```

The launcher retrieves the credential without printing it and supplies it to the
PAN-OS provider through the Terraform process environment. Do not put the
password in `palo.json` or Terraform variable files.

When you run `palo dev plan`, credentials are pulled automatically:

1. `palo` reads `env/dev/palo.json` for the Panorama hostname, keyring service,
   username, and certificate-verification setting.
2. With a configured username, it calls
   `keyring.get_password("panos_api_admin", "YOUR_USERNAME")`. If the username
   is omitted, it calls `keyring.get_credential(service, None)` to retrieve both
   the account name and password from the backend.
3. It launches Terraform with `PANOS_HOSTNAME`, `PANOS_USERNAME`,
   `PANOS_PASSWORD`, and `PANOS_SKIP_VERIFY_CERTIFICATE` in the child process
   environment. Your shell environment is not changed.
4. The PAN-OS provider reads those environment variables from the otherwise
   empty `provider "panos" {}` configuration and authenticates to Panorama.

```text
keyring set → OS keyring / macOS Keychain
                         ↓ palo reads the saved entry
                Terraform process environment
                         ↓
                   PAN-OS provider → Panorama
```

You save the password once and repeat `keyring set` only when it changes. There
is no need to manually export credentials before each command. This workflow
does not pass the login credentials through Terraform variables or a data
source, so it does not add them to Terraform state or saved plans.
`palo dev init` and `palo dev validate` are offline commands and skip keyring;
use `palo dev plan` to check connected provider access.

## Discover firewall serial numbers

Add a `device` map to the environment root's `env/dev/palo.json`. Keys are your
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
palo dev serials
```

This connects directly to each firewall over HTTPS using the existing keyring
username/password and `skip_verify_certificate` setting. The account must work
on each firewall and have XML API operational-command access. It reads
[`show system info`][system-info] and saves `env/dev/serial.json` as a
hostname-to-serial map:

```json
{
  "pa-a": "007954000920842",
  "pa-b": "EXAMPLE_SERIAL"
}
```

Serial discovery errors identify the device name/IP, failed API operation, and
sanitized failure reason. Discovery continues with the remaining devices.
Serials remain strings, preserving leading zeros. The file is replaced only when
every device succeeds; failures preserve the previous file and return a nonzero
exit code. The generated file is ignored by Git. Credentials and API keys are
never written to it. This command does not change configuration, commit/push, or
automatically update Terraform inputs.

## Onboard firewalls into Panorama

With the `device` map populated in `env/dev/palo.json`, preview and run:

```sh
palo dev onboard plan
palo dev onboard apply
```

The workflow uses the same keyring administrator credentials on Panorama and all
listed firewalls. It discovers live serials and automatically splits pending
firewalls into batches of 50. Each batch receives one shared registration key
restricted to its serials. Keys are generated as batches start and saved once in
`env/dev/onboarding.json`, adds missing managed-device entries on Panorama,
commits Panorama, installs each firewall's key and Panorama IP, commits each
firewall, and finishes after the commits succeed. The final connection wait is
skipped by default; initial preflight still checks for already-connected
devices. Already-connected devices are skipped. No Security/NAT or template push
is run. Device-group and template-stack assignment remains in Terraform.

To also wait for Panorama to report the devices connected:

```sh
palo dev onboard apply --connection-check
```

Without this flag, saved progress remains `firewall_committed`, not `connected`.
`--timeout` always applies to commit jobs and also applies to the final
connection wait when `--connection-check` is enabled.

`plan` only reads API data and does not create keys, write files, or commit.
`apply` asks for confirmation and performs **full candidate commits on Panorama
and the pending firewalls, including any other pending edits**. It stops on the
first failure after preflight; completed remote changes are not rolled back. Use
`--auto-approve` only when you intend to skip that confirmation.

`serial.json` keeps the hostname-to-serial map. `onboarding.json` contains a
top-level `registration_keys` map keyed by key name (key, permitted serials,
expiry and count), per-device progress, and pending commit job IDs. It is
plaintext, written atomically with owner-only permissions (`0600`), and ignored
by Git; it is not loaded into Terraform state or saved plans. Administrator
passwords and XML API session keys are never written to it. Each batch key
defaults to a 60-minute lifetime and **100 total registration uses**. The
default 50-device batch leaves capacity for retries:

```sh
palo dev onboard apply \
  --batch-size 50 --lifetime-minutes 120 --key-count 100 --timeout 600
```

Keep every firewall in one `device` map; 1,000 pending devices automatically
form 20 batches at the default size. Batches run sequentially: generate/recover
the batch key, register its serials, commit Panorama, then configure and commit
its firewalls. A failure stops later batches. Choose a key lifetime long enough
for a batch's commits and initial connections.

Retries retain valid saved key groups, even when only some devices remain
pending. Already-connected firewalls are skipped. New serials form new batches;
expired keys or a changed `--key-count` cause replacement keys to be generated.
`--batch-size` accepts 1–100 and is capped by `--key-count` (also 1–100). The
former single `registration_key` record is migrated and reused when valid.
Legacy per-device secrets are removed locally once a batch key is saved; old
Panorama keys are not revoked and expire independently. After interruptions,
recorded commit jobs are checked before further writes. If a saved key is
exhausted or revoked, or a recorded commit failed, inspect Panorama and the
saved progress before retrying; the command does not reset secure communications
or silently migrate firewalls from another Panorama.

Onboarding API errors identify the firewall name/IP and failed operation, with
HTTP status or PAN-OS error code and sanitized details. Timeouts, refused/reset
connections, DNS errors, TLS failures and invalid XML have distinct diagnostics.
After restarting a firewall's management server, a timeout or HTTP 503 can mean
its API is not ready yet; retry `palo dev onboard plan` after it recovers.
Preflight failures make no onboarding configuration changes or commits.
Passwords, API keys, registration keys and raw response bodies are not printed.

The Panorama IP defaults to `hostname` in `palo.json`. If that is a DNS name or
API endpoint with a port, add `"panorama_ip": "172.16.1.99"` with the address
the firewalls should use to reach Panorama. Direct HTTPS API access to all
devices and firewall-to-Panorama management connectivity must be available. The
helper currently handles one Panorama server, not HA migration.

References: [Palo Alto onboarding workflow][onboarding-workflow],
[registration key commands][registration-keys], and
[XML API commits and job status][api-commits].

## Self-signed Panorama certificates

Set this optional boolean in the environment's `palo.json`:

```json
"skip_verify_certificate": true
```

The launcher passes it as `PANOS_SKIP_VERIFY_CERTIFICATE` to the PAN-OS
provider. It is enabled for `env/dev/palo.json`. Other environments verify
certificates by default when this field is omitted or set to `false`. Use a JSON
boolean, not the string `"true"`.

HTTPS remains enabled, but `true` disables certificate verification, including
server identity checks. Set it to `false` when Panorama has a trusted
certificate. This setting applies when running through `palo`; direct Terraform
invocations do not read `palo.json`.

## Add another environment

Create `env/dev2` with its own root `.tf` files and a `palo.json`, for example:

```json
{
  "hostname": "panorama-dev2.example.com",
  "keyring_service": "panos_dev2",
  "keyring_username": "terraform-admin"
}
```

With the virtual environment activated, save the separate account:

```sh
python -m keyring set panos_dev2 terraform-admin
```

Then run `palo dev2 init` and `palo dev2 plan` from anywhere in that shell.
Reuse the shared modules. Give each root its own state/backend key. Copy only
source configuration when creating a new environment, never `.terraform`, state,
or saved plans. No launcher changes are required.

## Independent policy and network inputs

`device_groups` defines device groups by name, their `parent`, and firewall
`serials`. `templates` defines network templates/stacks and their independent
`serials`. A firewall belongs directly to one device group and one template
stack. A parent provides inherited policy to its children; do not repeat child
serials on the parent.

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

Environment inputs are split into automatically loaded files:

| File | Root variable |
| --- | --- |
| `device_groups.auto.tfvars` | `device_groups` |
| `templates.auto.tfvars` | `templates`, `template_stacks` |
| `policies.auto.tfvars` | `policies` |

Each has a tracked `.example` file in `env/dev`; actual values remain
gitignored. The examples cover three parent groups sharing a spoke network and a
separate hub network. Existing dev values are preserved in the corresponding
input files. Terraform automatically loads these files from the selected
environment root, so `palo dev plan`, `apply`, and `push-all` need no extra
flags. Keep each root variable in one file: repeated map definitions replace
rather than merge values. Do not also define these variables in a leftover
`terraform.tfvars`.


Composition variables use `type = any`; resource modules retain typed inputs.
Each declared stack call accepts one required, non-null `item` object. Dev
declares one common template, a spoke stack, and common policies;
unused stacks have no root
call. Feature module calls use one `items` map; only resource wrappers use
`for_each`. The template stack explicitly defines interfaces, subinterfaces,
zones, variables, routers and a default route. Set network values in
`templates.common.var`. To add a DMZ, add its values there and explicit resource
entries in templates/shared/common/main.tf; there is no need to
duplicate
the input
schema across parent modules. Supply WAN, LAN and management addresses as
complete strings, such as `"192.0.2.2/30"`, or `"None"` for an unassigned
template variable. Values pass through directly; separate prefix fields are no
longer used. Missing address fields raise Terraform errors. Assign device IP
overrides with `palo dev overrides plan` and `palo dev overrides apply`; see
[per-device overrides](docs/device-overrides.md). Common parent policies live in
`stacks/dev/policies/common`. Set one `policies.common` object in root tfvars
with `device_group = "parent"`, `lan_zone`, `wan_zone`, `wan_interface`, and
`default_security_rules`. These common policy inputs are independent of
templates; future site-specific policies may use template inputs. The parent
pre-rulebases contain:

- Source NAT for any service exiting the WAN zone/interface, using dynamic IP
  and port translation to the interface address.
- LAN-to-WAN allows for TCP destination port 22 and ICMP/ping, followed by an
  explicit deny for other LAN-to-WAN traffic. The deny precedes child rules.

NAT does not match virtual-router names; routing chooses the outgoing interface.
The rules are inherited by child device groups, including `spoke`. To deploy,
apply candidate changes, commit with
`module.deployment.action.panos_commit.all`, then push the child using
`module.deployment.action.panos_push_to_devices.policies["spoke"]`. The `branch`
and `hub` policy folders remain scaffolds. One module instance must own each
device-group/policy-type/rulebase scope; combine its ordered rules there.


`hub_template` is also a scaffold. Hub devices with the same WAN/LAN resource
layout can reuse the spoke stack through a new explicit root call with complete
inputs. Update the root template-key validation and action inputs at the same
time. Implement a separate hub module when its resource structure differs.

## Common templates and spoke stacks

Template definitions and stack assignments are separate:

- `templates.common` defines one shared network and settings template.
- `template_stacks.spoke` defines stack membership and firewall serials.

The common template contains interfaces, variables, routers, routes, zones,
and their profiles. Add future shared settings directly to this template.

```hcl
template_stacks = {
  spoke = {
    name = "example-stack"
    description = "Common and spoke configuration"
    templates = ["common"]
    serials = ["EXAMPLE_SERIAL"]
  }
}
```

Names and serials above are examples. `templates` lists root template keys in
priority order, highest first. The root resolves these keys through module
outputs. Use `["common"]` for a common-only stack, or add specific templates
in the desired order. Declare an additional explicit root stack call to create
another stack referencing the same common templates; do not recreate them.
A future hub stack can use `["common"]` and add a hub-specific
template ahead of common when needed.

`stacks/dev/templates/shared/common` owns the shared template, and
`stacks/dev/templates/spoke/stacks` owns stack creation. Each call accepts one
required object; module calls have no `for_each` or null guards. The existing
network template and stack keep their Panorama names. `env/dev/moved.tf` moves
the former nested stack module and renames the network module to
`module.common_template` without recreating its resources.

Commit targets include every template referenced by a stack. After changing a
shared template, push every affected stack to distribute the shared changes.

## Ping to interface addresses

The template creates one interface management profile for each configured zone
role. Shared names and settings live in `env/dev/locals.tf`:


```hcl
interface_management_profiles = {
  ping_only = {
    wan  = { name = "wan-ping", ping = true }
    lan  = { name = "lan-ping", ping = true }
    mgmt = { name = "mgmt-ping", ping = true }
  }
}
```

Select the set alongside `var` in the root template tfvars object:

```hcl
interface_management_profile_set = "ping_only"
```

The root resolves this required selector and passes the profiles to the stack.
Edit the definitions in `locals.tf` to change the shared names or permissions.
A missing or unknown selector raises an error.

These are example names. The WAN profile attaches to the physical WAN interface;
the LAN and management profiles attach to their respective subinterfaces.
Profiles attach to interfaces, not to zone objects. The unnumbered parent of
the subinterfaces has no management profile.

Only ping is enabled by these inputs. Other management services, including SSH,
HTTP and HTTPS, default to disabled. To restrict allowed sources, add
`permitted_ips = [{ name = "192.0.2.0/24" }]` to a profile; omitting this list
sets no source restriction in that profile. Ping requires an assigned interface
address and a working return route; an unassigned `"None"` variable provides no
address to ping. Apply the configuration, then commit and push to the devices.
See the [interface management profile documentation][interface-mgmt].

## Per-device overrides: `palo dev overrides`

`palo dev overrides` sets individual firewall values for shared Panorama
template variables. `dev` selects `env/dev`. This is a Python CLI command that
uses the Panorama XML API; it is separate from Terraform plan/apply.

The desired overrides come from **`env/dev/device_overrides.json`**, which you
create and edit. Start with
[`device_overrides.json.example`](env/dev/device_overrides.json.example),
replacing the example serial, stack name and addresses with your own values:

```json
{
  "firewall_a": {
    "serial": "YOUR_FIREWALL_SERIAL",
    "template_stack": "YOUR_TEMPLATE_STACK",
    "var": {
      "wan_ip": "192.0.2.2/30",
      "lan_ip": "198.51.100.1/24",
      "mgmt_ip": "203.0.113.1/24",
      "default_gateway": "192.0.2.1"
    }
  }
}
```

`firewall_a` is a local selection key for `--device`. `serial` identifies the
firewall, and `template_stack` must match its existing Panorama stack name (the
configured `template_stacks.spoke.name` value in this example). The device must
already be assigned to that stack, and the referenced IP Netmask variables must
exist in its templates. JSON keys omit the `$`: `lan_ip` updates `$lan_ip`. Add
more device entries to give firewalls sharing one template different values.

| Source | Purpose |
| --- | --- |
| `env/dev/templates.auto.tfvars` | Shared defaults and device assignments |
| `env/dev/device_overrides.json` | Desired per-firewall overrides |
| Panorama candidate configuration | Current values to compare and verify |

The helper does not generate the JSON from tfvars, discover desired addresses,
or export GUI overrides into the file. You supply the desired values; it reads
Panorama to determine what needs changing. Ordinary `palo dev plan` does not
show these API-managed override changes.

```sh
# Preview differences against Panorama candidate configuration; no writes.
palo dev overrides plan

# Recompute differences, write changed overrides and read them back.
palo dev overrides apply

# Select a device by its JSON key.
palo dev overrides plan --device firewall_a
palo dev overrides apply --device firewall_a

# Use another file; relative paths resolve under env/dev.
palo dev overrides plan --file device_overrides.staging.json
```

Absolute `--file` paths are also accepted. Apply the shared Terraform
configuration first, then run override plan/apply, then commit and push as shown
below. `overrides apply` changes candidate configuration only; it does not
commit or push. `--device` limits the override operation, not a later
commit/push action.

Only listed variables are managed. Omitting a variable or device leaves existing
overrides unchanged. To remove an override and inherit the template default, set
its JSON value to `null`, for example `"lan_ip": null`. Interface override
values require IPv4 address/prefix strings; the gateway requires an IPv4
address. The literal `"None"` is supported for shared template defaults, but is
not an accepted override-file address. A reset to inheritance may inherit
`"None"` if that is the template default. See
[per-device overrides](docs/device-overrides.md) for validation, authentication
and update details.

## Commit to Panorama and push to firewalls

```sh
palo dev init
palo dev plan
palo dev apply
palo dev overrides plan
palo dev overrides apply
# Commit all configured policy groups, templates and stacks:
palo dev apply -invoke='module.deployment.action.panos_commit.all'
# Push only the intersection of group "spoke" and template entry "spoke":
palo dev apply \
  -invoke='module.deployment.action.panos_push_to_devices.this["spoke/spoke"]'
```

To push every configured target after the commit succeeds:

```sh
palo dev push-all --dry-run
palo dev push-all
```

All environments share the actions and target selection in
`stacks/modules/panos/operations/commit_push`. Each root needs only this wiring
in `actions.tf` (plus any desired command comments):

```hcl
module "deployment" {
  source        = "../../stacks/modules/panos/operations/commit_push"
  device_groups = var.device_groups
  templates = { for key, item in local.template_stacks : key => {
    templates = item.templates
    stack = item.name
    serials = item.serials
  } }
}
```

After committing, push only templates or only policies with:

```sh
palo dev apply \
  -invoke='module.deployment.action.panos_push_to_devices.templates["spoke"]'
palo dev apply \
  -invoke='module.deployment.action.panos_push_to_devices.policies["spoke"]'
```

Use `plan` instead of `apply` to preview. These keys identify a template input
and a device group respectively; targets without assigned serials are excluded.
All action addresses use the `module.deployment` prefix, including commit-all.

`push-all` is a Python CLI command implemented in `src/palo_cli/push_all.py`,
not a Terraform action or a direct Python call to the Panorama API. It invokes
Terraform push actions; the PAN-OS provider performs the API calls.

`push-all` evaluates `module.deployment.deployment_items` using Terraform
console, lists the selected targets and serials, and asks for one confirmation.
It pushes targets sequentially and stops on the first failure. Use
`--auto-approve` to skip the batch prompt. It does not apply resource changes,
write variable overrides, or commit Panorama. Earlier successful pushes are not
rolled back on failure. “All” means this environment's configured group/template
intersections, not all firewalls in Panorama. Complete your configuration apply
and commit first. The command uses default environment variable files;
additional Terraform flags are not accepted, and inherited `TF_CLI_ARGS*`
options are ignored.

For a scoped commit, or a combined commit and push:

```sh
palo dev apply \
  -invoke='module.deployment.action.panos_commit.this["spoke/spoke"]'
palo dev apply \
  -invoke='module.deployment.action.panos_commit.commit_and_push["spoke/spoke"]'
```

Scoped commits include the target's parent group, child group, template and
stack. Action keys are `<device-group>/<template-key>`. Only non-empty serial
intersections create deployment targets. Unassigned groups/templates can still
be committed using `module.deployment.action.panos_commit.all`. Shared policy
commits can include changes affecting other children; push each affected target
deliberately. Normal apply does not invoke commit/push actions.

The root `moved.tf` migrates existing policy/template resource addresses. Run
`palo dev plan` and review the moves before applying; do not apply an old saved
plan. No state migration occurs until you apply. Unused root outputs are
removed; reusable modules retain `names` and other outputs needed by callers,
tests, or documented workflows.

## Offline checks

```sh
scripts/venv/bin/python3 -m unittest discover -s scripts -p "test_*.py"
terraform fmt -check -recursive
terraform -chdir=env/dev init -backend=false
terraform -chdir=env/dev validate
terraform -chdir=env/dev test
```

Mock-provider tests exercise two instances of every feature module, decoded
identifier names, policy order, multi-spoke variable/addressing configuration.
They also verify explicit values and pass-through fields, reject duplicate
interface ownership, and allow gateway values without custom subnet
restrictions. Action tests verify that only assigned spokes are eligible for
push and that blank serials are rejected. They do not verify device-side
acceptance or perform live commits/pushes.

See [deployment](docs/deployment.md) for the deployment boundary. Provider
reference:
https://registry.terraform.io/providers/PaloAltoNetworks/panos/2.0.13/docs

Input validation is limited to repository relationships and ownership: group
hierarchy, unique template/stack ownership, distinct managed interfaces, unique
resource/rule identities and unambiguous locations. Non-empty serial checks
remain because serials select push targets. Network value formats and
provider-specific attribute combinations are left to Terraform/provider
validation. Adding a field to the flexible composition inputs does not require a
matching validation rule; fields consumed by resource expressions must still be
supplied.


`.all` performs a full Panorama commit with no administrator, device-group,
template, or stack filters. It includes **all administrators' pending changes**,
including changes outside this Terraform environment, and does not push to
firewalls. `.this["group/template"]` remains a scoped partial commit. The
combined `commit_and_push` action also retains its scoped partial commit.

Shared zone protection settings live in `env/dev/locals.tf`. Select them with
`zone_protection_profile_set = "standard"` in a template entry in
`templates.auto.tfvars`. The root resolves that name and passes
`local.templates.common` to the shared network template module; tfvars cannot reference
locals directly. The `wan` and `lan` entries create separate profiles and attach
them to their respective zones through `network.zone_protection_profile`. The
reusable `network/zone_protection_profile` module supports multiple profiles and
returns a `names` map. The set selector and both profile entries
are required. Profile names are explicit in the shared WAN/LAN definitions in
`locals.tf`: `wan-protection` and `lan-protection`. Each selected template
creates its own profiles with those names in its template scope.

The dev enables SYN cookies, UDP/ICMP/ICMPv6/other-IP flood protection, TCP/UDP
scan and host-sweep blocking, and malformed/source-routing/TCP packet checks.
Spoofed-IP checks are enabled on LAN only; its ingress source routes must point
back to LAN. ICMP errors and fragmentation-needed replies remain available.
Authorized vulnerability scanners can be added to `scan_white_list` in the
shared locals.

Flood rates are **dev starting points, not vendor-recommended universal
values**: TCP SYN/UDP/other IP use alarm/activate/maximum rates of
1000/2000/4000 new connections per second; ICMP/ICMPv6 use 100/200/400. Baseline
normal and peak traffic and firewall capacity before applying to a busier
environment. SYN cookies also consume CPU. Reconnaissance uses 100 events in 2
seconds for port scans and 10 seconds for host sweeps. These controls act on
ingress traffic. See Palo Alto's [zone protection guidance][zone-protection] and
[reconnaissance settings][reconnaissance].

Deploy with a normal plan/apply, then commit Panorama and push the template:

```sh
palo dev plan
palo dev apply
palo dev apply -invoke='module.deployment.action.panos_commit.all'
palo dev apply \
  -invoke='module.deployment.action.panos_push_to_devices.templates["spoke"]'
```

Common policies also accept `default_security_rules` in root tfvars. The dev
sets `intrazone-default` to `deny` with session-end logging at the parent group.
Child firewalls inherit it unless a lower-level default-rule override takes
precedence. This blocks same-zone traffic only when no earlier security rule
matches; it does not affect traffic switched without traversing the firewall.
`interzone-default` retains its built-in deny behavior. One module must own the
complete default-security override list for each scope. Apply, commit Panorama,
and push the child device group's policies to activate the change.

Spoke subinterface assignments come from `env/dev/templates.auto.tfvars`: set
`mgmt_subinterface_tag`, `mgmt_zone`, and `mgmt_virtual_router` for management,
and `lan_subinterface_tag`, `lan_zone`, and `data_virtual_router` for data.
Spoke LAN networking uses the configured `lan_interface` as an unnumbered Layer
3 parent. Management and data subinterfaces use their configured tags, zones and
routers. Supply `mgmt_ip` and `lan_ip` as complete address/prefix strings or
`"None"`. The WAN default route remains in the data router; the management
router has no static routes configured.

The dev root creates one shared common template and one stack. Add explicit
root template/stack calls and corresponding input wiring for more targets.
`policies.common` is one object (no `parent` wrapper). State moves for the
previous dev addresses are in `env/dev/moved.tf`; review a fresh plan before
applying.

[keyring-setup]:
  #save-and-retrieve-panorama-credentials-with-keyring

[system-info]:
  https://docs.paloaltonetworks.com/ngfw/api/getting-started/explore-xmlapi

[onboarding-workflow]:
  https://docs.paloaltonetworks.com/panorama/administration/manage-firewalls/add-a-firewall-as-a-managed-device

[registration-keys]:
  https://docs.paloaltonetworks.com/panorama/administration/troubleshooting/recover-managed-device-connectivity-to-panorama

[api-commits]:
  https://docs.paloaltonetworks.com/ngfw/api/pan-os-xml-api-request-types-and-actions/commit

[zone-protection]:
  https://docs.paloaltonetworks.com/ngfw/administration/zone-protection-and-dos-protection/zone-defense/zone-protection-profiles

[reconnaissance]:
  https://docs.paloaltonetworks.com/ngfw/help/12-1/network/network-network-profiles/network-network-profiles-zone-protection/reconnaissance-protection

[interface-mgmt]:
  https://docs.paloaltonetworks.com/ngfw/networking/configure-interfaces/use-interface-management-profiles-to-restrict-access
