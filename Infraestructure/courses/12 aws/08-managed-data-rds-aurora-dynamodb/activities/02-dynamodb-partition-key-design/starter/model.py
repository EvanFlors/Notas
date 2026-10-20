#!/usr/bin/env python3
"""DynamoDB single-table model exercised against LocalStack.

Skips cleanly (exit 0 with a clear message) if LocalStack is unreachable.
Never talks to real AWS: the endpoint URL is read from AWS_ENDPOINT_URL
and defaults to http://localhost:4566. If no endpoint is set and no
LocalStack is up, the script skips.
"""

from __future__ import annotations

import os
import sys
import time
import socket
from urllib.parse import urlparse

TABLE = "ecom-single"
ENDPOINT = os.environ.get("AWS_ENDPOINT_URL", "http://localhost:4566")


def localstack_up(endpoint: str, timeout: float = 1.5) -> bool:
    """Return True if a TCP connection to the endpoint host:port succeeds."""
    try:
        parsed = urlparse(endpoint)
        host = parsed.hostname or "localhost"
        port = parsed.port or (443 if parsed.scheme == "https" else 80)
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def main() -> int:
    if not localstack_up(ENDPOINT):
        print(f"SKIP: LocalStack not available at {ENDPOINT}.")
        print("      Start it with: docker run -d -p 4566:4566 "
              "-e SERVICES=dynamodb localstack/localstack:latest")
        return 0

    try:
        import boto3
        from botocore.exceptions import ClientError
    except ImportError:
        print("SKIP: boto3 not installed. Install with: python3 -m pip install --user boto3")
        return 0

    os.environ.setdefault("AWS_ACCESS_KEY_ID", "dummy")
    os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "dummy")
    os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")

    ddb = boto3.client("dynamodb", endpoint_url=ENDPOINT)

    # Idempotent create.
    print(f"Creating table {TABLE}...")
    try:
        ddb.create_table(
            TableName=TABLE,
            AttributeDefinitions=[
                {"AttributeName": "PK",     "AttributeType": "S"},
                {"AttributeName": "SK",     "AttributeType": "S"},
                {"AttributeName": "GSI1PK", "AttributeType": "S"},
                {"AttributeName": "GSI1SK", "AttributeType": "S"},
            ],
            KeySchema=[
                {"AttributeName": "PK", "KeyType": "HASH"},
                {"AttributeName": "SK", "KeyType": "RANGE"},
            ],
            GlobalSecondaryIndexes=[{
                "IndexName": "GSI1",
                "KeySchema": [
                    {"AttributeName": "GSI1PK", "KeyType": "HASH"},
                    {"AttributeName": "GSI1SK", "KeyType": "RANGE"},
                ],
                "Projection": {"ProjectionType": "ALL"},
            }],
            BillingMode="PAY_PER_REQUEST",
        )
        time.sleep(0.5)  # LocalStack: table is usually ready immediately.
    except ClientError as exc:
        if exc.response["Error"]["Code"] != "ResourceInUseException":
            raise
        print(f"  table {TABLE} already exists; reusing")

    table = boto3.resource("dynamodb", endpoint_url=ENDPOINT).Table(TABLE)

    # Seed data: 1 user, 2 orders, 2 order items, 1 product.
    items = [
        {"PK": "USER#u-123", "SK": "PROFILE",
         "type": "user", "email": "ana@example.com", "name": "Ana"},

        {"PK": "USER#u-123", "SK": "ORDER#2026-10-16T10:00#o-1",
         "GSI1PK": "STATUS#pending", "GSI1SK": "2026-10-16#o-1",
         "type": "order", "total_cents": 12000, "status": "pending"},

        {"PK": "USER#u-123", "SK": "ORDER#2026-10-15T09:12#o-2",
         "GSI1PK": "STATUS#shipped", "GSI1SK": "2026-10-15#o-2",
         "type": "order", "total_cents": 3000, "status": "shipped"},

        {"PK": "ORDER#o-1", "SK": "ITEM#sku-A",
         "type": "order_item", "qty": 2, "unit_price_cents": 5000},
        {"PK": "ORDER#o-1", "SK": "ITEM#sku-B",
         "type": "order_item", "qty": 1, "unit_price_cents": 2000},

        {"PK": "PRODUCT#sku-A", "SK": "META",
         "GSI1PK": "CATEGORY#shoes", "GSI1SK": "sku-A",
         "type": "product", "name": "Running shoe", "price_cents": 5000},
    ]
    with table.batch_writer() as bw:
        for it in items:
            bw.put_item(Item=it)
    print(f"  seeded {len(items)} items")

    passed = 0

    # Pattern 1: user profile (GetItem).
    print("\nQuery 1: GetItem(PK=USER#u-123, SK=PROFILE)")
    r = table.get_item(Key={"PK": "USER#u-123", "SK": "PROFILE"})
    item = r.get("Item")
    print(f"  -> {item}")
    assert item and item["type"] == "user", "Pattern 1 failed"
    passed += 1

    # Pattern 2: user orders in Oct 2026.
    from boto3.dynamodb.conditions import Key
    print("\nQuery 2: Query(PK=USER#u-123, SK begins_with ORDER#2026-10)")
    r = table.query(
        KeyConditionExpression=Key("PK").eq("USER#u-123") &
                               Key("SK").begins_with("ORDER#2026-10"),
    )
    for it in r["Items"]:
        print(f"  -> {it['SK']} status={it['status']} total={it['total_cents']}")
    assert len(r["Items"]) == 2, "Pattern 2 failed"
    passed += 1

    # Pattern 3: items of order o-1.
    print("\nQuery 3: Query(PK=ORDER#o-1, SK begins_with ITEM#)")
    r = table.query(
        KeyConditionExpression=Key("PK").eq("ORDER#o-1") &
                               Key("SK").begins_with("ITEM#"),
    )
    for it in r["Items"]:
        print(f"  -> {it['SK']} qty={it['qty']} unit={it['unit_price_cents']}")
    assert len(r["Items"]) == 2, "Pattern 3 failed"
    passed += 1

    # Bonus: GSI1 — orders pending.
    print("\nQuery (GSI1): orders with status=pending")
    r = table.query(
        IndexName="GSI1",
        KeyConditionExpression=Key("GSI1PK").eq("STATUS#pending"),
    )
    for it in r["Items"]:
        print(f"  -> {it['SK']} total={it['total_cents']}")

    print(f"\nOK: {passed}/3 access patterns verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
