#!/usr/bin/env python3
"""Mock dynamic inventory for ans-01-02.

Respects the Ansible dynamic-inventory contract:
  --list              -> prints a JSON inventory with groups and _meta.hostvars
  --host <hostname>   -> prints '{}' because all vars are in _meta.hostvars

Not connected to any real cloud. Returns a fixed topology so the contract
can be verified end-to-end without AWS credentials.
"""

from __future__ import annotations

import json
import sys

INVENTORY = {
    "web": {
        "hosts": ["10.0.0.1", "10.0.0.2"],
        "vars": {"env": "prod", "role": "web"},
    },
    "db": {
        "hosts": ["10.0.0.10"],
        "vars": {"env": "prod", "role": "db"},
    },
    "prod": {
        "children": ["web", "db"],
    },
    "_meta": {
        "hostvars": {
            "10.0.0.1": {
                "ansible_host": "10.0.0.1",
                "ansible_user": "ec2-user",
                "az": "eu-west-1a",
            },
            "10.0.0.2": {
                "ansible_host": "10.0.0.2",
                "ansible_user": "ec2-user",
                "az": "eu-west-1b",
            },
            "10.0.0.10": {
                "ansible_host": "10.0.0.10",
                "ansible_user": "ec2-user",
                "az": "eu-west-1a",
            },
        }
    },
}


def main(argv: list[str]) -> int:
    if "--list" in argv:
        print(json.dumps(INVENTORY))
        return 0
    if "--host" in argv:
        # All vars live under _meta.hostvars; return empty per contract.
        print(json.dumps({}))
        return 0
    print("usage: dynamic-inventory.py --list | --host <hostname>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
