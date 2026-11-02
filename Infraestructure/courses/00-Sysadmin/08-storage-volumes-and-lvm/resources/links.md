# Recursos — sys-08

## Documentación oficial

### Manpages (sección 8 — administración)

- **`lvm(8)`** — <https://man7.org/linux/man-pages/man8/lvm.8.html>
- **`pvcreate(8)`** — <https://man7.org/linux/man-pages/man8/pvcreate.8.html>
- **`vgcreate(8)`** — <https://man7.org/linux/man-pages/man8/vgcreate.8.html>
- **`lvcreate(8)`** — <https://man7.org/linux/man-pages/man8/lvcreate.8.html>
- **`lvextend(8)`** — <https://man7.org/linux/man-pages/man8/lvextend.8.html>
- **`lvconvert(8)`** — <https://man7.org/linux/man-pages/man8/lvconvert.8.html>
- **`mkfs.ext4(8)`** — <https://man7.org/linux/man-pages/man8/mkfs.ext4.8.html>
- **`mkfs.xfs(8)`** — <https://man7.org/linux/man-pages/man8/mkfs.xfs.8.html>
- **`mount(8)`** — <https://man7.org/linux/man-pages/man8/mount.8.html>
- **`fstab(5)`** — <https://man7.org/linux/man-pages/man5/fstab.5.html>
- **`resize2fs(8)`** — <https://man7.org/linux/man-pages/man8/resize2fs.8.html>
- **`xfs_growfs(8)`** — <https://man7.org/linux/man-pages/man8/xfs_growfs.8.html>
- **`losetup(8)`** — <https://man7.org/linux/man-pages/man8/losetup.8.html>
- **`parted(8)`** — <https://man7.org/linux/man-pages/man8/parted.8.html>
- **`findmnt(8)`** — <https://man7.org/linux/man-pages/man8/findmnt.8.html>

### Guías de administración

- **Red Hat — Configuring and managing logical volumes** (guía oficial LVM, aplicable a cualquier distro) — <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_logical_volumes/>
- **Red Hat — Managing file systems** — <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/managing_file_systems/>
- **Debian Wiki — LVM** — <https://wiki.debian.org/LVM>
- **Arch Wiki — LVM** (muy didáctico) — <https://wiki.archlinux.org/title/LVM>
- **Arch Wiki — File systems** (comparativa práctica) — <https://wiki.archlinux.org/title/File_systems>
- **Arch Wiki — fstab** — <https://wiki.archlinux.org/title/Fstab>

### Documentación del kernel (filesystems e I/O)

- **Kernel docs — filesystems overview** — <https://www.kernel.org/doc/html/latest/filesystems/index.html>
- **ext4 filesystem** — <https://www.kernel.org/doc/html/latest/filesystems/ext4/index.html>
- **XFS filesystem** — <https://www.kernel.org/doc/html/latest/filesystems/xfs/index.html>
- **btrfs filesystem** — <https://docs.kernel.org/filesystems/btrfs.html>
- **Block layer & schedulers** — <https://www.kernel.org/doc/html/latest/block/index.html>
- **device-mapper** — <https://docs.kernel.org/admin-guide/device-mapper/index.html>

## Complementario

- **"How does LVM work?"** (introducción visual) — <https://tldp.org/HOWTO/LVM-HOWTO/>
- **xfs FAQ — "Why can't I shrink an XFS filesystem?"** — <https://xfs.org/docs/xfsdocs-xml-dev/XFS_FAQ/tmp/en-US/html/ch01s09.html>
- **systemd `.mount` units** — <https://www.freedesktop.org/software/systemd/man/systemd.mount.html>
- **systemd `.automount` units** — <https://www.freedesktop.org/software/systemd/man/systemd.automount.html>

## Herramientas útiles

- **`ncdu`** — explorador interactivo de uso de disco: <https://dev.yorhel.nl/ncdu>
- **`gdu`** — alternativa en Go, más rápido: <https://github.com/dundee/gdu>
- **`iotop`** — top por I/O: <https://man7.org/linux/man-pages/man8/iotop.8.html>
- **`fio`** — benchmark de I/O (para evaluar schedulers): <https://fio.readthedocs.io/>

## Nota de verificación

Última verificación de enlaces: pendiente de validar en Fase 4 (lecciones ejecutables). Todos los enlaces apuntan a dominios oficiales (`man7.org`, `kernel.org`, `docs.redhat.com`, wikis de distros reconocidas); verificar fecha y disponibilidad al momento de desarrollar el curso en producción.
