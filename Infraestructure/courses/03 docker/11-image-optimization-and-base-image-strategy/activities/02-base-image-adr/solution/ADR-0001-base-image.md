# ADR 0001 — Base image for service "payments-api"

## Status

Accepted — 2024-10. Review by 2025-04.

## Context

`payments-api` es un servicio Python 3.12 / FastAPI que corre en K8s con autoscaling: hasta 50 réplicas durante picos de tráfico. Un Pod frío debe estar `Ready` en < 10 s para no perder requests. Dependencias: FastAPI, SQLAlchemy, `cryptography` (firma de webhooks), `psycopg[binary]`.

Restricciones de la empresa:
- Política de supply chain: SBOM + firma cosign obligatorios.
- Debug en producción vía `kubectl debug` únicamente (no se admite `exec sh` en imágenes de prod).
- Scanner de CVEs en CI falla en Critical.

## Decision

Usar **`gcr.io/distroless/python3-debian12:nonroot`** como base del runtime, construida vía multi-stage sobre `python:3.12-slim` como builder.

Pin: por digest (`@sha256:...`), re-anclado mensualmente por un bot.

## Options considered

| base | size | cold-start | shell | CVEs C/H | notas |
|------|------|------------|-------|----------|-------|
| `python:3.12-slim` | ~190 MB | ~2.5 s | sí | 1 / 6 | ergonómico, pero más superficie |
| `python:3.12-alpine` | ~130 MB | ~2.3 s | sí | 0 / 2 | musl rompe wheels manylinux; compilar `cryptography` toma ~5 min y requiere toolchain |
| `distroless/python3-debian12` | ~85 MB | ~2.1 s | **no** | 0 / 0 | sin shell, sin pip; `USER nonroot` por default |
| `cgr.dev/chainguard/python` | ~95 MB | ~2.1 s | no | 0 / 0 | rolling release, exige re-pin frecuente |

(Mediciones de ejemplo; reproducir con `measurements.md`.)

## Consequences

Positivas:

- Imagen final < 100 MB → pull en nodo frío ~1.5 s en nuestra red, vs ~4 s con slim.
- Cero shell / pip / apt en runtime → superficie mínima; auditor contento.
- `USER nonroot` ya aplicado por la base.
- 0 CVEs Critical/High al momento de release → el gate de CI pasa en seco.

Negativas / mitigaciones:

- **No hay shell** → runbook de debug: `kubectl debug <pod> --image=busybox --target=<container> -it`, también se añade un sidecar efímero con `cryptic` para dumps. Documentado en `runbook/debug.md`.
- No se puede `pip install` en runtime → cualquier dep nueva requiere rebuild + redeploy. Explícitamente deseable.
- La base distroless no publica changelogs tan detallados como Debian — compensamos con `trivy image --exit-code 1` en el pipeline, que re-mide en cada push.

## Follow-ups

- Automatizar re-pin del digest mensual (Renovate bot).
- Re-evaluar Chainguard en 2025-Q2: si la política pasa a "FIPS" o "zero known CVE" firmado, migramos.
- Si aparece soporte oficial de Python 3.13 en distroless antes que en nuestra base actual, evaluar bump.
