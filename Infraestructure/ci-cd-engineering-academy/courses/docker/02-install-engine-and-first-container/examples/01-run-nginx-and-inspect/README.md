# Ejemplo 01 — Correr nginx y hacer inspect

## Concepto que demuestra

Ciclo de vida completo de un contenedor: `run → ps → logs → exec → inspect → stop → rm`, con comentarios sobre qué pide la CLI al daemon en cada paso y qué campos de `docker inspect` miran los profesionales.

## Contexto

Primer contenedor "de verdad". No construimos imagen; usamos `nginx:alpine` (chico, rápido, con un entrypoint que loguea a stdout).

## Objetivo

Al terminar sabrás:

- Qué muestra `docker ps` y qué no.
- Qué significa cada estado en `docker inspect .State`.
- Cómo diferenciar `logs` (stdout de PID 1) de `exec` (proceso adicional).
- Cómo extraer un campo concreto de `inspect` con `--format` y con `jq`.

## Prerrequisitos

- Docker instalado y daemon arriba (`docker version` muestra Client **y** Server).
- Puerto 8080 libre en el host (`lsof -iTCP:8080 -sTCP:LISTEN` sin resultados).
- `curl` y, opcionalmente, `jq`.

## Ejecución

Copia-pega bloque a bloque. **Lee la salida antes de pasar al siguiente.**

```bash
# 0. Entorno limpio.
docker rm -f web >/dev/null 2>&1 || true

# 1. RUN: arranca nginx en background, nombre humano, publica puerto.
docker run -d --name web -p 8080:80 nginx:alpine
#   Lo que pasó por debajo:
#     - CLI → POST /containers/create (daemon arma config OCI).
#     - daemon → containerd → runc create (crea namespaces, monta overlayfs).
#     - CLI → POST /containers/<id>/start → runc start (ejecuta entrypoint).
#     - Imprime el ID largo del contenedor.

# 2. PS: lista contenedores vivos.
docker ps
#   STATUS "Up X seconds" y PORTS "0.0.0.0:8080->80/tcp".
#   docker ps consulta al daemon; si el daemon está caído, ESTO FALLA.

docker ps -a | head
#   Igual + los exited. "-a" = all.

# 3. Probar el servicio.
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080
#   Debería imprimir "HTTP 200".

# 4. LOGS: stdout/stderr del PID 1 del contenedor.
docker logs web | tail -5
#   nginx loguea el access log a stdout. "logs" lee los archivos del
#   logging driver (json-file por default), NO llama al proceso.

docker logs --since 1m --follow web &
LOGS_PID=$!
curl -s http://localhost:8080 >/dev/null
curl -s http://localhost:8080/no-existe >/dev/null
sleep 1
kill "$LOGS_PID"

# 5. EXEC: proceso ADICIONAL dentro de los namespaces del contenedor.
docker exec web nginx -v
#   nginx -v arranca otro proceso dentro; comparte PID/MNT/NET namespaces.
docker exec web ps -ef
#   Verás nginx: master como PID 1, workers como hijos, y tu "ps -ef"
#   también apareciendo como proceso efímero.

# 6. INSPECT: TODO el estado del contenedor desde el daemon.
docker inspect web | head -40

#   Campos clave (practica cada uno):
docker inspect --format '{{.State.Status}}'                    web   # running
docker inspect --format '{{.State.Pid}}'                       web   # PID en el host
docker inspect --format '{{.Config.Entrypoint}}'               web   # ["/docker-entrypoint.sh"]
docker inspect --format '{{.Config.Cmd}}'                      web   # ["nginx","-g","daemon off;"]
docker inspect --format '{{.HostConfig.RestartPolicy.Name}}'   web   # "no"
docker inspect --format '{{.NetworkSettings.IPAddress}}'       web   # IP interna
docker inspect --format '{{json .NetworkSettings.Ports}}'      web   # mapping de puertos
docker inspect --format '{{.GraphDriver.Name}}'                web   # overlay2 (típicamente)
docker inspect --format '{{json .Mounts}}'                     web   # [] si no hay volúmenes

# PID real del master nginx en el HOST (no es cero: namespaces de PID aíslan la numeración interna).
PID=$(docker inspect --format '{{.State.Pid}}' web)
echo "nginx master en el host es PID $PID; dentro del contenedor es PID 1."

# 7. STOP: SIGTERM a PID 1, grace de 10 s, luego SIGKILL si no sale.
time docker stop web
#   Debería tardar < 1 s: nginx maneja SIGTERM y cierra limpio.

# 8. STATUS tras stop: existe pero exited.
docker ps -a | grep web
docker inspect --format '{{.State.Status}} exit={{.State.ExitCode}}' web

# 9. RM: elimina el contenedor del daemon (metadata + layer superior).
docker rm web
docker ps -a | grep web || echo "ya no está"
```

## Resultado esperado

- `docker ps` muestra `web` como `Up ... seconds` con mapping `0.0.0.0:8080->80/tcp`.
- `curl http://localhost:8080` devuelve HTTP 200.
- `docker logs web` muestra líneas de access log.
- `docker exec web ps -ef` muestra nginx como PID 1 dentro del contenedor.
- `docker inspect` responde a cada `--format` sin error.
- `docker stop web` termina en menos de 2 s.
- Tras `docker rm web`, el contenedor desaparece de `docker ps -a`.

## Limpieza

```bash
docker rm -f web >/dev/null 2>&1 || true
```

## Preguntas de reflexión

1. Si corres el bloque sin `--rm` y después haces `docker stop web`, ¿el contenedor sigue consumiendo recursos? ¿Qué sigue existiendo exactamente?
2. ¿Por qué `docker exec web ps -ef` incluye el propio `ps`? ¿Qué pasaría si lo corres en modo interactivo (`-it`)?
3. `docker logs web` sigue funcionando aun después de `docker stop web` (mientras el contenedor exista). ¿Por qué?
4. Si cambias `-p 8080:80` por `-p 80:80` sin privilegios, ¿qué falla y por qué?
