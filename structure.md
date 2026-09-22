# Repository structure and Terraform conventions

This project is an example of organizing PAN-OS configuration with Terraform,
not a specification for a particular deployment. These rules describe code
structure and input handling. They do not prescribe resource names or network
values. Read this file before making changes and preserve unrelated user edits.

## Line length

- Limit source lines to 80 characters. Wrap Markdown prose and comments, and use
  valid language syntax to split long code examples and commands.
- Keep table rows concise. Use reference links for long Markdown links.
- Unbreakable URL destinations may exceed 80 characters; never split a URL or
  change executable syntax merely to satisfy the limit.

## Configuration belongs in root tfvars

- Supply deployment values through `env/<environment>/*.tfvars`: template and
  template-stack names, interface names, VLAN tags, zone names, virtual-router
  names, profile names, addresses, prefix lengths, device assignments, and
  policy
  settings. Maintain inputs directly in `env/dev/`; do not add duplicate
  `.example` files there. Keep documentation examples aligned with inputs.
- Names and values in example files are illustrative. Do not turn them into
  project requirements, hardcoded module values, validation allowlists, or
  required naming conventions. Validate required fields and actual constraints,
  not equality with an example value.
- Root modules pass inputs to stacks. Root locals may resolve explicitly
  selected
  shared settings. Shared example settings are configuration, not universal
  defaults that every deployment must use. Interface management and zone
  protection profiles may use this pattern: define shared sets in root
  `locals.tf` and select a set explicitly in the template's tfvars input.
- Address inputs contain the complete provider value: an address with its prefix
  or the literal string `"None"` for an unassigned template variable. Pass the
  value directly; do not append a separate prefix or add fallback conditionals.
  Required address fields must be explicitly supplied; `"None"` is a value,
  not an omitted field or Terraform null.
- Stacks compose resources and wire references. Do not introduce hidden fallback
  values for required configuration. Derived names such as `${parent}.${tag}`
  must use configured inputs.
- Terraform block labels and logical map keys identify code instances; they are
  distinct from names sent to Panorama. Keep keys stable, but do not require
  configured resource names to match them.

## Layers

| Path | Responsibility |
| --- | --- |
| `env/<environment>/` | Root inputs, providers, stack wiring, and tests |
| `stacks/dev/` | Network and policy example composition |
| `stacks/modules/panos/` | Reusable wrappers around PAN-OS provider resources |
| `src/palo_cli/` | Operational CLI and device variable override support |
| `docs/` | Workflow and operational documentation |

## Template organization

- `stacks/dev/templates/shared/common/` owns one shared template containing
  networking and common settings for spoke and future hub stacks.
- `stacks/dev/templates/spoke/stacks/` creates a stack from an ordered list of
  existing template names and its own device assignments.
- Create each template once. Stacks reference its output name and may reuse it
  across multiple calls. A stack can use common alone or combine it with
  specific templates; root tfvars defines membership and priority order.
- Keep template definitions separate from stack/device assignments in root
  inputs. Keep interface-dependent profiles in the same template as the
  interfaces and zones that reference them.

## Explicit module composition

- Put provider resource blocks in reusable modules under
  `stacks/modules/panos/`.
  Stack files call these modules.
- Do not put `for_each` or `count` on stack or feature module calls. Each
  template
  or policy stack call accepts one `item` object. Declare separate explicit root
  calls for separate targets.
- A declared stack requires one complete, non-null `item` object
  (`nullable = false`, no default). Do not add null guards, fallback objects, or
  conditional enable/disable expressions to module `items`; use plain
  `items = { ... }` maps.
- Declare only the stack calls the example uses, with corresponding root inputs.
  Do not keep an unused call active with a null input. When adding a target,
  update its root call, input wiring, and any relevant structural validation.
- Each feature module receives one `items` map with a separate, explicit entry
  for each intended resource role. Keep `for_each` inside resource wrappers.
  Genuinely plural inputs remain maps in a single call.
- Do not hide fixed role definitions in flattened loops, numeric lists, or
  tag-based conditionals. Comprehensions are appropriate for genuinely
  input-driven collections and output maps.
- Declare `device_group` explicitly in each root device-group entry; map keys
  are logical identifiers. Pass the map directly without injecting names.
- Pass names already supplied by root tfvars directly. Do not merge an object
  solely to replace a configured name with an identical module output.
- Use explicit `depends_on` when direct inputs need creation ordering. Use
  `names` outputs when resolving logical keys or derived memberships.
- Use stable logical keys rather than mutable deployment values as resource
  instance keys.
- Pass declared profile and policy settings directly. Omit unused optional
  provider attributes instead of assigning null in module calls. Provider
  schemas may represent omitted optional attributes as null; this convention
  governs our configuration, not provider internals.
- An example stack may demonstrate a particular topology. That topology and its
  sample assignments do not establish mandatory interface names, zones, routers,
  VLANs, templates, or naming schemes for other examples or deployments.

## Reusable module contract

- Keep `main.tf`, `variables.tf`, and `versions.tf` separate. Add `outputs.tf`
  for the reusable `names` contract or outputs used by callers, tests, or
  documented operational workflows.
- Preserve `names` outputs under `stacks/modules/`, even when no current
  caller uses them. They are part of the reusable module contract.
- Remove other unused outputs and delete `outputs.tf` when none remain.
  Do not retain commented-out output blocks.
- Use a typed `items` map and `for_each = var.items` in the resource wrapper.
  Pass supported provider attributes through without imposing deployment
  choices.
- Expose `names` keyed by logical input key in reusable resource modules.
- Do not expose import-identifier maps as outputs. Test configured names,
  locations, memberships, and rule settings directly.
- Stack input objects follow the pass-through `type = any` convention; do not
  duplicate a full root schema in every composition layer.
- Expose resource maps directly, without an unnecessary outer target key when
  a stack call already represents one target.
- Add focused outputs when callers or tests need to inspect configured behavior.

## Verification and change handling

- Update inputs, examples, documentation, and affected tests together.
- Run Terraform formatting, validation, and relevant mock-provider tests for
  code
  changes. Use alternate input values to detect hardcoded names, tags, and
  memberships. Test values are fixtures, not required deployment settings.
- Run CLI tests when changing device variable support.
- Preserve unrelated edits and staged changes. Do not apply to Panorama as part
  of a code-only refactor.
- Resource-address changes require migration planning if already applied. Use
  appropriate moved blocks or explicit state moves; renaming a Terraform address
  does not adopt an existing device object. Keep deployment-specific migration
  mappings in the relevant environment configuration or migration documentation,
  not as naming rules in this file.
- Review the final diff against these rules. Update this document when the user
  changes a convention; do not refactor unrelated code solely for conformance.
