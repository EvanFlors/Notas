#!/usr/bin/env python3
"""Capstone app (minimal) for k8s-05-01.

Reads config from env vars (populated via envFrom from the ConfigMap `app-config`)
and the DB password from a file mounted via a Secret volume. Prints a JSON line
with the config and the *length* of the password (never the password itself),
then sleeps forever so the Pod stays Ready.
"""
import json
import os
import sys
import time

SECRET_PATH = "/etc/app/secret/db-password"


def main() -> int:
    cfg = {
        "log_level": os.environ.get("LOG_LEVEL", "<missing>"),
        "app_port": os.environ.get("APP_PORT", "<missing>"),
        "greeting": os.environ.get("GREETING", "<missing>"),
    }

    try:
        with open(SECRET_PATH, "r", encoding="utf-8") as f:
            password = f.read().rstrip("\n")
    except FileNotFoundError:
        print(json.dumps({"error": f"secret file missing: {SECRET_PATH}"}), flush=True)
        return 2

    # Never print the password; print its length so we prove we read it.
    print(json.dumps({**cfg, "password_len": len(password)}), flush=True)

    # Stay alive so the Pod is Ready for the validator.
    while True:
        time.sleep(3600)


if __name__ == "__main__":
    sys.exit(main())
