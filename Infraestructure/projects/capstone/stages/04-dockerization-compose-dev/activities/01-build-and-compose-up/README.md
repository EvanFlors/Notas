# cap-04-01 — Construir imagen y levantar Compose con healthcheck

## 1. Identificación
- **ID:** `cap-04-01-build-and-compose-up`
- **Tecnología:** capstone
- **Módulo:** `04-dockerization-compose-dev`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

La CI (etapa 3) ya protege el código, pero el artefacto real que se desplegará es la **imagen**. Antes de firmarla y escanearla en la etapa 5, tienes que poder construirla y correrla reproduciblemente en local, junto con su Postgres de desarrollo.

## 3. Objetivos
- Construir una imagen OCI multi-stage no-root y verificar que **no** contiene toolchain.
- Levantar la topología `app + db` con `docker compose` y esperar `healthy` en ambos.
- Confirmar que `GET /healthz` responde `200` desde el host y desde dentro del contenedor.
- Limpiar imágenes, contenedores y volúmenes al terminar.

## 4. Prerrequisitos
- Docker 24+ y Docker Compose v2.
- Puerto `8000` libre; opcionalmente `5432` (si no, ajusta el override).
- Haber cerrado etapas 1–3 del capstone (`app/main.py` con `/healthz` real).

## 5. Instrucciones

1. Posicionado en `projects/capstone/stages/04-dockerization-compose-dev/`:
   ```bash
   docker build -t capstone-app:dev .
   ```
2. Verifica el usuario del runtime:
   ```bash
   docker inspect --format '{{.Config.User}}' capstone-app:dev
   # Esperado: "nonroot:nonroot" o "10001:10001"
   ```
3. Levanta Compose (sin collector):
   ```bash
   docker compose up -d --build
   docker compose ps
   ```
4. Espera healthy (< 60 s) y hit al endpoint:
   ```bash
   curl -fsS http://localhost:8000/healthz
   ```
5. Ejecuta el validador:
   ```bash
   bash tests/validate.sh
   ```
6. Limpia:
   ```bash
   docker compose down -v --remove-orphans
   docker image rm capstone-app:dev
   ```

## 6. Resultado esperado
- Imagen `capstone-app:dev` existente y no-root.
- `docker compose ps` muestra `app` y `db` con `healthy`.
- `/healthz → 200`.
- `tests/validate.sh` imprime `RESULT: PASS`.

## 7. Criterios de aceptación
- No existe `pip` en la imagen final.
- No hay credenciales reales en `docker-compose.yml` (solo `fake-password`).
- `.dockerignore` recorta `.git` y `.venv` del contexto.
- Compose convierte sin warnings relevantes (`docker compose config -q`).

## 8. Validación
```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión
- ¿Por qué el runtime es distroless/Chainguard y no `python:3.12-slim`?
- ¿Qué pasaría si quitas el `HEALTHCHECK`? ¿Cómo se enteraría ECS/Kubernetes de un deadlock?
- ¿Qué cambia si corres `docker compose --profile otel up`?

## 10. Extensiones
- Añade un segundo stage `tester` que corra `pytest` y falle el build si rompe.
- Usa `BuildKit` cache mount para acelerar `pip install`.
- Reemplaza distroless por Chainguard y mide el delta de CVEs.

## 11. Limpieza
```bash
docker compose down -v --remove-orphans
docker image rm capstone-app:dev || true
docker builder prune -f
```
