# dkr-02-02 — ¿Por qué sale mi contenedor? (debug guiado)

## 1. Identificación

- **ID:** `dkr-02-02-why-is-my-container-exiting`
- **Tecnología:** docker
- **Módulo:** `02-install-engine-and-first-container`
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** debug

## 2. Contexto

"Mi contenedor sale inmediatamente" es el bug #1 de la vida de todo el mundo con Docker. Hay cuatro o cinco causas estructurales y, una vez las conoces, el diagnóstico es rápido:

- El proceso terminó bien (exit 0) porque **ya hizo su trabajo**.
- El proceso terminó mal (exit != 0) por error de configuración o comando mal escrito.
- El contenedor no tiene **TTY** y el proceso lo exige (shells sin stdin).
- Hay un restart loop que esconde el síntoma.

Esta actividad te hace diagnosticar **tres** contenedores con causas distintas. Debes identificar la causa y aplicar el **arreglo mínimo** (una sola línea del comando `run` cambia en cada caso).

## 3. Objetivos

- Clasificar la causa de un `Exited (...)` leyendo `docker logs` y `docker inspect`.
- Interpretar `State.ExitCode` (`0`, `1`, `127`, `137`, `143`).
- Aplicar el arreglo correcto en el comando `run` sin tocar la imagen.
- Automatizar el diagnóstico con `--format` queries.

## 4. Prerrequisitos

- Docker ≥ 20.10, daemon arriba.
- `bash`, `awk`.
- Puerto 8081 libre (lo usará el caso 3 arreglado, aunque no lo verificamos).
- Sin costo.

## 5. Instrucciones

Trabaja en `/tmp/dkr-02-02/`. Primero reproduce los tres casos rotos:

```bash
mkdir -p /tmp/dkr-02-02 && cd /tmp/dkr-02-02

docker rm -f case-1 case-2 case-3 fix-1 fix-2 fix-3 >/dev/null 2>&1 || true

# --- CASE 1: parece que no arranca ---
docker run --name case-1 alpine echo "hola mundo"

# --- CASE 2: comando "no existe" (typo) ---
docker run --name case-2 alpine sh -c "exit 2"

# --- CASE 3: shell interactiva sin TTY ---
docker run --name case-3 alpine sh
```

Observa:

```bash
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Command}}'
docker inspect --format '{{.Name}} exit={{.State.ExitCode}} status={{.State.Status}}' case-1 case-2 case-3
docker logs case-1
docker logs case-2
docker logs case-3
```

### Diagnóstico y arreglo

Para **cada** caso, debes:

1. Determinar la causa (sin preguntar).
2. Lanzar un nuevo contenedor llamado `fix-N` que **demuestre el arreglo**, usando la misma imagen (`alpine`) y, cuando aplique, el mismo comando "en espíritu".

El validador verifica el estado final:

| Caso | Nombre esperado | Estado esperado | Pista del arreglo |
|------|-----------------|-----------------|--------------------|
| 1    | `fix-1`         | **running** (keep-alive)     | el contenedor sale porque el comando terminó; dale un comando que no termine (por ejemplo `sleep 300`). Debe aparecer en `docker ps`. |
| 2    | `fix-2`         | exited con **ExitCode = 0**  | la causa fue un exit != 0 explícito; lanza algo que termine limpio. |
| 3    | `fix-3`         | **running**                  | la causa fue "shell sin stdin"; dale TTY y stdin con `-it -d` **o** usa un comando no-interactivo que no termine. |

Reglas del arreglo:

- Usa siempre `alpine` como imagen.
- Para `fix-1` y `fix-3` que deben quedar corriendo, usa `-d` y, si quieres, `--rm` NO (el validador necesita verlo).
- No uses `restart: always` para "falsear" un estado running: el validador comprueba `State.Status = running` directamente.

### Entregable escrito

En `/tmp/dkr-02-02/diagnostico.md`, escribe:

```markdown
# Diagnóstico

## case-1
- Causa:
- Evidencia (campo de inspect o línea de logs):
- Arreglo aplicado en fix-1:

## case-2
- Causa:
- Evidencia:
- Arreglo aplicado en fix-2:

## case-3
- Causa:
- Evidencia:
- Arreglo aplicado en fix-3:
```

### Validar

```bash
bash courses/docker/02-install-engine-and-first-container/activities/02-why-is-my-container-exiting/tests/validate.sh
```

## 6. Resultado esperado

- `case-1`, `case-2`, `case-3` existen (status `exited`).
- `fix-1` y `fix-3` están `running`.
- `fix-2` está `exited` con `ExitCode = 0`.
- `/tmp/dkr-02-02/diagnostico.md` existe y menciona los tres casos.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- No usas `--restart` para forzar un "running" falso.
- Las causas en `diagnostico.md` son coherentes con lo que de verdad pasó.

## 8. Validación

```bash
bash courses/docker/02-install-engine-and-first-container/activities/02-why-is-my-container-exiting/tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Qué significa `ExitCode = 137` y `ExitCode = 143`? ¿Qué los produce?
2. En `case-3`, ¿por qué `sh` sin TTY sale inmediatamente? ¿Qué espera un shell de su stdin?
3. Si pusieras `--restart always` sobre `case-2`, ¿qué verías en `docker ps` y en los logs del daemon?
4. ¿Cómo distinguirías "mi app crasheó al inicio" de "mi app terminó porque hizo su trabajo" solo con `docker inspect` y `docker logs`?

## 10. Extensiones

- Arranca `nginx:alpine` como PID 1 con `/bin/sh -c "nginx -g 'daemon off;'"`. Mide cuánto tarda `docker stop`. Fija la forma exec y vuelve a medir.
- Simula una app que escribe en `/log.txt` dentro del contenedor y nada a stdout. ¿Qué muestra `docker logs`? Arregla redirigiendo a `/dev/stdout`.

## 11. Limpieza

```bash
docker rm -f case-1 case-2 case-3 fix-1 fix-2 fix-3 >/dev/null 2>&1 || true
rm -rf /tmp/dkr-02-02
```
