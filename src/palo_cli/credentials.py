"""OS keyring access and legacy external-helper protocol."""
import json
import sys


class CredentialError(Exception):
    pass


def fetch(query, backend):
    if not isinstance(query, dict):
        raise CredentialError("Credential query must be an object.")
    service = query.get("service")
    username = query.get("username", "")
    if not isinstance(service, str) or not service.strip():
        raise CredentialError("service must be a non-empty string.")
    if not isinstance(username, str):
        raise CredentialError("username must be a string, or omitted.")
    if username:
        password = backend.get_password(service, username)
    else:
        credential = backend.get_credential(service, None)
        if credential is None:
            raise CredentialError("Credential not found; check service and username.")
        username, password = credential.username, credential.password
    if not isinstance(username, str) or not username or not isinstance(password, str) or not password:
        raise CredentialError("Credential not found or incomplete; check service and username.")
    return {"username": username, "password": password}


def resolve(query, backend):
    if not isinstance(query, dict) or not query:
        raise CredentialError("Input must be a non-empty JSON object.")
    if "service" in query:
        return fetch(query, backend)
    result = {}
    for name, value in query.items():
        if not isinstance(value, str):
            raise CredentialError("Named queries must be JSON strings; use jsonencode in Terraform.")
        result[name] = fetch(json.loads(value), backend)["password"]
    return result


def main():
    try:
        import keyring
        result = resolve(json.load(sys.stdin), keyring)
    except ImportError:
        print("[get_creds] Install the workspace package with pip install -e . in scripts/venv.", file=sys.stderr)
        return 1
    except (json.JSONDecodeError, CredentialError) as exc:
        message = "Invalid JSON input." if isinstance(exc, json.JSONDecodeError) else str(exc)
        print(f"[get_creds] {message}", file=sys.stderr)
        return 1
    except Exception:
        print("[get_creds] Keyring lookup failed; check backend access and unlock your keychain.", file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
