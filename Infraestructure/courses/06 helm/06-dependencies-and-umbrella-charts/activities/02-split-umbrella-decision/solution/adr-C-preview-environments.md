# ADR C — Umbrella chart para preview environments de PR

## Status
Accepted

## Context
Cada pull request levanta un *preview environment* efímero en un cluster compartido: la app, Postgres, Redis y MinIO. Vive 24 horas y se destruye. Nadie lo opera manualmente; lo crea y lo destruye un workflow de GitHub Actions al abrir/cerrar la PR. El coste de que un `helm upgrade` dañe un entorno es cero: se destruye y se recrea en minutos. El ownership operacional es trivial: nadie "opera" el entorno, es una herramienta de CI.

## Decision
Usamos un **umbrella chart** (`pr-preview`) que depende de nuestro chart `fastapi-app`, de `bitnami/postgresql`, `bitnami/redis` y `minio` como subcharts, todos con `condition:` para poder apagar piezas en PRs pequeños. El workflow hace `helm upgrade --install pr-<n> ./pr-preview -n pr-<n> --create-namespace --atomic`. El Chart.lock se commitea pero no es crítico — el ciclo de vida del artefacto es horas.

## Consequences
Positivas:
- **Un comando por PR**: ergonomía del workflow. El job de CI no orquesta 4 releases distintas, orquesta una.
- **Lifecycle unificado**: el entorno nace y muere junto; no hay "orden de instalación" ni dependencias cruzadas gestionadas en bash.
- **Blast radius irrelevante**: todo el entorno es desechable; acoplar lifecycles es *la decisión correcta* aquí.

Negativas / riesgos aceptados:
- **No reutilizable en prod**: el umbrella es explícitamente *solo* para CI. Si alguien quiere llevarlo a prod, hay que rediseñar (ver ADR B).
- **Bumps de deps requieren probar la combinación completa**: aceptable, lo cubre el propio pipeline de PR.

## Alternatives considered
- **Charts separados orquestados por el workflow**: añade complejidad bash sin beneficio operativo. Rechazado.
- **Un operador tipo preview-env**: desproporcionado para el caso de uso; introduce un CRD que mantener.
