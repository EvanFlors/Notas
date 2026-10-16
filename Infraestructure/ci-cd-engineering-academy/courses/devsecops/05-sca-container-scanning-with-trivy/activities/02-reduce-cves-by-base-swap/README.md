# Actividad 02 — Reducir CVEs cambiando la base image

## 1. Identificación

- **ID:** `sec-05-02-reduce-cves-by-base-swap`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-05-sca-container-scanning-with-trivy`
- **Dificultad:** intermediate
- **Duración estimada:** 55 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Un principio operativo de container scanning: **la mejor forma de reducir CVEs no es parchear, es cambiar a una base image más fina**. `python:3.12` arrastra ~400 paquetes Debian; `python:3.12-slim` ~100; `cgr.dev/chainguard/python:latest` prácticamente ninguno. En esta actividad construyes **la misma aplicación trivial** con las tres bases, escaneas cada una con Trivy, mides la reducción y escribes un ADR.

**Costos**: ninguno. **Red**: pulls de Docker Hub + cgr.dev + `aquasec/trivy:0.56.2`.

## 3. Objetivos

- Construir 3 variantes (`var1`, `var2`, `var3`) de la misma app.
- Escanear cada una con `trivy image --format json` y extraer el conteo por severidad.
- Calcular la **reducción porcentual** de `CRITICAL + HIGH` entre v1 y v3.
- Escribir un **ADR** (`ADR.md`) con contexto, decisión y consecuencias.
- Producir `COUNTS.md` con la tabla comparativa.

## 4. Prerrequisitos

- `docker` y `jq` instalados. Si falta alguno, el validador reporta **SKIP** sobre los checks ejecutables y evalúa solo los documentos.
- `bash` y un editor Markdown.
- Opcional: `trivy` nativo. Si no, usamos `aquasec/trivy:0.56.2` vía Docker.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/sec-05-base-swap
cd /tmp/sec-05-base-swap
```

### 5.2 La "aplicación" (idéntica para las tres variantes)

```bash
cat > app.py <<'EOF'
# Trivial: imprime el nombre y la version de Python.
import sys
print(f"hello from sec-05-base-swap on {sys.version}")
EOF
```

### 5.3 Los tres Dockerfiles

```bash
cat > Dockerfile.v1 <<'EOF'
FROM python:3.12
WORKDIR /app
COPY app.py .
CMD ["python", "app.py"]
EOF

cat > Dockerfile.v2 <<'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY app.py .
CMD ["python", "app.py"]
EOF

cat > Dockerfile.v3 <<'EOF'
# Chainguard: distroless + hardened + 0-known-CVE objetivo.
FROM cgr.dev/chainguard/python:latest
WORKDIR /app
COPY app.py .
ENTRYPOINT ["python", "app.py"]
EOF
```

### 5.4 Construir las tres variantes

```bash
docker build -f Dockerfile.v1 -t sec05-swap:v1 .
docker build -f Dockerfile.v2 -t sec05-swap:v2 .
docker build -f Dockerfile.v3 -t sec05-swap:v3 .
```

Si el pull de `cgr.dev/chainguard/python:latest` falla (red corporativa / registro bloqueado), puedes sustituir v3 por `gcr.io/distroless/python3-debian12:latest`; apunta este cambio en el `ADR.md`.

### 5.5 Escanear cada variante y extraer conteos

```bash
TRIVY="docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $HOME/.cache/trivy:/root/.cache/trivy \
  aquasec/trivy:0.56.2 image \
    --severity CRITICAL,HIGH,MEDIUM \
    --ignore-unfixed \
    --format json"

for v in v1 v2 v3; do
  $TRIVY sec05-swap:$v > scan-$v.json
done
```

Agrega conteos con `jq`:

```bash
count_sev() {
  local file="$1"
  local sev="$2"
  jq "[.Results[]?.Vulnerabilities[]? | select(.Severity==\"$sev\")] | length" "$file"
}

{
  echo "variant,critical,high,medium"
  for v in v1 v2 v3; do
    c=$(count_sev "scan-$v.json" CRITICAL)
    h=$(count_sev "scan-$v.json" HIGH)
    m=$(count_sev "scan-$v.json" MEDIUM)
    echo "$v,$c,$h,$m"
  done
} > counts.csv

cat counts.csv
```

### 5.6 Escribir `COUNTS.md`

Formato mínimo:

```markdown
# COUNTS.md — CVEs por variante de base image

| Variante | Base image                              | CRITICAL | HIGH | MEDIUM |
|----------|-----------------------------------------|----------|------|--------|
| v1       | python:3.12                             |    ...   |  ... |  ...   |
| v2       | python:3.12-slim                        |    ...   |  ... |  ...   |
| v3       | cgr.dev/chainguard/python:latest        |    ...   |  ... |  ...   |

**Reduccion v1 -> v3 (CRITICAL+HIGH):** ... %
**Fecha de medicion:** 2026-10-16
**DB Trivy version:** (sacarla del log del scan)
```

Fórmula: `((critH1+critL1) - (critH3+critL3)) / (critH1+critL1) * 100`.

### 5.7 Escribir `ADR.md`

Formato ADR corto (Michael Nygard):

```markdown
# ADR-001 — Cambio de base image para reducir inventario de CVEs

## Estado

Propuesto · 2026-10-16

## Contexto

La imagen productiva usa `python:3.12` como base. El scan diario con Trivy
reporta N CVEs CRITICAL + HIGH, mayoritariamente de paquetes de SO que
nuestra app no utiliza (perl, bash, libgcc dev tooling, ...).

## Decision

Migrar la base image a `python:3.12-slim` en el corto plazo (una sprint)
y a `cgr.dev/chainguard/python:latest` como objetivo a 2 sprints,
condicionado a que el pipeline de verificacion funcional pase.

## Alternativas consideradas

- Dejar `python:3.12` y parchar cada CVE individualmente -> insostenible.
- `python:3.12-alpine` (musl): descartado por incompatibilidades conocidas
  con wheels precompilados de Python de la comunidad.
- `gcr.dev/distroless/python3-debian12`: contemplado como fallback de
  Chainguard si hay restricciones de red con cgr.dev.

## Consecuencias

### Positivas

- Reduccion medida de X % en el conteo CRITICAL+HIGH (ver COUNTS.md).
- Imagen final mas pequena (menos capas, menor superficie de ataque).
- Menos ruido en Code Scanning -> triage mas accionable.

### Negativas / riesgos

- No hay shell en distroless/chainguard -> debug "docker exec sh" ya no funciona.
  Mitigacion: imagen `-debug` tag para troubleshooting puntual.
- Chainguard "latest" es rolling: puede introducir cambios de version de
  Python inesperados. Mitigacion: pinear a un digest especifico.
- Dependencia de cgr.dev como registry.

## Metricas de exito

- `COUNTS.md` muestra reduccion >= 70 % en CRITICAL+HIGH entre v1 y v3.
- CI verde con la nueva base.
- Monitoreo del scan diario en Code Scanning durante 2 semanas sin regresiones.
```

### 5.8 Limpieza

```bash
docker rmi sec05-swap:v1 sec05-swap:v2 sec05-swap:v3 2>/dev/null || true
# rm -rf /tmp/sec-05-base-swap  # al final
```

## 6. Resultado esperado

- `Dockerfile.v1`, `Dockerfile.v2`, `Dockerfile.v3` existen con bases correctas.
- `COUNTS.md` tiene las tres filas y menciona "Reduccion".
- `ADR.md` tiene las secciones estándar (Estado, Contexto, Decision, Alternativas, Consecuencias).
- `bash tests/validate.sh /tmp/sec-05-base-swap` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: los tres Dockerfiles existen con los tags base esperados.
- **Calidad**: `COUNTS.md` tiene números reales (si tuviste docker) o placeholders explícitos (`N/A` + nota) si el validador SKIP los scans.
- **Reproducibilidad**: alguien con `docker` + `jq` puede re-ejecutar `scan-*.json` y obtener números parecidos.
- **Mantenibilidad**: el ADR es defendible ante un lead y menciona el riesgo de "no hay shell".

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-05-base-swap
```

Si no tienes `docker` o `jq`, el validador reporta **SKIP** sobre los checks ejecutables y evalúa solo los documentos.

## 9. Preguntas de reflexión

1. ¿Por qué `python:3.12-alpine` **no** es la respuesta universal?
2. Si Chainguard es "0 known CVE objetivo", ¿cómo lo logran operativamente? (Pista: rebuild diario + rápido pickup de parches upstream).
3. ¿Qué pierde el equipo al pasar a distroless? ¿Cómo lo compensas?
4. Si el ADR dice "reducción de 85 %", ¿cuánto durará esa reducción si no actualizas la base?
5. ¿Qué signal del Trivy Operator confirmaría en runtime que la decisión del ADR se mantuvo?

## 10. Extensiones

- Añade una v4 con `cgr.dev/chainguard/python:latest-dev` (con shell) y mide la diferencia respecto a v3.
- Compara `--ignore-unfixed` vs sin el flag en v1: ¿cuántas CVEs "won't fix" aparecen?
- Pinea v3 por digest (`cgr.dev/chainguard/python@sha256:...`) y vuelve a medir en 1 mes para observar el drift.

## 11. Limpieza

```bash
docker rmi sec05-swap:v1 sec05-swap:v2 sec05-swap:v3 2>/dev/null || true
rm -rf /tmp/sec-05-base-swap
```
