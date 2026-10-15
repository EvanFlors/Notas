# dkr-04-02 — Arreglar permisos en un bind mount desalineado

## 1. Identificación

- **ID:** `dkr-04-02-fix-permissions-on-bind-mount`
- **Tecnología:** docker
- **Módulo:** `04-storage-volumes-bind-mounts-tmpfs`
- **Dificultad:** intermediate
- **Duración estimada:** 25 min
- **Tipo:** independent (debug)

## 2. Contexto

Heredas un contenedor "legacy" que no puedes modificar: su `ENTRYPOINT` corre fijo como UID **1000** y escribe un `report.txt` a `/output`. Alguien montó un directorio del host en `/output` como bind mount, pero el host lo creó con otro ownership. El contenedor falla con `Permission denied` al intentar escribir.

Tu trabajo:

1. Reproducir el fallo con el script del starter.
2. Diagnosticar la causa (no es un bug de la app).
3. Aplicar un fix **sin** modificar la imagen y **sin** usar `chmod 777`.
4. Verificar que el `report.txt` aparece en el host con contenido esperado.

No se te da la solución. Hay múltiples caminos válidos. El validador solo comprueba el estado final.

## 3. Objetivos

- Diagnosticar un `Permission denied` como mismatch UID host ↔ contenedor.
- Aplicar al menos un fix razonado (no `chmod 777`).
- Explicar por escrito qué otras alternativas había y por qué elegiste la tuya.

## 4. Prerrequisitos

- Docker ≥ 20.
- Capacidad de usar `chown`, posiblemente con `sudo` según permisos de `/tmp`.
- Haber leído la sección 6 de `theory/lesson.md`.

## 5. Instrucciones

Prepara el escenario roto:

```bash
cd courses/docker/04-storage-volumes-bind-mounts-tmpfs/activities/02-fix-permissions-on-bind-mount
bash starter/break.sh
```

Esto:

- Construye una pequeña imagen `dkr04-02-writer:latest` cuyo entrypoint corre como UID 1000 y hace `echo "wrote-from-uid-1000" > /output/report.txt`.
- Crea `/tmp/dkr04-02-output/` con ownership *distinto* a UID 1000 (típicamente el UID de tu usuario, 501 en macOS o 1001 en varios Linux).
- Borra `/tmp/dkr04-02-output/report.txt` si existiera.

Luego ejecuta el contenedor "como vendría de fábrica":

```bash
bash starter/run-broken.sh
```

Debe fallar con `Permission denied`.

Ahora **diagnostica y arregla** el bind mount para que al correr:

```bash
bash starter/run-broken.sh
```

**el archivo `/tmp/dkr04-02-output/report.txt` aparezca con contenido `wrote-from-uid-1000`**. No puedes:

- Modificar la imagen (`dkr04-02-writer:latest`).
- Modificar `starter/run-broken.sh`.
- Hacer `chmod 777` sobre el directorio (el validador lo detecta y falla).

Pistas (sin orden):

- `ls -lan /tmp/dkr04-02-output` muestra UID numérico, no nombres.
- `chown` existe y en `/tmp/` lo puedes correr sin `sudo` si el directorio es tuyo.
- La imagen declara `USER 1000` — ese 1000 es un número literal, no un nombre.
- Hay más de un fix válido (alinear host → contenedor es solo uno).

Cuando creas que está arreglado:

```bash
bash tests/validate.sh
```

Al terminar:

```bash
bash starter/cleanup.sh
```

## 6. Resultado esperado

- `/tmp/dkr04-02-output/report.txt` existe tras `run-broken.sh`.
- Contenido exacto: `wrote-from-uid-1000`.
- El directorio **no** tiene `0777` (ni `rwxrwxrwx`).

## 7. Criterios de aceptación

- `tests/validate.sh` exit 0.
- `/tmp/dkr04-02-output/report.txt` existe y tiene el contenido correcto.
- Perms del directorio no son `0777`.

## 8. Validación

```bash
bash tests/validate.sh
```

Verifica existencia + contenido + perms + que la imagen sigue intacta (no la rebuildeaste).

## 9. Preguntas de reflexión

Responde brevemente en un `notas.md` propio:

1. ¿Qué fix elegiste y por qué?
2. ¿Qué otros dos fixes habrías podido aplicar? ¿Qué los descarta en este escenario?
3. Si este contenedor se desplegara en un clúster compartido donde `/output` fuera un bind, ¿qué política pondrías para evitar el bug?
4. ¿Por qué `chmod 777` es tentador y por qué es un smell?
5. En producción, cambiar a **volumen nombrado** suele resolver el problema. ¿Por qué?

## 10. Extensiones

1. Modifica la imagen para aceptar `ARG UID` y rebuilda con tu UID. Compara con el fix original.
2. Reemplaza el bind mount por un volumen nombrado y verifica que ni siquiera necesitas el `chown`.
3. Monta la carpeta `:ro` y observa el `Permission denied` *incluso* siendo root. ¿Por qué?

## 11. Limpieza

```bash
bash starter/cleanup.sh
```

Borra el contenedor, la imagen y `/tmp/dkr04-02-output/`.
