# Ejemplo 02 — Escaneo con Trivy (vulnerabilidades + misconfig)

## Concepto que demuestra

- Qué devuelve un escaneo real de **Trivy** sobre una imagen Python típica.
- Diferencia entre `trivy image` (CVEs en paquetes OS/lang) y `trivy config` (misconfig estática del `Dockerfile`).
- Cómo convertir Trivy en **gate de CI** con `--exit-code` y `--severity`.
- Qué significa (y qué no) una CVE "CRITICAL" en una base image.

## Contexto

`docker scan` (basado en Snyk) fue el escáner integrado y está **deprecado**. En su lugar se usan Trivy o grype. Trivy escanea:

- Vulns de paquetes OS (apt/apk/yum).
- Vulns de dependencias de lenguaje (requirements.txt, package-lock.json, Gemfile.lock, go.sum, Cargo.lock, …).
- Secretos filtrados en capas de la imagen.
- Misconfig de IaC (Dockerfile, Kubernetes YAML, Terraform).
- (Opcional) licencias.

## Objetivo

Al terminar, podrás:

- Correr `trivy image` sobre una imagen local y leer la tabla.
- Correr `trivy config` sobre un Dockerfile y arreglar los findings.
- Diseñar un gate de CI que falle sólo en `CRITICAL` (o según política).

## Prerrequisitos

- Docker funcional.
- **Trivy** instalado:
  - macOS: `brew install trivy`.
  - Linux: ver <https://aquasecurity.github.io/trivy/>.
  - **Si no lo tienes**: el ejemplo te dice exactamente qué verías. Lee aunque no ejecutes.

## Archivos del ejemplo

En `files/`:

- `files/Dockerfile.bad` — Dockerfile con problemas intencionales (root, sin HEALTHCHECK, usa `latest`, etc.).
- `files/Dockerfile.good` — versión endurecida equivalente.
- `files/scan.sh` — pequeño wrapper para correr Trivy sobre ambas.

## Ejecución

```bash
mkdir -p /tmp/dkr13-ex02
cp courses/docker/13-runtime-security-and-hardening/examples/02-trivy-scan/files/* /tmp/dkr13-ex02/
cd /tmp/dkr13-ex02

# Construir las dos imágenes
docker build -f Dockerfile.bad  -t dkr13-ex02:bad  .
docker build -f Dockerfile.good -t dkr13-ex02:good .

# Escaneo
bash scan.sh
```

Si Trivy no está disponible, `scan.sh` imprime `SKIP` y termina en 0 — intencional, para que el ejemplo sea apto en entornos sin la herramienta.

## Walkthrough: `scan.sh`

```bash
# 1) Vulns de la imagen "mala"
trivy image --severity HIGH,CRITICAL dkr13-ex02:bad

# 2) Misconfig estática del Dockerfile "malo"
trivy config --severity HIGH,CRITICAL Dockerfile.bad

# 3) Lo mismo para la versión buena (debería tener bastante menos)
trivy image  --severity HIGH,CRITICAL dkr13-ex02:good
trivy config --severity HIGH,CRITICAL Dockerfile.good

# 4) Gate de CI: falla si hay cualquier CRITICAL
trivy image --severity CRITICAL --exit-code 1 --ignore-unfixed dkr13-ex02:good
```

## Resultado esperado

### `trivy image dkr13-ex02:bad`

Verás una tabla por paquete con columnas `Library | Vulnerability | Severity | Installed | Fixed | Title`. En una base `python:3.12-slim` suele haber un par de CVEs HIGH residuales de `libc`/`openssl` sin fix disponible. En `python:3.11` o versiones viejas, muchas más.

### `trivy config Dockerfile.bad`

Reporta findings como:

```
AVD-DS-0002 (HIGH)   : Specify at least 1 USER command in Dockerfile with non-root user
AVD-DS-0026 (LOW)    : Add HEALTHCHECK instruction
AVD-DS-0005 (MEDIUM) : Specify a tag in the 'FROM' statement for image 'python'
AVD-DS-0001 (HIGH)   : ':latest' tag used
```

### `trivy image dkr13-ex02:good`

Las CVEs residuales de la base siguen (no son culpa tuya). Las de misconfig desaparecen.

### Gate de CI

```bash
trivy image --severity CRITICAL --exit-code 1 --ignore-unfixed dkr13-ex02:good
# Si no hay CRITICAL con fix disponible → exit 0 (pasa).
# Si hay → exit 1 (bloquea el pipeline).
```

`--ignore-unfixed` evita bloquear por CVEs que no tienen parche aún (política razonable; otras políticas prefieren bloquear igual).

## Interpretación

- **CRITICAL con fix** → actualiza (base más nueva, bump de dependencia, parche).
- **HIGH sin fix** → nota, monitorea, mitiga en runtime (hardening) o deja un `trivyignore` justificado.
- **LOW/MEDIUM** → gestión de deuda, no gate.

Trivy es un *indicador*, no un veredicto. No todas las CVEs son explotables en tu contexto (código muerto, no expuesta, mitigada por capability drop, etc.). Un escáner que falla todo también es un ruido que la gente ignora.

## Alternativas

- **grype** (Anchore): tabla similar, muy rápido, integra bien con `syft` para SBOM. Comando: `grype <image>`.
- **docker scout**: integrado en Docker Desktop reciente, tabla y UI web.
- **Snyk CLI**: comercial, cubre más lenguajes/IaC.

## Errores frecuentes

- **Primer run tarda minutos**: Trivy baja su base de vulns (~200 MB). Está en `~/.cache/trivy`. Después es rápido.
- **"TOOMANYREQUESTS" al pull de la DB**: usa `--db-repository` con mirror corporativo o `--skip-db-update` tras un primer pull.
- **Reporta "unfixed" como CRITICAL**: fija política con `--ignore-unfixed` y revisa manualmente.

## Relación con escenarios reales

Esto se automatiza en el pipeline (`dkr-14` y `gha-14`): build → `trivy image` como gate → sólo si pasa, firma con cosign y push al registry. Es el patrón productivo moderno.

## Limpieza

```bash
docker rmi dkr13-ex02:bad dkr13-ex02:good 2>/dev/null || true
rm -rf /tmp/dkr13-ex02
```
