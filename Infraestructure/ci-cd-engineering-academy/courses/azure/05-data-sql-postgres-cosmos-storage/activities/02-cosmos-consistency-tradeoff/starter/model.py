#!/usr/bin/env python3
"""Cosmos DB single-container model + Azurite blob smoke.

Skips cleanly (exit 0 with a clear message) if the Cosmos emulator and/or
Azurite are unreachable. Never talks to real Azure.

Endpoints (overridable via env):
  COSMOS_ENDPOINT (default: https://localhost:8081)
  AZURITE_ENDPOINT (default: http://127.0.0.1:10000)

The Cosmos emulator ships with a well-known test key (public, documented
by Microsoft) used ONLY for the local emulator — never for real accounts.
"""

from __future__ import annotations

import os
import socket
import ssl
import sys
import urllib.request
from urllib.parse import urlparse

COSMOS_ENDPOINT = os.environ.get("COSMOS_ENDPOINT", "https://localhost:8081")
# Public, documented emulator key. Do NOT use in real accounts.
COSMOS_KEY = os.environ.get(
    "COSMOS_KEY",
    "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==",
)
AZURITE_ENDPOINT = os.environ.get("AZURITE_ENDPOINT", "http://127.0.0.1:10000")

DB_NAME = "shop"
CONTAINER_NAME = "orders"
PARTITION_PATH = "/tenantId"


def tcp_up(url: str, timeout: float = 1.5) -> bool:
    try:
        parsed = urlparse(url)
        host = parsed.hostname or "localhost"
        port = parsed.port or (443 if parsed.scheme == "https" else 80)
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def run_cosmos() -> tuple[int, int]:
    """Return (passed, total) of pattern checks against Cosmos emulator."""
    if not tcp_up(COSMOS_ENDPOINT):
        print(f"SKIP: Cosmos emulator not available at {COSMOS_ENDPOINT}.")
        print("      Start it with: docker run -d -p 8081:8081 -p 10250-10255:10250-10255 \\")
        print("        mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-preview")
        return (0, 0)

    try:
        from azure.cosmos import CosmosClient, PartitionKey, exceptions
    except ImportError:
        print("SKIP: azure-cosmos not installed. Install with: "
              "python3 -m pip install --user azure-cosmos")
        return (0, 0)

    # The emulator ships with a self-signed cert; disable verification locally.
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    ssl._create_default_https_context = ssl._create_unverified_context  # noqa: SLF001

    client = CosmosClient(COSMOS_ENDPOINT, credential=COSMOS_KEY, connection_verify=False)
    db = client.create_database_if_not_exists(id=DB_NAME)
    container = db.create_container_if_not_exists(
        id=CONTAINER_NAME,
        partition_key=PartitionKey(path=PARTITION_PATH),
        offer_throughput=400,
    )

    items = [
        {"id": "USER#u-123", "tenantId": "tenant-acme", "type": "user",
         "email": "ana@example.com", "name": "Ana"},
        {"id": "ORDER#o-1", "tenantId": "tenant-acme", "type": "order",
         "userId": "u-123", "status": "pending", "totalCents": 12000,
         "createdAt": "2026-10-16T10:00:00Z"},
        {"id": "ORDER#o-2", "tenantId": "tenant-acme", "type": "order",
         "userId": "u-123", "status": "shipped", "totalCents": 3000,
         "createdAt": "2026-10-15T09:12:00Z"},
        {"id": "ITEM#o-1#sku-A", "tenantId": "tenant-acme", "type": "order_item",
         "orderId": "o-1", "sku": "sku-A", "qty": 2, "unitPriceCents": 5000},
        {"id": "ITEM#o-1#sku-B", "tenantId": "tenant-acme", "type": "order_item",
         "orderId": "o-1", "sku": "sku-B", "qty": 1, "unitPriceCents": 2000},
        {"id": "PRODUCT#sku-A", "tenantId": "tenant-acme", "type": "product",
         "name": "Running shoe", "priceCents": 5000, "category": "shoes"},
    ]
    for it in items:
        container.upsert_item(it)
    print(f"  seeded {len(items)} items into {DB_NAME}/{CONTAINER_NAME}")

    passed = 0

    # Pattern 1: user profile — point read.
    print("\nQuery 1: read_item(id=USER#u-123, pk=tenant-acme)")
    user = container.read_item(item="USER#u-123", partition_key="tenant-acme")
    print(f"  -> {user['type']} {user.get('email')}")
    assert user["type"] == "user"
    passed += 1

    # Pattern 2: orders of a user — SQL query within the partition.
    print("\nQuery 2: orders of userId=u-123 in Oct 2026 (partition tenant-acme)")
    q = ("SELECT c.id, c.status, c.totalCents, c.createdAt FROM c "
         "WHERE c.type = 'order' AND c.userId = @uid "
         "AND STARTSWITH(c.createdAt, '2026-10')")
    rows = list(container.query_items(
        query=q,
        parameters=[{"name": "@uid", "value": "u-123"}],
        partition_key="tenant-acme",
    ))
    for r in rows:
        print(f"  -> {r['id']} {r['status']} total={r['totalCents']}")
    assert len(rows) == 2
    passed += 1

    # Pattern 3: items of order o-1.
    print("\nQuery 3: items of order o-1 (partition tenant-acme)")
    q = ("SELECT c.id, c.sku, c.qty, c.unitPriceCents FROM c "
         "WHERE c.type = 'order_item' AND c.orderId = @oid")
    rows = list(container.query_items(
        query=q,
        parameters=[{"name": "@oid", "value": "o-1"}],
        partition_key="tenant-acme",
    ))
    for r in rows:
        print(f"  -> {r['sku']} qty={r['qty']} unit={r['unitPriceCents']}")
    assert len(rows) == 2
    passed += 1

    return (passed, 3)


def run_azurite() -> bool:
    """Return True if blob upload succeeded, False if skipped."""
    if not tcp_up(AZURITE_ENDPOINT):
        print(f"\nSKIP: Azurite not available at {AZURITE_ENDPOINT}.")
        print("      Start it with: docker run -d -p 10000:10000 -p 10001:10001 -p 10002:10002 \\")
        print("        mcr.microsoft.com/azure-storage/azurite")
        return False

    try:
        from azure.storage.blob import BlobServiceClient
    except ImportError:
        print("\nSKIP: azure-storage-blob not installed. Install with: "
              "python3 -m pip install --user azure-storage-blob")
        return False

    # Azurite well-known dev account + key (public, documented).
    account = "devstoreaccount1"
    key = ("Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6"
           "tq/K1SZFPTOtr/KBHBeksoGMGw==")
    conn = (f"DefaultEndpointsProtocol=http;AccountName={account};"
            f"AccountKey={key};BlobEndpoint={AZURITE_ENDPOINT}/{account};")

    svc = BlobServiceClient.from_connection_string(conn)
    container_name = "uploads"
    try:
        svc.create_container(container_name)
    except Exception:  # ResourceExistsError
        pass

    blob = svc.get_blob_client(container=container_name, blob="invoices/inv-123.txt")
    body = b"Factura ficticia emitida localmente por Azurite. No real.\n"
    blob.upload_blob(body, overwrite=True)
    props = blob.get_blob_properties()
    print(f"\n  uploaded blob {blob.blob_name} size={props.size} bytes")
    return True


def main() -> int:
    passed, total = run_cosmos()
    blob_ok = run_azurite()

    msg = []
    if total == 0:
        msg.append("cosmos SKIP")
    else:
        msg.append(f"OK: {passed}/3 cosmos patterns verified")
    if blob_ok:
        msg.append("blob upload OK")
    else:
        msg.append("azurite SKIP")
    print("\n" + "; ".join(msg))
    return 0


if __name__ == "__main__":
    sys.exit(main())
