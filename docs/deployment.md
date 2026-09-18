# Deployment workflow

The lab requires Terraform >= 1.14 and PAN-OS provider 2.0.13. Actions are
defined in `stacks/modules/panos/operations/commit_push` and called from
`env/lab/actions.tf` as `module.deployment`: one commit action per spoke and one push
action per spoke with non-empty `serials`. They use the same keyring-based
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
   palo lab plan -invoke='module.deployment.action.panos_commit.this["spoke01"]'
   palo lab apply -invoke='module.deployment.action.panos_commit.this["spoke01"]'
   ```

6. After the commit succeeds, push to the spoke's assigned firewalls:

   ```sh
   palo lab plan -invoke='module.deployment.action.panos_push_to_devices.this["spoke01"]'
   palo lab apply -invoke='module.deployment.action.panos_push_to_devices.this["spoke01"]'
   ```

Replace `spoke01` with the input map key for another spoke. Keep the quoted
addresses so your shell does not interpret brackets or strip the key quotes.
Each apply retains Terraform's interactive confirmation.

## Commit and push behavior

Normal `palo lab apply` writes candidate configuration only. There are no
resource lifecycle action triggers. `-invoke` targets an operation rather than
performing a normal configuration apply; it does not apply pending interface,
variable or membership edits first. Complete step 4 before invoking actions.
Commit and push are separate invocations; no automatic dependency between them
is implied by their declarations.

The commit selects the spoke's device group, template and template stack, with
`force = false`. This is a configuration-scope selection, not a Terraform-only
change filter: review other pending administrator edits in the same scopes.

The push targets the device group and exactly the `serials` listed for that
spoke, includes template configuration, and leaves `force_template_values =
false` so it does not force template values over local overrides. An empty
serial list creates no push action; configuration-only spokes can still be
committed to Panorama. Firewalls must already be managed by Panorama.

The current lab inputs have `serials = []`, so only its commit action exists.
To push, set real serials, apply those membership changes, commit, and then
invoke push. The actions apply to the policy/template configuration in `spokes`.

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
palo lab plan -invoke='module.deployment.action.panos_commit.commit_and_push["spoke01"]'
palo lab apply -invoke='module.deployment.action.panos_commit.commit_and_push["spoke01"]'
```

The combined action uses the commit action's `push_configuration` option. It
selects the same device group/template/stack and explicit serials as the
separate actions, includes template configuration, and does not force local
template overrides. It only exists for entries with non-empty `serials`.
`name_id.commit_and_push` exposes the module-relative invocation addresses.
A successful commit is not rolled back if the subsequent push fails; inspect
the job results and retry the push-only action when appropriate.

## Shared device groups

Spokes can reference the same device-group name. Its device membership is the
combined serial list across all those spokes. A per-spoke commit includes that
shared group's pending changes, potentially including membership or policy
changes for another spoke. Push and combined actions still use only the
selected spoke's serials and their assigned template configuration.

For the existing lab state, `env/lab/moved.tf` migrates the PA-A group from key
`paa` to key `spoke`; review this state move in the next normal plan/apply before
invoking deployment actions.

For shared stacks with per-device variable values, run `palo lab overrides plan`
and `palo lab overrides apply` after the normal Terraform apply and before commit/push.
See [per-device overrides](device-overrides.md). Existing actions still target all
serials in the selected spoke entry, even if override apply used `--device`.
