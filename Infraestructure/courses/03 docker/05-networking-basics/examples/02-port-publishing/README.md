# Ejemplo 02 — `-p 8080:80` vs `--network host`

## Concepto que demuestra

Dos formas opuestas de hacer accesible un servicio: **publicar un puerto** (NAT, puerto distinto en host y contenedor) o **compartir la pila de red del host** (sin NAT, sin aislamiento).

## Contexto

Entender el trade-off entre aislamiento y simplicidad. En Docker Desktop (macOS/Windows), `--network host` tiene semántica distinta (expone a la VM Linux, no al Mac).

## Objetivo

- Publicar un puerto con `-p` y verificar con `curl` desde el host.
- Comparar con `--network host` (solo Linux de forma literal; en Mac/Win verás la limitación).
- Reproducir el error de "port is already allocated".

## Prerrequisitos

- Docker. Puerto `18080` del host **libre**.
- `curl` instalado.

## Archivo del ejemplo

`files/run-demo.sh`.

## Ejecución

```bash
bash courses/docker/05-networking-basics/examples/02-port-publishing/files/run-demo.sh
```

El script:

1. `docker run -d -p 18080:80 nginx:alpine` → `curl http://localhost:18080` → 200.
2. Intenta levantar un segundo contenedor con el mismo `-p 18080:80` → error de puerto ocupado.
3. En **Linux**, levanta uno con `--network host` escuchando en `18090`; muestra que `curl http://localhost:18090` funciona sin `-p`. En **macOS/Windows**, el script lo detecta y lo omite con `SKIP`.

## Resultado esperado

```
== -p 18080:80 ==
HTTP/1.1 200 OK
Server: nginx/...

== segundo -p 18080:80 ==
docker: Error response from daemon: ... port is already allocated.
(esperado)

== --network host ==
(Linux)  HTTP/1.1 200 OK
(macOS)  SKIP: --network host en Docker Desktop no expone al Mac.
```

## Interpretación

- Con `-p`, Docker inserta DNAT en `iptables` (cadena `DOCKER`, tabla `nat`). El contenedor sigue en su propio net namespace.
- Con `--network host`, no hay namespace nuevo: el `nginx` del contenedor es, para la pila de red, un proceso más del host.
- En Mac/Windows, el "host" para `--network host` es la **VM Linux** que Docker Desktop esconde; por eso `localhost` del Mac no lo ve. Usa `-p` siempre.

## Errores frecuentes

- **`bind: address already in use`** — otro proceso (incluido otro contenedor) ya ocupa el puerto del host.
- **Esperar que `--network host` publique en Mac/Windows** — no lo hará.
- **App que escucha en `127.0.0.1`** dentro del contenedor — ninguna cantidad de `-p` lo arregla; debe escuchar en `0.0.0.0`.

## Limpieza

El script limpia solo. Manual:

```bash
docker rm -f pub1 pub2 hostnet 2>/dev/null
```
