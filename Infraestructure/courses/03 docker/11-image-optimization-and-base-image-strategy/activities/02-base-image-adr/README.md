# dkr-11-02 — Base image ADR (independent)

## 1. Identificación

- **ID:** `dkr-11-02-base-image-adr`
- **Tecnología:** docker
- **Módulo:** `11-image-optimization-and-base-image-strategy`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto

Eres el responsable técnico de un servicio Python/FastAPI que correrá en K8s en producción. Debes **elegir la base image** y **documentar por qué**. En la empresa se exige una ADR corta (una página o dos) para cualquier decisión de infra persistente.

Esta actividad es **independiente**: el `solution/` existe pero no debes leerlo hasta terminar tu propio ADR.

## 3. Objetivos

- Construir la misma app sobre al menos **tres bases**: `python:3.12-slim`, `python:3.12-alpine`, `gcr.io/distroless/python3-debian12:nonroot`. Opcional: `cgr.dev/chainguard/python`.
- Medir y tabular:
  - Tamaño descomprimido (`docker image inspect ... --format '{{.Size}}'`).
  - Tiempo de cold-start (`time docker run --rm <tag> python -c 'print(1)'` tras `docker rmi` para no cachear).
  - CVEs Critical/High si tienes `trivy` instalado (opcional).
  - Dificultad de debug (¿tiene shell?).
- Escribir `ADR-0001-base-image.md` siguiendo la plantilla de abajo.

## 4. Prerrequisitos

- Docker Engine. `trivy` opcional. No necesitas credenciales.
- ~2 GB de disco para los builds.
- **Costo:** $0.

## 5. Instrucciones

1. Copia `starter/` a `/tmp/dkr-11-adr/`:

   ```
   cp -R starter/* /tmp/dkr-11-adr/
   cd /tmp/dkr-11-adr
   ```

2. Escribe tres Dockerfiles (`Dockerfile.slim`, `Dockerfile.alpine`, `Dockerfile.distroless`). Puedes guiarte por `examples/01-slim-vs-alpine-vs-distroless/` del módulo, pero no copiar literal.

3. Construye y mide. Guarda la tabla en `measurements.md`:

   ```
   | base        | size (MB) | cold-start (s) | CVEs C/H | shell? |
   |-------------|-----------|----------------|----------|--------|
   | slim        | ...       | ...            | ...      | yes    |
   | alpine      | ...       | ...            | ...      | yes    |
   | distroless  | ...       | ...            | ...      | no     |
   ```

4. Escribe `ADR-0001-base-image.md` con **estas secciones** (mínimas):

   ```
   # ADR 0001 — Base image for service X

   ## Status
   Proposed | Accepted | Superseded by ...

   ## Context
   (Qué servicio es, qué restricciones hay: K8s, tiempos de pull, equipo que debuggea con sh, etc.)

   ## Decision
   Elegimos <base>. Pin: <digest o tag>.

   ## Options considered
   - slim: pros / cons / números.
   - alpine: pros / cons / números.
   - distroless: pros / cons / números.
   - (opcional) chainguard, scratch.

   ## Consequences
   Positivas: ...
   Negativas / mitigaciones: ...
   (Ej: "no hay shell → runbook de debug con kubectl debug --image=busybox").

   ## Follow-ups
   (Cosas que la decisión implica agendar: re-evaluar en 6 meses, migrar a chainguard si cambia política, etc.)
   ```

5. Entrega: el archivo `ADR-0001-base-image.md` y `measurements.md` en `/tmp/dkr-11-adr/`.

## 6. Resultado esperado

- Dos archivos en `/tmp/dkr-11-adr/`: `ADR-0001-base-image.md` y `measurements.md`.
- La decisión no es "la más pequeña gana": está justificada contra el contexto (ej. el equipo usa `cryptography`, por lo tanto alpine queda descartada por musl).

## 7. Criterios de aceptación

- `ADR-0001-base-image.md` contiene las secciones `Status`, `Context`, `Decision`, `Options considered`, `Consequences`.
- `measurements.md` contiene una tabla con al menos 3 bases y columnas `size`, `cold-start`, `shell?`.
- La decisión final cita al menos un número de `measurements.md`.
- No se copia literal del `solution/`.

## 8. Validación

```
BASE_DIR=/tmp/dkr-11-adr bash tests/validate.sh
```

El validador comprueba la **presencia y estructura** de los dos archivos; la *calidad* del razonamiento la revisa un humano.

## 9. Preguntas de reflexión

1. ¿Cuánto cuesta en operación "no tener shell"? ¿Qué compensas con observabilidad?
2. ¿Qué pin usas para la base? ¿`:latest`, `:3.12-slim`, `@sha256:...`? ¿Por qué?
3. Si la política de la empresa cambia y exige "zero known CVE", ¿tu ADR se mantiene?
4. Si tu app empieza a usar GPU + CUDA, ¿tu decisión aguanta?

## 10. Extensiones

- Agrega `Dockerfile.chainguard` y una cuarta fila a la tabla.
- Instala `trivy` y añade conteo real de CVEs.
- Mide pull time real tras `docker rmi` + `docker system prune` para forzar red.
- Mide `docker save | wc -c` como aproximación al tamaño comprimido en registry.

## 11. Limpieza

```
docker rmi app:slim app:alpine app:distroless app:chainguard 2>/dev/null || true
rm -rf /tmp/dkr-11-adr
```
