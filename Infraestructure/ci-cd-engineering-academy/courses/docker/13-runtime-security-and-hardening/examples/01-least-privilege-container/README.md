# Ejemplo 01 — Contenedor con mínimo privilegio

## Concepto que demuestra

El patrón productivo completo: una imagen con `USER` no-root + un `docker run` con los seis controles de hardening (read-only FS, cap-drop ALL, no-new-privileges, memory, pids-limit, cpus). Ves qué comprueba cada flag ejecutando los `docker inspect` y los experimentos de "romperlo a propósito".

## Contexto

Es la receta objetivo de la lección (§12.4) aplicada a un servidor HTTP mínimo escrito en Python. Deliberadamente usamos `python:3.12-slim` y no distroless para que puedas abrir shell y romper cosas; en producción real cambiarías a distroless (ver `dkr-11`).

## Objetivo

Al terminar, podrás responder:

- ¿Por qué `--cap-drop=ALL` solo no basta sin `USER` no-root?
- ¿Qué pasa exactamente si quitas `--read-only`? ¿Y si quitas `--pids-limit`?
- ¿Dónde ve `docker inspect` cada uno de los seis controles?

## Prerrequisitos

- Docker funcional (`docker info` sin errores).
- No requiere Trivy, red externa, ni root en el host.

## Archivos del ejemplo

Están en `files/`:

- `files/Dockerfile` — imagen hardened.
- `files/app.py` — servidor HTTP minimal (sin dependencias externas: usa `http.server`).
- `files/run-hardened.sh` — `docker run` con los seis controles.
- `files/run-insecure.sh` — contra-ejemplo con defaults.
- `files/verify.sh` — reporta por qué cada flag importa.

## Walkthrough: el Dockerfile

```dockerfile
FROM python:3.12-slim AS runtime

RUN groupadd --system --gid 10001 app \
 && useradd  --system --uid 10001 --gid 10001 --no-create-home --shell /sbin/nologin app

WORKDIR /app
COPY --chown=app:app app.py /app/app.py

USER 10001:10001
EXPOSE 8000
ENTRYPOINT ["python", "-u", "/app/app.py"]
```

- `USER 10001:10001` — numérico para compatibilidad con `runAsNonRoot` de Kubernetes.
- `--chown=app:app` en el `COPY` evita una capa extra con `chown -R`.
- Puerto 8000 (no < 1024) para no necesitar `CAP_NET_BIND_SERVICE`.

## Walkthrough: el `docker run` hardened

```bash
docker run -d \
  --name dkr13-ex01-hardened \
  --user 10001:10001 \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  --cap-drop=ALL \
  --security-opt no-new-privileges:true \
  --memory=128m \
  --memory-swap=128m \
  --pids-limit=50 \
  --cpus=0.5 \
  --restart=on-failure:3 \
  -p 127.0.0.1:8000:8000 \
  dkr13-ex01:hardened
```

Flag por flag:

| Flag | Qué comprueba |
|------|---------------|
| `--user 10001:10001` | Refuerzo del `USER` del Dockerfile. Doble candado. |
| `--read-only` | FS raíz inmutable. Toda escritura falla con EROFS. |
| `--tmpfs /tmp:rw,noexec,nosuid,size=16m` | Permite `/tmp` escribible pero sin ejecución ni setuid. |
| `--cap-drop=ALL` | Elimina las ~14 capabilities por default. |
| `--security-opt no-new-privileges:true` | Setea `PR_SET_NO_NEW_PRIVS`. Bloquea escalada por setuid. |
| `--memory=128m` | OOM kill si pasa 128 MB. |
| `--memory-swap=128m` igual a `--memory` | Sin swap. |
| `--pids-limit=50` | Previene fork bombs. |
| `--cpus=0.5` | Techo de medio core. |
| `-p 127.0.0.1:8000:8000` | Expone sólo a loopback del host. |

## Ejecución

```bash
# Clonar los archivos del ejemplo a /tmp (sin tocar el repo)
mkdir -p /tmp/dkr13-ex01
cp courses/docker/13-runtime-security-and-hardening/examples/01-least-privilege-container/files/* /tmp/dkr13-ex01/
cd /tmp/dkr13-ex01

# Build
docker build -t dkr13-ex01:hardened .

# Run hardened
bash run-hardened.sh

# Verificar
bash verify.sh

# Probar HTTP
curl -s http://127.0.0.1:8000/
```

## Resultado esperado

`verify.sh` imprime, para el contenedor `dkr13-ex01-hardened`, algo como:

```
== Config del contenedor dkr13-ex01-hardened ==
  Config.User:               10001:10001
  HostConfig.ReadonlyRootfs: true
  HostConfig.CapDrop:        [ALL]
  HostConfig.CapAdd:         []
  HostConfig.SecurityOpt:    [no-new-privileges:true]
  HostConfig.Memory (bytes): 134217728   (= 128 MiB)
  HostConfig.PidsLimit:      50
  HostConfig.NanoCpus:       500000000   (= 0.5 CPU)

== Chequeos desde adentro ==
  id:        uid=10001 gid=10001 groups=10001
  NoNewPrivs:1  (/proc/self/status)
  Seccomp:   2  (filter mode active)

== Test de que read-only funciona ==
  touch /etc/foo -> OK: 'Read-only file system' (EROFS) tal como esperado
```

Y `curl` responde HTTP 200.

## Experimentos "rompe cosas a propósito"

### Experimento 1: quita `--read-only`

```bash
docker rm -f dkr13-ex01-hardened
docker run -d --name dkr13-ex01-insecure \
  --user 10001:10001 --cap-drop=ALL \
  --security-opt no-new-privileges:true \
  -p 127.0.0.1:8000:8000 dkr13-ex01:hardened
docker exec dkr13-ex01-insecure sh -c 'touch /etc/evil 2>&1 || echo "bloqueado"'
# Esperado: NO bloqueado (crea el archivo). Esto demuestra que --read-only es necesario.
```

### Experimento 2: pon `--privileged`

```bash
docker run --rm --privileged alpine sh -c 'capsh --print | head -2'
# Current: =ep (todas las capabilities)
# vs:
docker run --rm --cap-drop=ALL alpine sh -c 'capsh --print | head -2'
# Current: =
```

### Experimento 3: fork bomb vs `--pids-limit`

```bash
docker run --rm --pids-limit=20 alpine sh -c ':(){ :|:& };:' 2>&1 | tail -3
# "fork: Resource temporarily unavailable" — bloqueado por pids-limit.
# Sin --pids-limit podría agotar PIDs del host.
```

## Errores frecuentes

- **`EACCES` al leer archivos de la app**: olvidaste `--chown=app:app` en el `COPY`. Los archivos quedaron como root y el UID 10001 no puede leerlos.
- **La app falla al escribir `/tmp/<cosa>`**: `--read-only` sin `--tmpfs /tmp`. Añade `--tmpfs`.
- **`permission denied` al bind a `:80`**: no-root no puede. Mueve al 8000 o añade `--cap-add=NET_BIND_SERVICE` (sólo si realmente necesitas :80 adentro).

## Relación con escenarios reales

Esta receta es exactamente la base line que un operador productivo debe exigir. En Kubernetes se traduce a:

```yaml
spec:
  containers:
  - name: app
    image: dkr13-ex01:hardened
    securityContext:
      runAsUser: 10001
      runAsNonRoot: true
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
    resources:
      limits:
        memory: 128Mi
        cpu: 500m
```

## Limpieza

```bash
docker rm -f dkr13-ex01-hardened dkr13-ex01-insecure 2>/dev/null || true
docker rmi dkr13-ex01:hardened 2>/dev/null || true
rm -rf /tmp/dkr13-ex01
```
