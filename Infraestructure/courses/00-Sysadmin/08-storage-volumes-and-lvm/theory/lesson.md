# Lección: Storage, volúmenes y LVM

> **ID:** `sys-08-storage-volumes-and-lvm` · **Nivel:** intermedio · **Duración:** 3 h
> **Prerrequisitos:** `sys-03`, `sys-04`.

---

## 1. Introducción intuitiva

Un servidor arranca. El kernel detecta un disco SSD NVMe de 1 TB. Lo "ve" como `/dev/nvme0n1`. Pero el usuario no interactúa con bloques crudos: abre `/home/eva/informe.md`. Entre esos dos extremos hay **cuatro capas** apiladas que todo sysadmin debe conocer:

```
Aplicación           cat /home/eva/informe.md
       │
Filesystem           ext4 — traduce path a inodo, inodo a bloques
       │
Volumen lógico       LVM — presenta un "disco virtual" sobre uno o más PVs
       │
Partición            una porción contigua de un disco físico
       │
Dispositivo bloque   /dev/nvme0n1 — el hardware real
```

La magia operativa del sysadmin moderno es que estas capas son **desacoplables**: puedes crecer el filesystem sin tocar la partición, mover un volumen lógico a otro disco en caliente, tomar una foto consistente del estado sin detener la aplicación. Nada de esto es posible si piensas en términos de "el disco". Hay que pensar en términos de la pila.

Este módulo construye ese modelo mental y lo aterriza en comandos reales.

---

## 2. Fundamentos

### 2.1 Dispositivos de bloque

Un **dispositivo de bloque** es un recurso del kernel al que se accede por bloques de tamaño fijo (típicamente 512 B o 4 KiB), no por carácter como un teclado. El kernel los expone bajo `/dev/`:

| Convención | Qué es |
|------------|--------|
| `/dev/sda`, `/dev/sdb` | discos SATA/SAS/USB (el kernel enumera en orden de detección — ¡no es estable!). |
| `/dev/nvme0n1` | el namespace `1` del controlador NVMe `0`. |
| `/dev/sda1`, `/dev/nvme0n1p1` | **particiones** dentro de ese disco. |
| `/dev/mapper/<name>` | dispositivos creados por `device-mapper` (LVM, LUKS, multipath). |
| `/dev/loop0` | un *archivo* presentado como dispositivo de bloque — base de los labs. |

Inspección rápida:

```bash
lsblk                  # árbol: disco → partición → LV → mountpoint
lsblk -f               # añade FSTYPE, UUID y LABEL
blkid                  # igual pero orientado a identificadores
cat /proc/partitions   # vista cruda del kernel
```

> **Advertencia nombre-vs-identidad.** `/dev/sdb` **hoy** puede ser `/dev/sdc` **mañana** tras un reboot si cambia el orden de enumeración USB. Nunca pongas `/dev/sdX` en `/etc/fstab`: usa `UUID=` o `LABEL=`. Explicado en §6.

### 2.2 Particiones: GPT vs MBR

Una **partición** es un rango contiguo de bloques dentro de un disco. La tabla de particiones vive en los primeros bloques del disco. Hay dos esquemas vigentes:

| Aspecto | MBR (Master Boot Record) | GPT (GUID Partition Table) |
|---------|--------------------------|-----------------------------|
| Año | 1983 | 2000 (parte de UEFI) |
| Tamaño máximo de disco | 2 TiB | 9.4 ZB (sí, zettabytes) |
| Particiones primarias | 4 (más extendidas/lógicas) | 128 por defecto |
| Checksum CRC32 | no | sí, con backup al final del disco |
| Identificador | tipo de 1 byte (0x83, 0x8E…) | GUID por partición |
| Bootloader | BIOS legacy | UEFI (y BIOS con GRUB bios_boot) |

**Regla práctica:** en 2026 usa GPT salvo que estés clonando una máquina legacy. Herramientas:

- `parted` — moderna, scriptable, hace GPT nativo. Mi recomendación.
- `fdisk` — moderna desde util-linux 2.23, también hace GPT. Interactivo cómodo.
- `gdisk` — específica para GPT, utilidad `sgdisk` para scripts.

### 2.3 Filesystems

Un **filesystem** es la estructura lógica que organiza los bloques en archivos, directorios y metadatos (permisos, timestamps, enlaces). Formatear es escribir las estructuras iniciales con `mkfs.<tipo>`.

### Comparativa de filesystems principales

| Capacidad | ext4 | xfs | btrfs |
|-----------|------|-----|-------|
| Journaling | sí (metadata; `data=ordered` por defecto) | sí (metadata) | copy-on-write (no journal clásico) |
| Crecer online (`mount`-ed) | sí (`resize2fs`) | sí (`xfs_growfs`) | sí |
| **Encoger** | sí (offline o con tooling cuidadoso) | **NO** | sí |
| Snapshots nativos | no (usar LVM o dm-thin) | no | sí |
| Checksums de datos | no | metadata sí, datos no | sí (datos y metadata) |
| Compresión transparente | no | no | sí (`zstd`, `lzo`) |
| Subvolúmenes | no | no | sí |
| Madurez en producción | muy alta (default Debian/Ubuntu) | muy alta (default RHEL) | buena, históricamente controvertida |
| Workload ideal | general-purpose | archivos grandes, alta concurrencia | NAS, snapshots frecuentes, dev stations |

**Por qué xfs no se puede encoger.** xfs fue diseñado por SGI para workloads donde "si tengo espacio, lo uso": asigna extents (rangos contiguos) agresivamente por todo el espacio y mantiene estructuras B+Tree distribuidas. Reducir el tamaño implicaría *reubicar* todos los extents vivos del área a cortar — una operación que los autores decidieron no implementar porque en el perfil de uso objetivo (SAN con LUNs grandes y crecientes) no vale la pena. Si eliges xfs y necesitas encoger: no puedes. Punto. Esto es **la razón** por la que mucha gente elige ext4 por defecto en VMs cuyo almacenamiento aún se dimensiona.

---

## 3. El ciclo mínimo: crear → formatear → montar

Flujo canónico sobre una partición nueva `/dev/sdb1` (ejemplo conceptual, los labs usan loopback):

```bash
# 1. Formatear como ext4 con una etiqueta identificable
sudo mkfs.ext4 -L datos /dev/sdb1

# 2. Crear el punto de montaje
sudo mkdir -p /mnt/datos

# 3. Montar manualmente (una vez)
sudo mount /dev/sdb1 /mnt/datos

# 4. Verificar
findmnt /mnt/datos
df -hT /mnt/datos
```

Esto **no sobrevive al reboot**. Para persistir, se usa `/etc/fstab` (§6) o una unit `.mount` de systemd (§7).

### 3.1 `mount` por dentro

`mount(8)` es un wrapper sobre la syscall `mount(2)`. Lo que hace:

1. Lee opciones (del fstab, de la línea de comandos, o defaults del fs).
2. Invoca `mount(2)` que pide al VFS del kernel asociar el dispositivo al punto de montaje con un driver de fs.
3. Si todo va bien, aparece en `/proc/mounts` y `/proc/self/mountinfo`.

```bash
cat /proc/mounts           # lo que el kernel ve ahora mismo
findmnt --real             # vista jerárquica legible (recomendado)
findmnt -T /home           # qué fs cubre este path
```

---

## 4. Identificadores estables: UUID y LABEL

Cada filesystem tiene un **UUID** generado al formatear:

```bash
blkid /dev/sdb1
# /dev/sdb1: LABEL="datos" UUID="4e3a..." TYPE="ext4" PARTUUID="..."
```

Hay cuatro identificadores distintos — no los confundas:

| Identificador | Vive en | Lo cambia |
|---------------|---------|-----------|
| `UUID=` | superblock del filesystem | `mkfs` o `tune2fs -U` |
| `LABEL=` | superblock del filesystem | `mkfs -L` o `e2label` / `xfs_admin -L` |
| `PARTUUID=` | tabla GPT | reparticionar |
| `PARTLABEL=` | tabla GPT | reparticionar |

**Regla:** en fstab usa `UUID=` (persistente al mover el disco, sobrevive al cambio de nombre). `LABEL=` es cómodo pero colisiona si clonas filesystems.

---

## 5. `/etc/fstab` anotado

El fichero `/etc/fstab` describe qué montar al arrancar. Un ejemplo real anotado:

```
# <spec>                                   <mountpoint>  <fstype>  <options>                 <dump> <pass>
UUID=4e3a1c88-7f6c-4b9d-9d2a-7e0a6b3c1f22  /             ext4      defaults,errors=remount-ro  0     1
UUID=0b22b4e0-aa11-4b7f-9f2d-1a8c0e4d9bb2  /boot         ext4      defaults                    0     2
UUID=8CAC-21E3                             /boot/efi     vfat      umask=0077                  0     1
UUID=f1a0d7e2-33ab-4211-9c4e-5c2d8e9b1a04  /home         xfs       defaults,noatime            0     0
tmpfs                                      /tmp          tmpfs     defaults,size=2G,mode=1777  0     0
/swap.img                                  none          swap      sw                          0     0
# bind mount: proyectos accesibles desde dos rutas
/srv/projects                              /home/eva/projects  none  bind                      0     0
```

Campo a campo:

1. **`<spec>`** — qué montar. Prefiere `UUID=` o `LABEL=`. `tmpfs` para RAM-fs. Ruta absoluta para swap files y bind.
2. **`<mountpoint>`** — dónde. Debe existir. `none` para swap y bind source.
3. **`<fstype>`** — `ext4`, `xfs`, `vfat`, `tmpfs`, `swap`, `none` (para bind), `nfs`, etc.
4. **`<options>`** — separadas por coma, sin espacios. `defaults` = `rw,suid,dev,exec,auto,nouser,async`. Comunes útiles:
   - `noatime` — no actualizar access time (gran ganancia de I/O en lectura intensiva).
   - `nofail` — no bloquear boot si falta el dispositivo (p. ej. disco USB).
   - `x-systemd.automount` — montaje perezoso al primer acceso.
   - `ro` — solo lectura.
   - `errors=remount-ro` — si el fs detecta corrupción, remontar RO en vez de panic.
5. **`<dump>`** — flag para la utilidad `dump(8)`, obsoleta. Siempre `0`.
6. **`<pass>`** — orden de `fsck` al boot. `1` para root, `2` para los demás con fs, `0` para no chequear (tmpfs, swap, bind, remotos).

Validar fstab **sin reiniciar**:

```bash
sudo mount -a            # intenta montar todo lo marcado para auto
findmnt --verify         # chequeo semántico de /etc/fstab
```

> **Advertencia.** Un `/etc/fstab` roto puede dejar la máquina sin boot. Siempre valida con `findmnt --verify` y `mount -a` **antes** de reiniciar. En VMs, snapshot antes de tocar.

---

## 6. Unidades `.mount` de systemd

Alternativa moderna a fstab. systemd puede *generar* units automáticamente desde fstab, pero puedes escribir las tuyas:

```ini
# /etc/systemd/system/mnt-datos.mount
[Unit]
Description=Montar /mnt/datos
After=local-fs.target

[Mount]
What=/dev/disk/by-uuid/4e3a1c88-7f6c-4b9d-9d2a-7e0a6b3c1f22
Where=/mnt/datos
Type=ext4
Options=defaults,noatime

[Install]
WantedBy=multi-user.target
```

**Convención crítica:** el nombre del archivo **debe** coincidir con el `Where=` sustituyendo `/` por `-`. `/mnt/datos` → `mnt-datos.mount`. Si no, systemd lo rechaza.

Ventajas sobre fstab:
- Dependencias explícitas (`After=`, `Requires=`).
- Montaje perezoso con un `.automount` compañero.
- Logging en journal.

Para empezar: usa fstab salvo que necesites algo que fstab no da.

---

## 7. LVM — Logical Volume Manager

LVM es la pieza que convierte "tengo este disco" en "tengo una piscina de almacenamiento que distribuyo como quiero y crezco cuando necesito".

### 7.1 El modelo PV → VG → LV

```
                       Volume Group  "vg_data"
         ┌────────────────────────────────────────────────────┐
         │                                                    │
    ┌────┴────┐          ┌──────────┐          ┌──────────┐   │
    │  PV #1  │          │  PV #2   │          │  PV #3   │   │
    │ /dev/sdb│          │/dev/sdc1 │          │/dev/sdd1 │   │
    │   1 TB  │          │  500 GB  │          │  500 GB  │   │
    └─────────┘          └──────────┘          └──────────┘   │
         │                                                    │
         │  2 TB totales distribuidos en extents (4 MiB)      │
         │                                                    │
         │   ┌─────────────────┐   ┌───────────────────┐      │
         │   │   LV "lv_root"  │   │   LV "lv_home"    │      │
         │   │     200 GB      │   │      800 GB       │      │
         │   │   → ext4  → /   │   │   → xfs  → /home  │      │
         │   └─────────────────┘   └───────────────────┘      │
         └────────────────────────────────────────────────────┘
```

**Las tres capas:**

- **PV (Physical Volume)** — un dispositivo de bloque "ofrecido" a LVM. Puede ser un disco entero (`/dev/sdb`) o una partición (`/dev/sdc1`). Se crea con `pvcreate`.
- **VG (Volume Group)** — un pool que agrupa uno o más PVs. Expone capacidad total como "extents" (unidad mínima, 4 MiB por defecto). Se crea con `vgcreate <nombre> <PV1> <PV2> ...`.
- **LV (Logical Volume)** — un "disco virtual" tallado del VG. Aparece en `/dev/mapper/<vg>-<lv>` y `/dev/<vg>/<lv>`. Se crea con `lvcreate -L <tamaño> -n <nombre> <vg>`.

### 7.2 Comandos esenciales

```bash
# Inspección
pvs                              # tabla resumen de PVs
vgs                              # tabla resumen de VGs
lvs                              # tabla resumen de LVs
pvdisplay / vgdisplay / lvdisplay  # formato verbose

# Crear
sudo pvcreate /dev/sdb1
sudo vgcreate vg_data /dev/sdb1
sudo lvcreate -L 10G -n lv_app vg_data
sudo mkfs.ext4 /dev/vg_data/lv_app

# Crecer un LV en caliente (y el fs encima)
sudo lvextend -L +5G /dev/vg_data/lv_app
sudo resize2fs /dev/vg_data/lv_app       # ext4
# — o —
sudo xfs_growfs /mountpoint              # xfs (toma el MOUNTPOINT, no el device)

# Atajo: extender y crecer el fs en un paso
sudo lvextend -r -L +5G /dev/vg_data/lv_app

# Añadir un PV nuevo al VG
sudo pvcreate /dev/sdc1
sudo vgextend vg_data /dev/sdc1

# Encoger (solo si el fs lo soporta — xfs NO)
sudo umount /mnt/app
sudo e2fsck -f /dev/vg_data/lv_app
sudo resize2fs /dev/vg_data/lv_app 8G
sudo lvreduce -L 8G /dev/vg_data/lv_app
```

> **Advertencia.** Para encoger: **primero** el filesystem, **después** el LV. Si lo haces al revés, pierdes datos. `lvreduce` te avisa, pero no te salva si confirmas sin leer. Y recuerda: xfs no se encoge.

### 7.3 Snapshots LVM

Un **snapshot** es un LV especial que captura el estado del origen *en un instante*. Usa **copy-on-write (COW)**: no copia los datos; cuando el origen va a modificar un bloque, LVM copia el bloque *original* al snapshot antes del cambio. El snapshot "vive" en el delta.

```bash
# Crear snapshot de 2 GB del LV lv_app
sudo lvcreate -L 2G -s -n lv_app_snap /dev/vg_data/lv_app

# Montarlo (típicamente read-only, para backup)
sudo mkdir -p /mnt/snap
sudo mount -o ro /dev/vg_data/lv_app_snap /mnt/snap

# ... hacer el backup, inspeccionar ...

# Rollback total al estado del snapshot
sudo umount /mnt/app
sudo lvconvert --merge /dev/vg_data/lv_app_snap
# El merge ocurre en el próximo mount si el LV estaba en uso.
```

**Puntos críticos:**

- El snapshot debe tener **espacio suficiente** para los cambios acumulados. Si se llena, se **invalida** (irrecuperable). Monitorea con `lvs` — la columna `Data%` sube con los cambios.
- Un snapshot **no es un backup**: vive en el mismo VG. Un disco muerto se los lleva a los dos.
- Snapshots clásicos degradan el rendimiento del origen (toda escritura genera una lectura+escritura extra). Para producción: considera thin snapshots (`lvcreate --thinpool`).
- Al hacer `--merge`, el snapshot desaparece tras consolidarse.

---

## 8. tmpfs y bind mounts

Dos tipos de montaje que no corresponden a un dispositivo de bloque:

### tmpfs — filesystem en RAM

```bash
sudo mount -t tmpfs -o size=1G tmpfs /mnt/scratch
```

Vive en memoria (parcialmente paginada a swap si falta RAM). Se **borra al reiniciar**. Útil para datos efímeros de alto rendimiento: cachés, builds, scratch de pipelines. `/tmp` suele ser tmpfs en servidores modernos.

### Bind mounts — exponer la misma rama en dos sitios

```bash
sudo mount --bind /srv/projects /home/eva/projects
```

Mismo inode-set accesible desde dos paths. Útil para contenedores (bind monta volúmenes del host), chroot, dejar accesible una ruta profunda sin symlink. En fstab: tipo `none`, opciones `bind`.

---

## 9. Internals ligeros

### 9.1 El block layer

Entre el filesystem y el driver del dispositivo hay una capa — el **block layer** — que recibe `bio` requests (operaciones I/O), las encola, las agrupa (merging) y las ordena antes de pasarlas al dispositivo.

### 9.2 I/O schedulers

El scheduler decide **en qué orden** se envían las operaciones encoladas al dispositivo. Linux moderno usa el framework multi-queue (`blk-mq`); los schedulers disponibles son:

| Scheduler | Para |
|-----------|------|
| `none` | NVMe (el dispositivo ya ordena mejor que el kernel). |
| `mq-deadline` | SSD/SATA, workloads mixtos. Buen default. |
| `kyber` | SSD, baja latencia. |
| `bfq` | HDD y desktop (prioriza respuesta interactiva). |

```bash
# Ver scheduler actual de un disco
cat /sys/block/nvme0n1/queue/scheduler
# [none] mq-deadline kyber bfq

# Cambiarlo (no persistente)
echo mq-deadline | sudo tee /sys/block/sda/queue/scheduler
```

En práctica rara vez se toca; distros modernas eligen razonablemente. Impórtalo cuando debuguees latencia de I/O.

### 9.3 device-mapper

LVM está construido sobre **device-mapper** (`dm`), un framework del kernel para componer dispositivos virtuales. Lo mismo que usa LUKS (encriptación), multipath (HA), y dm-cache. Explorable:

```bash
ls -la /dev/mapper/
sudo dmsetup ls --tree
```

---

## 10. Errores frecuentes y antipatrones

- **Poner `/dev/sdb1` en fstab.** Rompe al cambiar el orden de enumeración. Usa `UUID=`.
- **`mkfs.ext4 -f` sobre el disco equivocado.** `-f` fuerza aunque haya un fs presente. **Lee dos veces el path.** Usa `lsblk` justo antes.
- **Encoger un LV sin encoger antes el filesystem.** Pierdes datos. Primero `resize2fs <tamaño>`, luego `lvreduce`.
- **Dejar un snapshot LVM clásico olvidado en producción.** Degrada I/O y puede llenarse. Monitorea `Data%` o automatiza expiración.
- **No usar `nofail` en discos removibles.** El boot cuelga si falta el USB.
- **Confundir `UUID=` del filesystem con `PARTUUID=` de la partición.** Son identificadores distintos; cambian independientemente.
- **Olvidar `sync` o `umount` antes de desconectar un USB.** El kernel buferiza — `cp` que "terminó" puede no estar en disco.

---

## 11. Decisiones de diseño típicas

| Pregunta | Guía |
|----------|------|
| ¿GPT o MBR? | GPT, siempre que puedas. |
| ¿ext4 o xfs? | ext4 si vas a redimensionar hacia abajo o la máquina es "general-purpose". xfs si archivos grandes, alta concurrencia, nunca encoges. |
| ¿Particiones directas o LVM? | LVM si existe la posibilidad de crecer, mover entre discos o snapshots. Particiones directas si es un embedded con footprint fijo. |
| ¿Separar `/`, `/var`, `/home`? | Sí para servidores: aísla llenado de logs (`/var`) del root; `/home` sobrevive a reinstalaciones. |
| ¿Tamaño de LV al crear? | Pequeño. Crece bajo demanda. Un VG con 50% libre al principio es más valioso que LVs pre-dimensionados "por si acaso". |
| ¿Snapshot para backup? | Monta el snapshot RO, haz el backup desde ahí (consistencia). No es el backup en sí mismo. |

---

## 12. Preguntas de reflexión

Responde sin consultar antes de pasar al siguiente módulo:

1. Un compañero clona una VM. Al arrancar la copia, falla el boot con "cannot find root device". Sabes que el fstab usa `UUID=`. Hipotetiza la causa y proponé el fix.
2. Diseñas el almacenamiento de un servidor con un disco de 500 GB. ¿Qué layout LVM eliges para `/`, `/var`, `/home`, swap? ¿Qué dejas sin asignar y por qué?
3. Un filesystem xfs al 95% empieza a dar latencia alta. ¿Qué opciones tienes para añadirle espacio sin downtime? ¿Y si fuera ext4 y necesitaras *reducir* su tamaño?
4. Explica, en términos de COW, por qué un snapshot LVM de 1 GB puede "llenarse" aunque el LV origen tenga solo 500 MB de cambios. ¿Qué pasa cuando se llena?
5. En `/etc/fstab`, ¿qué diferencia operativa real hay entre poner `0` o `2` en el campo `<pass>` de un filesystem de datos no-root?
6. Tu laptop monta un disco externo USB con `/etc/fstab`. Un día arrancas sin el disco conectado y la máquina se queda en el prompt de emergencia. ¿Qué opción cambia este comportamiento?
7. Un `mkfs.ext4` sobre el disco equivocado destruyó datos. ¿Qué información tendrías que haber consultado **antes** de pulsar Enter y con qué comando?
8. ¿Por qué `xfs_growfs` recibe un *mountpoint* y `resize2fs` un *device*? ¿Qué dice esto del diseño de cada filesystem?

---

## 13. Resumen operativo

- Dispositivo → partición → (LVM) → filesystem → mountpoint. Conoce la pila.
- GPT por defecto. ext4 si redimensionas hacia abajo, xfs si no.
- fstab con `UUID=`. Valida con `findmnt --verify` y `mount -a` antes de reiniciar.
- LVM: PV → VG → LV. Crece en caliente con `lvextend -r`. Encoge solo si el fs lo soporta y en orden fs→LV.
- Snapshots: COW, mismo VG, no son backup, se invalidan si se llenan. Útiles para rollback atómico y backups consistentes.
- tmpfs para RAM, bind para exponer rama en dos sitios.
- `lsblk` antes de cada `mkfs`. Siempre.
