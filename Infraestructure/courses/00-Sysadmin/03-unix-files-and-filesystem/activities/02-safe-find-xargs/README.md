# Actividad 02 — Safe `find` + `xargs`

## 1. Identificación

- **ID:** `sys-03-02-safe-find-xargs`
- **Tecnología:** `linux-sysadmin`
- **Módulo:** `sys-03-unix-files-and-filesystem`
- **Dificultad:** intermediate
- **Duración estimada:** 40–50 min
- **Tipo:** independent

## 2. Contexto

En producción, los archivos **no** se llaman `foo.txt`. Se llaman `cliente — reporte Q3 (final).pdf`, o un atacante los puede llamar `; rm -rf $HOME.txt`, o un script Windows los deja con `\r\n` embebido en el nombre. Todos los pipelines ingenuos (`for f in $(find ...)`, `find | xargs`) **se rompen o abren vulnerabilidades**.

Vas a construir y validar un script `find-biggest.sh` que, dado un directorio, imprima los N archivos regulares más grandes bajo él, **a prueba de nombres hostiles** y **sin cruzar mount points**.

## 3. Objetivos

Al terminar deberías poder:

- Explicar por qué `for f in $(find ...)` es incorrecto para iterar archivos.
- Usar `find -print0 | xargs -0` idiomáticamente.
- Usar `find -exec ... +` como alternativa sin `xargs`.
- Usar `while IFS= read -r -d ''` como alternativa en bash puro.
- Entender qué protege `--` en comandos como `rm`.

## 4. Prerrequisitos

- Lectura previa de `theory/lesson.md` (secciones 8, 9).
- `bash`, `coreutils`, `findutils`.
- Opcional: `shellcheck` instalado para validar tu script.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Generar un directorio con nombres hostiles

```bash
bash starter/make-messy-files.sh /tmp/messy
ls -la /tmp/messy
```

El script crea una docena de archivos con: espacios, newlines embebidos, guiones iniciales, comillas, unicode y tamaños variados.

### 5.2 Verifica que un pipeline ingenuo falla

En `/tmp/messy`, prueba primero el enfoque incorrecto y observa el daño:

```bash
# INCORRECTO: cuenta tokens, no archivos; rompe con espacios/newlines
cd /tmp/messy
for f in $(find . -type f); do
    echo "procesando: $f"
done
```

Vas a ver "archivos" partidos en pedazos. Toma nota — este es el pecado que vas a corregir.

### 5.3 Escribe `find-biggest.sh`

Entregable: `/tmp/messy/find-biggest.sh`, ejecutable, que:

- Acepta dos argumentos: `DIR` (directorio raíz) y `N` (cuántos archivos, default 10).
- Imprime los N archivos regulares más grandes bajo `DIR`.
- Formato por línea: `<bytes>\t<ruta>` (tab como separador).
- Es **seguro frente a nombres con espacios, newlines, comillas, unicode y guiones iniciales**.
- **No cruza mount points** (`-xdev`).
- Empieza con:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  IFS=$'\n\t'
  ```
- Pasa `shellcheck` sin warnings serios.

Técnicas obligatorias:

- `find ... -print0` + `xargs -0 ...` **o** `find ... -exec ... +`.
- `--` donde haga falta separar opciones de rutas.

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/messy/find-biggest.sh /tmp/messy
```

El test:

- Comprueba que el script existe y es ejecutable.
- Comprueba la presencia de `set -euo pipefail`, `IFS=`, `-print0` o `-exec`.
- Comprueba que `shellcheck` (si está instalado) pasa.
- Ejecuta el script sobre `/tmp/messy` y comprueba que cuenta correctamente, incluyendo los archivos con nombres hostiles (comparando contra una cuenta de referencia).

## 6. Resultado esperado

- `/tmp/messy/find-biggest.sh` ejecutable y correcto.
- `tests/validate.sh` pasa.
- Capacidad de explicar oralmente por qué cada decisión en el script es necesaria.

## 7. Criterios de aceptación

- [ ] El script tiene `#!/usr/bin/env bash`, `set -euo pipefail`, `IFS=$'\n\t'`.
- [ ] Usa `-print0`/`-0` o `-exec ... +`.
- [ ] Procesa correctamente archivos con espacios, newlines y guiones iniciales.
- [ ] Usa `-xdev` para no cruzar mounts.
- [ ] `shellcheck` limpio (si está instalado).
- [ ] Documentado al inicio con un comentario de 2–3 líneas.

## 8. Validación

```bash
bash tests/validate.sh /tmp/messy/find-biggest.sh /tmp/messy
```

## 9. Preguntas de reflexión

1. ¿Por qué `IFS=$'\n\t'` ayuda cuando algo escapa al `-print0`?
2. ¿Qué diferencia hay entre `find ... -exec cmd {} \;` y `find ... -exec cmd {} +`?
3. Un script debe borrar `*.tmp` bajo `/var/cache/mi-app/`. ¿Qué le pedirías además de `-print0` para que sea seguro en producción?

## 10. Extensiones (opcional)

- **E1** — Añade al script un flag `-h` que imprima tamaños humanos (`numfmt --to=iec`).
- **E2** — Añade filtrado por antigüedad: `--older-than DAYS`.
- **E3** — Reescribe el core en Python usando `os.walk` + `os.stat` y compara rendimiento con `time`.

## 11. Limpieza

```bash
rm -rf /tmp/messy
```
