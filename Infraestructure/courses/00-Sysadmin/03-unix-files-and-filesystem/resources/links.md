# Recursos — sys-03

## Estándares

- **Filesystem Hierarchy Standard 3.0 (oficial, Linux Foundation)** — <https://refspecs.linuxfoundation.org/fhs.shtml>
- **FHS 3.0 HTML completo** — <https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html>
- **POSIX / Open Group — "File System"** — <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap04.html>

## Man pages (man7.org — canónicas)

- **`inode(7)`** — anatomía del inodo. <https://man7.org/linux/man-pages/man7/inode.7.html>
- **`symlink(7)`** — semántica de symlinks. <https://man7.org/linux/man-pages/man7/symlink.7.html>
- **`path_resolution(7)`** — cómo el kernel resuelve rutas. <https://man7.org/linux/man-pages/man7/path_resolution.7.html>
- **`hier(7)`** — jerarquía del filesystem (equivalente man a FHS). <https://man7.org/linux/man-pages/man7/hier.7.html>
- **`find(1)`** — <https://man7.org/linux/man-pages/man1/find.1.html>
- **`xargs(1)`** — <https://man7.org/linux/man-pages/man1/xargs.1.html>
- **`stat(1)`** y **`stat(2)`** — <https://man7.org/linux/man-pages/man1/stat.1.html> · <https://man7.org/linux/man-pages/man2/stat.2.html>
- **`ln(1)`** — <https://man7.org/linux/man-pages/man1/ln.1.html>
- **`readlink(1)`** y **`readlink(2)`** — <https://man7.org/linux/man-pages/man1/readlink.1.html>
- **`proc(5)`** — descripción exhaustiva de `/proc`. <https://man7.org/linux/man-pages/man5/proc.5.html>
- **`sysfs(5)`** — <https://man7.org/linux/man-pages/man5/sysfs.5.html>
- **`mount(8)`** — <https://man7.org/linux/man-pages/man8/mount.8.html>
- **`findmnt(8)`** — <https://man7.org/linux/man-pages/man8/findmnt.8.html>

## Kernel documentation (ejecutable y versionada)

- **`Documentation/filesystems/proc.rst`** — <https://www.kernel.org/doc/html/latest/filesystems/proc.html>
- **`Documentation/filesystems/sysfs.rst`** — <https://www.kernel.org/doc/html/latest/filesystems/sysfs.html>
- **`Documentation/filesystems/vfs.rst`** — <https://www.kernel.org/doc/html/latest/filesystems/vfs.html>
- **`Documentation/filesystems/ext4.rst`** — <https://www.kernel.org/doc/html/latest/filesystems/ext4/index.html>
- **`Documentation/filesystems/xfs.rst`** — <https://www.kernel.org/doc/html/latest/filesystems/xfs/index.html>
- **`Documentation/filesystems/btrfs.rst`** — <https://btrfs.readthedocs.io/en/latest/>

## Herramientas útiles

- **`shellcheck`** — linter de shell. <https://www.shellcheck.net/>
- **`mlocate` / `plocate`** — índices rápidos de archivos. <https://man7.org/linux/man-pages/man1/locate.1.html>
- **`ncdu`** — navegador interactivo de uso de disco. <https://dev.yorhel.nl/ncdu>

## Complementario (lectura)

- **"The Linux Programming Interface" — Michael Kerrisk**, caps. 4, 14, 15, 18. Referencia definitiva en semántica de archivos e inodos.
- **"Advanced Programming in the UNIX Environment" — Stevens & Rago**, cap. 4 "Files and Directories".
- **"How Linux Works" — Brian Ward**, caps. 2–4 (orientado a sysadmin).

## Nota de verificación

Última verificación de enlaces: pendiente de validar al ejecutar el módulo. Todos los dominios son oficiales (`linuxfoundation.org`, `man7.org`, `kernel.org`, `opengroup.org`).
