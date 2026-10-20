# dkr-08-02 — Flaky startup: arreglar con healthcheck

## 1. Identificación

- **ID:** `dkr-08-02-flaky-startup-fix-with-healthcheck`
- **Tecnología:** docker
- **Módulo:** `08-compose-for-development`
- **Dificultad:** intermediate
- **Duración estimada:** 40 min
- **Tipo:** independent (debug)

## 2. Contexto

Un compañero te pasa un `compose.yaml` que *a veces* funciona y *a veces* no. En su máquina rara vez falla; en la tuya (más rápida) falla casi siempre. El síntoma es el mismo: el servicio `api` arranca "exitosamente" pero el primer request a `/db` devuelve `503`. Tras unos segundos, los requests pasan a `200`.

Diagnostica, hipotetiza y arregla **sin leer `solution/`**.

## 3. Objetivos

- Reproducir el bug intermitente de forma consistente.
- Formular una hipótesis sobre el orden real de arranque de los servicios.
- Aplicar la corrección mínima que haga el stack arrancar *determinísticamente*.
- Validar con dos corridas consecutivas que ya no es flaky.

## 4. Prerrequisitos

- Haber hecho la actividad 01.
- `docker` y `docker compose` v2 instalados.

## 5. Instrucciones

Está prohibido abrir `solution/` hasta que termines (o te hayas atascado 60 min).

### 5.1 Copia el starter a /tmp

```bash
BASE=/tmp/dkr-08-02-flaky-startup
rm -rf "$BASE" && mkdir -p "$BASE"
cp -R starter/. "$BASE/"
cd "$BASE"
```

### 5.2 Reproduce el bug

Hazlo **al menos 3 veces** seguidas:

```bash
docker compose down -v >/dev/null 2>&1
docker compose up -d --build
sleep 1
curl -i http://localhost:8010/db
docker compose logs api | tail -10
```

Cuenta cuántas veces `/db` devuelve 503 y cuántas 200.

### 5.3 Diagnostica

Preguntas que deberías responderte **antes** de tocar el YAML:

- ¿`api` arranca antes o después de `db`? ¿Cómo lo sabes?
- Cuando `api` levanta, ¿Postgres está aceptando conexiones?
- ¿Qué dice `docker compose logs db` sobre cuándo acepta conexiones?
- ¿Qué forma de `depends_on` está usando el `compose.yaml`?
- ¿Hay healthcheck en `db`? ¿Y en `api`?

### 5.4 Formula hipótesis y arregla

Edita `compose.yaml`. La corrección es **la mínima** que elimine la ventana de carrera. No reescribas el stack entero.

### 5.5 Valida

Ejecuta el validador. Debe hacer **dos** iteraciones de `up/curl/down -v` seguidas y las dos deben pasar:

```bash
cd /ruta/al/repo/courses/docker/08-compose-for-development/activities/02-flaky-startup-fix-with-healthcheck
bash tests/validate.sh
```

## 6. Resultado esperado

- El validador reporta **las dos iteraciones** en OK.
- `curl http://localhost:8010/db` responde `200` inmediatamente tras `docker compose up -d --wait` (sin `sleep`).
- La corrección es **puntual**: no editas la app, solo el `compose.yaml`.

## 7. Criterios de aceptación

- 2/2 corridas consecutivas pasan.
- `db` tiene un healthcheck real.
- `api` depende de `db` con `condition: service_healthy`.
- `docker compose down -v` limpia todo entre corridas.

## 8. Validación

```bash
bash tests/validate.sh
```

El validador ejecuta dos ciclos completos: `down -v` → `up -d --wait` → `curl /db` → `down -v`. Si cualquiera de los dos ciclos falla, exit 1.

## 9. Preguntas de reflexión

- ¿Por qué el bug era *intermitente* y no determinístico? ¿Qué factores lo hacen más o menos probable (velocidad de disco, carga del host, versión de Postgres)?
- ¿Qué pasaría si en vez de arreglar Compose, hicieras `api` *resiliente* (retry con backoff en el pool de conexiones)? ¿Qué estrategia es "mejor"? ¿Son excluyentes?
- Si estuvieras en Kubernetes, ¿qué equivalente usarías? ¿`readinessProbe`? ¿`initContainer`? ¿Ambos?
- Tu arreglo garantiza que el **primer** request funcione. Si Postgres se cae a media sesión, ¿Compose vuelve a esperar antes de que `api` reintente? ¿O eso ya es tu problema?

## 10. Extensiones

1. Añade **también** un `healthcheck` a `api` que pegue `/health`. ¿Qué cambia en `docker compose ps`?
2. Mide empíricamente cuántos segundos tarda Postgres en pasar de "started" a "healthy" en tu máquina.
3. Simula un fallo del healthcheck de `db` (cámbialo a `pg_isready -U nouser`). ¿Qué pasa con `api`?

## 11. Limpieza

```bash
cd /tmp/dkr-08-02-flaky-startup
docker compose down -v --remove-orphans
rm -rf /tmp/dkr-08-02-flaky-startup
```
