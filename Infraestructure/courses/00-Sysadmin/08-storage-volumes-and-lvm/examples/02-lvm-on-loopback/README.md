# Ejemplo 02 — Stack LVM completo sobre loopback

## Concepto que demuestra

Construir la pila PV → VG → LV **sin un disco real**, usando archivos presentados como dispositivos de bloque (`losetup`). Es la base operativa de todas las actividades del módulo.

## Contexto

Trabajar con LVM "en caliente" sobre discos reales es arriesgado para aprender. Los **loop devices** permiten reproducir el stack entero con cero riesgo: creas un archivo, `losetup` lo expone como `/dev/loopN`, y a partir de ahí LVM lo trata como cualquier dispositivo de bloque.

## Objetivo

Al terminar podrás:

- Convertir un archivo en un dispositivo de bloque con `losetup`.
- Crear PV, VG, LV paso a paso.
- Formatear, montar y escribir sobre el LV resultante.
- Desmontar y limpiar sin dejar loops colgados.

## Prerrequisitos

- Linux con LVM instalado (`sudo apt install lvm2` en Debian/Ubuntu, ya viene en RHEL).
- `sudo` disponible.
- Espacio libre en `/tmp` para dos archivos de 1 GB cada uno.

## Material

- `files/setup-loopback.sh` — script idempotente que crea dos archivos de 1 GB, los asocia a loops y los expone como PVs. Guardado por `CONFIRM=yes` porque toca el estado del kernel.

## Ejecución

### 1. Revisa el script antes de ejecutar

```bash
cat files/setup-loopback.sh
```

**Nunca ejecutes ciegamente** scripts que invocan `losetup` o `pvcreate`.

### 2. Lanzar el setup

```bash
CONFIRM=yes sudo -E bash files/setup-loopback.sh
```

Esto crea:
- `/tmp/lvm-demo-1.img` y `/tmp/lvm-demo-2.img` (1 GB cada uno, dispersos).
- `/dev/loop<N1>` y `/dev/loop<N2>` asociados.
- Dos PVs listos.

Verifica:

```bash
losetup -a | grep lvm-demo
sudo pvs
```

### 3. Crear el VG

```bash
sudo vgcreate vg_demo /dev/loop<N1> /dev/loop<N2>
sudo vgs vg_demo
sudo vgdisplay vg_demo
```

Debe mostrar ~2 GB totales (menos un pelín de metadata).

### 4. Crear un LV y formatearlo

```bash
sudo lvcreate -L 500M -n lv_app vg_demo
sudo lvs
sudo mkfs.ext4 /dev/vg_demo/lv_app
```

### 5. Montar y usar

```bash
sudo mkdir -p /mnt/demo
sudo mount /dev/vg_demo/lv_app /mnt/demo
findmnt /mnt/demo
echo "hola LVM" | sudo tee /mnt/demo/hola.txt
cat /mnt/demo/hola.txt
```

### 6. Explorar el device-mapper

```bash
ls -la /dev/mapper/
# vg_demo-lv_app → ../dm-0 (o similar)

sudo dmsetup ls --tree
# vg_demo-lv_app  (254:0)
#  ├─ loop1
#  └─ loop0   (o el que sea)
```

### 7. Limpieza completa

```bash
sudo umount /mnt/demo
sudo lvremove -f vg_demo/lv_app
sudo vgremove -f vg_demo
sudo pvremove /dev/loop<N1> /dev/loop<N2>
sudo losetup -d /dev/loop<N1> /dev/loop<N2>
sudo rm -f /tmp/lvm-demo-1.img /tmp/lvm-demo-2.img
sudo rmdir /mnt/demo
```

Verifica que no queden loops:

```bash
losetup -a | grep lvm-demo || echo "sin loops colgados"
sudo pvs | grep vg_demo    || echo "sin PVs"
```

## Resultado esperado

- `pvs`, `vgs`, `lvs` muestran el stack mientras existía.
- Un archivo escrito en `/mnt/demo` sobrevive a `umount`/`mount` del mismo LV.
- Tras la limpieza, `/tmp/lvm-demo-*.img` desaparecen y no hay loops colgados.

## Interpretación

- `losetup` no copia nada: *expone* el archivo como dispositivo. Toda operación de bloque va al archivo.
- Los extents del VG (4 MiB por defecto) se distribuyen por los PVs disponibles; `lvs -o+devices` muestra el reparto real.
- `/dev/mapper/vg_demo-lv_app` y `/dev/vg_demo/lv_app` apuntan al mismo nodo; ambos sirven.

## Errores frecuentes

- **"Device or resource busy" al `losetup -d`:** aún hay un LV/VG/PV encima. Desmonta y desarma la pila en orden inverso.
- **Olvidar `pvremove`:** reactivar los loops en otra sesión reaparecen los PVs huérfanos. Siempre destruye los PVs antes de borrar los archivos.
- **Perder el número de loop:** `losetup -a | grep lvm-demo` siempre te lo dice.
- **`vgcreate` falla con "Device excluded by filter":** `/etc/lvm/lvm.conf` puede estar filtrando `/dev/loop*`. En labs se desactiva temporalmente o se ejecuta como root.

## Relación con escenarios reales

- Mismo workflow en producción, cambiando loops por particiones reales (`/dev/sdb1`) o LUNs de SAN.
- CI de infra prueba playbooks LVM contra loop devices para evitar provisionar hardware.
- Diagnóstico post-mortem: `losetup` sobre un `.img` rescatado permite montar y leer sin tocar el disco original.
