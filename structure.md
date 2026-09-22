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

## Fixed definitions and deployment inputs

- Use root `env/<environment>/*.tfvars` for values that need to vary or be
  overridden by deployment, site, or stack caller. Do not expose every constant
  as an input merely because it is a configurable provider attribute.
- Declare fixed shared definitions directly in the owning stack's module calls
  or locals. Service ports, rule names, actions, application lists, and shared
  object definitions may live there when callers do not need to change them.
- The common policy stack already follows this pattern for the `tcp-22`
  service and shared NAT/security rules. Device-group scope, interface and zone
  selections remain inputs where deployments need different values.
- Common policy addresses and groups belong in the common policy stack.
  Fixed shared objects and membership may be declared there. Expose only the
  names, subnets, or membership that callers need to override through inputs
  under `policies.common`; whole object maps are appropriate when the object
  set itself varies by deployment.
- Keep each definition in one place. Do not duplicate fixed stack definitions
  in tfvars or add fallback/merge logic solely to make constants overridable.
  Promote a fixed value to an explicit input when a caller needs to vary it.
- Use root `locals.tf` for common profiles and `local.templates` to assemble
  template inputs with their selected profiles. Pass
  `local.templates.<role>` to the corresponding template module. Put explicit
  role GRE tunnels and memberships in each role module's `main.tf`.
  Locals may also assemble template-stack inputs, resolving logical template
  keys once. Pass the same objects directly to stack and deployment modules;
  do not add an adapter solely to rename fields such as `name` to `stack`.
  Keep role-specific resource definitions in their stack modules.
- Root modules pass inputs to stacks. Select common profile sets explicitly
  through tfvars. Maintain inputs directly in
  `env/dev/`; do not add duplicate `.example` files there. Keep documentation
  examples aligned with inputs.
- Fixed values in an example stack describe that stack, not universal project
  requirements. Keep reusable provider modules under `stacks/modules/panos/`
  free of deployment choices. Validate actual constraints, not equality with
  example names or values.
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

- `stacks/dev/templates/shared/common/` owns shared device settings independent
  of role networking, such as DNS, NTP, or timezone when configured. It may
  remain an empty template until those settings are supplied.
- `stacks/dev/templates/spoke/network/` and `hub/network/` each own a complete
  network template: physical and tunnel interfaces, subinterfaces, address
  variables, interface-dependent profiles, zones, routers, and GRE endpoints.
- Keep every network reference within its owning role template. GRE sources
  reference that template's WAN interface address variable. Management routers
  and zones include the management subinterface and the role's tunnels.
- Configure BGP on the role's existing management router. Keep peer definitions
  explicit in `main.tf` and deployment-specific BGP inputs in the role's
  network object. Reuse tunnel address variables for BGP local addresses.
  Match tfvars field names to template variable keys and names, excluding the
  Panorama `$` prefix. Use explicit peer-prefixed fields for multiple peers;
  do not introduce a nested peer map that requires renaming those fields.
- Expose per-device ASNs as AS Number variables and peer/router-ID addresses as
  IP Netmask variables. Keep authentication secrets in Terraform inputs when
  the installed provider does not support a matching template-variable type.
  Do not publish secret values through non-sensitive outputs.
- Do not create stack-scoped network overrides or duplicate the same router
  across common and role templates. Reuse Terraform profile definitions and
  resource wrappers, while creating their Panorama objects in each role.
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
  calls for separate targets. Pass the complete role network configuration as
  `network = var.templates.<role>.var`. Keep deployment-specific network values
  under that role, including GRE and future IPsec; do not add separate feature
  input variables or tfvars files. Include tunnel interface names in this
  network object; keep template identity and profile selections outside it.
  Stack names are not network module inputs.
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
- Template composition modules expose their single template name as
  `names.template`, consistently across common, spoke, and hub.
- Expose resource maps directly, without an unnecessary outer target key when
  a stack call already represents one target.
- Add focused outputs when callers or tests need to inspect configured behavior.

## Verification and change handling

- Update inputs, examples, documentation, and affected tests together.
- Run Terraform formatting, validation, and relevant mock-provider tests for
  code
  changes. Use alternate values to verify configurable inputs are respected.
  Verify intentional fixed definitions separately. Test values are fixtures,
  not required deployment settings.
- Run CLI tests when changing device variable support.
- Preserve unrelated edits and staged changes. Do not apply to Panorama as part
  of a code-only refactor.
- Resource-address changes require migration planning if already applied. Use
  appropriate moved blocks or explicit state moves; renaming a Terraform address
  does not adopt an existing device object. Keep deployment-specific migration
  mappings in the relevant environment configuration or migration documentation,
  not as naming rules in this file. Changing Panorama location requires an
  actual configuration migration; state moves alone do not relocate objects.
  Remove obsolete common networking and stack overrides before pushing the
  completed migration. Preserve per-device variable overrides.
- Review the final diff against these rules. Update this document when the user
  changes a convention; do not refactor unrelated code solely for conformance.
