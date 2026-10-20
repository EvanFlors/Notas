"""Spanner emulator starter: create instance+db, schema with interleaved
child table, run a read-write transaction.

Requires:
  SPANNER_EMULATOR_HOST=localhost:9010
  GOOGLE_CLOUD_PROJECT=example-project-id
"""
from __future__ import annotations

import os
import sys

from google.cloud import spanner
from google.api_core import exceptions as gax


PROJECT = os.environ.get("GOOGLE_CLOUD_PROJECT", "example-project-id")
INSTANCE_ID = "demo-instance"
DATABASE_ID = "demo-db"

SCHEMA = [
    """CREATE TABLE Users (
         UserId STRING(36) NOT NULL,
         Name   STRING(100) NOT NULL,
         Balance INT64 NOT NULL,
       ) PRIMARY KEY (UserId)""",
    """CREATE TABLE Orders (
         UserId  STRING(36) NOT NULL,
         OrderId STRING(36) NOT NULL,
         Amount  INT64 NOT NULL,
       ) PRIMARY KEY (UserId, OrderId),
         INTERLEAVE IN PARENT Users ON DELETE CASCADE""",
]


def main() -> int:
    client = spanner.Client(project=PROJECT)

    config_name = f"projects/{PROJECT}/instanceConfigs/emulator-config"
    instance = client.instance(INSTANCE_ID, configuration_name=config_name)
    try:
        instance.create().result(60)
    except gax.AlreadyExists:
        pass

    database = instance.database(DATABASE_ID, ddl_statements=SCHEMA)
    try:
        database.create().result(60)
    except gax.AlreadyExists:
        pass

    with database.batch() as batch:
        batch.insert_or_update(
            table="Users",
            columns=("UserId", "Name", "Balance"),
            values=[
                ("u1", "Ana", 500),
                ("u2", "Bruno", 50),
            ],
        )

    def place_order(transaction: spanner.transaction.Transaction) -> str:
        row = transaction.execute_sql(
            "SELECT Balance FROM Users WHERE UserId = @uid",
            params={"uid": "u1"},
            param_types={"uid": spanner.param_types.STRING},
        ).one()
        balance = row[0]
        amount = 120
        if balance < amount:
            return "rejected"
        transaction.insert_or_update(
            table="Orders",
            columns=("UserId", "OrderId", "Amount"),
            values=[("u1", "o-100", amount)],
        )
        transaction.update(
            table="Users",
            columns=("UserId", "Balance"),
            values=[("u1", balance - amount)],
        )
        return "accepted"

    result = database.run_in_transaction(place_order)
    print(f"order: {result}")

    with database.snapshot() as snap:
        rows = list(snap.execute_sql(
            "SELECT UserId, Name, Balance FROM Users ORDER BY UserId"
        ))
    for r in rows:
        print(f"user: {r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
