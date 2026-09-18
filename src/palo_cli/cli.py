"""Run a workspace Terraform root with credentials supplied only to its process."""
import json
import os
from pathlib import Path
import re
import shutil
import sys

def workspace_root(environ):
    # Editable installs resolve to <workspace>/src/palo_cli/cli.py.
    # Wheel installations can select their checkout explicitly.
    configured = environ.get("PALO_WORKSPACE")
    root = Path(configured).expanduser().resolve() if configured else Path(__file__).resolve().parents[2]
    if not (root / "env").is_dir():
        raise ValueError("Workspace not found. Install with pip install -e . or set PALO_WORKSPACE to the checkout path.")
    return root

OFFLINE = {"init", "validate", "fmt", "test", "version", "providers"}


def prepare(argv, workspace, environ, backend=None):
    if len(argv) < 2:
        raise ValueError("Usage: palo <environment> <terraform-command> [arguments...]")
    name, command, *args = argv
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", name):
        raise ValueError("Environment must be a simple name, such as lab or lab2.")
    env_base = (workspace / "env").resolve()
    root = (env_base / name).resolve()
    if root.parent != env_base or not root.is_dir():
        raise ValueError(f"Unknown environment: {name}")
    if command.startswith('-') or any(arg.startswith('-chdir') for arg in args):
        raise ValueError("Select the Terraform directory with the environment argument.")
    child = dict(environ)
    if command not in OFFLINE and not any(a in {"-help", "--help"} for a in args):
        try:
            config = json.loads((root / "palo.json").read_text())
        except (OSError, ValueError):
            raise ValueError(f"Create a valid env/{name}/palo.json with hostname and keyring_service.") from None
        if not isinstance(config, dict):
            raise ValueError("palo.json must contain an object.")
        hostname = config.get("hostname")
        if not isinstance(hostname, str) or not hostname.strip():
            raise ValueError(f"Set hostname in env/{name}/palo.json before connecting.")
        skip_verify = config.get("skip_verify_certificate", False)
        if not isinstance(skip_verify, bool):
            raise ValueError("skip_verify_certificate must be a JSON boolean (true or false).")
        from .credentials import fetch
        if backend is None:
            import keyring
            backend = keyring
        credential = fetch({"service": config.get("keyring_service"), "username": config.get("keyring_username", "")}, backend)
        # Discard inherited PAN-OS settings to avoid connecting with another
        # environment's API key, target serial, auth file, or TLS override.
        child = {k: v for k, v in child.items() if not k.startswith('PANOS_')}
        child.update(PANOS_HOSTNAME=hostname, PANOS_USERNAME=credential['username'], PANOS_PASSWORD=credential['password'],
                     PANOS_SKIP_VERIFY_CERTIFICATE=str(skip_verify).lower())
    return ["terraform", f"-chdir={root}", command, *args], child


def main():
    if sys.argv[1:] in ([], ["-h"], ["--help"]):
        print("Usage: palo <environment> <terraform-command> [arguments...]\n"
              "Examples: palo lab plan | palo lab apply | palo lab2 plan\n"
              "Device variables: palo lab overrides plan | palo lab overrides apply [--device paa]\n"
              "Push all targets: palo lab push-all [--dry-run] [--auto-approve]\n"
              "Paths passed to Terraform are relative to the selected environment.\n"
              "init, validate, fmt, test, version and providers do not read keyring.")
        return 0
    try:
        workspace = workspace_root(os.environ)
        if len(sys.argv) >= 3 and sys.argv[2] == "push-all":
            from . import push_all
            options = push_all.parser().parse_args(sys.argv[3:])
            executable = shutil.which("terraform")
            if executable is None:
                raise ValueError("terraform is not on PATH.")
            command, child = prepare([sys.argv[1], "push-all"], workspace, os.environ)
            root = Path(command[1].removeprefix("-chdir="))
            return push_all.run(options, root, child, executable)
        if len(sys.argv) >= 3 and sys.argv[2] == "overrides":
            from . import overrides
            options = overrides.parser().parse_args(sys.argv[3:])
            # Reuse environment selection and keyring/TLS handling; do not run Terraform.
            command, child = prepare([sys.argv[1], "overrides"], workspace, os.environ)
            root = Path(command[1].removeprefix("-chdir="))
            return overrides.run(options, root, child)
        command, child = prepare(sys.argv[1:], workspace, os.environ)
        executable = shutil.which("terraform")
        if executable is None:
            raise ValueError("terraform is not on PATH.")
    except ValueError as exc:
        print(f"[palo] {exc}", file=sys.stderr)
        return 1
    except Exception:
        print("[palo] Credential lookup failed. Check keyring service/account and unlock your keychain.", file=sys.stderr)
        return 1
    # Replace the launcher: terminal interaction, signals and exit codes go
    # directly to Terraform. No credentials appear in argv or output.
    os.chdir(workspace)
    os.execve(executable, command, child)


if __name__ == '__main__':
    sys.exit(main())
