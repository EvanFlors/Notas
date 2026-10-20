# Solución — dkr-04-02

El `break.sh` deja `/tmp/dkr04-02-output` con ownership UID=2000 (visto desde cualquier contenedor). El `entrypoint.sh` del writer rehúsa trabajar si `/output` no está en UID=1000. Hay varios fixes válidos; el validador acepta cualquiera que:

- Deje `report.txt` escrito con el contenido correcto.
- No haya hecho `chmod 777` sobre el directorio.
- No haya mutado la imagen (`USER` sigue siendo `1000`).

## Fix 1 (recomendado) — alinear el ownership del bind al UID del contenedor

En **Linux nativo** (donde el chown del host es también el chown que ven los contenedores):

```bash
sudo chown 1000:1000 /tmp/dkr04-02-output
bash starter/run-broken.sh
```

En **Docker Desktop (macOS / Windows)**, el UID visto por los contenedores es gestionado por la VM del daemon, no por tu FS nativo. Usa un contenedor efímero para hacer el chown "desde dentro":

```bash
docker run --rm \
  --mount type=bind,source=/tmp/dkr04-02-output,target=/x \
  alpine:3.20 chown 1000:1000 /x

bash starter/run-broken.sh
```

Ambos caminos pasan el validador. El cross-platform (docker-chown) funciona también en Linux.

## Fix 2 — rebuilder la imagen para aceptar un UID vía `ARG`

**Rechazado por el enunciado**: no se puede modificar la imagen. Es un patrón válido en el mundo real cuando controlas la imagen: `ARG UID=1000` + `RUN useradd -u $UID`. Permite construir una imagen alineada al host sin tocar permisos.

## Fix 3 — forzar `--user` en `docker run`

**No se puede aplicar aquí** porque el enunciado prohíbe modificar `run-broken.sh`. Conceptualmente:

```bash
docker run --user "$(id -u):$(id -g)" ...
```

El contenedor ignora el `USER 1000` de la imagen y adopta tu UID. Funciona si la app no depende de UIDs específicos (muchas sí: Postgres rehúsa pgdata ajeno, Node a veces falla al escribir `/node_modules/.cache`).

## Fix 4 — pasar a volumen nombrado

Si no necesitas el archivo visible en el host, cambiar el mount a volumen *elimina* el bug: Docker gestiona el ownership del volumen alineándolo al `USER` de la imagen. **No** pasa este validador (busca el archivo en el bind path), pero es la respuesta correcta en producción cuando el host no necesita ver los datos.

## El anti-fix

```bash
chmod 777 /tmp/dkr04-02-output
```

El validador rechaza perms `0777` explícitamente. Pasarlo quitaría la señal de "esto está mal diseñado".

## Para la reflexión

Preguntas 1-5 del README. Una respuesta sólida identifica:

- Que el UID del contenedor es un número literal; en Linux es el mismo UID del kernel del host.
- Que **Docker Desktop añade una capa de traducción** en bind mounts para ergonomía: los contenedores ven la UID que el daemon define, no la UID del FS macOS. Esto puede *ocultar* bugs que sí aparecen en producción Linux.
- Que `chmod 777` quita visibilidad del problema real sin resolverlo.
- Que volumen nombrado es la respuesta por default para datos de app en producción.
