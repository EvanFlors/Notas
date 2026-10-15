# Ejemplo 02 — PID 1 y señales (la trampa del `sh -c`)

## Concepto que demuestra

Cómo `SIGTERM` llega (o no llega) a tu proceso dentro del contenedor, por qué `docker stop` a veces tarda **exactamente** 10 segundos, y qué resuelve el flag `--init`.

## Contexto

En Linux, el **PID 1** tiene semánticas especiales: ignora señales sin handler explícito y es el "reaper" de huérfanos. En un contenedor, PID 1 es tu entrypoint. Si tu entrypoint es `/bin/sh -c "..."`, el shell es PID 1 y por default **no reenvía señales a sus hijos**. Resultado típico: tu app no se entera del shutdown.

## Objetivo

Al terminar sabrás:

- Reproducir el bug "mi app ignora SIGTERM" en < 30 s.
- Compararlo con la forma `exec` (tu app como PID 1 directo).
- Usar `--init` como arreglo universal (`tini` como PID 1).
- Observar reaping de zombies.

## Prerrequisitos

- Docker instalado y daemon arriba.
- Imagen `alpine` (se bajará sola la primera vez).
- `time` disponible en el shell.

## Ejecución

### Demo A — forma shell (mala): `sh -c` como PID 1

```bash
docker rm -f sig-bad >/dev/null 2>&1 || true

# `sh -c "sleep 1000"` → sh es PID 1, sleep es hijo. sh NO reenvía señales.
docker run -d --name sig-bad alpine sh -c "sleep 1000"

# Confirmemos quién es PID 1 dentro.
docker exec sig-bad ps -ef
#   PID 1: /bin/sh -c "sleep 1000"
#   PID 7 (aprox): sleep 1000

# Pedimos stop. docker manda SIGTERM a PID 1 (sh). sh lo ignora.
# A los 10 s manda SIGKILL. Mide el tiempo:
time docker stop sig-bad
#   Esperable: ~10.x s
#   El exit code del contenedor será 137 (= 128 + 9, señal SIGKILL).

docker inspect --format '{{.State.ExitCode}}' sig-bad   # 137

docker rm sig-bad
```

### Demo B — forma exec (buena): tu binario como PID 1

```bash
docker rm -f sig-good >/dev/null 2>&1 || true

# Sin sh en el medio: `sleep` ES PID 1, y sleep SÍ sale ante SIGTERM.
docker run -d --name sig-good alpine sleep 1000

docker exec sig-good ps -ef
#   PID 1: sleep 1000

time docker stop sig-good
#   Esperable: < 1 s.
#   Exit code: 0 si sleep manejó la señal; en versiones recientes de busybox
#   sleep suele devolver 143 (= 128 + 15, SIGTERM). Ambos son "limpio".

docker inspect --format '{{.State.ExitCode}}' sig-good

docker rm sig-good
```

### Demo C — forma shell + `--init` (arreglo universal)

```bash
docker rm -f sig-init >/dev/null 2>&1 || true

# --init inyecta `tini` como PID 1. tini reenvía señales a su único hijo
# (nuestro sh), que a su vez... sigue sin reenviar a sleep.
# Pero tini ADEMÁS maneja SIGTERM: tras pasarlo a sh, si sh no muere en el
# grace, mata el PID namespace completo. En la práctica: cierre rápido y limpio.
docker run -d --init --name sig-init alpine sh -c "sleep 1000"

docker exec sig-init ps -ef
#   PID 1: /sbin/docker-init -- sh -c "sleep 1000"   (tini)
#   PID 7 (aprox): /bin/sh -c "sleep 1000"
#   PID 8: sleep 1000

time docker stop sig-init
#   Mucho más rápido que la Demo A (típicamente < 2 s).

docker rm sig-init
```

### Demo D — reaping de zombies

```bash
docker rm -f zombies >/dev/null 2>&1 || true

# Lanzamos un "mal padre": arranca hijos y no hace wait().
# Script hecho con sh: cada "sleep 1 &" se vuelve huérfano cuando termina
# si el padre no está haciendo wait. Como sh ES PID 1, nadie los recolecta.
docker run -d --name zombies alpine sh -c '
  for i in $(seq 1 20); do (sleep 0.2; exit 0) & done
  sleep 60
'

sleep 2

# Buscamos zombies dentro del contenedor.
docker exec zombies sh -c 'ps -ef | awk "{print \$2, \$8}" | head'
docker exec zombies sh -c 'ps -eo pid,stat,comm | grep "^.* Z"'
#   Deberías ver procesos con STAT "Z" (zombie).

docker rm -f zombies

# Mismo escenario con --init: tini hace wait() y no quedan zombies.
docker run -d --init --name zombies-ok alpine sh -c '
  for i in $(seq 1 20); do (sleep 0.2; exit 0) & done
  sleep 60
'
sleep 2
docker exec zombies-ok sh -c 'ps -eo pid,stat,comm | grep "^.* Z" || echo "sin zombies"'

docker rm -f zombies-ok
```

## Resultado esperado

- Demo A: `docker stop` tarda ~10 s, exit code 137.
- Demo B: `docker stop` < 1 s, exit code 0 o 143.
- Demo C: `docker stop` rápido; `ps -ef` muestra `docker-init` (tini) como PID 1.
- Demo D (sin init): varios procesos con STAT `Z`; con `--init`, ninguno.

## Limpieza

```bash
docker rm -f sig-bad sig-good sig-init zombies zombies-ok >/dev/null 2>&1 || true
```

## Preguntas de reflexión

1. ¿Por qué `sh -c "sleep 1000"` ignora SIGTERM aunque `sleep` por separado no lo haga?
2. ¿Qué pasaría si tu `CMD` en Dockerfile fuera `CMD python app.py` (forma shell) y tu app sí maneja SIGTERM pero el shell no reenvía? ¿Importa el handler de la app?
3. ¿`--init` sustituye la responsabilidad de la app de manejar SIGTERM? ¿O son cosas complementarias?
4. ¿Qué consecuencias prácticas tiene que un contenedor acumule zombies durante horas?
