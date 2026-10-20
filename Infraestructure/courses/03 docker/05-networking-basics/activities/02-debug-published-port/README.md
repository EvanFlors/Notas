# Actividad 02 — Debug: "mi puerto publicado no responde"

## 1. Identificación

- **ID:** `dkr-05-02-debug-published-port`
- **Tecnología:** `docker`
- **Módulo:** `dkr-05-networking-basics`
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** debug

## 2. Contexto

El bootstrap deja un contenedor **publicado** en el host, pero `curl http://localhost:<puerto>/` falla. Tu trabajo: diagnosticar la causa (hay **una** causa raíz típica de este módulo) y aplicar la corrección mínima para que el servicio responda 200.

No se te da la respuesta en el README. Primero investiga; si te atascas 10+ min, usa las pistas al final.

## 3. Objetivos

- Diagnosticar por qué un contenedor publicado no responde.
- Reconocer el patrón "la app hace bind al loopback de **su** net namespace".
- Aplicar una corrección mínima que no cambie el puerto publicado.

## 4. Prerrequisitos

- Docker Engine o Desktop corriendo.
- Puerto `18086` libre.
- Costo: $0.

## 5. Instrucciones

### 5.1 Bootstrap (setup roto)

```bash
bash courses/docker/05-networking-basics/activities/02-debug-published-port/starter/bootstrap.sh
```

Al terminar, el contenedor `broken-web` corre y aparece publicado en `0.0.0.0:18086 -> 8000/tcp`. Verifica el síntoma:

```bash
docker ps --filter name=broken-web
docker port broken-web
curl -v --max-time 3 http://localhost:18086/   # FALLA
```

### 5.2 Diagnostica

Sugerencias de qué mirar (no te damos el culpable):

- `docker logs broken-web`
- `docker exec broken-web ss -ltn` (o `netstat -ltn` si no hay `ss`). ¿En qué **IP** escucha realmente la app?
- `docker inspect -f '{{json .NetworkSettings.Ports}}' broken-web`
- `docker exec broken-web wget -qO- --timeout=3 http://127.0.0.1:8000/` (dentro del contenedor) vs desde el host.

### 5.3 Aplica la corrección mínima

Debe cumplir **todas** estas condiciones:

- El contenedor sigue llamándose `broken-web`.
- Sigue publicado en el host en `18086`.
- `curl http://localhost:18086/` devuelve 200.

Puedes `docker rm -f broken-web` y recrearlo. Puedes modificar el comando que corre. **No** cambies el puerto publicado del host.

### 5.4 Valida

```bash
bash courses/docker/05-networking-basics/activities/02-debug-published-port/tests/validate.sh
```

Debe reportar `OK` en todos los checks.

### 5.5 Pistas progresivas (úsalas solo si llevas 10+ min atascado)

> **Pista 1**: `docker port broken-web` dice que hay publicación. El puerto DEL HOST sí está ocupado por el daemon. Entonces no es un problema de `iptables` ausente.

> **Pista 2**: haz `docker exec broken-web ss -ltn`. ¿Qué ves en la columna `Local Address:Port`?

> **Pista 3**: lee la lección §9. El patrón de bind a `127.0.0.1` ya salió ahí.

## 6. Resultado esperado

- `broken-web` corriendo, publicado en `18086`, respondiendo 200.
- La app **debe** escuchar en `0.0.0.0:8000` dentro del contenedor (no en `127.0.0.1`).

## 7. Criterios de aceptación

- [ ] Contenedor `broken-web` corriendo.
- [ ] Publicación `18086 -> 8000`.
- [ ] `curl http://localhost:18086/` responde 200.
- [ ] Dentro del contenedor, el proceso escucha en `0.0.0.0:8000` (o `*:8000`, equivalente).

## 8. Validación

```bash
bash courses/docker/05-networking-basics/activities/02-debug-published-port/tests/validate.sh
```

Omite con `SKIP` si no hay Docker.

## 9. Preguntas de reflexión

1. ¿Por qué `-p 18086:8000` **no** fue suficiente? Describe la ruta del paquete desde el host hasta donde se perdió.
2. ¿Qué pasa a nivel TCP cuando llega un SYN a un namespace donde no hay socket en la IP/puerto esperados?
3. Si en vez de corregir el bind cambias a `--network host`, ¿también funciona? ¿Qué pierdes?
4. ¿Cómo detectarías este mismo bug sin leer los logs — solo con comandos de red dentro del contenedor?
5. ¿Por qué `--publish-all` (`-P`) no habría cambiado nada aquí?

## 10. Extensiones

- **E1** — Reproduce el bug con `nginx` (dale un `conf.d/default.conf` que haga `listen 127.0.0.1:80`).
- **E2** — Hazlo "al revés": `-p 127.0.0.1:18086:8000` desde el host; levanta otro contenedor que trate de llegar via `host.docker.internal:18086`. ¿Funciona? ¿Por qué?

## 11. Limpieza

```bash
docker rm -f broken-web 2>/dev/null
```
