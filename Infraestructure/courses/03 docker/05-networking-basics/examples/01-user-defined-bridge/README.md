# Ejemplo 01 — User-defined bridge con DNS entre contenedores

## Concepto que demuestra

Dos contenedores en una **user-defined bridge** se resuelven **por nombre** (no hace falta IP). La bridge default **no** hace esto.

## Contexto

Es el patrón canónico para app + DB en un host: una network aislada, nombres estables, cero IPs hardcodeadas.

## Objetivo

Al terminar sabrás:

- Crear una red `bridge` propia (`docker network create`).
- Correr dos contenedores en ella y verificar DNS con `getent hosts` / `nslookup`.
- Entender por qué el mismo experimento falla en la red default.

## Prerrequisitos

- Docker instalado y corriendo (`docker info` OK).
- ~100 MB de ancho de banda para pulls (`alpine`, `nginx:alpine`).
- Puertos del host **no** son necesarios (todo es tráfico interno).

## Archivo del ejemplo

`files/run-demo.sh`. Léelo primero; después lo corres.

## Ejecución

```bash
bash courses/docker/05-networking-basics/examples/01-user-defined-bridge/files/run-demo.sh
```

El script:

1. Crea la red `dkr05-demo-net`.
2. Levanta `web` (nginx) y `client` (alpine durmiendo) en esa red.
3. Desde `client`, resuelve `web` por nombre y hace `wget` a `http://web:80/`.
4. Repite el mismo experimento en la red default y muestra que **falla por nombre**.
5. Limpia todo.

## Resultado esperado

```
== user-defined bridge ==
PING web ... bytes from 172.x.y.z
HTTP/1.1 200 OK

== default bridge ==
nslookup: can't resolve 'web2'
```

## Interpretación

- En `dkr05-demo-net`, `/etc/resolv.conf` del contenedor apunta a `127.0.0.11` — el resolver embebido de Docker. Ese resolver conoce los nombres de contenedores conectados.
- En la bridge default no hay resolver por nombre; para hablar hay que usar IP (o `--link`, deprecated).

## Errores frecuentes

- **"name resolution failed"** al no especificar `--network`: te caíste a la bridge default.
- **"network has active endpoints"** al borrar: aún hay contenedores conectados; mátalos primero.

## Nota macOS/Windows

Idéntico comportamiento: Docker Desktop corre una VM Linux donde todo lo descrito ocurre.

## Limpieza

El script limpia automáticamente. Si algo quedó colgado:

```bash
docker rm -f web client web2 client2 2>/dev/null
docker network rm dkr05-demo-net 2>/dev/null
```
