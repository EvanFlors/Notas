# sys-08 — Storage, volúmenes y LVM

## Identificación

- **ID:** `sys-08-storage-volumes-and-lvm`
- **Curso:** `00-Sysadmin`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `sys-03` (filesystem Linux, permisos), `sys-04` (procesos y señales).

## Objetivo

Gestionar discos, particiones, filesystems, montajes y **LVM** (Logical Volume Manager) para **crecer y encoger** almacenamiento sin reinstalar ni reparticionar manualmente. Al terminar deberías poder diseñar un layout LVM, montar filesystems de forma persistente y tomar snapshots consistentes para rollback.

## Alcance

Este módulo cubre:

- Modelo de dispositivos de bloque: `/dev/sdX`, `/dev/nvme0n1`, `/dev/mapper/*`.
- Tabla de particiones: **GPT** vs **MBR**, herramientas `parted` y `fdisk`.
- Filesystems: `ext4`, `xfs`, `btrfs` — trade-offs y cuándo usar cada uno.
- Formateo (`mkfs.ext4`, `mkfs.xfs`), montaje (`mount`, `umount`, `findmnt`).
- Persistencia de montajes: `/etc/fstab`, por qué usar `UUID=` o `LABEL=` en vez de `/dev/sdX`.
- Unidades `.mount` de systemd como alternativa a fstab.
- **LVM**: pila PV → VG → LV; `pvcreate`, `vgcreate`, `lvcreate`, `lvextend`, `resize2fs`, `xfs_growfs`.
- Snapshots LVM: cómo funcionan (copy-on-write), tamaño del snapshot, rollback.
- Tipos especiales: `tmpfs` (RAM) y bind mounts.
- Internals ligeros: block layer, I/O schedulers y por qué xfs **no se puede encoger**.

Lo que **no** cubre:
- RAID por software (`mdadm`) → mencionado, no profundizado.
- Encriptación LUKS → `sys-13`.
- Filesystems de red (NFS, SMB) → `sys-10`+.
- ZFS → fuera del scope del curso base.

## Materiales

- **`theory/lesson.md`** — lección profunda (~500 líneas) con diagrama PV→VG→LV, tabla comparativa ext4/xfs/btrfs, fstab anotado y recuadros de advertencia.
- **`examples/`** — ejemplos demostrativos:
  - `01-fstab-anatomy/` — leer un `/etc/fstab` campo por campo.
  - `02-lvm-on-loopback/` — montar un stack LVM completo sobre archivos loopback (sin disco real).
- **`activities/`** — dos actividades aplicadas:
  - `01-grow-a-filesystem-online/` — crecer un LV + filesystem **en caliente** (guided-lab, 60 min).
  - `02-lvm-snapshot-and-rollback/` — tomar un snapshot, romper el LV y restaurar (independent, 60 min).
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre partición, PV, VG y LV. Decir por qué xfs no se encoge y qué implica para diseño. Describir cómo funciona un snapshot LVM (COW). |
| Operativa | Crear una partición GPT, formatear, montar persistentemente por UUID, crear un stack LVM, extender un LV y crecer el filesystem **sin desmontar**, tomar snapshot y hacer rollback. |
| Arquitectónica | Diseñar un layout de disco separando `/`, `/var` y `/home` con criterios de crecimiento. Elegir ext4 vs xfs según perfil de workload y requisitos de redimensión. |

## Criterios de evaluación

- Un stack `PV → VG → LV` creado sobre loopback, con filesystem montado por UUID.
- Un LV crecido en caliente (sin `umount`) con filesystem acompañando.
- Un snapshot LVM creado, el origen modificado, y rollback verificado por hash.
- `tests/validate.sh` pasa en ambas actividades.
- Respuesta argumentada a las preguntas de reflexión de la lección.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada; densidad alta — vuelve a tabla comparativa cuando dudes).
2. Reproduce `examples/01-fstab-anatomy/` con tu propio `/etc/fstab` abierto al lado.
3. Reproduce `examples/02-lvm-on-loopback/` paso a paso — este es el "tanque de pruebas" para todo el módulo.
4. Haz la actividad `activities/01-grow-a-filesystem-online/` (guided).
5. Haz la actividad `activities/02-lvm-snapshot-and-rollback/` (independent).
6. Vuelve a `theory/lesson.md` §11–12 y responde las preguntas de reflexión sin consultar.

## Advertencia operativa

Todas las actividades usan **archivos loopback** (`/tmp/*.img` + `losetup`) para que *no haya ningún disco real en riesgo*. Aun así, cualquier comando que use `mkfs`, `parted`, `dd` o `wipefs` sobre un dispositivo equivocado **destruye datos irreversiblemente**. Lee dos veces antes de pulsar Enter. Los scripts del módulo exigen `CONFIRM=yes` para operaciones destructivas.

## Siguiente

→ `sys-09-scheduling-cron-and-timers`: programar trabajos recurrentes (cron, systemd timers).
