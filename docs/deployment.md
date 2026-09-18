# Deployment workflow

The lab requires Terraform >= 1.14 and PAN-OS provider 2.0.13. Actions are
defined in `stacks/modules/panos/operations/commit_push` and called from
`env/lab/actions.tf` as `module.deployment`: one scoped commit/push target per non-empty device-group/template serial intersection. They use the same keyring-based
provider connection as the configuration resources.

1. Store Panorama credentials in keyring and set hostname/keyring selectors in
   `env/lab/palo.json`. See README for setup.
2. Edit environment inputs and review device-group/template ownership. For
   existing configuration, import the resources before applying and reconcile
   the plan. Use provider import identifiers, not device UUIDs.
3. Activate the virtual environment from the workspace root:

   ```sh
   source scripts/venv/bin/activate
   ```

4. Run offline checks, review the candidate-configuration plan, then apply it:

   ```sh
   palo lab validate
   palo lab test
   palo lab plan -out=lab.tfplan
   palo lab apply lab.tfplan
   ```

5. Review candidate changes and commit the selected spoke to Panorama:

   ```sh
   palo lab plan -invoke='module.deployment.action.panos_commit.this["spoke/spoke"]'
   palo lab apply -invoke='module.deployment.action.panos_commit.this["spoke/spoke"]'
   ```

6. After the commit succeeds, push to the spoke's assigned firewalls:

   ```sh
   palo lab plan -invoke='module.deployment.action.panos_push_to_devices.this["spoke/spoke"]'
   palo lab apply -invoke='module.deployment.action.panos_push_to_devices.this["spoke/spoke"]'
   ```

Replace `spoke/spoke` with `<device-group>/<template-key>` for another target. Keep the quoted
addresses so your shell does not interpret brackets or strip the key quotes.
Each apply retains Terraform's interactive confirmation.

## Commit and push behavior

Normal `palo lab apply` manages configuration, including move-device-group jobs for hierarchy changes, but does not invoke commit/push actions. There are no
resource lifecycle action triggers. `-invoke` targets an operation rather than
performing a normal configuration apply; it does not apply pending interface,
variable or membership edits first. Complete step 4 before invoking actions.
Commit and push are separate invocations; no automatic dependency between them
is implied by their declarations.

The commit selects the target's parent group, device group, template and template stack, with
`force = false`. This is a configuration-scope selection, not a Terraform-only
change filter: review other pending administrator edits in the same scopes.

The push targets only serials present in both the device group and template
entry. It includes template configuration and leaves `force_template_values = false`.
Unassigned groups/templates have no scoped target; commit them using:

```sh
palo lab plan -invoke='action.panos_commit.all'
palo lab apply -invoke='action.panos_commit.all'
```

Firewalls must already be managed by Panorama. The actual lab retains PA-A's
existing group/stack assignment.

Mocked tests verify configuration and target selection. No live commit or push
was performed during implementation. Verify job results in Panorama during
live testing. Commit/push failures do not roll back the candidate-resource
apply; resolve the reported issue and retry the required operation.

One environment root owns its state. Shared objects and policy rulebases must
have exactly one owner. Before shared production use, configure a remote
backend with locking/access controls and verify the full workflow in the lab.

References:
- [Commit action](https://github.com/PaloAltoNetworks/terraform-provider-panos/blob/v2.0.13/docs/actions/commit.md)
- [Push action](https://github.com/PaloAltoNetworks/terraform-provider-panos/blob/v2.0.13/docs/actions/push_to_devices.md)
- [Terraform action invocation](https://developer.hashicorp.com/terraform/language/invoke-actions)

## Combined commit and push

After applying candidate configuration, use this as an alternative to separate
commit and push invocations:

```sh
palo lab plan -invoke='module.deployment.action.panos_commit.commit_and_push["spoke/spoke"]'
palo lab apply -invoke='module.deployment.action.panos_commit.commit_and_push["spoke/spoke"]'
```

The combined action uses the commit action's `push_configuration` option. It
selects the same device group/template/stack and explicit serials as the
separate actions, includes template configuration, and does not force local
template overrides. It only exists for entries with non-empty `serials`.
`name_id.commit_and_push` exposes the module-relative invocation addresses.
A successful commit is not rolled back if the subsequent push fails; inspect
the job results and retry the push-only action when appropriate.

## Shared device groups

`device_groups` owns group membership and parent relationships independently
of `templates`. A parent commit can affect multiple child groups. Push every
affected group/template target after changing inherited policy.

`env/lab/moved.tf` preserves existing resources while moving policy ownership
to `module.device_grp` and network ownership to `module.templates`. Review these
moves in a fresh plan before applying; do not use an older saved plan.

Run `palo lab overrides plan` and `palo lab overrides apply` after the normal
Terraform apply and before commit/push. See [per-device overrides](device-overrides.md).
`--device` only limits helper writes; actions still target the full selected
policy/template intersection.
