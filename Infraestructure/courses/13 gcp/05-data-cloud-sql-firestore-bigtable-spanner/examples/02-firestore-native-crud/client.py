"""Firestore CRUD against the official emulator.

Requires:
  FIRESTORE_EMULATOR_HOST=localhost:8080
  GOOGLE_CLOUD_PROJECT=example-project-id
"""
from __future__ import annotations

import os
import sys

from google.cloud import firestore


def main() -> int:
    project = os.environ.get("GOOGLE_CLOUD_PROJECT", "example-project-id")
    db = firestore.Client(project=project)

    users = db.collection("users")

    # 1. Simple writes with subcollection
    for uid, name in [("u1", "Ana"), ("u2", "Bruno"), ("u3", "Carla")]:
        users.document(uid).set({"name": name, "active": True})
        users.document(uid).collection("orders").document("o1").set(
            {"amount": 100, "status": "paid"}
        )

    # 2. Read by document reference
    doc = users.document("u1").get()
    print(f"doc u1: {doc.to_dict()}")

    # 3. Query with where filter
    active = users.where(filter=firestore.FieldFilter("active", "==", True))
    print(f"active users: {sum(1 for _ in active.stream())}")

    # 4. ACID transaction across documents
    transaction = db.transaction()

    @firestore.transactional
    def transfer_flag(tx: firestore.Transaction) -> None:
        src = users.document("u1")
        dst = users.document("u2")
        tx.update(src, {"active": False})
        tx.update(dst, {"active": True})

    transfer_flag(transaction)

    # 5. Batched write (atomic, no reads)
    batch = db.batch()
    batch.update(users.document("u3"), {"name": "Carla Updated"})
    batch.set(users.document("u4"), {"name": "Dani", "active": True})
    batch.commit()

    final = {d.id: d.to_dict() for d in users.stream()}
    print(f"final users: {final}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
