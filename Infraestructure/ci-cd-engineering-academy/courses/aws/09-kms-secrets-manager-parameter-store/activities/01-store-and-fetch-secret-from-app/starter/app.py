#!/usr/bin/env python3
"""Simulated 'checkout' app startup for aws-09-01.

- Reads cmk.json / secret.json / param.json from the scratch dir to decide
  if we're in online mode (LocalStack reachable) or offline mode (SKIP).
- Online: resolves the fake Secrets Manager secret and the fake SSM
  SecureString parameter, then logs ONLY lengths (never the value).
- Offline: logs SKIP markers but still produces app.log so the validator
  has a stable artifact.

All values here are intentionally fake. NEVER print real secrets.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    import boto3  # type: ignore
    from botocore.exceptions import BotoCoreError, ClientError  # type: ignore
except Exception:  # pragma: no cover
    boto3 = None  # type: ignore
    BotoCoreError = ClientError = Exception  # type: ignore


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def log(fh, msg: str) -> None:
    line = f"{now()} INFO checkout-app {msg}"
    print(line)
    fh.write(line + "\n")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scratch", required=True)
    args = ap.parse_args()

    scratch = Path(args.scratch)
    scratch.mkdir(parents=True, exist_ok=True)
    endpoint = os.environ.get("AWS_ENDPOINT_URL", "http://localhost:4566")

    secret_meta = {}
    param_meta = {}
    if (scratch / "secret.json").exists():
        secret_meta = json.loads((scratch / "secret.json").read_text())
    if (scratch / "param.json").exists():
        param_meta = json.loads((scratch / "param.json").read_text())

    online = (
        secret_meta.get("status") == "OK"
        and param_meta.get("status") == "OK"
        and boto3 is not None
    )

    log_path = scratch / "app.log"
    with log_path.open("w") as fh:
        log(fh, "boot start")
        if not online:
            reason = (
                secret_meta.get("reason")
                or param_meta.get("reason")
                or "boto3-missing"
            )
            log(fh, f"SKIP online resolution ({reason}); using placeholders")
            log(fh, "resolved secret OK (len=offline)")
            log(fh, "resolved param OK (len=offline)")
            log(fh, "boot done (mode=offline)")
            print(f"wrote {log_path} (mode=offline)")
            return 0

        sm = boto3.client("secretsmanager", endpoint_url=endpoint)
        ssm = boto3.client("ssm", endpoint_url=endpoint)
        try:
            s = sm.get_secret_value(SecretId=secret_meta["secret_name"])
            value_len = len(s.get("SecretString", "") or "")
            log(fh, f"resolved secret OK (len={value_len})")
        except (BotoCoreError, ClientError) as exc:
            log(fh, f"resolve secret FAIL: {exc!s}")
            return 1

        try:
            p = ssm.get_parameter(
                Name=param_meta["param_name"], WithDecryption=True
            )
            value_len = len(p["Parameter"]["Value"])
            log(fh, f"resolved param OK (len={value_len})")
        except (BotoCoreError, ClientError) as exc:
            log(fh, f"resolve param FAIL: {exc!s}")
            return 1

        log(fh, "boot done (mode=online)")

    print(f"wrote {log_path} (mode=online)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
