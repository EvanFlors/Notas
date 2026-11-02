# Ejemplo 01 — Anatomía de `/etc/fstab`

## Concepto que demuestra

Cómo leer, campo por campo, un `/etc/fstab` real y validarlo **sin reiniciar** la máquina.

## Contexto

`/etc/fstab` es el "manifiesto de montaje" que el sistema aplica al boot. Un error aquí puede dejar la máquina sin arrancar. Entenderlo línea a línea es una competencia operativa básica.

## Objetivo

Al terminar podrás:

- Explicar los seis campos de una entrada fstab.
- Diferenciar `UUID=`, `LABEL=`, `PARTUUID=` y `/dev/sdX`.
- Validar cambios en fstab sin reiniciar.

## Prerrequisitos

- Lectura de `theory/lesson.md` §4–§6.
- Shell con `sudo` (los comandos de validación lo requieren).

## Material

- `files/sample.fstab` — fstab anotado de ejemplo que vas a leer.

## Ejecución

### 1. Abre tu fstab actual

```bash
cat /etc/fstab
```

Compara mentalmente cada línea con la de `files/sample.fstab`.

### 2. Lee el fstab anotado del ejemplo

```bash
less files/sample.fstab
```

Identifica, para cada línea no-comentario, los seis campos:

```
<spec>  <mountpoint>  <fstype>  <options>  <dump>  <pass>
```

### 3. Inspección cruzada con el sistema

```bash
# ¿Qué está realmente montado ahora?
findmnt --real

# ¿Qué UUIDs están disponibles?
sudo blkid

# ¿Qué fs cubre /home?
findmnt -T /home
```

Comprueba que los `UUID=` de tu fstab existen en la salida de `blkid`.

### 4. Validación semántica

```bash
# Chequeo sintáctico y de referencias del fstab
findmnt --verify
```

Lee la salida: te marca entradas con UUID inexistente, mountpoint ausente, opciones desconocidas, etc.

### 5. Simulación segura

Para probar una línea nueva **sin reiniciar**:

```bash
# a) Añade la línea a /etc/fstab (edita con sudo tu editor favorito).
# b) Crea el mountpoint:
sudo mkdir -p /mnt/pruebafstab
# c) Monta todo lo marcado para automontaje:
sudo mount -a
# d) Verifica:
findmnt /mnt/pruebafstab
```

Si `mount -a` falla, **no reinicies** hasta corregir — la máquina no bootearía.

## Resultado esperado

- Identificas los 6 campos de cada línea sin dudar.
- `findmnt --verify` corre y entiendes su salida.
- Sabes qué comando usar antes de reiniciar tras tocar fstab.

## Interpretación

- `UUID=` es el ancla estable: sobrevive al cambio de nombres de dispositivo.
- El campo `<pass>` controla orden de `fsck` al boot: `1` para `/`, `2` para los demás con fs, `0` para omitir.
- `defaults` = `rw,suid,dev,exec,auto,nouser,async`. Si quieres algo distinto, lo pones explícito.
- `nofail` es la diferencia entre "la máquina arranca aunque falte el USB" y "la máquina cuelga en el prompt de emergencia".

## Errores frecuentes

- **`/dev/sdX` en fstab:** se rompe al cambiar el orden de enumeración. Sustituir por `UUID=`.
- **Mountpoint inexistente:** el montaje falla silencioso al boot. Crea el directorio antes.
- **Opciones separadas por espacio:** deben ir separadas por **coma**, sin espacio.
- **Tabs vs espacios:** cualquier whitespace sirve, pero sé consistente.
- **Olvidar `findmnt --verify` o `mount -a`** antes de reiniciar.

## Relación con escenarios reales

- Clonas una VM y no arranca: el nuevo disco tiene UUIDs nuevos; hay que regenerar fstab.
- Montas un snapshot LVM: añades línea `nofail` para no bloquear boot si el snapshot ya no existe.
- Un contenedor hace bind mount de `/srv/data` → línea con `none bind` en fstab lo persiste.

## Limpieza

Si añadiste una línea de prueba:

```bash
sudo umount /mnt/pruebafstab 2>/dev/null || true
sudo rmdir /mnt/pruebafstab 2>/dev/null || true
# y borra la línea de prueba de /etc/fstab
```
