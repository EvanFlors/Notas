# Actividad 02 — Arregla el manejo de señales (PID 1)

## 1. Identificación

- **ID:** `dkr-03-02-fix-signal-handling`
- **Tecnología:** `docker`
- **Módulo:** `dkr-03-images-dockerfile-basics`
- **Dificultad:** beginner
- **Duración estimada:** 25–35 min
- **Tipo:** independent (debug)

## 2. Contexto

Te dan una imagen construida a partir de un `Dockerfile` que **sí funciona**
(arranca, loguea, sirve requests), pero cuando el equipo corre `docker stop`
el contenedor tarda ~10 segundos en terminar. En producción, con decenas de
pods rotando durante un deployment, esto se traduce en varios minutos extra por
rolling update y en requests perdidos durante el shutdown.

Tu trabajo:
1. **Reproducir** el síntoma: contenedor que tarda ~10 s en responder a `docker stop`.
2. **Encontrar** la causa en el `Dockerfile`.
3. **Aplicar** la corrección mínima para que `docker stop` termine en < 2 s.
4. **Demostrar** que el proceso recibió `SIGTERM` (log debe mostrarlo).

No se te revela la solución exacta. Si has leído la lección y los `examples/`,
tienes todo lo necesario. Hay **más de un fix aceptable**.

## 3. Objetivos

- Diagnosticar que el proceso dentro del contenedor **no está recibiendo**
  `SIGTERM`.
- Identificar la línea del `Dockerfile` responsable.
- Aplicar la mínima modificación que resuelva el problema sin cambiar el
  comportamiento funcional de la app.
- Documentar en una línea *por qué* tu fix funciona.

## 4. Prerrequisitos

- Docker 24+ y daemon corriendo (`docker info`). Si no, el validador hace SKIP.
- Haber leído `theory/lesson.md` §2.6, §4 y `examples/02-entrypoint-vs-cmd/`.
- Costo: $0.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash courses/docker/03-images-dockerfile-basics/activities/02-fix-signal-handling/starter/bootstrap.sh /tmp/dkr-03-02
```

El bootstrap crea `/tmp/dkr-03-02/project/`:

```
project/
├── Dockerfile       <- el que debes arreglar
└── app.py           <- app que loguea cada señal; NO la toques
```

### 5.2 Reproduce el síntoma

```bash
cd /tmp/dkr-03-02/project
docker build -t signal-broken:v1 .
docker run -d --name sb signal-broken:v1
sleep 1
time docker stop sb       # esperado: ~10 s
docker logs sb            # NO verás "recibi SIGTERM"
docker rm sb
```

Si observas los ~10 segundos y los logs no muestran recepción de `SIGTERM`, el
síntoma está confirmado.

### 5.3 Diagnostica

Preguntas útiles:
- ¿Qué proceso es PID 1 dentro del contenedor? (`docker exec sb ps -ef`.)
- ¿Qué forma tienen `CMD` / `ENTRYPOINT` en el `Dockerfile`?
- ¿Qué pasaría si `/bin/sh -c` recibe `SIGTERM`?
- ¿Qué cambiarías para que **tu proceso** (python) sea PID 1?

Lee `theory/lesson.md` §2.6 y §4.4 si necesitas refrescar.

### 5.4 Aplica el fix

Edita `Dockerfile`. Fixes aceptables (al menos uno):

- **(A)** Convertir `CMD`/`ENTRYPOINT` a **exec form** (JSON array). Python toma PID 1.
- **(B)** Mantener shell form pero envolver con `exec`: `CMD exec python /app.py`.
  (Nota: en forma shell `CMD exec ...` sigue siendo `/bin/sh -c "exec python ..."`,
  pero el `exec` del shell reemplaza al propio shell → python toma PID 1.)
- **(C)** Añadir un `entrypoint.sh` con `exec python "$@"` y usar `ENTRYPOINT ["/entrypoint.sh"]`.

El validador acepta cualquiera de las tres.

Si estás en apuro, también `docker run --init` resolvería el problema inyectando
`tini` como PID 1 — pero este es un parche **de runtime**, no una corrección del
`Dockerfile`. El validador busca el fix en el `Dockerfile`.

### 5.5 Verifica

```bash
docker build -t signal-fixed:v1 .
docker run -d --name sf signal-fixed:v1
sleep 1
time docker stop sf       # esperado: < 2 s
docker logs sf            # DEBE mostrar "recibi SIGTERM; shutdown ordenado"
docker rm sf
```

### 5.6 Validación automatizada

```bash
bash courses/docker/03-images-dockerfile-basics/activities/02-fix-signal-handling/tests/validate.sh /tmp/dkr-03-02
```

## 6. Resultado esperado

- `docker stop` sobre el contenedor tarda **< 3 s** (holgura).
- Los logs contienen literalmente la cadena `recibi SIGTERM`.
- `docker exec <ct> ps -o pid,comm` muestra que PID 1 es `python` (o un script
  que *haya hecho `exec python`*; el `ps` del final mostrará `python` como PID 1
  si usaste `exec`).

## 7. Criterios de aceptación

- [ ] `Dockerfile` existe y es distinto del original.
- [ ] Build con éxito.
- [ ] `docker stop` termina en < 3 segundos.
- [ ] Logs contienen `recibi SIGTERM`.
- [ ] PID 1 dentro del contenedor es `python` (no `sh`).

## 8. Validación

```bash
bash courses/docker/03-images-dockerfile-basics/activities/02-fix-signal-handling/tests/validate.sh /tmp/dkr-03-02
```

El validador:
1. SKIP gracioso si docker no está.
2. Construye la imagen.
3. Arranca el contenedor.
4. Mide con `date` lo que tarda `docker stop`.
5. Chequea `recibi SIGTERM` en logs.
6. Chequea PID 1 = `python` con `docker exec … ps`.

## 9. Preguntas de reflexión

1. ¿Qué hace exactamente `/bin/sh -c "python /app.py"` cuando recibe `SIGTERM`? ¿Por qué el default es "ignorar"?
2. ¿Por qué `exec python /app.py` en shell form **también** resuelve el problema? ¿Qué hace `exec` del shell internamente (hint: `execve`)?
3. Si en vez de arreglar el `Dockerfile`, en runtime hubieses usado `docker run --init signal-broken:v1`, ¿qué pasaría? ¿Es equivalente?
4. ¿Qué efecto tienen los 10 segundos default en un cluster Kubernetes con `terminationGracePeriodSeconds: 30` y rolling update de 100 pods?
5. ¿Qué pasaría si tu app ignora `SIGTERM` explícitamente (hace `signal.signal(SIGTERM, SIG_IGN)`)? ¿Lo rescata exec form o `--init`? ¿Qué queda?

## 10. Extensiones (opcional)

- **E1** — Modifica `app.py` para que tarde 15 s en terminar su shutdown handler (p. ej. `time.sleep(15)` dentro del handler). ¿Qué hace Docker? ¿Cómo lo controlas desde el run?
- **E2** — Reproduce con `docker run --init` y confirma que mitiga el problema incluso con shell form. Compara los PID.
- **E3** — Añade un `STOPSIGNAL SIGINT` al Dockerfile. ¿Qué cambia?

## 11. Limpieza

```bash
docker rm -f sb sf 2>/dev/null || true
docker rmi signal-broken:v1 signal-fixed:v1 2>/dev/null || true
rm -rf /tmp/dkr-03-02
```
