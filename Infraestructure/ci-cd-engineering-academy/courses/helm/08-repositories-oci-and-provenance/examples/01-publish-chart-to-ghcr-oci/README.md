# Ejemplo 01 — Publicar un chart a GHCR (OCI)

## Concepto que demuestra

El ciclo completo **empaquetar → push → inspeccionar → pull** usando el protocolo OCI contra un registry.

Soporta dos modos:

- **`MODE=local`** (default) — levanta un `registry:2` en `localhost:5000` y publica contra `oci://localhost:5000/charts`. Sin red, sin credenciales. Ideal para iterar.
- **`MODE=live`** — publica a GHCR real (`oci://ghcr.io/<org>/charts`). Requiere que ya hayas hecho `helm registry login ghcr.io` con un PAT con scope `write:packages`.

## Contexto

Ver `theory/lesson.md` §4 (OCI registries) y §5 (SemVer).

## Archivos

- `run.sh` — orquesta todo. Lee `MODE` del env y, en `local`, no toca nada fuera de `/tmp/`.

## Ejecución

### MODE=local

```bash
bash run.sh                             # workdir /tmp/helm-08-ex01
# o
bash run.sh /tmp/mi-workdir
```

Hace:

1. SKIP si falta `docker` o `helm`.
2. Levanta `registry:2` en `localhost:5000` (si no está).
3. `helm create` → chart demo `oci-demo`.
4. `helm package` → `oci-demo-0.1.0.tgz`.
5. `helm push --plain-http oci://localhost:5000/charts`.
6. Inspecciona tags del registry vía API HTTP.
7. `helm pull --plain-http` para confirmar round-trip.
8. `helm show chart` para leer metadata directamente del registry.

### MODE=live

```bash
# Prerrequisito:
#   export GHCR_USER=youruser
#   export GHCR_TOKEN=ghp_...     (PAT con write:packages)
#   echo "$GHCR_TOKEN" | helm registry login ghcr.io -u "$GHCR_USER" --password-stdin
MODE=live REGISTRY=ghcr.io/yourorg bash run.sh
```

Al terminar, verifica en la UI de GHCR que aparece el package `charts/oci-demo` con tag `0.1.0`.

## Qué mirar

Después del push en modo local:

```bash
# Lista de tags
curl -s http://localhost:5000/v2/charts/oci-demo/tags/list | jq
# {
#   "name": "charts/oci-demo",
#   "tags": ["0.1.0"]
# }

# Manifest OCI del chart
curl -s -H "Accept: application/vnd.oci.image.manifest.v1+json" \
  http://localhost:5000/v2/charts/oci-demo/manifests/0.1.0 | jq
# Nota los media types: vnd.cncf.helm.config.v1+json y vnd.cncf.helm.chart.content.v1.tar+gzip
```

## Limpieza

```bash
docker stop helm-08-ex01-reg 2>/dev/null || true
rm -rf /tmp/helm-08-ex01
```

## Referencias

- `theory/lesson.md` §4.
- `resources/links.md` → Helm OCI docs.
