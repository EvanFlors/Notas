# Actividad 01 — Dos contenedores hablándose por nombre

## 1. Identificación

- **ID:** `dkr-05-01-two-containers-talking-by-name`
- **Tecnología:** `docker`
- **Módulo:** `dkr-05-networking-basics`
- **Dificultad:** beginner
- **Duración estimada:** 40 min
- **Tipo:** guided-lab

## 2. Contexto

Es el patrón que verás 1000 veces: una red privada por app, una base de datos accesible por nombre desde el servicio que la consume. Si no publicas la DB al host, nadie fuera del host puede llegarle; perfecto para dev local.

## 3. Objetivos

- Crear una user-defined bridge con `docker network create`.
- Correr dos contenedores (`db` postgres, `web` nginx) en ella.
- Verificar DNS por nombre desde cada contenedor.
- Publicar `web` al host en `18085` y confirmarlo con `curl`.

## 4. Prerrequisitos

- Docker Engine o Docker Desktop corriendo (`docker info` OK).
- Puerto `18085` del host libre.
- ~100 MB de pulls (`nginx:alpine`, `postgres:16-alpine`).
- Costo: $0 (todo local).

## 5. Instrucciones

### 5.1 Bootstrap

```bash
bash courses/docker/05-networking-basics/activities/01-two-containers-talking-by-name/starter/bootstrap.sh /tmp/dkr05-act1
```

El bootstrap deja un directorio scratch `/tmp/dkr05-act1/` con notas. No pre-crea los contenedores (eso lo haces tú).

### 5.2 Crea la red y los contenedores

Objetivo: una red `dkr05-act1-net` con `db` (postgres) y `web` (nginx), y `web` publicado al host en `18085`.

Pistas (no te damos el comando completo; úsa `docker network create --help`, `docker run --help`):

- Nombre de red: **`dkr05-act1-net`** (requerido por el validador).
- Contenedores: **`db`** y **`web`** (requerido por el validador).
- Imagen para `db`: `postgres:16-alpine` con `POSTGRES_PASSWORD=demo`.
- Imagen para `web`: `nginx:alpine`.
- Publicación: `web` en `18085:80`.
- Ambos **en la misma red** `dkr05-act1-net`.

### 5.3 Verifica DNS por nombre

Desde `web`, resuelve `db`. Desde `db`, resuelve `web`. Verifica TCP:

```bash
docker exec web  getent hosts db
docker exec db   getent hosts web
docker exec web  sh -c "nc -z db 5432 && echo 'db:5432 OK'"
```

Y verifica el puerto publicado:

```bash
curl -sS -o /dev/null -w "status=%{http_code}\n" http://localhost:18085/
```

### 5.4 Valida

```bash
bash courses/docker/05-networking-basics/activities/01-two-containers-talking-by-name/tests/validate.sh
```

Debe reportar `RESULT: N/N checks OK.`.

### 5.5 Dibuja la red

En `/tmp/dkr05-act1/diagram.txt` (ya lo creó el bootstrap como placeholder), dibuja en ASCII el estado: host, red `dkr05-act1-net`, los dos contenedores, la IP interna de cada uno (sácalas con `docker network inspect`), el puerto publicado.

## 6. Resultado esperado

- Red `dkr05-act1-net` existe.
- Contenedores `db` y `web` corriendo, ambos conectados a `dkr05-act1-net`.
- `getent hosts db` desde `web` responde con una IP de la subred de `dkr05-act1-net`.
- `curl http://localhost:18085/` responde 200.
- `/tmp/dkr05-act1/diagram.txt` tiene un diagrama no trivial.

## 7. Criterios de aceptación

- [ ] Red creada con el nombre correcto.
- [ ] Contenedores con los nombres correctos y conectados a la red.
- [ ] DNS por nombre funciona en ambas direcciones.
- [ ] Puerto `18085` publicado y responde 200.

## 8. Validación

```bash
bash courses/docker/05-networking-basics/activities/01-two-containers-talking-by-name/tests/validate.sh
```

Si `docker` no está presente, el validador imprime `SKIP` y sale con 0.

## 9. Preguntas de reflexión

1. ¿Por qué el mismo experimento falla en la red default `bridge`?
2. ¿Qué contiene `/etc/resolv.conf` dentro de `web`? ¿Qué sucede si cambias la nameserver manualmente?
3. ¿Qué pasa si recreas `db` manteniendo el mismo nombre? ¿`web` sigue resolviéndolo?
4. Si publicaras también `db` con `-p 5432:5432`, ¿qué riesgo introduces en una laptop con WiFi pública?
5. ¿Para qué sirve `--network-alias`? ¿En qué se diferencia de `--name`?

## 10. Extensiones

- **E1** — Añade un tercer contenedor `cache` (redis) a la misma red y verifica DNS.
- **E2** — Conecta `web` a una segunda red `dkr05-act1-mgmt` sin desconectarlo de la primera. Observa `/etc/resolv.conf` y las dos `eth*`.
- **E3** — Usa `nicolaka/netshoot` para `tcpdump` el tráfico interno entre `web` y `db` en el bridge.

## 11. Limpieza

```bash
docker rm -f web db
docker network rm dkr05-act1-net
rm -rf /tmp/dkr05-act1
```
