# Ejercicio operativo — Docker (intermedio-avanzado)

Peso: **40%** del examen. Tiempo sugerido: **50–70 min**.

## Contexto

Heredas un microservicio `pricing-api` (FastAPI, Python 3.12) en `starter/`. El equipo anterior dejó:

- Un `Dockerfile` monolítico, con caché mal aprovechada, corriendo como `root`, con `:latest`, y leakeando un token.
- Un `compose.yaml` que monta `docker.sock`, expone `postgres` en `0.0.0.0` y guarda credenciales en claro.
- Sin SBOM, sin scan, sin firma.

Tu trabajo es **endurecerlo, demostrarlo con artefactos verificables y publicarlo a un registry local**.

## Prerrequisitos locales

```bash
docker --version          # >= 24.x
docker buildx version
syft version
trivy --version
cosign version            # >= 2.x

# registry local (puerto 5001 para evitar colisiones con AirPlay en macOS)
docker run -d --restart=always -p 5001:5000 --name local-registry registry:2
```

Todos los secretos usados en el ejercicio son **dummy generados localmente**:

```bash
openssl rand -hex 32 > /tmp/fake-build-token
```

No debe usarse ningún token real.

## Tareas

### OP-task-1 — Reescribir el Dockerfile a multi-stage con caché efectiva (C3)

- Separa `builder` (compila wheels, instala deps en venv) y `runtime` (sólo lo necesario).
- Ordena para que un cambio en `app/` **no** invalide la capa de dependencias.
- Usa `--mount=type=cache,target=/root/.cache/pip`.
- Añade `# syntax=docker/dockerfile:1.7` (o superior vigente).

**Métrica objetivo:** rebuild tras cambiar `app/main.py` en **< 5 s** (`time docker build ...`).

### OP-task-2 — Base image endurecida y mínima (C8)

- Reemplaza la base actual por **distroless** (`gcr.io/distroless/python3-debian12:nonroot`) **o** **Chainguard** (`cgr.dev/chainguard/python:latest`).
- Imagen final **< 150 MB** (`docker images --format '{{.Size}}'`).
- Justifica la elección en `notes.md` incluyendo trade-offs (shell ausente, debugging, actualizaciones).

### OP-task-3 — Consumir un secreto de build sin filtrarlo (C4)

- El `builder` necesita `GH_TOKEN` para `pip install` desde un índice privado simulado (ver `starter/pip.conf.template`).
- Usa `--mount=type=secret,id=gh_token`. **Prohibido** `ARG GH_TOKEN`.
- Demuestra con `docker history --no-trunc <image>` y `docker save ... | tar -xO | grep -r <token>` que el token **no** aparece.

### OP-task-4 — Pinnear base por digest y tag inmutable propio (C6)

- `FROM` debe referenciar `base@sha256:...` (no un tag mutable).
- La imagen final se tagea como `localhost:5001/pricing-api:1.0.0` **y** `localhost:5001/pricing-api@sha256:...` (grabar el digest en `notes.md`).

### OP-task-5 — Hardening de runtime y corrección del `compose.yaml` (C9, C12)

Edita `starter/compose.yaml` → `solution/compose.yaml`:

- Elimina el montaje de `/var/run/docker.sock`.
- `read_only: true` para el servicio `pricing-api`, con `tmpfs` para `/tmp`.
- `cap_drop: [ALL]` + sólo `NET_BIND_SERVICE` **si** realmente lo necesitas (justifica si no).
- `security_opt: ["no-new-privileges:true"]`.
- `user: "10001:10001"` (no-root).
- `pids_limit: 100`.
- `mem_limit: 256m`, `cpus: "0.5"`.
- Mueve credenciales a `secrets:` (archivo de Compose) y referéncialas con `/run/secrets/...`.
- Postgres **no** expuesto al host (`ports:` eliminado o bindeado a `127.0.0.1`).

### OP-task-6 — SBOM + Scan + Fail-on-critical (C10)

```bash
syft localhost:5001/pricing-api@sha256:<DIGEST> -o cyclonedx-json > solution/sbom.cdx.json
trivy image --format json --severity HIGH,CRITICAL --exit-code 1 \
  localhost:5001/pricing-api@sha256:<DIGEST> > solution/trivy-report.json
```

Si `trivy` reporta HIGH/CRITICAL explotables, debes **reescribir** la imagen (actualizar deps o cambiar base) hasta pasar. Documenta el ciclo.

### OP-task-7 — Firma con cosign y attestation (C10)

Modo *keyed* local (keyless OIDC requiere Internet; aquí trabajamos offline):

```bash
cosign generate-key-pair                 # produce cosign.key / cosign.pub
cosign sign --key cosign.key localhost:5001/pricing-api@sha256:<DIGEST>
cosign attest --predicate solution/sbom.cdx.json \
  --type cyclonedx --key cosign.key \
  localhost:5001/pricing-api@sha256:<DIGEST>
cosign verify --key cosign.pub localhost:5001/pricing-api@sha256:<DIGEST>
cosign verify-attestation --key cosign.pub --type cyclonedx \
  localhost:5001/pricing-api@sha256:<DIGEST>
```

Entrega `cosign.pub` (sólo la pública). **Nunca** incluyas `cosign.key` en la entrega — es red flag.

## Validación automática

Ejecuta `./validate.sh` desde la raíz del ejercicio. El script:

1. Verifica estructura de archivos (`solution/Dockerfile`, `solution/compose.yaml`, `solution/sbom.cdx.json`, `solution/trivy-report.json`, `solution/cosign.pub`, `solution/notes.md`).
2. Rechaza el envío si detecta `cosign.key`, cualquier credencial > 20 chars en claro, o `docker.sock` en `compose.yaml`.
3. Buildea y mide: tamaño final < 150 MB, rebuild caliente < 5 s.
4. Corre `docker history` y falla si encuentra el token dummy del paso 3.
5. Corre `trivy` sobre la imagen y falla si hay HIGH/CRITICAL.
6. Verifica firma y attestation con la clave pública entregada.
7. Levanta `compose up`, hace `curl http://localhost:8000/health`, luego `compose down -v`.

El log íntegro debe pegarse en `solution/notes.md` sección "validation output".

## Rúbrica (por tarea)

| Tarea | Criterio | 0 Insuficiente | 1 Básico | 2 Competente | 3 Experto |
|-------|----------|----------------|----------|--------------|-----------|
| OP-1 | Caché + multi-stage | Monolítico o no reduce rebuild | Multi-stage pero caché mal ordenada | Rebuild < 5 s, orden correcto | + cache mount BuildKit documentado + benchmark antes/después |
| OP-2 | Base image | Mantiene base original o alpine con roturas | Base reducida pero > 200 MB | Distroless/Chainguard < 150 MB funcional | + ADR corto comparando 3 bases con tamaño/CVEs/cold-start |
| OP-3 | Secreto de build | Token filtrado en history | Usa ARG pero intenta ocultarlo | `--mount=type=secret` correcto | + demuestra con `docker save` + grep que no filtra |
| OP-4 | Pinning | `:latest` o tag mutable | Tag propio pero base por tag | `base@sha256` + tag versionado | + script que rota el pin registrando el digest anterior |
| OP-5 | Hardening | `docker.sock` montado o root | Un control aplicado | Todos los controles aplicados y justificados | + razona por qué cada capability es necesaria o no |
| OP-6 | SBOM + scan | Sin SBOM o scan sin fail | Genera pero no bloquea | CycloneDX válido + fail on HIGH/CRITICAL | + muestra ciclo de remediación de una CVE real |
| OP-7 | Firma + attestation | Sin firma o `cosign.key` entregado | Firma sin attestation | Firma + attestation verificadas | + explica por qué cosign keyless sería preferible en CI y qué cambia |

**Peso de la operativa:** OP-1=10, OP-2=10, OP-3=12, OP-4=8, OP-5=20, OP-6=20, OP-7=20 (sobre 100). Mínimo por tarea: 1 (una tarea en 0 **no** reprueba, dos sí).

## Red flags que invalidan el ejercicio (ver `competency-matrix.yaml`)

- Entregar `cosign.key` (clave privada).
- `docker.sock` presente en `compose.yaml` final.
- Imagen final corre como root (`USER root` o sin `USER`).
- Secreto real detectado por el script `gitleaks` incluido en `validate.sh`.
- `ARG` con nombre `*TOKEN*|*SECRET*|*KEY*` en el `Dockerfile` final.
