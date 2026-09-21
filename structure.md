# Repository structure and Terraform conventions

These rules govern new work and changes to existing code. Consult this file before
editing Terraform. Preserve unrelated user changes; do not refactor unrelated
stacks just to bring them into conformance.

## Configuration belongs in root tfvars

- Define environment choices in `env/<environment>/*.tfvars`: interface parents,
  VLAN tags, zone and router names, addresses, prefix lengths, assignments,
  device serials, and policy settings. Update matching `.example` files.
- Root modules pass inputs to stacks. Root locals may resolve explicitly selected
  shared settings (such as the existing zone protection profile sets).
- Stacks compose resources and wire references; do not hardcode deployment values
  or introduce hidden fallback values for required configuration.
- Stable logical keys (`wan`, `lan`, `mgmt`, `data`), fixed topology, descriptive
  comments, and provider scope conventions are implementation details. Derived
  names such as `${parent}.${tag}` must use configured inputs. Existing fixed
  route defaults remain part of the topology until made configurable deliberately.

## Layers

| Path | Responsibility |
| --- | --- |
| `env/<environment>/` | Root inputs, provider configuration, stack wiring, and tests |
| `stacks/dev/` | Compose feature modules into readable network and policy topology |
| `stacks/modules/panos/` | Reusable, typed wrappers around PAN-OS provider resources |
| `src/palo_cli/` | Operational CLI and device variable override support |
| `docs/` | Workflow and operational documentation |

## Explicit module composition

- Put provider resource blocks in reusable modules under `stacks/modules/panos/`.
  Stack files should call modules, following the existing `module "interfaces"`
  pattern.
- Use `for_each = var.items` for per-template composition and an `items` map with
  a separate, explicit entry for each intended role. A reader must be able to
  see management and LAN subinterfaces individually.
- Do not hide a fixed set of role definitions in flattened loops, numeric lists,
  or tag-based conditionals. Comprehensions are appropriate for genuinely
  input-driven collections and output maps.
- Reference module outputs for dependencies and memberships. Avoid reconstructing
  another module's resource name where its `names` output is available.
- Use stable logical keys rather than mutable VLAN tags as resource instance keys.

The spoke zone protection module declares explicit `wan` and `lan` entries.
Profile values come from the root-selected shared profile set. Each entry is
optional; a filtering comprehension may omit absent entries after their explicit
definitions. Add any new role explicitly rather than silently expanding all input
keys.

The spoke subinterface module has explicit `mgmt` and `lan` entries. The root
`templates.auto.tfvars` supplies:

| Role | VLAN tag | Zone | Virtual router | Address |
| --- | --- | --- | --- | --- |
| Management | `mgmt_subinterface_tag` | `mgmt_zone` | `mgmt_virtual_router` | `mgmt_ip`, `mgmt_prefix_length` |
| LAN/data | `lan_subinterface_tag` | `lan_zone` | `data_virtual_router` | `lan_ip`, `lan_prefix_length` |

Both use `lan_interface` as their parent. The parent is unnumbered; subinterfaces
are assigned to their respective zones and routers. The WAN default route belongs
to the data router. Dev currently uses VLAN 10 for management and VLAN 20 for data.

## Reusable module contract

- Keep `main.tf`, `variables.tf`, `outputs.tf`, and `versions.tf` separate.
- Use a typed `items` map and `for_each = var.items` in the resource wrapper.
  Pass supported provider attributes through without imposing deployment choices.
- Expose `names` keyed by logical input key and `name_id` keyed by resource name.
  Import identifiers must include the provider's required parent and location.
- Stack input objects follow the existing pass-through `type = any` convention;
  do not duplicate a full root schema in every composition layer.
- Add focused outputs when callers or tests need to inspect configured behavior.

## Verification and change handling

- Update root inputs, examples, documentation, and affected tests together.
- Run Terraform formatting, validation, and relevant mock-provider tests. Test
  alternate root values to detect hardcoded tags, names, and memberships.
- Run CLI tests when changing device variable support.
- Preserve unrelated edits and staged changes. Do not apply to Panorama as part
  of a code-only refactor.
- Resource-address changes require migration planning if already applied. Use
  appropriate moved blocks or explicit state moves; never assume renaming a
  Terraform address adopts an existing device object.
- Review the final diff against these rules. Explain any necessary exception;
  update this document when the user changes a convention.

### Subinterface module refactor

Subinterface output keys are now stable roles (`mgmt`, `lan`) rather than VLAN
numbers. If the earlier direct-resource version was applied, migrate each
existing instance before applying the refactor. For the current dev spoke, the
address mappings are:

```text
module.templates.panos_ethernet_layer3_subinterface.lan["spoke/10"]
  -> module.templates.module.subinterfaces["spoke"].panos_ethernet_layer3_subinterface.this["mgmt"]
module.templates.panos_ethernet_layer3_subinterface.lan["spoke/20"]
  -> module.templates.module.subinterfaces["spoke"].panos_ethernet_layer3_subinterface.this["lan"]
```

Use the actual template keys and prior VLAN tags for other deployments. No state
migration or live apply is performed by this code refactor.
