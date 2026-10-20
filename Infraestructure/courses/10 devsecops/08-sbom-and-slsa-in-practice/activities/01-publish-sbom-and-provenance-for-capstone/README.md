# Actividad 01 — Publicar SBOM + provenance (local-hands-on + GHA walkthrough)

## 1. Identificación

- **ID:** `sec-08-01-publish-sbom-and-provenance-for-capstone`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-08-sbom-and-slsa-in-practice`
- **Dificultad:** advanced
- **Duración estimada:** 60–75 min
- **Tipo:** guided-lab (independiente — no depende de la actividad 02)

## 2. Contexto

Tu capstone va a producir imágenes de contenedor. Hoy no emites ni SBOM ni provenance. En esta actividad vas a:

1. Generar **SBOM** CycloneDX y SPDX **localmente** con `syft` sobre una imagen (o un directorio si falta Docker).
2. Pasar el SBOM a `grype` y obtener un reporte de vulnerabilidades reproducible.
3. Escribir a mano un **`provenance.json` nivel L1** (auto-reportado) como primer paso del roadmap SLSA.
4. Preparar un **workflow GHA** `release.yml` listo para publicar SBOM + provenance a GHCR (no se ejecuta — queda como template).

El validador comprueba la **estructura** de los entregables; la **corrección semántica** la autoevalúas contra `solution/REFERENCE.md`.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Emitir SBOM en **ambos formatos** con una sola herramienta.
- Explicar por qué escanear el SBOM con Grype es más reproducible que escanear la imagen directamente.
- Redactar un `provenance.json` L1 mínimo que cumpla el esquema in-toto Statement v1.
- Nombrar las 4 claves imprescindibles de un workflow GHA para alcanzar L3 con `attest-build-provenance`.

## 4. Prerrequisitos

- `sec-01`, `sec-05`.
- Haber leído `../../theory/lesson.md` y los tres ejemplos.
- Herramientas: `bash`, `syft`, `grype`. **Opcional**: `docker`, `cosign`, `gh`. El validador y los scripts hacen **skip graceful** si faltan.

**Costos**: ninguno. Todo es local.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/sec-08-capstone
cd /tmp/sec-08-capstone
```

### 5.2 Emitir SBOMs

Si tienes **Docker**: construye una imagen Alpine mínima y escanéala. Si no, escanea un directorio con `requirements.txt`.

Comandos (adaptados):

```bash
# Opción A — con Docker
cat > Dockerfile <<'EOF'
FROM python:3.11-alpine
RUN pip install --no-cache-dir "requests==2.25.1" "urllib3==1.26.5"
EOF
docker build -t sec-08-capstone:local .
syft sec-08-capstone:local -o cyclonedx-json=sbom.cdx.json
syft sec-08-capstone:local -o spdx-json=sbom.spdx.json

# Opción B — sin Docker (desde un dir)
cat > requirements.txt <<'EOF'
requests==2.25.1
urllib3==1.26.5
EOF
syft dir:. -o cyclonedx-json=sbom.cdx.json
syft dir:. -o spdx-json=sbom.spdx.json
```

Entregables en `/tmp/sec-08-capstone/`:

- `sbom.cdx.json` (CycloneDX).
- `sbom.spdx.json` (SPDX).

### 5.3 Escanear el SBOM con Grype

```bash
grype sbom:sbom.cdx.json -o json > vulns.json
```

Entregable: `/tmp/sec-08-capstone/vulns.json`.

### 5.4 Escribir `provenance.json` nivel L1 a mano

Rellena este esqueleto (plantilla disponible en `starter/provenance.template.json`):

```json
{
  "_type": "https://in-toto.io/Statement/v1",
  "subject": [{
    "name": "sec-08-capstone",
    "digest": {"sha256": "<reemplazar con hash real o 'LOCAL-BUILD'>"}
  }],
  "predicateType": "https://slsa.dev/provenance/v1",
  "predicate": {
    "buildDefinition": {
      "buildType": "https://example.com/manual-build/v1",
      "externalParameters": {
        "note": "L1 self-reported — subir a L2 con hosted builder"
      },
      "resolvedDependencies": [{
        "uri": "git+file:///tmp/sec-08-capstone",
        "digest": {"gitCommit": "N/A"}
      }]
    },
    "runDetails": {
      "builder": {"id": "local-workstation"},
      "metadata": {
        "invocationId": "manual-run",
        "startedOn": "<ISO 8601>",
        "finishedOn": "<ISO 8601>"
      }
    }
  }
}
```

Entregable: `/tmp/sec-08-capstone/provenance.json`.

### 5.5 Preparar el workflow GHA (template, no se ejecuta)

Copia `starter/release.yml.template` a `/tmp/sec-08-capstone/release.yml` y adáptalo mentalmente a tu repo. Debe contener:

- `permissions:` con `id-token: write` y `attestations: write`.
- Un step que use `actions/attest-build-provenance`.
- Un step que use `actions/attest-sbom` o `anchore/sbom-action`.
- Pin por **digest** (`steps.push.outputs.digest`), no por tag.

Entregable: `/tmp/sec-08-capstone/release.yml`.

## 6. Resultado esperado

- `sbom.cdx.json` y `sbom.spdx.json` existen y son JSON válido.
- `vulns.json` existe (si Grype está disponible; si no, el validador lo tolera).
- `provenance.json` existe y menciona `in-toto.io/Statement/v1` + `slsa.dev/provenance/v1`.
- `release.yml` existe y menciona `attest-build-provenance`, `id-token: write`, `attestations: write`.
- `bash tests/validate.sh /tmp/sec-08-capstone` pasa.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural en verde.
- **Calidad**: `provenance.json` tiene subject + predicate; `release.yml` tiene permisos correctos.
- **Reproducibilidad**: alguien puede repetir el lab con los mismos comandos.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-08-capstone
```

El validador comprueba estructura, nombres de archivos y presencia de claves — no la corrección semántica del `provenance.json`.

## 9. Preguntas de reflexión

1. ¿Por qué `provenance.json` escrito a mano es solo **L1** y no L2? ¿Qué pieza concreta falta?
2. ¿Qué pasaría si el workflow usara `--certificate-identity` en la verificación pero el *regexp* permitiera `.*workflow.*`? ¿Qué garantía se pierde?
3. CycloneDX vs SPDX: dado el `sbom.cdx.json` y el `sbom.spdx.json` que acabas de generar, ¿cuál usarías para hablar con el equipo legal? ¿Y para alimentar Dependency-Track?
4. ¿Qué diferencia hay entre `syft dir:.` y `syft <image>` en términos del *tipo de SBOM* del §4 de la lección?

## 10. Extensiones

- Añade `trivy sbom sbom.cdx.json` y compara findings con `grype`.
- Firma localmente con `cosign sign-blob --yes sbom.cdx.json > sbom.cdx.json.sig` (requiere `cosign` + navegador OIDC — opcional).
- Convierte `sbom.cdx.json` a formato `table` con `syft convert sbom.cdx.json -o table` para inspección rápida.

## 11. Limpieza

```bash
rm -rf /tmp/sec-08-capstone
docker rmi sec-08-capstone:local 2>/dev/null || true
```
