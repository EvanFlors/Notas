# Ejemplo 02 — `ENTRYPOINT` vs `CMD`, shell form vs exec form

## Concepto que demuestra

Las cuatro combinaciones de `CMD` / `ENTRYPOINT` × shell / exec form, y cómo cada
una se comporta ante `docker stop` (que envía `SIGTERM`). Muestra en vivo por qué
la forma shell "pierde" las señales a PID 1.

## Contexto

El error más caro de principiante con Dockerfiles es escribir
`CMD python app.py` (shell form). Parece inocuo. Lo que ocurre es que `/bin/sh -c`
queda como PID 1 y no reenvía `SIGTERM` a tu proceso Python. Resultado: `docker stop`
espera 10 s de grace y después mata con `SIGKILL`. Shutdown abrupto, locks sin
liberar, conexiones no cerradas.

## Objetivo

Al terminar podrás:
- Decir qué recibe `SIGTERM` en cada forma.
- Diferenciar override de `CMD` vs override de `ENTRYPOINT`.
- Explicar por qué `exec python ...` en un entrypoint script rescata la señal.

## Prerrequisitos

- Docker 24+.
- `/usr/bin/time` o el `time` builtin del shell.

## Archivos del ejemplo

Están en `files/`:

```
files/
├── Dockerfile.shell-cmd
├── Dockerfile.exec-cmd
├── Dockerfile.entrypoint-shell
├── Dockerfile.entrypoint-exec
├── Dockerfile.entrypoint-script
├── signal-aware.py
└── entrypoint.sh
```

### `signal-aware.py`

Script que loguea cada señal y hace shutdown en SIGTERM:

```python
import signal, sys, time, os

def handler(signum, frame):
    name = signal.Signals(signum).name
    print(f"[{os.getpid()}] recibí {name}; shutdown ordenado.", flush=True)
    sys.exit(0)

signal.signal(signal.SIGTERM, handler)
signal.signal(signal.SIGINT, handler)

print(f"[{os.getpid()}] PID {os.getpid()}; esperando señales...", flush=True)
while True:
    time.sleep(1)
```

### Las cinco variantes

**1. `Dockerfile.shell-cmd`** — `CMD` en forma shell → `/bin/sh -c` es PID 1.

```dockerfile
FROM python:3.12-slim
COPY signal-aware.py /app.py
CMD python /app.py
```

**2. `Dockerfile.exec-cmd`** — `CMD` en forma exec → Python es PID 1.

```dockerfile
FROM python:3.12-slim
COPY signal-aware.py /app.py
CMD ["python", "/app.py"]
```

**3. `Dockerfile.entrypoint-shell`** — `ENTRYPOINT` en forma shell → mismo problema que (1).

```dockerfile
FROM python:3.12-slim
COPY signal-aware.py /app.py
ENTRYPOINT python /app.py
```

**4. `Dockerfile.entrypoint-exec`** — `ENTRYPOINT` en forma exec → correcto.

```dockerfile
FROM python:3.12-slim
COPY signal-aware.py /app.py
ENTRYPOINT ["python", "/app.py"]
```

**5. `Dockerfile.entrypoint-script`** — entrypoint shell con `exec` final → también correcto.

```dockerfile
FROM python:3.12-slim
COPY signal-aware.py /app.py
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

Donde `entrypoint.sh` es:

```sh
#!/bin/sh
# ... setup (expansión de vars, migraciones, lo que necesites) ...
exec python /app.py "$@"       # exec: reemplaza el shell; python toma PID 1
```

## Ejecución

```bash
cd /tmp
rm -rf dkr-03-ex-02 && mkdir dkr-03-ex-02 && cd dkr-03-ex-02
cp -r /path/to/examples/02-entrypoint-vs-cmd/files/. .

for v in shell-cmd exec-cmd entrypoint-shell entrypoint-exec entrypoint-script; do
  echo "=== $v ==="
  docker build -q -t "signal-demo:$v" -f "Dockerfile.$v" . >/dev/null
  docker run -d --name "sd-$v" "signal-demo:$v" >/dev/null
  sleep 1

  # Mide cuánto tarda docker stop en terminar el contenedor
  start=$(date +%s)
  docker stop "sd-$v" >/dev/null
  end=$(date +%s)
  elapsed=$((end - start))

  echo "docker stop tardó ${elapsed}s"
  echo "--- últimos logs ---"
  docker logs "sd-$v" 2>&1 | tail -5
  docker rm "sd-$v" >/dev/null
  echo
done
```

## Resultado esperado

| Variante | Tiempo de `docker stop` | Log al final |
|----------|------------------------|-------------|
| `shell-cmd` | ~10 s | sin mensaje de shutdown (fue `SIGKILL`) |
| `exec-cmd` | < 2 s | `recibí SIGTERM; shutdown ordenado.` |
| `entrypoint-shell` | ~10 s | sin mensaje |
| `entrypoint-exec` | < 2 s | `recibí SIGTERM; shutdown ordenado.` |
| `entrypoint-script` | < 2 s | `recibí SIGTERM; shutdown ordenado.` |

Los 10 segundos son la ventana de grace por default de Docker (`--time 10`) antes
de mandar `SIGKILL`.

## Interpretación

- **shell-cmd / entrypoint-shell**: `/bin/sh -c "python /app.py"`. El shell es
  PID 1. Al llegar `SIGTERM`, el shell lo ignora (comportamiento por default). Python
  es hijo y nunca ve la señal. Tras 10 s, `SIGKILL` lo mata sin ceremonia.
- **exec-cmd / entrypoint-exec**: no hay shell. Python es PID 1. Recibe `SIGTERM`
  directamente y corre su handler.
- **entrypoint-script**: hay un shell inicial, pero el `exec python ...` *reemplaza*
  al shell con python; python toma PID 1. Lo mejor de los dos mundos: lógica de
  setup en shell + señales correctas.

**Override de `CMD` vs `ENTRYPOINT`:**

```bash
# CMD se sobreescribe fácil con args del run
docker run signal-demo:exec-cmd echo hola    # ← imprime "hola" y termina
docker run signal-demo:entrypoint-exec echo hola  # ← ignora "echo hola", corre python
# Para cambiar ENTRYPOINT hace falta un flag explícito
docker run --entrypoint echo signal-demo:entrypoint-exec hola  # ← ahora sí
```

## Errores frecuentes

- **"Mi contenedor tarda 10 s en parar"** — forma shell en `CMD`/`ENTRYPOINT`. Cambia
  a exec form o pon un entrypoint script con `exec`.
- **"Necesito `$VAR` en el `CMD`"** — exec form no expande vars. Opciones: (a)
  entrypoint script con `exec`; (b) `CMD ["sh", "-c", "python app.py --port $PORT"]`
  (pero vuelves al problema de señales a menos que uses `exec` dentro).
- **`docker run myimg bash` no abre bash si hay `ENTRYPOINT`** — el `bash` se
  concatena como arg al entrypoint. Usa `--entrypoint bash`.

## Relación con escenarios reales

- Un servicio HTTP sin shutdown ordenado deja conexiones TCP a medio cerrar y
  requests en vuelo rotos durante rolling updates.
- Una app que corre migraciones de DB sin shutdown ordenado puede dejar la DB en
  estado inconsistente.
- Es por esto que Kubernetes envía `SIGTERM` al pod y espera
  `terminationGracePeriodSeconds`; si tu PID 1 no la recibe, pierdes toda la ventana.

Alternativa útil: `docker run --init <image>` inyecta `tini` como PID 1, que
reenvía señales. Útil cuando no controlas el Dockerfile.

## Limpieza

```bash
for v in shell-cmd exec-cmd entrypoint-shell entrypoint-exec entrypoint-script; do
  docker rm -f "sd-$v" 2>/dev/null || true
  docker rmi "signal-demo:$v" 2>/dev/null || true
done
rm -rf /tmp/dkr-03-ex-02
```
