# Ejemplo 01 — `trivy image` en CI (GitHub Actions)

> Lectura y análisis. Si quieres ejecutarlo contra una imagen propia, lo haces en la actividad `01-scan-and-fail-on-critical/`.

## 1. Objetivo del ejemplo

Mostrar el **workflow mínimo** de GitHub Actions que:

1. Construye una imagen a partir del `Dockerfile` del repo.
2. La escanea con **Trivy** (`aquasec/trivy:0.56.2` vía `aquasecurity/trivy-action`).
3. **Falla el job** si aparece una vulnerabilidad `CRITICAL` **con fix disponible** y **sin excepción documentada en `.trivyignore`**.

Es el gate más básico y defendible. No incluye SARIF (ese es el ejemplo `02`) ni cluster scanning (ejemplo `03`).

## 2. Estructura mínima del repo (asumida)

```
.
├── Dockerfile
├── requirements.txt
├── .trivyignore          # excepciones justificadas, opcional
└── .github/
    └── workflows/
        └── container-scan.yml
```

## 3. El workflow comentado

Nombre: `.github/workflows/container-scan.yml`.

```yaml
name: container-scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4

      - name: Set image ref
        id: ref
        run: echo "image=ghcr.io/${{ github.repository }}:${{ github.sha }}" >> $GITHUB_OUTPUT

      - name: Build image (local, no push)
        run: docker build -t "${{ steps.ref.outputs.image }}" .

      # Pin del action por SHA en prod; por tag aqui para legibilidad.
      - name: Trivy scan — fail on CRITICAL with fix
        uses: aquasecurity/trivy-action@0.24.0
        env:
          TRIVY_DB_REPOSITORY: ghcr.io/aquasecurity/trivy-db
        with:
          image-ref: ${{ steps.ref.outputs.image }}
          severity: CRITICAL
          exit-code: '1'           # <-- gate: 1 CRITICAL con fix => job rojo
          ignore-unfixed: true     # <-- no bloquear por lo que no se puede arreglar
          vuln-type: 'os,library'  # SO + lenguaje
          scanners: 'vuln'         # solo vulns en este gate; config/secret van en jobs aparte
          trivyignores: '.trivyignore'
          format: 'table'          # log humano
```

## 4. Decisiones comentadas línea por línea

- **`image-ref` apunta a un tag local**: no empujamos a GHCR hasta pasar el gate. Si el scan falla, nunca se publicó la imagen vulnerable.
- **`severity: CRITICAL`**: contrato explícito. `HIGH` lo manejamos en otro job (nightly + SARIF para visibilidad) sin bloquear PRs.
- **`exit-code: '1'`**: sin esto el workflow pasa aunque haya hallazgos. Es la línea que convierte "informar" en "bloquear".
- **`ignore-unfixed: true`**: una vulnerabilidad sin fix upstream no es responsabilidad del developer en el PR. Se trackea aparte.
- **`vuln-type: 'os,library'`**: cubre las dos capas (base image + lockfiles de lenguaje).
- **`scanners: 'vuln'`**: scope limitado. Config (IaC misconfigs) y secretos los corremos en jobs dedicados para que el log de este gate sea legible.
- **`trivyignores: '.trivyignore'`**: ignores con razón y expiración. Pre-commit opcional valida el formato.
- **`TRIVY_DB_REPOSITORY`**: define el registro OCI de la DB. En setups aislados cambias este a un mirror interno.

## 5. Lo que **no** hace este workflow (y por qué)

- **No sube SARIF** — ver ejemplo `02`.
- **No firma la imagen** — eso es `sec-09`.
- **No valida labels OCI, `USER` != root, ni `HEALTHCHECK`** — eso es `trivy config` sobre el Dockerfile, en otro job.
- **No publica a GHCR** — un workflow `release.yml` separado lo hace **después** del merge a `main` con los gates verdes.
- **No cachea la DB explícitamente** — el `trivy-action` lo hace vía `actions/cache` internamente. Si tienes un self-hosted runner, montar `~/.cache/trivy` como volumen persistente es más eficiente.

## 6. Qué esperas ver en el log (ejemplo abreviado)

```
2026-10-16T10:12:04.221Z  INFO  Need to update DB
2026-10-16T10:12:12.045Z  INFO  DB downloaded
2026-10-16T10:12:12.891Z  INFO  Vulnerability scanning is enabled
2026-10-16T10:12:14.117Z  INFO  Detected OS: alpine
2026-10-16T10:12:14.117Z  INFO  Detecting Alpine vulnerabilities...
2026-10-16T10:12:14.233Z  INFO  Number of language-specific files: 1
2026-10-16T10:12:14.233Z  INFO  Detecting python-pkg vulnerabilities...

my-app:abc1234 (alpine 3.14.2)
==============================
Total: 2 (CRITICAL: 2)

┌────────────────┬────────────────┬──────────┬──────────────────┬───────────────┬──────────────────┐
│    Library     │ Vulnerability  │ Severity │ Installed Vers.  │ Fixed Version │       Title      │
├────────────────┼────────────────┼──────────┼──────────────────┼───────────────┼──────────────────┤
│ openssl        │ CVE-2024-5535  │ CRITICAL │ 1.1.1n-r0        │ 1.1.1w-r2     │ info leak...     │
│ libcrypto1.1   │ CVE-2024-5535  │ CRITICAL │ 1.1.1n-r0        │ 1.1.1w-r2     │ info leak...     │
└────────────────┴────────────────┴──────────┴──────────────────┴───────────────┴──────────────────┘

Error: Process completed with exit code 1.
```

Dos CVEs `CRITICAL` con fix → job rojo → merge bloqueado hasta subir la base image o añadir un ignore justificado en `.trivyignore.yaml`.

## 7. Variante: correr Trivy localmente sin el action

Para debug / dev local:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $HOME/.cache/trivy:/root/.cache/trivy \
  -v $(pwd)/.trivyignore:/.trivyignore \
  aquasec/trivy:0.56.2 image \
  --severity CRITICAL \
  --exit-code 1 \
  --ignore-unfixed \
  --ignorefile /.trivyignore \
  my-app:local
```

El binario de Trivy también está disponible en Homebrew (`brew install trivy`), apt, yum, chocolatey, winget, etc. — pero en pipelines preferimos la **imagen pineada** para que el output sea idéntico en todas las ejecuciones.

## 8. Preguntas de reflexión

1. ¿Por qué separar en jobs distintos `vuln`, `config` y `secret` en lugar de correrlos juntos?
2. ¿Qué pasa si `ignore-unfixed` se queda en `false` y hay un CVE `CRITICAL` sin fix upstream? ¿Es seguro desbloquear eso con un `.trivyignore` entry eterna?
3. En qué caso **sí** quieres fallar también en `HIGH`? Lista al menos tres triggers organizacionales.
4. Si tu CI ya tiene un `docker build` en 5 workflows distintos, ¿dónde pones Trivy — como step en cada uno, como workflow reusable, o como webhook sobre GHCR?
