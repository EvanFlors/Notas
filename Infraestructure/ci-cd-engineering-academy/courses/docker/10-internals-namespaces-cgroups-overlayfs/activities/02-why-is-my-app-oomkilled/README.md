# Actividad 02 — ¿Por qué me matan a `OOMKilled`?

## 1. Identificación

- **ID:** `dkr-10-02-why-is-my-app-oomkilled`
- **Tecnología:** `docker`
- **Módulo:** `dkr-10-internals-namespaces-cgroups-overlayfs`
- **Dificultad:** advanced
- **Duración estimada:** 30–50 min
- **Tipo:** independent (debug)

## 2. Contexto

Tu "app" (un proceso que asigna memoria) muere al arrancar dentro del contenedor. El host tiene 32 GB libres. Tu monitoring dice "exit code 137". Tienes que explicar **por qué** termina y **dónde** se ve en el kernel.

Es un escenario común en producción: alguien pone `--memory=128m` "por si acaso", la app crece de verdad bajo carga, y empieza a reiniciarse en loop sin logs claros.

Esta actividad es **independiente**: no leas la solución hasta terminar. El validator decide si está bien.

## 3. Objetivos

- Reproducir el OOMKill a propósito en un contenedor.
- Identificar el OOMKill desde la CLI de Docker (`docker inspect`).
- Correlacionarlo con el OOM-killer del cgroup (`memory.events`).
- Explicar por qué `exit code = 137` y qué señal es.
- Escribir un `root-cause.md` con 3–5 bullets.

## 4. Prerrequisitos

- Linux + Docker Engine (en macOS/Windows: VM Ubuntu con `multipass launch`).
- cgroups v2 (`stat -fc %T /sys/fs/cgroup` → `cgroup2fs`).
- `jq` recomendado (para parsear `docker inspect`).
- Costos: ninguno.

## 5. Instrucciones

### 5.1 Reproducir el bug (starter)

El starter trae un script que lanza el contenedor "roto":

```bash
bash starter/run-broken.sh
```

Esto corre `polinux/stress` dentro de un contenedor con `--memory=64m`
intentando asignar `--vm-bytes=128M`. El contenedor se llamará `oom-victim`.
El script termina rápido; **el contenedor queda detenido**.

> Si no tienes conexión a `docker.io/polinux/stress`, usa el fallback:
> `bash starter/run-broken.sh --fallback` (construye un contenedor que corre `tail /dev/zero`).

### 5.2 Investigar

Tienes que responder, en `/tmp/oom-investigation/root-cause.md`:

1. ¿Cuál es el `ExitCode` del contenedor según `docker inspect`?
2. ¿Qué valor tiene `State.OOMKilled`?
3. ¿Qué número de señal POSIX corresponde a ese exit code? (regla: `128 + N`)
4. En `/sys/fs/cgroup/system.slice/docker-<ID>.scope/memory.events`,
   ¿qué contador se incrementó?
5. ¿Qué cambiarías para evitarlo? (una línea).

El validator busca:

- Un archivo `/tmp/oom-investigation/root-cause.md` que contenga las frases clave:
  `ExitCode 137`, `SIGKILL`, `OOMKilled`, `memory.max` y `oom_kill`.
- Un volcado de `docker inspect` del contenedor en `/tmp/oom-investigation/inspect.json`.

### 5.3 Pistas (ordenadas de menor a mayor)

<details><summary>Pista 1 — por dónde empezar</summary>

```bash
docker ps -a --filter name=oom-victim
docker inspect oom-victim --format '{{.State.ExitCode}} {{.State.OOMKilled}}'
```

</details>

<details><summary>Pista 2 — mapear exit code a señal</summary>

Convención POSIX: cuando un proceso muere por señal `N`, el shell reporta
`128 + N`. 137 = 128 + 9. La señal 9 es `SIGKILL`. ¿Quién manda ese `SIGKILL`?

</details>

<details><summary>Pista 3 — dónde vive el cgroup del contenedor</summary>

```bash
# Driver systemd (default moderno)
ID=$(docker inspect oom-victim --format '{{.Id}}')
CG="/sys/fs/cgroup/system.slice/docker-$ID.scope"
sudo cat "$CG/memory.events"
sudo cat "$CG/memory.max"
```

Si tu daemon usa `cgroupfs` driver, el path será
`/sys/fs/cgroup/docker/<ID>/` en vez de `system.slice/docker-<ID>.scope/`.

</details>

### 5.4 Entregar

```bash
mkdir -p /tmp/oom-investigation
docker inspect oom-victim > /tmp/oom-investigation/inspect.json
# Escribe /tmp/oom-investigation/root-cause.md con tus 5 bullets
bash tests/validate.sh
```

## 6. Resultado esperado

- `oom-victim` quedó detenido con `ExitCode=137` y `OOMKilled=true`.
- `/tmp/oom-investigation/inspect.json` contiene el JSON completo del inspect.
- `/tmp/oom-investigation/root-cause.md` menciona `ExitCode 137`, `SIGKILL`, `OOMKilled`, `memory.max` y `oom_kill`.
- Validator en `OK`.

## 7. Criterios de aceptación

- [ ] El contenedor `oom-victim` existe y está exited con `ExitCode=137`.
- [ ] `OOMKilled` es `true`.
- [ ] El `root-cause.md` contiene las 5 frases clave.
- [ ] (Opcional pero recomendado) `memory.events` muestra `oom_kill >= 1` capturado en las notas.

## 8. Validación

```bash
bash tests/validate.sh
```

En macOS/Windows el validator imprime `SKIP: Linux required` y exit 0.

## 9. Preguntas de reflexión

1. ¿Por qué el OOM-killer del cgroup mata **tu** proceso y no uno random del host?
2. Si pones `--memory=64m` pero **no** pones `--memory-swap`, ¿qué pasa? ¿Y si pones `--memory-swap=-1`?
3. En vez de "subir el límite", ¿qué otra alternativa haría que la app no sea OOMKilled? (pista: `--oom-score-adj`, `--oom-kill-disable`, o rediseñar la app).
4. ¿Qué métrica expondrías en Prometheus para detectar OOMs recurrentes antes de que el on-call los vea?
5. ¿Qué debug extra te daría la combinación `docker events --filter event=oom`?

## 10. Extensiones (opcional)

- **E1** — Repite con `--memory=64m --memory-swap=64m` (sin swap) vs `--memory=64m --memory-swap=256m` (192M de swap). Observa diferencias en `memory.events` y en timing.
- **E2** — Levanta el stack con `docker events --filter type=container --filter event=oom &` **antes** y observa el evento en vivo.
- **E3** — Reproduce la misma situación con `podman` rootless. ¿Cambia algo?

## 11. Limpieza

```bash
docker rm -f oom-victim 2>/dev/null || true
rm -rf /tmp/oom-investigation
```
