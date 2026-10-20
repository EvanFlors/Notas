#!/usr/bin/env python3
"""Envelope encryption demo — DEK + KEK con rotacion local, sin GCP.

Simula el modelo de Cloud KMS:
  - Un plaintext se cifra con una DEK (AES-256-GCM).
  - La DEK se envuelve con una KEK (AES Key Wrap, RFC 3394).
  - Al rotar la KEK se re-envuelve la DEK; el ciphertext NO cambia.

Dependencias: `cryptography` (`pip install cryptography`).
"""

from __future__ import annotations

import os
import sys

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.keywrap import aes_key_unwrap, aes_key_wrap


def generate_key(size_bytes: int = 32) -> bytes:
    """Clave simetrica aleatoria (32 bytes = AES-256)."""
    return os.urandom(size_bytes)


def encrypt_with_dek(dek: bytes, plaintext: bytes, aad: bytes = b"") -> tuple[bytes, bytes]:
    """Cifra con AES-GCM. Devuelve (nonce, ciphertext_incluyendo_tag)."""
    aesgcm = AESGCM(dek)
    nonce = os.urandom(12)
    ciphertext = aesgcm.encrypt(nonce, plaintext, aad)
    return nonce, ciphertext


def decrypt_with_dek(dek: bytes, nonce: bytes, ciphertext: bytes, aad: bytes = b"") -> bytes:
    aesgcm = AESGCM(dek)
    return aesgcm.decrypt(nonce, ciphertext, aad)


def main() -> int:
    plaintext = b"customer-data-chunk-1"
    aad = b"gcp-06-01-demo"

    # Paso 1: generar KEK v1 y DEK.
    kek_v1 = generate_key()
    dek = generate_key()

    # Paso 2: cifrar el plaintext con la DEK.
    nonce, ciphertext = encrypt_with_dek(dek, plaintext, aad)

    # Paso 3: envolver la DEK con la KEK v1.
    wrapped_dek_v1 = aes_key_wrap(kek_v1, dek)

    print(f"PLAINTEXT_LEN={len(plaintext)}")
    print(f"NONCE={nonce.hex()}")
    print(f"CIPHERTEXT={ciphertext.hex()}")
    print(f"WRAPPED_DEK_V1={wrapped_dek_v1.hex()}")

    # Paso 4: ROTACION — generar KEK v2 y re-envolver la MISMA DEK.
    kek_v2 = generate_key()
    wrapped_dek_v2 = aes_key_wrap(kek_v2, dek)
    print(f"WRAPPED_DEK_V2={wrapped_dek_v2.hex()}")

    # Paso 5: demostrar que ambas envueltas unwrap-ean a la MISMA DEK
    # y la MISMA DEK descifra el MISMO ciphertext.
    dek_from_v1 = aes_key_unwrap(kek_v1, wrapped_dek_v1)
    dek_from_v2 = aes_key_unwrap(kek_v2, wrapped_dek_v2)

    assert dek_from_v1 == dek, "DEK recuperada con KEK v1 no coincide"
    assert dek_from_v2 == dek, "DEK recuperada con KEK v2 no coincide"

    recovered_v1 = decrypt_with_dek(dek_from_v1, nonce, ciphertext, aad)
    recovered_v2 = decrypt_with_dek(dek_from_v2, nonce, ciphertext, aad)

    assert recovered_v1 == plaintext, "decrypt via KEK v1 fallo"
    assert recovered_v2 == plaintext, "decrypt via KEK v2 fallo"
    assert recovered_v1 == recovered_v2, "plaintexts recuperados divergen"

    # Paso 6: linea obligatoria que busca el validador.
    print("ROTATION_IMPACT: ciphertext unchanged, both KEK versions decrypt")
    return 0


if __name__ == "__main__":
    sys.exit(main())
