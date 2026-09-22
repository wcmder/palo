# Deployment workflow

The dev requires Terraform >= 1.14 and PAN-OS provider 2.0.13. Actions are
defined in `stacks/modules/panos/operations/commit_push` and called from
`env/dev/actions.tf` as `module.deployment`: one scoped commit/push target per
non-empty device-group/template serial intersection. They use the same
keyring-based
provider connection as the configuration resources.

1. Store Panorama credentials in keyring and set hostname/keyring selectors in
   `env/dev/palo.json`. See README for setup.
2. Edit environment inputs and review device-group/template ownership. For
   existing configuration, import the resources before applying and reconcile
   the plan. Use provider import identifiers, not device UUIDs.
3. Activate the virtual environment from the workspace root:

   ```sh
   source scripts/venv/bin/activate
   ```

4. Run offline checks, review the candidate-configuration plan, then apply it:

   ```sh
   palo dev validate
   palo dev test
   palo dev plan -out=dev.tfplan
   palo dev apply dev.tfplan
   ```

5. Review candidate changes and commit the selected spoke to Panorama:

   ```sh
   palo dev plan
   -invoke='module.deployment.action.panos_commit.this["spoke/spoke"]'
   palo dev apply
   -invoke='module.deployment.action.panos_commit.this["spoke/spoke"]'
   ```

6. After the commit succeeds, push to the spoke's assigned firewalls:

   ```sh
   palo dev plan
   -invoke='module.deployment.action.panos_push_to_devices.this["spoke/spoke"]'
   palo dev apply
   -invoke='module.deployment.action.panos_push_to_devices.this["spoke/spoke"]'
   ```

Replace `spoke/spoke` with `<device-group>/<template-key>` for another target.
Keep the quoted
addresses so your shell does not interpret brackets or strip the key quotes.
Each apply retains Terraform's interactive confirmation.

## Commit and push behavior

Normal `palo dev apply` manages configuration, including move-device-group jobs
for hierarchy changes, but does not invoke commit/push actions. There are no
resource lifecycle action triggers. `-invoke` targets an operation rather than
performing a normal configuration apply; it does not apply pending interface,
variable or membership edits first. Complete step 4 before invoking actions.
Commit and push are separate invocations; no automatic dependency between them
is implied by their declarations.

The commit selects the target's parent group, device group, template and
template stack, with
`force = false`. This is a configuration-scope selection, not a Terraform-only
change filter: review other pending administrator edits in the same scopes.

The push targets only serials present in both the device group and template
entry. It includes template configuration and leaves `force_template_values =
false`.
Unassigned groups/templates have no scoped target; commit them using:

```sh
palo dev plan -invoke='module.deployment.action.panos_commit.all'
palo dev apply -invoke='module.deployment.action.panos_commit.all'
```

`.all` performs a full Panorama commit with no administrator, device-group,
template, or stack filters. It includes **all administrators' pending changes**,
including changes outside this Terraform environment, and does not push to
firewalls. `.this["group/template"]` remains a scoped partial commit.
The combined `commit_and_push` action also retains its scoped partial commit.


Firewalls must already be managed by Panorama. The actual dev retains PA-A's
existing group/stack assignment.

Mocked tests verify configuration and target selection. No live commit or push
was performed during implementation. Verify job results in Panorama during
live testing. Commit/push failures do not roll back the candidate-resource
apply; resolve the reported issue and retry the required operation.

One environment root owns its state. Shared objects and policy rulebases must
have exactly one owner. Before shared production use, configure a remote
backend with locking/access controls and verify the full workflow in the dev.

References:
- [Commit action](https://github.com/PaloAltoNetworks/terraform-provider-panos/blob/v2.0.13/docs/actions/commit.md)
- [Push action](https://github.com/PaloAltoNetworks/terraform-provider-panos/blob/v2.0.13/docs/actions/push_to_devices.md)
- [Terraform action invocation](https://developer.hashicorp.com/terraform/language/invoke-actions)

## Combined commit and push

After applying candidate configuration, use this as an alternative to separate
commit and push invocations:

```sh
palo dev plan
-invoke='module.deployment.action.panos_commit.commit_and_push["spoke/spoke"]'
palo dev apply
-invoke='module.deployment.action.panos_commit.commit_and_push["spoke/spoke"]'
```

The combined action uses the commit action's `push_configuration` option. It
selects the same device group/template/stack and explicit serials as the
separate actions, includes template configuration, and does not force local
template overrides. It only exists for entries with non-empty `serials`.
Use the action addresses shown above when invoking a target.
A successful commit is not rolled back if the subsequent push fails; inspect
the job results and retry the push-only action when appropriate.

## Shared device groups

`device_groups` owns group membership and parent relationships independently
of `templates`. A parent commit can affect multiple child groups. Push every
affected group/template target after changing inherited policy.

Network ownership now belongs to the spoke and hub templates. For existing
common networking and stack overrides, follow the
[migration procedure](gre.md#migration-from-shared-networking). State moves
alone cannot change the Panorama location of network objects.

Run `palo dev overrides plan` and `palo dev overrides apply` after the normal
Terraform apply and before commit/push. See [per-device
overrides](device-overrides.md).
`--device` only limits helper writes; actions still target the full selected
policy/template intersection.

## Push every configured target

After applying configuration/overrides and successfully committing Panorama:

```sh
palo dev push-all --dry-run
palo dev push-all
```

The command discovers current `module.deployment.deployment_items` through
Terraform console,
shows target keys and serials, and requests one batch confirmation. Each push
runs sequentially through the existing provider action. It stops at the first
failure, reports completed targets, and never automatically retries or rolls
back.
Check Panorama job results before retrying. `--auto-approve` skips confirmation.
An empty target map performs no pushes. The command does not commit, apply
configuration resources, or update device overrides. It uses the selected
root's default inputs and ignores inherited `TF_CLI_ARGS*` options.
