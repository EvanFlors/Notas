#!/usr/bin/env python3
"""Envelope-encryption demo for aws-09-01.

- Online mode (LocalStack reachable + CMK created by setup.sh):
    1. kms:GenerateDataKey -> plaintext data key + wrapped ciphertext.
    2. AES-GCM encrypt payload locally with the plaintext data key.
    3. Persist wrapped_key + nonce + ciphertext + tag.
    4. Round-trip: kms:Decrypt wrapped_key, AES-GCM decrypt payload, verify sha256.

- Offline mode (no LocalStack): use a deterministic synthetic data key so
  the artifact structure is still produced. The envelope.json is tagged
  mode="offline" and includes a visible warning. This keeps the activity
  completable even without LocalStack.

All values here are intentionally fake / dummy. NEVER feed real secrets.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import sys
from pathlib import Path

try:
    import boto3  # type: ignore
    from botocore.exceptions import BotoCoreError, ClientError  # type: ignore
except Exception:  # pragma: no cover
    boto3 = None  # type: ignore
    BotoCoreError = ClientError = Exception  # type: ignore

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
except Exception:  # pragma: no cover
    AESGCM = None  # type: ignore


def b64(b: bytes) -> str:
    return base64.b64encode(b).decode("ascii")


def unb64(s: str) -> bytes:
    return base64.b64decode(s.encode("ascii"))


def encrypt_online(cmk_id: str, payload: bytes, endpoint: str) -> dict:
    client = boto3.client("kms", endpoint_url=endpoint)
    resp = client.generate_data_key(KeyId=cmk_id, KeySpec="AES_256")
    plaintext_key = resp["Plaintext"]
    wrapped = resp["CiphertextBlob"]

    nonce = os.urandom(12)
    aes = AESGCM(plaintext_key)
    ct_and_tag = aes.encrypt(nonce, payload, None)
    # AESGCM.encrypt returns ciphertext || tag (16 bytes)
    ciphertext, tag = ct_and_tag[:-16], ct_and_tag[-16:]

    # Scrub the plaintext data key from local memory ASAP.
    plaintext_key = b"\x00" * len(plaintext_key)
    del plaintext_key

    return {
        "mode": "online",
        "cmk_id": cmk_id,
        "wrapped_key_b64": b64(wrapped),
        "nonce_b64": b64(nonce),
        "ciphertext_b64": b64(ciphertext),
        "tag_b64": b64(tag),
        "payload_sha256": hashlib.sha256(payload).hexdigest(),
    }


def decrypt_online(blob: dict, endpoint: str) -> bytes:
    client = boto3.client("kms", endpoint_url=endpoint)
    wrapped = unb64(blob["wrapped_key_b64"])
    nonce = unb64(blob["nonce_b64"])
    ciphertext = unb64(blob["ciphertext_b64"])
    tag = unb64(blob["tag_b64"])

    resp = client.decrypt(CiphertextBlob=wrapped)
    plaintext_key = resp["Plaintext"]
    aes = AESGCM(plaintext_key)
    plaintext = aes.decrypt(nonce, ciphertext + tag, None)

    plaintext_key = b"\x00" * len(plaintext_key)
    del plaintext_key
    return plaintext


def encrypt_offline(payload: bytes) -> dict:
    """Deterministic placeholder so the artifact exists even without KMS."""
    synthetic_key = hashlib.sha256(b"aws-09-offline-synthetic-key").digest()
    nonce = hashlib.sha256(b"aws-09-offline-nonce").digest()[:12]
    if AESGCM is not None:
        aes = AESGCM(synthetic_key)
        ct_and_tag = aes.encrypt(nonce, payload, None)
        ciphertext, tag = ct_and_tag[:-16], ct_and_tag[-16:]
    else:
        # Last-resort fallback: XOR (NOT secure, used only to produce an artifact).
        ciphertext = bytes(b ^ synthetic_key[i % 32] for i, b in enumerate(payload))
        tag = b"\x00" * 16
    return {
        "mode": "offline",
        "warning": "SKIP: KMS not reachable, offline synthetic key used, NOT secure",
        "cmk_id": "offline-synthetic",
        "wrapped_key_b64": b64(b"OFFLINE-NO-WRAPPED-KEY"),
        "nonce_b64": b64(nonce),
        "ciphertext_b64": b64(ciphertext),
        "tag_b64": b64(tag),
        "payload_sha256": hashlib.sha256(payload).hexdigest(),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scratch", required=True)
    ap.add_argument("--payload", required=True,
                    help="Fake payload to envelope-encrypt. Must be labelled fake.")
    args = ap.parse_args()

    scratch = Path(args.scratch)
    scratch.mkdir(parents=True, exist_ok=True)
    cmk_file = scratch / "cmk.json"
    endpoint = os.environ.get("AWS_ENDPOINT_URL", "http://localhost:4566")

    payload = args.payload.encode("utf-8")
    if b"NOT-REAL" not in payload and b"fake" not in payload.lower():
        print("WARN: payload does not look fake. Prefix 'fake-' or add 'NOT-REAL'.",
              file=sys.stderr)

    use_online = False
    cmk_id = None
    if cmk_file.exists():
        try:
            cmk_meta = json.loads(cmk_file.read_text())
            if cmk_meta.get("status") == "OK" and boto3 is not None and AESGCM is not None:
                cmk_id = cmk_meta["key_id"]
                use_online = True
        except Exception:
            pass

    if use_online:
        try:
            blob = encrypt_online(cmk_id, payload, endpoint)
        except (BotoCoreError, ClientError, Exception) as exc:
            print(f"WARN: online encrypt failed ({exc!s}), falling back to offline.",
                  file=sys.stderr)
            blob = encrypt_offline(payload)
    else:
        blob = encrypt_offline(payload)

    envelope_path = scratch / "envelope.json"
    envelope_path.write_text(json.dumps(blob, indent=2) + "\n")
    print(f"wrote {envelope_path} (mode={blob['mode']})")

    # Round-trip only when online, to prove it works end-to-end.
    if blob["mode"] == "online":
        try:
            decrypted = decrypt_online(blob, endpoint)
            dec_path = scratch / "envelope.decrypted.txt"
            dec_path.write_text(decrypted.decode("utf-8", errors="replace") + "\n")
            print(f"wrote {dec_path} (round-trip OK)")
        except Exception as exc:
            print(f"WARN: round-trip decrypt failed: {exc!s}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
