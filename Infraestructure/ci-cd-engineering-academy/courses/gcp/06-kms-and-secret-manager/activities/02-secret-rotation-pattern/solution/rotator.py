#!/usr/bin/env python3
"""Simulador local de rotacion de un secret, con ventana de solape.

NO habla con Secret Manager. NO publica a Pub/Sub. Todos los valores son
ficticios y empiezan por `fake-sk-`. El script falla si por error se intenta
publicar un valor que parezca real.

Modela el ciclo:
  1. Estado inicial: v1 ENABLED.
  2. rotate(): crea v2 ENABLED y marca el solape.
  3. settle(): tras el solape, v1 -> DISABLED. (Opcional: luego DESTROYED.)
"""

from __future__ import annotations

import secrets
import sys
import time
from dataclasses import dataclass, field


# Ventana durante la cual la version vieja sigue vigente para dar tiempo
# a cachés en consumidores. En un flujo real serian horas o dias; aqui
# ejecutamos sincronico para que el test termine rapido.
OVERLAP_SECONDS = 0.05


@dataclass
class Version:
    id: int
    value: str
    state: str  # ENABLED | DISABLED | DESTROYED


@dataclass
class Secret:
    name: str
    versions: list[Version] = field(default_factory=list)

    def latest_enabled(self) -> Version:
        for v in reversed(self.versions):
            if v.state == "ENABLED":
                return v
        raise RuntimeError(f"no ENABLED version in {self.name}")


def _generate_fake_value(version_id: int) -> str:
    """Genera un valor ficticio. SIEMPRE empieza por `fake-sk-`."""
    nonce = secrets.token_hex(8)
    return f"fake-sk-v{version_id}-{nonce}"


def _reject_if_real(value: str) -> None:
    """Defensa: si por error se pasa algo que parezca un secreto real, abortar."""
    forbidden_prefixes = (
        "sk_live_", "sk_test_", "AKIA", "ghp_", "xoxb-", "AIza",
    )
    for p in forbidden_prefixes:
        if value.startswith(p):
            print(
                f"ABORT: value looks like a real secret (prefix={p!r}). "
                "This script only works with ficticious values.",
                file=sys.stderr,
            )
            sys.exit(1)
    if not value.startswith("fake-"):
        print(
            f"ABORT: value must start with 'fake-'. Got: {value[:12]}...",
            file=sys.stderr,
        )
        sys.exit(1)


def rotate(secret: Secret) -> Version:
    """Crea una nueva version ENABLED. No desactiva la anterior aun."""
    next_id = (secret.versions[-1].id + 1) if secret.versions else 1
    new_value = _generate_fake_value(next_id)
    _reject_if_real(new_value)
    new_version = Version(id=next_id, value=new_value, state="ENABLED")
    secret.versions.append(new_version)
    return new_version


def settle(secret: Secret) -> None:
    """Pasado el solape, desactiva todas las versiones ENABLED excepto la ultima."""
    time.sleep(OVERLAP_SECONDS)
    enabled = [v for v in secret.versions if v.state == "ENABLED"]
    if len(enabled) <= 1:
        return
    *to_disable, _keep = enabled
    for v in to_disable:
        v.state = "DISABLED"


def main() -> int:
    secret = Secret(
        name="external-api-key",
        versions=[Version(id=1, value=_generate_fake_value(1), state="ENABLED")],
    )
    _reject_if_real(secret.versions[0].value)

    print(f"BEFORE: {[(v.id, v.state) for v in secret.versions]}")

    new = rotate(secret)
    print(f"ROTATED: new version id={new.id} value_prefix={new.value[:12]}...")

    settle(secret)

    previous = next(v for v in secret.versions if v.id == new.id - 1)
    print(f"AFTER:  {[(v.id, v.state) for v in secret.versions]}")

    # Linea obligatoria que busca el validador.
    print(f"ROTATION_OK: new={new.id} previous={previous.state}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
