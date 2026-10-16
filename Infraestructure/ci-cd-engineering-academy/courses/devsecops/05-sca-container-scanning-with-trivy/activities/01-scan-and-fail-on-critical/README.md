# Actividad 01 — Escanear y fallar en CRITICAL con Trivy

## 1. Identificación

- **ID:** `sec-05-01-scan-and-fail-on-critical`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-05-sca-container-scanning-with-trivy`
- **Dificultad:** intermediate
- **Duración estimada:** 50 min
- **Tipo:** guided-lab (independiente de la actividad 02)

## 2. Contexto

Vas a jugar el papel de "gate guardian": construyes una imagen deliberadamente vieja, la escaneas con **Trivy**, y demuestras que el pipeline **falla** si aparece una `CRITICAL` **con fix disponible** y **sin excepción documentada**. Después, documentas una excepción con razón, aprobador y expiración, verificas que ahora el gate pasa, y escribes un `POLICY.md` corto defendiendo la política.

**Costos**: ninguno. **Red**: solo pulls de Docker Hub (`alpine:3.14`, `python:3.12-alpine`, `aquasec/trivy:0.56.2`).

## 3. Objetivos

Al terminar deberías poder, sin consultar la lección:

- Correr `trivy image` con la política `--severity CRITICAL --exit-code 1 --ignore-unfixed`.
- Leer la tabla y distinguir vulns de **OS packages** vs vulns de **language packages**.
- Escribir un `.trivyignore.yaml` válido con los tres campos obligatorios (`id`, `statement`, `expired_at`).
- Defender por qué `--ignore-unfixed` **no** es "ignorar la vuln", sino "no bloquear por lo que no se puede arreglar".

## 4. Prerrequisitos

- `docker` corriendo. Si no, el validador **SKIP** gracefully.
- `bash` y un editor.
- Opcional: `trivy` binario local (`brew install trivy`). Si no, usamos la imagen `aquasec/trivy:0.56.2` vía Docker.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/sec-05-fail-on-critical
cd /tmp/sec-05-fail-on-critical
```

### 5.2 Crear el `Dockerfile` deliberadamente vulnerable

```bash
cat > Dockerfile <<'EOF'
# Base image VIEJA a proposito: alpine 3.14 (EOL, muchas CVEs)
FROM alpine:3.14

RUN apk add --no-cache python3 py3-pip

# Dependencia Python antigua a proposito
RUN pip3 install --no-cache-dir "requests==2.19.0"

CMD ["python3", "-c", "import requests; print(requests.__version__)"]
EOF
```

Esta imagen tiene **CVEs garantizadas** en la capa OS (openssl viejo, musl viejo) y en la capa Python (`requests` 2.19.0 arrastra `urllib3` con `CVE-2020-26137`, por ejemplo).

### 5.3 Construir la imagen

```bash
docker build -t sec05-badimage:local .
```

### 5.4 Primer scan — sin ignore, esperamos fallar

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$HOME/.cache/trivy:/root/.cache/trivy" \
  aquasec/trivy:0.56.2 image \
    --severity CRITICAL \
    --exit-code 1 \
    --ignore-unfixed \
    sec05-badimage:local

# Captura el exit code
echo "exit=$?" > scan1.exit
```

El exit code debe ser **1** (al menos una `CRITICAL` con fix). Guárdalo: lo valida el validador.

### 5.5 Documentar la excepción

Elige **una** CVE `CRITICAL` de las que aparecieron (p. ej. una de `openssl` o de `libcrypto`) y escribe:

```bash
cat > .trivyignore.yaml <<'EOF'
# Excepciones de Trivy — cada entrada DEBE tener id, statement, expired_at.
vulnerabilities:
  - id: CVE-XXXX-XXXXX           # <-- sustituye por una CVE real del scan previo
    statement: |
      Vulnerabilidad en openssl/libcrypto. En este lab la ruta de codigo
      vulnerable (SSL/TLS server-side) no se ejecuta: la imagen solo
      corre un cliente HTTP de prueba. Aprobado por @security-lead
      para efectos pedagogicos.
    expired_at: 2026-12-31
EOF
```

> El validador no verifica que la CVE sea real — solo que el `.trivyignore.yaml` existe y tiene los tres campos obligatorios.

### 5.6 Segundo scan — con ignore

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$HOME/.cache/trivy:/root/.cache/trivy" \
  -v "$PWD/.trivyignore.yaml:/.trivyignore.yaml" \
  aquasec/trivy:0.56.2 image \
    --severity CRITICAL \
    --exit-code 1 \
    --ignore-unfixed \
    --ignorefile /.trivyignore.yaml \
    sec05-badimage:local

echo "exit=$?" > scan2.exit
```

Si solo había **una** CVE `CRITICAL` con fix y la silenciaste, exit será **0**. Si había varias, repite añadiendo más entradas al `.trivyignore.yaml` o acepta el fail y documéntalo en `POLICY.md` como "el ignore solo cubre una parte; el resto se arregla subiendo la base image en el siguiente PR".

> El validador acepta **ambos** desenlaces del scan2 — lo que verifica es que **existe** `scan2.exit` y que el `.trivyignore.yaml` está bien formado.

### 5.7 Escribir `POLICY.md`

Documento corto (una página) con tres secciones mínimas:

```markdown
# POLICY.md — gate de container scanning con Trivy

## Seccion A — Que bloquea el merge

- Severidad: `CRITICAL` con fix disponible (`--ignore-unfixed`).
- Fuente: `trivy image` sobre la imagen construida en el PR.
- Overrides permitidos: entradas en `.trivyignore.yaml` con `id`, `statement`, `expired_at`.

## Seccion B — Que NO bloquea (de momento)

- `HIGH` CVSS: warn via SARIF a Code Scanning, no bloquea.
- `CRITICAL` sin fix: trackeada aparte via nightly scan + ticket, no bloquea.
- `MEDIUM`/`LOW`: inventario, no bloquea.

## Seccion C — Cuando subir el gate

- Si una CVE `HIGH` aparece en el catalogo **KEV** de CISA.
- Si una CVE `HIGH` tiene **EPSS > 0.5**.
- Si auditoria externa lo exige por un cliente concreto.
```

El validador comprueba estructura (tres secciones + mención de las palabras clave `CRITICAL`, `KEV`, `EPSS`, `ignore-unfixed`), no semántica.

### 5.8 Limpieza

```bash
docker rmi sec05-badimage:local || true
# el directorio se puede borrar al final; el validador no lo exige
# rm -rf /tmp/sec-05-fail-on-critical
```

## 6. Resultado esperado

- `/tmp/sec-05-fail-on-critical/Dockerfile` existe y usa `FROM alpine:3.14`.
- `/tmp/sec-05-fail-on-critical/scan1.exit` contiene `exit=1`.
- `/tmp/sec-05-fail-on-critical/scan2.exit` existe (contenido indiferente).
- `/tmp/sec-05-fail-on-critical/.trivyignore.yaml` tiene las tres claves `id`, `statement`, `expired_at`.
- `/tmp/sec-05-fail-on-critical/POLICY.md` tiene las tres secciones (A/B/C) y menciona `CRITICAL`, `KEV`, `EPSS`, `ignore-unfixed`.
- `bash tests/validate.sh /tmp/sec-05-fail-on-critical` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: el gate falla sin ignore y pasa (o se documenta el fallo residual) con ignore.
- **Calidad**: `.trivyignore.yaml` tiene razón concreta — no "falso positivo" seco.
- **Reproducibilidad**: alguien puede re-correr tu lab y obtener los mismos exit codes.
- **Mantenibilidad**: `POLICY.md` es defendible ante un lead escéptico.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-05-fail-on-critical
```

Si no tienes `docker` o `trivy` disponible, el validador reporta **SKIP** sobre esos checks y evalúa solo los artefactos de documentación.

## 9. Preguntas de reflexión

1. ¿Por qué `--ignore-unfixed` **no** es un atajo peligroso?
2. Si tu `.trivyignore.yaml` tiene 40 entradas, ¿qué proceso disparas?
3. ¿Cuánto tiempo máximo debería durar una `expired_at` razonable? ¿Un mes? ¿Un trimestre?
4. Si subes de `alpine:3.14` a `alpine:3.20`, ¿cuántas de las CVEs de este lab esperas que desaparezcan sin tocar código?
5. Un dev del equipo propone "deshabilitamos el gate en los PRs urgentes". ¿Qué respondes?

## 10. Extensiones

- Añade un segundo scan con `--format sarif --output trivy-results.sarif` y verifica que es JSON válido con `jq`.
- Añade `trivy config .` sobre el `Dockerfile` para detectar misconfigs (p. ej. `USER root`).
- Agrega una tercera dependencia Python antigua (`django==1.11`) y mide cuántos CVEs nuevos aparecen.

## 11. Limpieza

```bash
docker rmi sec05-badimage:local 2>/dev/null || true
rm -rf /tmp/sec-05-fail-on-critical
```
