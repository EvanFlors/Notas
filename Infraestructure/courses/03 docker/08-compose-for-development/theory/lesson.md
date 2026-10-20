# dkr-08 — Compose para desarrollo (lección profunda)

> Lectura estimada: 2.5–3 h. 12 secciones. El objetivo no es memorizar YAML sino entender **qué hace Compose debajo** para que puedas depurar y defender decisiones.

---

## 1. De qué estamos hablando: Compose como orquestador local

Hasta aquí (`dkr-01` a `dkr-07`) corriste contenedores sueltos con `docker run` y construiste imágenes con `docker build`. En cuanto una app tiene **más de un servicio** —app + base de datos, app + cache, app + proxy, test runner + fixtures— la línea de comandos se vuelve inmanejable:

```
docker network create devnet
docker volume create pgdata
docker run -d --name db --network devnet \
  -e POSTGRES_PASSWORD=dev -v pgdata:/var/lib/postgresql/data postgres:16
docker run -d --name api --network devnet -p 8000:8000 \
  -e DATABASE_URL=postgresql://postgres:dev@db:5432/postgres myapi:dev
# ... y repites el ritual cada mañana, y lo tienes que escribir en un README
# para que un compañero lo reproduzca
```

**Docker Compose** es la respuesta oficial a ese problema: un archivo YAML (`compose.yaml`) que describe el stack —servicios, redes, volúmenes, dependencias— y un CLI (`docker compose up/down/logs/ps/exec`) que lo opera.

Puntos de encuadre importantes antes de seguir:

- Compose es **declarativo con reconciliación muy limitada**. No es Kubernetes. No reprograma pods. Si tu máquina se cae, Compose no te salva.
- Compose está pensado para **una sola máquina** (tu laptop o un host de dev/CI). No orquesta varios nodos.
- Compose está pensado para **ciclos de vida cortos y manuales**: tú ejecutas `up`, tú ejecutas `down`.
- Compose comparte el modelo mental con la CLI: cada entrada en `services:` es, al final, un `docker run` con parámetros.

Dicho de otro modo: Compose es un **"docker run as code"** con dependencias, redes y perfiles.

---

## 2. `docker compose` v2 vs `docker-compose` v1: por qué importa

Durante años, Compose fue un **binario separado en Python** (`docker-compose`, con guion). En 2021 Docker reescribió Compose en Go e introdujo **Compose v2**, integrado como *plugin de la CLI* bajo el subcomando `docker compose` (sin guion).

```
docker-compose up    # v1 — DEPRECATED, en vías de desaparición
docker compose up    # v2 — plugin oficial, lo que debes usar
```

Diferencias relevantes:

| Aspecto | v1 (`docker-compose`) | v2 (`docker compose`) |
|---|---|---|
| Implementación | Python, binario separado | Go, plugin de la CLI (`docker-compose-plugin`) |
| Nombre canónico del archivo | `docker-compose.yml` | `compose.yaml` (también lee `docker-compose.yml`) |
| Versión declarada en el YAML | `version: "3.8"` obligatorio | **omítela** — es ignorada, provoca warning |
| Soporte oficial | discontinuado | activo |
| Perfiles, build con BuildKit, OCI builder | parcial | nativo |

Reglas prácticas:
- Instala Docker Engine o Docker Desktop recientes — ambos ya traen Compose v2.
- Verifica con `docker compose version`.
- Nombra tus archivos `compose.yaml` (sin `version:`).
- Si ves un README que te dice `docker-compose up`, es viejo. El comando correcto es `docker compose up`.

> **Nota operativa (validadores de este curso):** todos los scripts de este módulo usan `docker compose` (v2). Si en tu máquina solo existe `docker-compose` v1 o Compose no está instalado, los validadores saltan con un mensaje `SKIP` en vez de fallar.

---

## 3. Anatomía mínima de un `compose.yaml`

El archivo canónico vive en la raíz del proyecto y describe tres secciones principales: `services`, `networks`, `volumes`.

```yaml
# compose.yaml
services:
  api:
    build: ./app
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://postgres:dev@db:5432/postgres
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: dev
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 2s
      timeout: 3s
      retries: 10

volumes:
  pgdata:
```

Qué está pasando aquí, pieza por pieza:

- `services:` — dos servicios: `api` (construido desde `./app/Dockerfile`) y `db` (imagen pre-hecha).
- `build: ./app` — Compose invoca BuildKit para construir la imagen; es equivalente a `docker build ./app` + usar esa imagen.
- `image:` para `db` — se descarga de Docker Hub.
- `ports: "8000:8000"` — publica puerto host:container (sintaxis idéntica a `docker run -p`).
- `environment:` — variables de entorno **dentro del contenedor** (no en Compose).
- `depends_on: db: condition: service_healthy` — Compose arranca `db` primero y **espera a que su healthcheck esté `healthy`** antes de arrancar `api`.
- `healthcheck:` — Compose configura el healthcheck de Docker (`HEALTHCHECK` del Dockerfile, pero declarado desde fuera).
- `volumes: pgdata` — volumen nombrado persistente para los datos de Postgres (sobrevive a `restart`, lo borra `down -v`).

El `compose.yaml` **completo del capstone** añadirá un reverse proxy (Caddy) y perfiles para test; lo construyes paso a paso en `activities/01-full-dev-stack/`.

---

## 4. El modelo de proyecto: una network por proyecto, DNS por nombre

Cuando ejecutas `docker compose up` en un directorio, Compose:

1. Deriva el **nombre del proyecto** del nombre del directorio (p. ej. `mystack`), o del flag `-p mystack`, o de `$COMPOSE_PROJECT_NAME`.
2. Crea **una network bridge dedicada**: `mystack_default` (user-defined bridge, no la `bridge` por default de Docker).
3. Prefija recursos con el nombre del proyecto: `mystack-api-1`, `mystack-db-1`, `mystack_pgdata`.
4. Levanta los contenedores conectados a esa network.

Diagrama:

```
                host
                 |
           [docker0  bridge]
                 |
  ─────────────────────────────────
   mystack_default (bridge, dedicada al proyecto)
   ├── mystack-api-1   (hostname: api)   ─ puerto host 8000
   ├── mystack-db-1    (hostname: db)
   └── (otros servicios del proyecto)
```

Dos consecuencias **cruciales**:

### 4.1 DNS por nombre entre servicios

Dentro de la network del proyecto, cada servicio es resoluble **por el nombre que le diste en `services:`**. En el ejemplo anterior, `api` puede abrir `postgresql://postgres:dev@db:5432/...` porque `db` resuelve a la IP del contenedor `mystack-db-1`.

Esto **no** funcionaría en la bridge por default de Docker (`docker network create`-free). Compose siempre crea una user-defined bridge con DNS habilitado — por eso "simplemente funciona".

### 4.2 Aislamiento entre proyectos

Dos stacks de Compose distintos (`projectA`, `projectB`) viven en networks separadas y no se ven. Si quieres conectarlos, usas la clave `networks:` para declarar una network externa compartida — fuera del alcance de este módulo.

---

## 5. `depends_on`: la trampa del arranque vs el listo

Esta es la sección donde se concentra el 60 % de los bugs intermitentes de dev stacks. Léela despacio.

### 5.1 La forma corta: solo arranque

```yaml
services:
  api:
    depends_on:
      - db
```

Esto le dice a Compose: **"arranca `db` antes de arrancar `api`"**. Nada más.

"Antes" significa que `docker run db` se ejecuta antes que `docker run api`. **No significa que `db` esté lista para aceptar conexiones.** Postgres puede tardar 2–8 s en abrir el socket; `api` ya arrancó, intentó conectar, falló, y murió con `connection refused`. Si tu app no reintenta, el stack arranca roto.

### 5.2 La forma larga con `condition: service_healthy`

```yaml
services:
  api:
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 2s
      timeout: 3s
      retries: 10
      start_period: 5s
```

Ahora Compose:
1. Arranca `db`.
2. Ejecuta el healthcheck cada 2 s.
3. Marca a `db` como `healthy` cuando `pg_isready` sale con 0.
4. **Entonces** —y solo entonces— arranca `api`.

Las condiciones válidas son:

| Condición | Qué espera |
|---|---|
| `service_started` | que Docker haya ejecutado `run` (equivalente al corto). Default. |
| `service_healthy` | que el healthcheck esté `healthy`. **Requiere que el servicio tenga `healthcheck`.** |
| `service_completed_successfully` | que el servicio termine con exit 0 (útil para seeders, migrations). |

### 5.3 Alternativas en el lado del cliente

`depends_on: condition: service_healthy` **no es magia**: solo funciona en `up`. Si Postgres se reinicia a media sesión, Compose no re-espera a que esté sano antes de que `api` reintente. Por eso **tu app debe seguir siendo resiliente**: pool de conexiones con retry, backoff exponencial, circuit breaker. Compose arregla el arranque; no te libera de escribir código robusto.

En producción (K8s) resuelves esto con `readinessProbe` + endpoints de servicio; Compose es el análogo mínimo para dev.

---

## 6. Healthchecks: qué chequear y cómo

Un healthcheck es un comando que corre dentro del contenedor cada N segundos. Si sale con 0, el contenedor es `healthy`; con cualquier otro código, `unhealthy`. Mientras no haya corrido el primero, está `starting`.

Formato típico:

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -fsS http://localhost:8000/health || exit 1"]
  interval: 5s        # cada cuánto corre tras el start_period
  timeout: 3s         # cuánto espera a que termine un check
  retries: 5          # cuántos fallos consecutivos antes de 'unhealthy'
  start_period: 10s   # grace inicial: fallos aquí NO cuentan como retry
```

Reglas prácticas:

- Prefiere `CMD` o `CMD-SHELL`. Nunca uses `NONE` por accidente.
- El comando debe estar **presente dentro de la imagen**. Si tu imagen es distroless y no tiene `curl`, usa un endpoint TCP (`exec` con `python -c`) o invierte: expón el healthcheck como un binario en el entrypoint.
- `start_period` existe específicamente para apps lentas de arrancar (JVM, migrations). Un fallo durante `start_period` **no** incrementa el contador de retries, solo pospone el "healthy".
- Para Postgres: `pg_isready -U <user>`. Para MySQL: `mysqladmin ping`. Para HTTP: `curl -fsS <url>` o `wget -q -O- <url>`.
- No pongas healthchecks de 30 s en dev — hacen el ciclo iterativo doloroso. 2–5 s para infra conocida (Postgres), 1–2 s para tus apps.

> **Pitfall común**: `curl -fsS` sin `-f` no devuelve exit non-zero en 404 ni 500. `-f` (fail) es imprescindible, o terminas con un servicio "healthy" que devuelve `500 Internal Server Error`.

Ver el estado:

```
docker compose ps
# NAME             STATUS                   PORTS
# mystack-api-1    Up 3s (healthy)          0.0.0.0:8000->8000/tcp
# mystack-db-1     Up 10s (healthy)         5432/tcp
```

---

## 7. `profiles`: servicios opcionales en el mismo archivo

Problema: tienes un `compose.yaml` para dev y quieres meter un **test runner** o un **seeder** que no corra siempre. Las malas soluciones serían dos archivos duplicados o un script bash. La buena solución es `profiles`.

```yaml
services:
  api:
    build: ./app
    # (sin profiles → arranca siempre)

  db:
    image: postgres:16-alpine
    # (sin profiles → arranca siempre)

  tests:
    build: ./app
    command: pytest
    profiles: ["test"]
    depends_on:
      db:
        condition: service_healthy

  seeder:
    build: ./app
    command: python seed.py
    profiles: ["dev", "seed"]
    depends_on:
      db:
        condition: service_healthy
```

Comportamiento:

```
docker compose up                        # arranca api + db. tests y seeder NO.
docker compose --profile test up         # arranca api + db + tests
docker compose --profile dev up          # arranca api + db + seeder
docker compose --profile dev --profile test up   # arranca todo
```

**Regla**: un servicio **sin** `profiles` arranca siempre. Un servicio **con** `profiles` arranca solo si activas al menos uno de ellos.

Uso típico: `profiles: ["test"]` para fixtures o test runners; `profiles: ["admin"]` para pgadmin / mailhog; `profiles: ["prod-like"]` para servicios opcionales que solo se levantan al reproducir un bug.

---

## 8. Override files y `-f`: componer sin duplicar

Compose carga automáticamente `compose.override.yaml` si existe. Se **merguea** sobre `compose.yaml` (los valores del override ganan).

```
compose.yaml              # base
compose.override.yaml     # defaults locales de dev (bind mounts, puertos extra)
```

Caso típico: el `compose.yaml` base describe un stack *parecido a prod* (sin bind mounts, sin puertos extra); el `override.yaml` lo adapta a dev (bind mount del código fuente, puerto 5432 expuesto para conectar un cliente SQL).

Para composiciones explícitas:

```
docker compose -f compose.yaml -f compose.ci.yaml up    # base + overrides de CI
```

Los archivos a la derecha ganan sobre los de la izquierda. Esto permite tener un `compose.yaml` canónico y perfiles de override para `dev`, `test`, `ci`, `smoke`, sin duplicar servicios.

> **Advertencia**: el merge **no es profundo** en todas las claves. Listas (`ports`, `volumes`, `command`) se **reemplazan**, no se concatenan. Es un error frecuente creer que `ports: - "5432:5432"` en el override "añade" un puerto; en realidad **reemplaza** toda la lista `ports` del base. Consulta la especificación cuando dudes.

---

## 9. Variables de entorno: dos mundos distintos

Hay dos mundos de variables en Compose y es crítico no confundirlos.

### 9.1 Variables de interpolación (sustitución en el YAML)

Compose procesa el YAML antes de ejecutarlo y sustituye `${VAR}` con el entorno del proceso que lo invoca, incluyendo el archivo `.env` auto-cargado (ubicado junto al `compose.yaml`).

```
# .env
POSTGRES_PASSWORD=devsecret
APP_PORT=8000
```

```yaml
# compose.yaml
services:
  api:
    build: ./app
    ports:
      - "${APP_PORT:?APP_PORT is required}:8000"
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

Formas útiles:
- `${VAR}` — vacío si no existe.
- `${VAR:-default}` — usa `default` si vacía o unset.
- `${VAR:?mensaje}` — falla con `mensaje` si vacía/unset. Óptimo para forzar explicitud.

### 9.2 Variables dentro del contenedor (`environment:` / `env_file:`)

Estas se pasan al proceso del contenedor, idéntico a `docker run -e`.

```yaml
services:
  api:
    environment:
      LOG_LEVEL: debug
      DATABASE_URL: postgresql://postgres:${POSTGRES_PASSWORD}@db:5432/postgres
    env_file:
      - .env.app        # un archivo distinto, cargado dentro del contenedor
```

Pitfall: `.env` (en la raíz, auto-cargado) es para **interpolación**. Si lo quieres también adentro del contenedor, debes referenciarlo explícitamente con `env_file:`.

### 9.3 Secretos

**No pongas secretos reales en `.env` ni en `compose.yaml` versionados.** Para dev está bien usar passwords dummy (`POSTGRES_PASSWORD=dev`). Para CI y prod hay otros mecanismos (secrets de Compose, Vault, External Secrets en K8s) que se cubren más adelante.

---

## 10. Ciclo de vida: comandos que debes dominar

```
docker compose up                    # arranca en foreground (logs en pantalla)
docker compose up -d                 # arranca en background (detached)
docker compose up -d --build         # reconstruye imágenes antes de arrancar
docker compose up -d --wait          # bloquea hasta que los healthchecks pasen
docker compose up -d --wait --wait-timeout 60   # con timeout

docker compose ps                    # estado de los contenedores del proyecto
docker compose logs -f api           # tail de logs del servicio 'api'
docker compose logs --since=2m db    # últimos 2 minutos

docker compose exec api sh           # abre shell en el contenedor en vivo
docker compose run --rm api pytest   # arranca un contenedor efímero (nuevo)

docker compose restart api           # reinicia un servicio
docker compose stop                  # para todo (pero no borra)
docker compose down                  # para y elimina contenedores + network
docker compose down -v               # ... y además borra volúmenes nombrados
docker compose down -v --remove-orphans   # también borra servicios huérfanos
```

Reglas prácticas:

- Siempre `down -v` al terminar una sesión de dev si no te importa la data (test runners, fixtures). Mantener volúmenes zombies es la fuente #1 de "en mi máquina sí arranca".
- `exec` abre shell en el contenedor **existente**; `run --rm` crea uno nuevo (útil para one-shots como migrations).
- `--wait` es nuevo en Compose v2 y es el canónico para scripts y CI: bloquea hasta que *todos* los servicios con healthcheck estén `healthy` o un servicio sin healthcheck esté `started`.
- `logs -f` es tu primer paso en cualquier debugging. Si no hay logs, el contenedor no imprime (buffering de stdout en Python → `PYTHONUNBUFFERED=1`).

---

## 11. Internals: qué hace Compose debajo

Compose no reinventa nada: traduce el YAML a llamadas al **mismo Docker Engine** que ya conoces.

```
compose.yaml
     │
     ▼
docker compose (CLI plugin, Go)
     │  parsea YAML + .env, resuelve interpolación,
     │  calcula orden topológico por depends_on
     ▼
Docker Engine API (/var/run/docker.sock)
     │
     ├── docker network create <project>_default
     ├── docker volume create <project>_<volname>
     ├── docker build ... (vía BuildKit)
     ├── docker create ... (uno por servicio)
     ├── docker start ... (en el orden de depends_on)
     └── polling de healthchecks (lee `docker inspect`)
```

Qué significa esto en la práctica:

- Puedes **inspeccionar manualmente** cada recurso con `docker` directo: `docker network inspect mystack_default`, `docker volume inspect mystack_pgdata`. Compose solo es un cliente privilegiado.
- Si borras un contenedor del proyecto con `docker rm`, el siguiente `docker compose ps` lo reporta como "missing" — Compose no se entera en tiempo real, lo descubre al re-inspeccionar.
- Las labels de Compose en los recursos (`com.docker.compose.project`, `com.docker.compose.service`) son cómo Compose sabe qué le pertenece. Si editas esas labels a mano, el proyecto se te desaparece de `compose ps`.
- `depends_on` con `condition: service_healthy` es puro polling del healthcheck de Docker — no hay nada mágico, solo un bucle que lee `docker inspect <container>` y espera a que `.State.Health.Status == "healthy"`.

### 11.1 Resolución DNS entre servicios

Compose crea una user-defined bridge (`<project>_default`). Docker Engine corre un embedded DNS resolver en `127.0.0.11:53` dentro del net namespace de cada contenedor. Ese resolver conoce todos los contenedores de la misma network por su `--network-alias` (que Compose setea al nombre del servicio).

Verifica tú mismo:

```
docker compose exec api cat /etc/resolv.conf
# nameserver 127.0.0.11
# ...
docker compose exec api getent hosts db
# 172.19.0.2  db
```

---

## 12. Por qué Compose NO es un orquestador de producción

Esta es la sección de evaluación conceptual del módulo. Memorizala.

Compose fue diseñado **explícitamente para dev y CI**. No es un sustituto de Kubernetes, ECS, Nomad o similares. Las razones:

1. **Un solo host.** Compose no distribuye servicios entre nodos. Si tu laptop/host muere, el stack muere. Un orquestador tiene scheduling multi-nodo y failover.

2. **Sin self-healing real.** Compose puede `restart: unless-stopped`, pero si todo el daemon de Docker muere, no hay nada que lo levante. K8s tiene el control plane corriendo aparte y pods respawneados por el scheduler.

3. **Sin rolling updates seguros.** `docker compose up --force-recreate` tumba y recrea; no hay rolling update con readiness-gated traffic switch como en K8s Deployments.

4. **Sin service mesh / ingress serio.** Compose publica puertos en el host. No hay ingress controller, no hay TLS termination gestionada, no hay load balancer L7 cluster-wide. Puedes meter un Caddy/nginx en el stack pero sigue siendo un contenedor más en el mismo host.

5. **Sin control de recursos a nivel cluster.** Puedes poner `deploy.resources.limits` pero Compose solo los traduce a límites del contenedor; no hay bin-packing ni quotas por namespace.

6. **Sin RBAC, sin NetworkPolicy, sin PodSecurity.** Todo corre con los privilegios del daemon. En prod necesitas segmentación de red y permisos declarativos.

7. **El modelo declarativo es débil.** Compose no reconcilia continuamente. Es "ejecuta esto una vez y rezá". Un operator en K8s observa el estado deseado y actúa.

8. **El `restart:` es por contenedor, no por cluster.** `restart: always` es local al daemon; si el daemon no está, no hay restart.

### 12.1 Dónde SÍ encaja Compose

- Dev local reproducible (lo que estamos haciendo acá).
- CI effímero: `compose up`, correr tests de integración, `compose down -v`.
- Demos y PoCs single-host.
- Entornos educativos.
- Servicios muy pequeños, no críticos, en una VM — con la conciencia de que no hay HA.

### 12.2 Compose en producción: la trampa de la pereza

Es tentador meter Compose en una VM de producción para "ir rápido". Luego:
- Un reboot del host sin `restart: unless-stopped` configurado → stack caído.
- Un deploy que requiere rolling → downtime.
- Un pico de carga que requiere escalar → no se puede sin cambiar de host.
- Un fallo de disco → data loss porque no hay replicación.

Si realmente necesitas Compose en prod por restricciones de equipo o budget, al menos: usa `restart: unless-stopped`, systemd unit que haga `compose up -d` al boot, backups de volúmenes, monitoring externo, y un plan documentado para migrar. Pero sabé que estás contrayendo deuda operacional.

---

## Preguntas de evaluación

Respóndelas sin re-leer la lección. Si te atascas en alguna, vuelve a la sección correspondiente.

1. ¿Qué diferencia hay entre `depends_on: - db` y `depends_on: db: condition: service_healthy`? ¿En qué caso el stack arrancaría "roto"?
2. Un compañero dice "mi `compose.yaml` no funciona, `api` no encuentra `db`". ¿Qué red creó Compose y por qué `api` debería poder resolver `db`? ¿Qué chequearías primero?
3. ¿Por qué `docker-compose up` (con guion) y `docker compose up` (sin guion) **no** son lo mismo? ¿Cuál usas y por qué?
4. Enumera tres razones concretas por las que Compose no sustituye a Kubernetes/ECS en producción.
5. ¿Qué hace `start_period` en un healthcheck y por qué es distinto de `interval`?
6. Tienes un seeder que solo quieres correr a veces. ¿Cómo lo modelas sin duplicar `compose.yaml`?
7. ¿Qué pasa cuando ejecutas `docker compose down -v`? Mencionalo todo: contenedores, red, volúmenes nombrados, bind mounts, imágenes.
8. Diferencia entre variables en `.env` (en la raíz, auto-cargado) y variables en `env_file:` dentro de un servicio.
9. ¿Por qué `curl -s http://api/health` dentro de un healthcheck es un bug sutil? ¿Qué flag falta?
10. Un `compose.override.yaml` declara `ports: - "6543:5432"` y el `compose.yaml` base ya tenía `ports: - "5432:5432"`. ¿Qué pasa al mergear? ¿Quedan ambos puertos?
