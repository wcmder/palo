"""Push committed configuration to the deployment targets in an environment."""
import argparse
import json
import subprocess
import sys


def parser():
    result = argparse.ArgumentParser(
        prog="palo <environment> push-all",
        description="Push committed configuration to all configured deployment targets. Does not apply resources, overrides, or commit Panorama.",
    )
    result.add_argument("--dry-run", action="store_true", help="List targets without pushing.")
    result.add_argument("--auto-approve", action="store_true", help="Skip the batch confirmation.")
    return result


def discover(executable, root, child):
    # Evaluate Terraform's own target expression rather than parsing HCL or
    # relying on an output saved by a previous apply.
    result = subprocess.run(
        [executable, f"-chdir={root}", "console", "-no-color"],
        input="jsonencode(local.deployment_items)\n", text=True,
        capture_output=True, env=child,
    )
    if result.returncode:
        raise ValueError("Could not evaluate deployment targets. Run palo <environment> init and validate, and apply configuration before pushing.")
    try:
        targets = json.loads(json.loads(result.stdout.strip()))
        if not isinstance(targets, dict):
            raise ValueError()
        for key, target in targets.items():
            if not isinstance(key, str) or not isinstance(target, dict):
                raise ValueError()
            serials = target.get("serials")
            if not isinstance(serials, list) or not serials or not all(isinstance(s, str) and s.strip() for s in serials):
                raise ValueError()
        return targets
    except (ValueError, TypeError):
        raise ValueError("Deployment targets must be known and contain non-empty serial lists.") from None


def run(options, root, child, executable):
    try:
        # Batch operations use this environment's default inputs. Inherited CLI
        # arguments must not redirect discovery or substitute another apply plan.
        child = {k: v for k, v in child.items() if not k.startswith("TF_CLI_ARGS")}
        targets = discover(executable, root, child)
        if not targets:
            print("[palo] No assigned deployment targets; nothing to push.")
            return 0
        print("[palo] Push targets (committed configuration only):", flush=True)
        for key in sorted(targets):
            print(f"  {key}: {', '.join(targets[key]['serials'])}", flush=True)
        if options.dry_run:
            return 0
        if not options.auto_approve:
            answer = input('Push all listed targets? Type "yes" to continue: ')
            if answer != "yes":
                print("[palo] Push cancelled.")
                return 0
        completed = []
        for key in sorted(targets):
            address = f"module.deployment.action.panos_push_to_devices.this[{json.dumps(key)}]"
            print(f"[palo] Pushing {key}...", flush=True)
            result = subprocess.run(
                [executable, f"-chdir={root}", "apply", "-auto-approve", f"-invoke={address}"],
                env=child,
            )
            if result.returncode:
                print(f"[palo] Push failed for {key}; stopping. Completed targets: {', '.join(completed) or 'none'}. Inspect Panorama jobs before retrying; earlier pushes are not rolled back.", file=sys.stderr)
                return result.returncode if result.returncode > 0 else 1
            completed.append(key)
        print(f"[palo] Pushed {len(completed)} deployment target(s).")
        return 0
    except (EOFError, KeyboardInterrupt):
        print("[palo] Push interrupted. Inspect Panorama jobs before retrying.", file=sys.stderr)
        return 130
    except (ValueError, OSError) as exc:
        # Do not expose captured Terraform output or process environment.
        message = str(exc) if isinstance(exc, ValueError) else "Unable to run Terraform. Check the executable and environment directory."
        print(f"[palo] {message}", file=sys.stderr)
        return 1
