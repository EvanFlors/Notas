# Actividad 02 — Snapshot LVM y rollback

## 1. Identificación

- **ID:** `sys-08-02-lvm-snapshot-and-rollback`
- **Tecnología:** `00-Sysadmin`
- **Módulo:** `sys-08-storage-volumes-and-lvm`
- **Dificultad:** intermedio
- **Duración estimada:** 60 min
- **Tipo:** independent
- **Privilegios:** requiere `sudo`.

## 2. Contexto

Antes de aplicar un cambio arriesgado (upgrade, migración de esquema, patching de kernel) tomas un **snapshot LVM** del volumen afectado. Si el cambio sale mal: hacer rollback debería ser una operación de minutos, no "restaurar del backup de anoche".

En esta actividad reproduces el ciclo completo: snapshot → modificación destructiva del origen → verificación de que el snapshot *no* refleja los cambios → rollback → verificación de que el origen volvió al estado del snapshot.

## 3. Objetivos

Al terminar deberías poder:

- Crear un snapshot LVM dimensionado al cambio esperado.
- Explicar en voz alta por qué un snapshot "se llena" y qué ocurre si pasa.
- Montar un snapshot read-only para inspección/backup.
- Hacer rollback con `lvconvert --merge` y verificar por hash que los datos volvieron.
- Limpiar el stack sin dejar PVs/VGs huérfanos.

## 4. Prerrequisitos

- `sys-08` theory §7.3 leída.
- Actividad `01-grow-a-filesystem-online` completada y limpiada (comparten patrón de setup).

**Costos**: ninguno.

## 5. Instrucciones (independent)

A diferencia del guided-lab previo, aquí **tú escribes los comandos**. El starter deja el stack listo con un archivo "canónico" cuyo hash conoces. La solución existe pero intenta primero resolverlo sin mirarla.

### 5.1 Preparar

```bash
cd activities/02-lvm-snapshot-and-rollback
cat starter/setup.sh
CONFIRM=yes sudo -E bash starter/setup.sh
```

El setup deja:

- Loopback `/tmp/sys08-02.img` de 1.5 GB.
- VG `vg_snap` con un único PV.
- LV `lv_data` de 400 MiB formateado ext4, montado en `/mnt/sys08-02`.
- Archivo `datos-oro.txt` con contenido conocido. Su hash está guardado en `/tmp/sys08-02-hash-original.txt`.

Verifica:

```bash
cat /mnt/sys08-02/datos-oro.txt
cat /tmp/sys08-02-hash-original.txt
```

### 5.2 Tareas (sin pistas)

Resuelve en este orden:

**T1. Crear un snapshot de 100 MiB** del LV `vg_snap/lv_data` llamado `lv_data_snap`.

**T2. Verificar que el snapshot aparece en `lvs`** y entender la columna `Data%`.

**T3. "Romper" el origen**: borra `datos-oro.txt` y crea un `basura.bin` de 50 MiB con `dd`.

**T4. Montar el snapshot en modo RO** en `/mnt/sys08-02-snap` y comprobar que `datos-oro.txt` SÍ existe allí con el hash original.

**T5. Preparar el rollback**: desmonta origen y snapshot.

**T6. Hacer merge** con `lvconvert --merge vg_snap/lv_data_snap`.

**T7. Remontar el LV origen** en `/mnt/sys08-02` y comprobar:
   - `datos-oro.txt` volvió.
   - El hash coincide con `/tmp/sys08-02-hash-original.txt`.
   - `basura.bin` NO está.
   - El snapshot ya no aparece en `lvs` (se consumió en el merge).

### 5.3 Validar

```bash
sudo -E bash tests/validate.sh
```

### 5.4 Comparar con la solución

Solo después de intentarlo:

```bash
cat solution/snapshot-rollback.sh
```

## 6. Resultado esperado

- Hash de `datos-oro.txt` tras el rollback == hash original.
- `basura.bin` ausente.
- `lvs vg_snap` no muestra el snapshot (fue consumido por el merge).
- `tests/validate.sh` pasa.

## 7. Criterios de aceptación

- [ ] Funcionalidad: rollback verificado por hash.
- [ ] Operación: snapshot creado con tamaño razonable (no 1 MiB "porque sí", no 1 GiB "por si acaso").
- [ ] Comprensión: puedes explicar por qué un snapshot al 100% se vuelve inválido.
- [ ] Reproducibilidad: `tests/validate.sh` pasa.

## 8. Validación

```bash
sudo -E bash tests/validate.sh
```

Chequea: VG existe, LV origen montado, hash de `datos-oro.txt` coincide con el original, `basura.bin` ausente, snapshot ya no existe.

## 9. Preguntas de reflexión

1. ¿Por qué el snapshot ocupa espacio aunque el origen no haya cambiado? ¿En qué momento empieza a crecer?
2. ¿Qué pasa si el snapshot llega al 100% de uso? ¿Se puede recuperar?
3. Un snapshot de 100 MiB sobre un LV de 400 MiB: ¿puede captar cambios de 300 MiB? Argumenta usando el modelo COW.
4. ¿Por qué `lvconvert --merge` necesita que el origen esté desmontado (o se difiere)?
5. Un snapshot NO es un backup. Da dos escenarios de desastre donde el snapshot no te salva pero un backup sí.

## 10. Extensiones (opcional)

- **E1** — Repite con un **thin snapshot**: crea un `--thinpool`, un thin LV, y haz snapshots instantáneos (`lvcreate -s --name snap thinpool/lv`). Compara overhead.
- **E2** — Simula el fallo "snapshot lleno": haz un `dd` masivo sobre el origen hasta exceder los 100 MiB del snapshot. Observa en `dmesg` y `lvs` qué ocurre.
- **E3** — Script el ciclo completo con `trap` que haga rollback automático si una validación falla (patrón "deploy con red de seguridad").

## 11. Limpieza

```bash
sudo umount /mnt/sys08-02 2>/dev/null || true
sudo umount /mnt/sys08-02-snap 2>/dev/null || true
sudo lvremove -f vg_snap 2>/dev/null || true
sudo vgremove -f vg_snap 2>/dev/null || true
for loop in $(losetup -j /tmp/sys08-02.img | awk -F: '{print $1}'); do
  sudo pvremove -ff "$loop" 2>/dev/null || true
  sudo losetup -d "$loop" 2>/dev/null || true
done
sudo rm -f /tmp/sys08-02.img /tmp/sys08-02-hash-original.txt
sudo rmdir /mnt/sys08-02 /mnt/sys08-02-snap 2>/dev/null || true
```
