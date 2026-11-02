# Actividad 01 — Crecer un filesystem en caliente

## 1. Identificación

- **ID:** `sys-08-01-grow-a-filesystem-online`
- **Tecnología:** `00-Sysadmin`
- **Módulo:** `sys-08-storage-volumes-and-lvm`
- **Dificultad:** intermedio
- **Duración estimada:** 60 min
- **Tipo:** guided-lab
- **Privilegios:** requiere `sudo` (losetup, lvm, mount).

## 2. Contexto

Una base de datos en `/mnt/app` está al 95% de uso. El SRE pide ampliar sin downtime. En producción se añadiría un disco al VG y se extendería el LV; aquí lo reproduces con loopback para hacerlo sin riesgo. Al terminar sabrás ejecutar la operación en caliente, con confianza, y verificando antes y después.

## 3. Objetivos

Al terminar deberías poder:

- Crear un stack `PV → VG → LV → ext4` desde cero con loopback.
- Añadir un segundo PV a un VG existente (`vgextend`).
- Crecer un LV con `lvextend` **sin desmontar**.
- Crecer el filesystem ext4 que vive encima con `resize2fs` (o el atajo `lvextend -r`).
- Verificar antes y después con `lsblk`, `vgs`, `lvs`, `df -hT`.

## 4. Prerrequisitos

- `sys-08` theory leída, especialmente §7.
- Ejemplo `02-lvm-on-loopback` reproducido.
- Linux con `lvm2` instalado.

**Costos**: ninguno (solo loopback files locales).

## 5. Instrucciones

### 5.1 Preparar el entorno

```bash
cd activities/01-grow-a-filesystem-online
cat starter/setup.sh      # LEE antes de ejecutar
CONFIRM=yes sudo -E bash starter/setup.sh
```

El setup deja:

- Dos archivos de 1 GB en `/tmp/sys08-01-{1,2}.img`.
- Dos loop devices asociados.
- Un PV sobre el primer loop.
- Un VG `vg_grow` con ese PV.
- Un LV `lv_app` de 500 MiB formateado ext4.
- Montado en `/mnt/sys08-01` con un archivo de prueba.

Verifica el estado inicial:

```bash
sudo lsblk
sudo vgs vg_grow
sudo lvs vg_grow
df -hT /mnt/sys08-01
```

Debes ver: VG ~1 GiB total, LV 500 MiB, filesystem ~470 MiB disponibles, 1 archivo dentro.

### 5.2 Hacer que "se llene"

Simula consumo real:

```bash
sudo dd if=/dev/zero of=/mnt/sys08-01/relleno.bin bs=1M count=400 status=progress
df -hT /mnt/sys08-01
```

Deberías estar sobre el 90% de uso. Esta es la "alerta" que motiva crecer.

### 5.3 Añadir el segundo PV al VG

El segundo loop ya existe pero no está en el VG. Añádelo:

```bash
# Localiza el segundo loop (el que apunta a /tmp/sys08-01-2.img)
LOOP2="$(losetup -j /tmp/sys08-01-2.img | awk -F: '{print $1}')"
echo "LOOP2=$LOOP2"

sudo pvcreate "$LOOP2"
sudo vgextend vg_grow "$LOOP2"
sudo vgs vg_grow        # ahora ~2 GiB totales
```

### 5.4 Crecer el LV en caliente

**Sin desmontar nada**:

```bash
# Añade 400 MiB al LV
sudo lvextend -L +400M /dev/vg_grow/lv_app
sudo lvs vg_grow

# El filesystem AÚN no ha crecido:
df -hT /mnt/sys08-01     # mismo tamaño que antes
```

El LV es más grande pero el filesystem no se ha enterado. Hazlo crecer:

```bash
sudo resize2fs /dev/vg_grow/lv_app
df -hT /mnt/sys08-01     # ahora ~870 MiB total
```

### 5.5 Opción atajo (para la próxima vez)

En una pasada, `lvextend -r` hace ambas cosas:

```bash
sudo lvextend -r -L +100M /dev/vg_grow/lv_app
df -hT /mnt/sys08-01
```

### 5.6 Verificar integridad

El archivo de prueba y el `relleno.bin` deben seguir legibles:

```bash
cat /mnt/sys08-01/README-prueba.txt
md5sum /mnt/sys08-01/relleno.bin
ls -lh /mnt/sys08-01/
```

### 5.7 Validar

```bash
sudo -E bash tests/validate.sh
```

Debe pasar con `OK`.

### 5.8 Comparar con la solución

```bash
cat solution/grow.sh
```

Es el mismo flujo scriptado, idempotente.

## 6. Resultado esperado

- LV `vg_grow/lv_app` creció de 500 MiB a ~970 MiB sin desmontar.
- `df -hT /mnt/sys08-01` refleja el nuevo tamaño.
- Datos previos intactos (`relleno.bin` conserva su hash).
- VG tiene 2 PVs (`pvs` muestra ambos loops).

## 7. Criterios de aceptación

- [ ] Funcionalidad: LV ≥ 900 MiB, fs usable, datos previos conservados.
- [ ] Operación en caliente: en ningún momento se desmontó.
- [ ] Reproducibilidad: `tests/validate.sh` pasa.
- [ ] Comprensión: puedes responder las preguntas de reflexión sin consultar.

## 8. Validación

```bash
sudo -E bash tests/validate.sh
```

Chequea: VG con 2 PVs, LV ≥ 900 MiB, filesystem montado, tamaño del fs coincide con el LV, archivo de prueba legible.

## 9. Preguntas de reflexión

1. Si tras `lvextend` olvidaras `resize2fs`, ¿qué muestra `df` vs `lvs`? ¿Qué pasa con los datos?
2. ¿Por qué el filesystem se puede crecer "en caliente" pero encogerlo típicamente requiere desmontarlo?
3. Si en vez de ext4 fuera xfs, ¿qué comando sustituiría a `resize2fs`? ¿Qué argumento le pasas (device o mountpoint)?
4. ¿Qué habría pasado si el VG no tuviera espacio libre y hubieras intentado `lvextend` sin añadir el segundo PV?

## 10. Extensiones (opcional)

- **E1** — Repite usando xfs: formatea el LV con `mkfs.xfs`, crece y usa `xfs_growfs <mountpoint>`.
- **E2** — Mueve los extents del primer PV al segundo con `pvmove` y retira el primero del VG (`vgreduce`).
- **E3** — Simula un fallo: intenta encoger el LV con `lvreduce -L -200M` **antes** de encoger el fs. Observa el aviso de LVM.

## 11. Limpieza

```bash
sudo umount /mnt/sys08-01 2>/dev/null || true
sudo lvremove -f vg_grow 2>/dev/null || true
sudo vgremove -f vg_grow 2>/dev/null || true
for img in /tmp/sys08-01-1.img /tmp/sys08-01-2.img; do
  for loop in $(losetup -j "$img" | awk -F: '{print $1}'); do
    sudo pvremove -ff "$loop" 2>/dev/null || true
    sudo losetup -d "$loop" 2>/dev/null || true
  done
done
sudo rm -f /tmp/sys08-01-1.img /tmp/sys08-01-2.img
sudo rmdir /mnt/sys08-01 2>/dev/null || true
```
