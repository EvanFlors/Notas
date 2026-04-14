# Bash & Linux — Guía Completa para Cloud Engineering

> **Idea central:** El shell es la interfaz universal de Linux.
> Todo servidor en la nube — AWS EC2, Azure VM, GCP Compute Engine — se administra a través de Bash. Dominar la línea de comandos no es opcional: es la habilidad #1 que separa a un ingeniero que opera infraestructura de uno que solo la consume. Con un puñado de comandos, scripts, y buenas prácticas de seguridad, puedes administrar fleets de miles de servidores tan fácilmente como uno solo.

---

## Tabla de Contenidos

**Parte I — Fundamentos**
1. [Introducción a Linux y Bash](#1-introducción-a-linux-y-bash)
2. [Distribuciones Linux](#2-distribuciones-linux)
3. [El Shell y la Terminal](#3-el-shell-y-la-terminal)
4. [Anatomía de un Comando](#4-anatomía-de-un-comando)

**Parte II — Navegación y Gestión de Archivos**
5. [Navegación del File System](#5-navegación-del-file-system)
6. [Gestión de Archivos y Directorios](#6-gestión-de-archivos-y-directorios)
7. [Búsqueda de Archivos](#7-búsqueda-de-archivos)
8. [Links (Symlinks y Hard Links)](#8-links-symlinks-y-hard-links)

**Parte III — Visualización y Procesamiento de Texto**
9. [Visualización de Archivos](#9-visualización-de-archivos)
10. [grep — Búsqueda de Patrones](#10-grep--búsqueda-de-patrones)
11. [sed — Stream Editor](#11-sed--stream-editor)
12. [awk — Procesamiento de Columnas](#12-awk--procesamiento-de-columnas)
13. [Pipelines y Redirección](#13-pipelines-y-redirección)

**Parte IV — Usuarios y Permisos**
14. [Modelo de Permisos Unix](#14-modelo-de-permisos-unix)
15. [Gestión de Usuarios y Grupos](#15-gestión-de-usuarios-y-grupos)
16. [sudo y Privilegios](#16-sudo-y-privilegios)

**Parte V — Procesos y Servicios**
17. [Gestión de Procesos](#17-gestión-de-procesos)
18. [systemctl y Servicios](#18-systemctl-y-servicios)
19. [Logs con journalctl](#19-logs-con-journalctl)
20. [Cron Jobs y Automatización](#20-cron-jobs-y-automatización)

**Parte VI — Networking**
21. [Comandos de Red](#21-comandos-de-red)
22. [SSH — Secure Shell](#22-ssh--secure-shell)
23. [Transferencia de Archivos (scp, rsync)](#23-transferencia-de-archivos-scp-rsync)
24. [curl y wget](#24-curl-y-wget)

**Parte VII — Package Management**
25. [APT (Debian/Ubuntu)](#25-apt-debianubuntu)
26. [YUM / DNF (RHEL/CentOS/Fedora)](#26-yum--dnf-rhelcentosfedora)
27. [Alpine apk y Snap](#27-alpine-apk-y-snap)

**Parte VIII — Disco y Almacenamiento**
28. [Gestión de Disco](#28-gestión-de-disco)
29. [Monitoreo del Sistema](#29-monitoreo-del-sistema)

**Parte IX — Shell Scripting**
30. [Fundamentos de Scripting](#30-fundamentos-de-scripting)
31. [Variables, Condicionales y Loops](#31-variables-condicionales-y-loops)
32. [Funciones y Scripts Avanzados](#32-funciones-y-scripts-avanzados)

**Parte X — Cloud, Seguridad y Troubleshooting**
33. [Seguridad y Hardening](#33-seguridad-y-hardening)
34. [Troubleshooting en Cloud Servers](#34-troubleshooting-en-cloud-servers)
35. [Tips y Buenas Prácticas](#35-tips-y-buenas-prácticas)

---

# PARTE I — FUNDAMENTOS

---

# 1. Introducción a Linux y Bash

## 1.1 ¿Qué es Linux?

```text
Linux es un kernel (núcleo) de sistema operativo creado por Linus Torvalds en 1991.
Combinado con las herramientas GNU, forma un SO completo (GNU/Linux).

¿Por qué importa para cloud?
  → ~96% de los servidores en la nube corren Linux
  → AWS, Azure, GCP: todas ofrecen Linux como opción principal
  → Más ligero, más seguro, más eficiente que Windows Server
  → Docker, Kubernetes, la mayoría de DevOps tools: Linux-native
```

## 1.2 ¿Qué es Bash?

```text
Bash = Bourne Again SHell

Es el shell (intérprete de comandos) por defecto en la mayoría de
distribuciones Linux. Cuando abres una terminal, estás en Bash.

Shell ≠ Terminal:
  Terminal = la ventana/aplicación (emulador de terminal)
  Shell    = el programa que interpreta tus comandos (bash, zsh, fish)

En macOS moderno: el shell por defecto es zsh, pero Bash está disponible.
En Ubuntu/Debian: Bash es el shell por defecto.
En Alpine: sh (ash) es el default; instalar bash con `apk add bash`.
```

## 1.3 Linux en Cloud Environments

```text
┌──────────────────────────────────────────────────────────────┐
│  Cloud Provider     │  Default Linux AMIs/Images             │
├─────────────────────┼────────────────────────────────────────┤
│  AWS EC2            │  Amazon Linux 2023, Ubuntu, RHEL       │
│  Azure VM           │  Ubuntu, RHEL, CentOS, Debian          │
│  GCP Compute Engine │  Debian, Ubuntu, CentOS, RHEL          │
│  Docker             │  Alpine, Ubuntu, Debian (slim)         │
└─────────────────────┴────────────────────────────────────────┘

Conexión típica:
  ssh -i my-key.pem ec2-user@<public-ip>     # AWS
  ssh -i my-key.pem azureuser@<public-ip>    # Azure
  ssh -i my-key.pem <username>@<public-ip>   # GCP
```

---

# 2. Distribuciones Linux

## 2.1 Familias principales

```text
┌────────────────────┬───────────────────┬─────────────┬──────────────┐
│  Familia           │  Distribuciones   │  Pkg Manager│  Pkg Format  │
├────────────────────┼───────────────────┼─────────────┼──────────────┤
│  Debian-based      │  Ubuntu, Debian   │  apt        │  .deb        │
│                    │  Linux Mint       │             │              │
│  RHEL-based        │  RHEL, CentOS     │  yum / dnf  │  .rpm        │
│                    │  Fedora, Rocky    │             │              │
│                    │  Amazon Linux     │             │              │
│  Alpine            │  Alpine Linux     │  apk        │  .apk        │
│  Arch-based        │  Arch, Manjaro    │  pacman     │  .pkg.tar.zst│
│  SUSE-based        │  openSUSE, SLES   │  zypper     │  .rpm        │
└────────────────────┴───────────────────┴─────────────┴──────────────┘
```

## 2.2 Diferencias clave entre distribuciones

```text
1. Package Management:
   Debian/Ubuntu → apt (dpkg debajo)
   RHEL/CentOS  → dnf (reemplazó yum; rpm debajo)
   Alpine       → apk (extremadamente ligero)

2. Init System:
   Mayoría moderna → systemd (systemctl)
   Alpine          → OpenRC (rc-service, rc-update)
   Legacy          → SysVinit (service, chkconfig)

3. Release Cycle:
   Ubuntu LTS        → soporte 5 años (22.04, 24.04)
   RHEL              → soporte 10 años
   Arch / Rolling    → actualizaciones continuas
   Alpine            → releases cada ~6 meses

4. Tamaño base (Docker image):
   Alpine    → ~5 MB (ideal para containers)
   Debian    → ~120 MB
   Ubuntu    → ~75 MB
   CentOS    → ~200 MB

5. Shell por defecto:
   Ubuntu/Debian → bash
   Alpine        → ash (BusyBox sh)
   macOS         → zsh
```

---

# 3. El Shell y la Terminal

## 3.1 El prompt

```bash
# Formato típico:
usuario@hostname:directorio$

# Ejemplos reales:
ubuntu@ip-172-31-40-2:~$              # EC2 Ubuntu
[ec2-user@ip-10-0-1-5 ~]$             # Amazon Linux
root@690d0307b09f:/#                  # Docker container

# Desglose:
#   ubuntu     → usuario actual
#   @          → separador
#   ip-172...  → hostname (nombre de la máquina)
#   :~         → directorio actual (~ = home)
#   $          → usuario normal  (# = root)
```

## 3.2 Atajos esenciales de teclado

```text
┌──────────────┬───────────────────────────────────────┐
│  Atajo       │  Acción                               │
├──────────────┼───────────────────────────────────────┤
│  Ctrl + C    │  Cancelar comando actual              │
│  Ctrl + D    │  EOF / salir del shell                │
│  Ctrl + Z    │  Suspender proceso (enviar a bg)      │
│  Ctrl + L    │  Limpiar pantalla (= clear)           │
│  Ctrl + R    │  Buscar en historial de comandos      │
│  Ctrl + A    │  Ir al inicio de la línea             │
│  Ctrl + E    │  Ir al final de la línea              │
│  Ctrl + W    │  Borrar palabra anterior              │
│  Ctrl + U    │  Borrar desde cursor al inicio        │
│  Ctrl + K    │  Borrar desde cursor al final         │
│  Tab         │  Autocompletar                        │
│  Tab Tab     │  Mostrar opciones de autocompletado   │
│  ↑ / ↓       │  Navegar historial                    │
│  !!          │  Repetir último comando               │
│  !$          │  Último argumento del comando previo  │
└──────────────┴───────────────────────────────────────┘
```

## 3.3 Variables de entorno importantes

```bash
echo $HOME         # Directorio home del usuario (/home/ubuntu)
echo $USER         # Usuario actual (ubuntu)
echo $SHELL        # Shell actual (/bin/bash)
echo $PATH         # Directorios donde buscar ejecutables
echo $PWD          # Directorio actual
echo $HOSTNAME     # Nombre del host
echo $?            # Exit code del último comando (0 = éxito)
echo $$            # PID del shell actual

# Ver todas las variables de entorno:
env
printenv

# Definir variable temporal (solo esta sesión):
export MY_VAR="hello"

# Definir variable permanente:
echo 'export MY_VAR="hello"' >> ~/.bashrc
source ~/.bashrc
```

---

# 4. Anatomía de un Comando

## 4.1 Estructura

```text
comando [opciones] [argumentos]

Ejemplo:
  ls -la /var/log
  │   │  └── argumento (sobre qué actuar)
  │   └── opciones/flags (cómo actuar)
  └── comando (qué hacer)

Tipos de opciones:
  -l          → opción corta (una letra, un guión)
  --long      → opción larga (palabra completa, dos guiones)
  -la         → opciones cortas combinadas (-l + -a)
  --color=auto → opción larga con valor
```

## 4.2 Obtener ayuda

```bash
man ls              # Manual completo (navegar con flechas, q para salir)
ls --help           # Ayuda rápida
info ls             # Documentación extendida (GNU)
whatis ls           # Descripción de una línea
type ls             # Muestra si es built-in, alias o programa

# Buscar qué comando hace algo:
apropos "copy files"     # Busca en descripciones de man pages
man -k "copy"            # Igual que apropos
```

## 4.3 Exit codes

```bash
# Todo comando retorna un exit code:
#   0 = éxito
#   1-255 = error (cada programa define sus códigos)

ls /tmp
echo $?     # 0 (éxito)

ls /noexiste
echo $?     # 2 (error: no such file)

# Usar en scripts:
if command; then
    echo "Éxito"
else
    echo "Falló con código $?"
fi
```

---

# PARTE II — NAVEGACIÓN Y GESTIÓN DE ARCHIVOS

---

# 5. Navegación del File System

## 5.1 Filesystem Hierarchy Standard (FHS)

```text
/                     → Raíz del sistema (todo está debajo)
├── bin/              → Binarios esenciales (ls, cp, cat)
├── boot/             → Archivos de arranque (kernel, grub)
├── dev/              → Dispositivos (discos, terminales)
├── etc/              → Archivos de configuración del sistema
│   ├── ssh/          → Config de SSH
│   ├── nginx/        → Config de Nginx
│   └── systemd/      → Config de systemd
├── home/             → Directorios home de usuarios
│   └── ubuntu/       → Home de usuario "ubuntu"
├── lib/              → Librerías compartidas
├── mnt/              → Punto de montaje temporal
├── opt/              → Software opcional/terceros
├── proc/             → Info de procesos (virtual, no en disco)
├── root/             → Home del usuario root
├── run/              → Datos de runtime (PIDs, sockets)
├── sbin/             → Binarios del sistema (root)
├── srv/              → Datos de servicios (web, FTP)
├── sys/              → Info del kernel (virtual)
├── tmp/              → Archivos temporales (se borran al reiniciar)
├── usr/              → Programas de usuario
│   ├── bin/          → Binarios de usuario
│   ├── lib/          → Librerías
│   ├── local/        → Software instalado manualmente
│   └── share/        → Datos compartidos (man pages, docs)
└── var/              → Datos variables
    ├── log/          → LOGS del sistema y aplicaciones
    ├── www/          → Archivos web (Apache/Nginx)
    └── lib/          → Datos de estado (bases de datos)
```

## 5.2 pwd — Print Working Directory

```bash
pwd
# /home/ubuntu

# Equivalente a:
echo $PWD
```

## 5.3 cd — Change Directory

```bash
cd /var/log           # Ir a ruta absoluta
cd logs               # Ir a subdirectorio relativo
cd ..                 # Subir un nivel
cd ../..              # Subir dos niveles
cd ~                  # Ir al home (~  = /home/usuario)
cd                    # Igual que cd ~ (ir al home)
cd -                  # Ir al directorio ANTERIOR (toggle)

# Ejemplo cloud: navegar a logs de nginx en EC2
cd /var/log/nginx
```

## 5.4 ls — List Directory Contents

```bash
ls                    # Listar directorio actual
ls /var/log           # Listar directorio específico
ls -l                 # Formato largo (permisos, tamaño, fecha)
ls -a                 # Mostrar archivos ocultos (. y ..)
ls -la                # Combinación: largo + ocultos
ls -lh                # Human-readable (KB, MB, GB)
ls -lS                # Ordenar por tamaño (mayor primero)
ls -lt                # Ordenar por fecha (más reciente primero)
ls -ltr               # Ordenar por fecha (más antiguo primero)
ls -R                 # Recursivo (subdirectorios)
ls -1                 # Un archivo por línea

# Ejemplo cloud: ver los logs más recientes
ls -lth /var/log/ | head -20
```

### Entender la salida de `ls -l`

```text
-rw-r--r-- 1 ubuntu ubuntu 4096 Mar 31 10:20 config.yml
││   │  │  │  │      │     │        │         └── nombre
││   │  │  │  │      │     │        └── fecha modificación
││   │  │  │  │      │     └── tamaño en bytes
││   │  │  │  │      └── grupo propietario
││   │  │  │  └── usuario propietario
││   │  │  └── número de hard links
││   │  └── permisos de otros (r--)
││   └── permisos del grupo (r--)
│└── permisos del dueño (rw-)
└── tipo: - archivo, d directorio, l symlink
```

## 5.5 tree — Visualizar estructura

```bash
# Instalar:
sudo apt install tree      # Debian/Ubuntu
sudo yum install tree      # RHEL/CentOS

tree                       # Árbol del directorio actual
tree -L 2                  # Solo 2 niveles de profundidad
tree -d                    # Solo directorios
tree -a                    # Incluir archivos ocultos
tree -h                    # Mostrar tamaños human-readable
tree -I "node_modules"     # Ignorar patrón
```

---

# 6. Gestión de Archivos y Directorios

## 6.1 mkdir — Make Directory

```bash
mkdir logs                   # Crear directorio
mkdir -p /opt/app/config     # Crear toda la ruta (-p = parents)
mkdir -p {src,bin,lib,docs}  # Crear múltiples directorios
mkdir -m 755 public          # Crear con permisos específicos
```

## 6.2 touch — Crear archivo / Actualizar timestamp

```bash
touch file.txt               # Crear archivo vacío (o actualizar timestamp)
touch file1.txt file2.txt    # Crear múltiples archivos
touch -t 202401011200 f.txt  # Establecer timestamp específico
```

## 6.3 cp — Copy

```bash
cp file.txt backup.txt            # Copiar archivo
cp file.txt /tmp/                 # Copiar a otro directorio
cp -r src/ dest/                  # Copiar directorio (-r = recursivo)
cp -i file.txt dest/              # Interactivo (pedir confirmación si existe)
cp -p file.txt dest/              # Preservar permisos y timestamps
cp -a src/ dest/                  # Archive: -r + preservar todo (= backup)
cp -v *.log /backup/              # Verbose: mostrar qué se copia
cp --backup=numbered f.txt dest/  # Crear backups numerados si existe

# Cloud: backup de config antes de modificar
cp -a /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%Y%m%d)
```

## 6.4 mv — Move / Rename

```bash
mv old.txt new.txt           # Renombrar archivo
mv file.txt /tmp/            # Mover a otro directorio
mv -i file.txt dest/         # Interactivo (confirmar si existe)
mv -n file.txt dest/         # No sobreescribir si existe
mv *.log /var/archive/       # Mover todos los .log
```

## 6.5 rm — Remove

```bash
rm file.txt                  # Eliminar archivo
rm -i file.txt               # Pedir confirmación
rm -f file.txt               # Forzar (sin confirmación, sin error si no existe)
rm -r directory/             # Eliminar directorio y contenido
rm -rf /tmp/cache/           # Forzar eliminar directorio recursivo

# ⚠️  NUNCA ejecutar:
#   rm -rf /           → DESTRUYE TODO EL SISTEMA
#   rm -rf /*          → Igual de destructivo
#   rm -rf ~/*         → Borra todo tu home
#
# SIEMPRE verificar antes:
#   echo rm -rf /path  → Imprimir primero, ejecutar después
#   ls /path           → Ver qué vas a borrar
```

## 6.6 Wildcards (Globbing)

```bash
*            # Cualquier cantidad de caracteres
?            # Exactamente un carácter
[abc]        # Uno de: a, b, o c
[a-z]        # Rango: de a a z
[!abc]       # Ninguno de: a, b, c
{txt,log}    # Alternativas exactas

# Ejemplos:
ls *.log               # Todos los archivos .log
ls file?.txt           # file1.txt, fileA.txt, etc.
ls [A-Z]*.conf         # .conf que empiezan con mayúscula
rm *.{log,tmp}         # Borrar todos los .log y .tmp
cp /var/log/{syslog,auth.log} /backup/   # Copiar archivos específicos
```

---

# 7. Búsqueda de Archivos

## 7.1 find — Búsqueda por atributos

```bash
# Sintaxis: find [ruta] [condiciones] [acciones]

# ─── Por nombre ───
find / -name "nginx.conf"           # Buscar por nombre exacto (case sensitive)
find / -iname "readme*"             # Case insensitive
find /var -name "*.log"             # Todos los .log en /var

# ─── Por tipo ───
find /etc -type f                   # Solo archivos (f)
find /home -type d                  # Solo directorios (d)
find /dev -type l                   # Solo symlinks (l)

# ─── Por tamaño ───
find / -size +100M                  # Archivos > 100 MB
find / -size -1k                    # Archivos < 1 KB
find / -size +1G -type f            # Archivos > 1 GB

# ─── Por tiempo ───
find /var/log -mtime -1             # Modificados en las últimas 24h
find /var/log -mtime +30            # Modificados hace más de 30 días
find /tmp -atime +7                 # Accedidos hace más de 7 días
find /var -mmin -60                 # Modificados en los últimos 60 minutos

# ─── Por permisos ───
find / -perm 777                    # Permisos exactos 777 (peligroso)
find / -perm -u+s                   # Con SUID bit
find /home -not -user ubuntu        # No pertenecen a ubuntu

# ─── Con acciones ───
find /tmp -name "*.tmp" -delete     # Encontrar y borrar
find /var/log -name "*.log" -size +50M -exec ls -lh {} \;   # Listar logs grandes
find / -name "*.conf" -exec grep -l "password" {} \;        # Configs con passwords

# ─── Cloud: limpiar logs viejos ───
find /var/log -name "*.log" -mtime +30 -exec rm {} \;
find /var/log -name "*.gz" -mtime +90 -delete
```

## 7.2 locate — Búsqueda por base de datos

```bash
# Más rápido que find (usa base de datos indexada)
sudo apt install mlocate        # Instalar
sudo updatedb                   # Actualizar base de datos

locate nginx.conf               # Buscar archivo
locate -i readme                # Case insensitive
locate -c "*.log"               # Contar resultados
locate -l 10 "*.conf"           # Limitar a 10 resultados

# Limitación: la base de datos puede estar desactualizada.
# Para archivos recién creados, usar find.
```

## 7.3 which, whereis, type

```bash
which nginx         # Ruta del ejecutable (/usr/sbin/nginx)
which python3       # /usr/bin/python3

whereis nginx       # Binario + man page + source
# nginx: /usr/sbin/nginx /etc/nginx /usr/share/nginx

type ls             # ¿Es built-in, alias, o programa?
# ls is aliased to 'ls --color=auto'

type cd             # cd is a shell builtin
```

---

# 8. Links (Symlinks y Hard Links)

## 8.1 Conceptos

```text
Hard Link:
  → Apunta al MISMO inode (datos en disco)
  → Si borras el original, el hard link SIGUE funcionando
  → No puede cruzar filesystems
  → No puede apuntar a directorios

Symlink (Symbolic Link / Soft Link):
  → Apunta al NOMBRE del archivo (como un acceso directo)
  → Si borras el original, el symlink se ROMPE (dangling link)
  → Puede cruzar filesystems
  → Puede apuntar a directorios

Analogía:
  Hard Link = dos entradas en la agenda que apuntan al mismo teléfono
  Symlink   = una nota que dice "mira en la página 42"
```

## 8.2 Comandos

```bash
# Symlink (el más común):
ln -s /etc/nginx/nginx.conf ~/nginx-config      # Crear symlink
ls -l ~/nginx-config
# lrwxrwxrwx 1 ubuntu ubuntu 23 ... nginx-config -> /etc/nginx/nginx.conf

# Hard link:
ln archivo.txt hardlink.txt

# Ver inodes:
ls -li          # Mostrar número de inode

# Cloud: común para versionado de configs
ln -sf /opt/app/config-v2.yml /opt/app/config.yml
# -f = forzar (reemplazar si existe)
```

---

# PARTE III — VISUALIZACIÓN Y PROCESAMIENTO DE TEXTO

---

# 9. Visualización de Archivos

## 9.1 cat — Concatenate and Print

```bash
cat file.txt                  # Mostrar todo el archivo
cat -n file.txt               # Con números de línea
cat -b file.txt               # Números solo en líneas no vacías
cat file1.txt file2.txt       # Concatenar múltiples archivos
cat > newfile.txt             # Crear archivo (escribir, Ctrl+D para terminar)
cat >> file.txt               # Append al archivo
```

## 9.2 less — Pager interactivo

```bash
less /var/log/syslog          # Ver archivo paginado

# Navegación dentro de less:
#   Space / f     → avanzar una página
#   b             → retroceder una página
#   g             → ir al inicio
#   G             → ir al final
#   /patrón       → buscar hacia adelante
#   ?patrón       → buscar hacia atrás
#   n             → siguiente resultado
#   N             → resultado anterior
#   q             → salir

less +F /var/log/syslog       # Follow mode (como tail -f, Ctrl+C para pausa)
```

## 9.3 head y tail

```bash
head file.txt                 # Primeras 10 líneas (default)
head -n 20 file.txt           # Primeras 20 líneas
head -c 100 file.txt          # Primeros 100 bytes

tail file.txt                 # Últimas 10 líneas
tail -n 50 file.txt           # Últimas 50 líneas
tail -f /var/log/syslog       # FOLLOW: ver nuevas líneas en tiempo real
tail -F /var/log/syslog       # Follow + reintentar si el archivo rota

# ─── Cloud: monitorear logs en producción ───
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# Combinar: ver las últimas 100 líneas y seguir
tail -n 100 -f /var/log/app/app.log

# Múltiples logs al mismo tiempo:
tail -f /var/log/nginx/access.log /var/log/nginx/error.log
```

## 9.4 wc — Word Count

```bash
wc file.txt                   # líneas, palabras, bytes
wc -l file.txt                # Solo líneas
wc -w file.txt                # Solo palabras
wc -c file.txt                # Solo bytes
wc -m file.txt                # Solo caracteres

# ¿Cuántas peticiones hoy en el access log?
grep "$(date +%d/%b/%Y)" /var/log/nginx/access.log | wc -l
```

## 9.5 sort y uniq

```bash
sort file.txt                  # Ordenar alfabéticamente
sort -n file.txt               # Ordenar numéricamente
sort -r file.txt               # Orden inverso
sort -k 2 file.txt             # Ordenar por columna 2
sort -t ',' -k 3 -n data.csv   # Separador coma, columna 3, numérico
sort -u file.txt               # Ordenar y eliminar duplicados

uniq file.txt                  # Eliminar líneas duplicadas CONSECUTIVAS
sort file.txt | uniq           # Eliminar todos los duplicados
sort file.txt | uniq -c        # Contar ocurrencias
sort file.txt | uniq -d        # Solo mostrar duplicados

# Cloud: top 10 IPs con más peticiones
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10
```

## 9.6 diff y cmp

```bash
diff file1.txt file2.txt      # Diferencias entre archivos
diff -u file1.txt file2.txt   # Formato unificado (como git diff)
diff -y file1.txt file2.txt   # Side-by-side
diff -r dir1/ dir2/           # Comparar directorios recursivamente

# Cloud: verificar si un config cambió
diff /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
```

---

# 10. grep — Búsqueda de Patrones

## 10.1 Uso básico

```bash
grep "error" file.txt               # Buscar "error" en archivo
grep -i "error" file.txt            # Case insensitive
grep -n "error" file.txt            # Mostrar números de línea
grep -c "error" file.txt            # Contar líneas que coinciden
grep -v "debug" file.txt            # Invertir: líneas que NO coinciden
grep -r "TODO" /src/                # Recursivo en directorio
grep -l "password" /etc/*.conf      # Solo nombres de archivos que coinciden
grep -w "error" file.txt            # Palabra completa (no "errors" ni "terror")
```

## 10.2 Flags importantes

```text
┌──────────┬──────────────────────────────────────┐
│  Flag    │  Descripción                         │
├──────────┼──────────────────────────────────────┤
│  -i      │  Case insensitive                    │
│  -n      │  Mostrar número de línea             │
│  -c      │  Contar coincidencias                │
│  -v      │  Invertir (líneas que NO coinciden)  │
│  -r / -R │  Recursivo en directorios            │
│  -l      │  Solo nombres de archivos            │
│  -w      │  Palabra completa                    │
│  -o      │  Solo la parte que coincide          │
│  -A 3    │  Mostrar 3 líneas DESPUÉS            │
│  -B 3    │  Mostrar 3 líneas ANTES              │
│  -C 3    │  Mostrar 3 líneas de CONTEXTO        │
│  -E      │  Extended regex (= egrep)            │
│  -P      │  Perl regex                          │
│  --color │  Colorear coincidencias              │
└──────────┴──────────────────────────────────────┘
```

## 10.3 Con regex

```bash
grep -E "error|warning|critical" /var/log/syslog   # OR
grep -E "^root:" /etc/passwd                        # Empieza con "root:"
grep -E "\.conf$" file.txt                          # Termina con ".conf"
grep -E "[0-9]{1,3}\.[0-9]{1,3}" access.log        # Patrón de IP
grep -P "\d{4}-\d{2}-\d{2}" file.txt               # Fecha YYYY-MM-DD (Perl)
```

## 10.4 Ejemplos cloud

```bash
# Errores en logs de aplicación
grep -i "error\|exception\|fatal" /var/log/app/app.log

# Peticiones 5xx en nginx
grep '" 5[0-9][0-9] ' /var/log/nginx/access.log

# Intentos de login fallidos (seguridad)
grep "Failed password" /var/log/auth.log
grep "Failed password" /var/log/auth.log | tail -20

# IPs que causan 404
grep '" 404 ' /var/log/nginx/access.log | awk '{print $1}' | sort | uniq -c | sort -rn

# Buscar en archivos comprimidos
zgrep "error" /var/log/syslog.*.gz
```

---

# 11. sed — Stream Editor

## 11.1 Uso básico

```bash
# Sintaxis: sed [opciones] 'comando' archivo

# Sustituir (primera ocurrencia por línea):
sed 's/old/new/' file.txt

# Sustituir TODAS las ocurrencias por línea (g = global):
sed 's/old/new/g' file.txt

# Sustituir con modificación in-place (-i):
sed -i 's/old/new/g' file.txt

# In-place con backup:
sed -i.bak 's/old/new/g' file.txt     # Crea file.txt.bak

# Case insensitive:
sed 's/error/ERROR/gI' file.txt
```

## 11.2 Operaciones comunes

```bash
# Borrar líneas:
sed '5d' file.txt                     # Borrar línea 5
sed '/^#/d' file.txt                  # Borrar líneas que empiezan con #
sed '/^$/d' file.txt                  # Borrar líneas vacías

# Imprimir líneas específicas:
sed -n '10p' file.txt                 # Solo línea 10
sed -n '10,20p' file.txt              # Líneas 10 a 20
sed -n '/error/p' file.txt            # Líneas con "error" (como grep)

# Insertar/agregar:
sed '3i\Nueva línea' file.txt         # Insertar ANTES de línea 3
sed '3a\Nueva línea' file.txt         # Insertar DESPUÉS de línea 3

# Múltiples operaciones:
sed -e 's/foo/bar/g' -e 's/baz/qux/g' file.txt
```

## 11.3 Ejemplos cloud

```bash
# Cambiar puerto de nginx:
sed -i 's/listen 80;/listen 8080;/' /etc/nginx/nginx.conf

# Cambiar hostname en configuración:
sed -i "s/old-server/new-server/g" /etc/app/config.yml

# Descomentar una línea:
sed -i 's/^#Port 22/Port 2222/' /etc/ssh/sshd_config

# Agregar línea después de un patrón:
sed -i '/\[mysqld\]/a max_connections=500' /etc/mysql/my.cnf
```

---

# 12. awk — Procesamiento de Columnas

## 12.1 Uso básico

```bash
# Sintaxis: awk 'patrón {acción}' archivo
# awk divide cada línea en campos: $1, $2, ..., $NF (último)
# $0 = línea completa

awk '{print $1}' file.txt              # Imprimir columna 1
awk '{print $1, $3}' file.txt          # Columnas 1 y 3
awk '{print NR, $0}' file.txt          # Número de línea + línea
awk -F ',' '{print $2}' data.csv       # Separador personalizado (coma)
awk -F ':' '{print $1}' /etc/passwd    # Usuarios del sistema
```

## 12.2 Variables especiales

```text
┌──────────┬──────────────────────────────────────┐
│  Variable│  Significado                         │
├──────────┼──────────────────────────────────────┤
│  $0      │  Línea completa                      │
│  $1..$n  │  Campo n (separado por FS)           │
│  NR      │  Número de registro (línea actual)   │
│  NF      │  Número de campos en la línea        │
│  $NF     │  Último campo                        │
│  FS      │  Field separator (default: espacio)  │
│  OFS     │  Output field separator              │
│  RS      │  Record separator (default: newline) │
└──────────┴──────────────────────────────────────┘
```

## 12.3 Filtros y cálculos

```bash
# Filtrar por condición:
awk '$3 > 100' data.txt                 # Líneas donde col 3 > 100
awk '/error/' file.txt                  # Líneas con "error" (como grep)
awk '$1 == "root"' /etc/passwd          # Líneas donde col 1 es "root"

# Cálculos:
awk '{sum += $2} END {print sum}' data.txt           # Suma de columna 2
awk '{sum += $2; n++} END {print sum/n}' data.txt    # Promedio
awk 'BEGIN {max=0} $2 > max {max=$2} END {print max}' data.txt  # Máximo

# Formatear output:
awk '{printf "%-20s %10d\n", $1, $2}' data.txt
```

## 12.4 Ejemplos cloud

```bash
# Top 10 IPs en access log:
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10

# Requests por status code:
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn

# Tráfico total por IP:
awk '{ip[$1] += $10} END {for (i in ip) print ip[i], i}' access.log | sort -rn | head

# Uso de memoria por proceso:
ps aux | awk '{mem[$11] += $6} END {for (p in mem) printf "%10d KB  %s\n", mem[p], p}' | sort -rn | head

# Extraer campo de JSON-like log (básico):
awk -F '"' '{print $4}' app.log
```

---

# 13. Pipelines y Redirección

## 13.1 Pipes

```bash
# El pipe (|) conecta la SALIDA de un comando con la ENTRADA del siguiente:
comando1 | comando2 | comando3

# Ejemplos:
ls -la | grep ".log"
cat /var/log/syslog | grep "error" | wc -l
ps aux | grep nginx | grep -v grep
dmesg | tail -20
history | grep "docker" | tail -10
```

## 13.2 Redirección

```bash
# Output redirection:
echo "hello" > file.txt         # Escribir (sobreescribe)
echo "world" >> file.txt        # Append (agregar al final)

# Input redirection:
sort < unsorted.txt             # Leer desde archivo
wc -l < file.txt                # Contar líneas desde archivo

# Error redirection:
command 2> errors.log           # Solo stderr a archivo
command 2>/dev/null             # Descartar errores
command > output.log 2>&1       # stdout Y stderr al mismo archivo
command &> all.log              # Atajo para lo anterior (bash)

# Here document:
cat << EOF > config.yml
server:
  port: 8080
  host: 0.0.0.0
EOF

# Here string:
grep "pattern" <<< "string to search in"
```

## 13.3 /dev/null — El agujero negro

```bash
# Descartar output completamente:
command > /dev/null              # Descartar stdout
command 2> /dev/null             # Descartar stderr
command > /dev/null 2>&1         # Descartar TODO

# Útil en cron jobs para no generar email:
0 * * * * /opt/cleanup.sh > /dev/null 2>&1
```

## 13.4 tee — Dividir output

```bash
# tee escribe a un archivo Y a stdout (como una T en plomería)
echo "hello" | tee file.txt               # Escribir + mostrar
echo "hello" | tee -a file.txt            # Append + mostrar
command | tee output.log                   # Guardar log mientras ves output

# Cloud: ejecutar y guardar log
./deploy.sh 2>&1 | tee deploy-$(date +%Y%m%d).log
```

## 13.5 xargs — Construir comandos desde stdin

```bash
# xargs toma input de stdin y lo pasa como ARGUMENTOS a un comando

find /tmp -name "*.tmp" | xargs rm           # Borrar archivos encontrados
echo "file1 file2 file3" | xargs touch       # Crear múltiples archivos
cat urls.txt | xargs -n 1 curl -O            # Descargar cada URL
find . -name "*.py" | xargs grep "import os" # Buscar en archivos encontrados

# Con confirmación (-p):
find /var/log -name "*.log" -mtime +30 | xargs -p rm

# Manejar espacios en nombres (-0 con find -print0):
find . -name "*.txt" -print0 | xargs -0 wc -l
```

---

# PARTE IV — USUARIOS Y PERMISOS

---

# 14. Modelo de Permisos Unix

## 14.1 El sistema de permisos

```text
Cada archivo tiene 3 conjuntos de permisos para 3 tipos de usuario:

  Usuario (u)  │  Grupo (g)  │  Otros (o)
  rwx          │  rwx        │  rwx

  r = read     (4)
  w = write    (2)
  x = execute  (1)
  - = sin permiso (0)

Ejemplo:  -rwxr-xr--
  │ = archivo (d = directorio, l = symlink)
  rwx = dueño puede leer, escribir, ejecutar
  r-x = grupo puede leer y ejecutar
  r-- = otros solo pueden leer

Valor octal: rwx = 4+2+1 = 7, r-x = 4+0+1 = 5, r-- = 4+0+0 = 4
  → 754
```

## 14.2 chmod — Cambiar permisos

```bash
# Modo simbólico:
chmod u+x script.sh              # Agregar ejecución al dueño
chmod g-w file.txt               # Quitar escritura al grupo
chmod o-rwx file.txt             # Quitar todo a otros
chmod a+r file.txt               # Agregar lectura a todos
chmod u+x,g+r,o-w file.txt      # Múltiples cambios

# Modo octal:
chmod 755 script.sh              # rwxr-xr-x (scripts, binarios)
chmod 644 config.yml             # rw-r--r-- (archivos de config)
chmod 600 id_rsa                 # rw------- (claves SSH)
chmod 700 .ssh/                  # rwx------ (directorio SSH)
chmod 777 file.txt               # ⚠️ NUNCA en producción

# Recursivo:
chmod -R 755 /var/www/html/      # Todo el directorio

# Cloud: permisos típicos
chmod 400 my-key.pem             # AWS key pair (REQUERIDO)
chmod 600 ~/.ssh/id_rsa          # SSH private key
chmod 644 ~/.ssh/id_rsa.pub      # SSH public key
chmod 700 ~/.ssh                 # Directorio SSH
```

## 14.3 chown — Cambiar propietario

```bash
chown user file.txt              # Cambiar dueño
chown user:group file.txt        # Cambiar dueño y grupo
chown :group file.txt            # Solo cambiar grupo
chown -R www-data:www-data /var/www/    # Recursivo

# Cloud: después de desplegar una app web
sudo chown -R www-data:www-data /var/www/html
sudo chown -R ubuntu:ubuntu /opt/app
```

## 14.4 Permisos especiales

```bash
# SUID (Set User ID) — ejecutar como el dueño:
chmod u+s /usr/bin/program       # o chmod 4755
# Ejemplo: /usr/bin/passwd tiene SUID → cualquier usuario puede cambiar su password

# SGID (Set Group ID) — ejecutar como el grupo / heredar grupo en dirs:
chmod g+s /shared/               # Nuevos archivos heredan el grupo del directorio
# chmod 2755

# Sticky Bit — solo el dueño puede borrar sus archivos:
chmod +t /tmp                    # chmod 1777
# /tmp tiene sticky bit → todos pueden escribir pero solo borrar lo suyo
```

## 14.5 umask

```bash
# umask define los permisos POR DEFECTO para nuevos archivos/directorios
umask                # Ver umask actual (típicamente 0022)

# El permiso real = permiso base - umask
# Archivos base:    666 (rw-rw-rw-)
# Directorios base: 777 (rwxrwxrwx)
# Con umask 022:
#   Archivos:    666 - 022 = 644 (rw-r--r--)
#   Directorios: 777 - 022 = 755 (rwxr-xr-x)

umask 077            # Solo dueño tiene permisos (archivos: 600, dirs: 700)
```

---

# 15. Gestión de Usuarios y Grupos

## 15.1 Información de usuarios

```bash
whoami                       # Usuario actual
id                           # UID, GID, grupos
id ubuntu                    # Info de usuario específico
who                          # Quién está loggeado
w                            # Quién está loggeado + qué hace
last                         # Historial de logins
lastlog                      # Último login de cada usuario

# Archivos importantes:
cat /etc/passwd              # Lista de usuarios
cat /etc/shadow              # Passwords (hash) — solo root
cat /etc/group               # Lista de grupos
```

## 15.2 Gestión de usuarios

```bash
# Crear usuario:
sudo useradd -m -s /bin/bash newuser     # -m = crear home, -s = shell
sudo useradd -m -s /bin/bash -G sudo,docker deploy   # Con grupos

# Establecer password:
sudo passwd newuser

# Modificar usuario:
sudo usermod -aG docker ubuntu           # Agregar a grupo docker (-a = append)
sudo usermod -s /bin/zsh ubuntu          # Cambiar shell
sudo usermod -L username                 # Bloquear cuenta
sudo usermod -U username                 # Desbloquear cuenta

# Eliminar usuario:
sudo userdel username                    # Eliminar usuario
sudo userdel -r username                 # Eliminar usuario + home

# Cloud: crear usuario para deployment
sudo useradd -m -s /bin/bash -G sudo deploy
sudo mkdir -p /home/deploy/.ssh
sudo cp ~/.ssh/authorized_keys /home/deploy/.ssh/
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys
```

## 15.3 Gestión de grupos

```bash
sudo groupadd developers              # Crear grupo
sudo groupdel developers              # Eliminar grupo
sudo gpasswd -a user developers       # Agregar usuario a grupo
sudo gpasswd -d user developers       # Quitar usuario de grupo
groups ubuntu                          # Ver grupos del usuario
```

---

# 16. sudo y Privilegios

## 16.1 Uso de sudo

```bash
sudo command                 # Ejecutar como root
sudo -u deploy command       # Ejecutar como otro usuario
sudo -i                      # Shell interactivo como root
sudo -s                      # Shell como root (mantiene env)
sudo su -                    # Cambiar a root (login shell)
sudo !!                      # Repetir último comando con sudo

# Verificar qué puedes hacer:
sudo -l                      # Listar permisos sudo del usuario
```

## 16.2 Configurar sudoers

```bash
sudo visudo                  # SIEMPRE editar con visudo (valida sintaxis)

# Agregar usuario con sudo completo:
# username ALL=(ALL:ALL) ALL

# Sin password:
# deploy ALL=(ALL) NOPASSWD: ALL

# Solo comandos específicos:
# deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx

# Grupo con sudo:
# %developers ALL=(ALL) ALL
```

---

# PARTE V — PROCESOS Y SERVICIOS

---

# 17. Gestión de Procesos

## 17.1 ps — Process Status

```bash
ps                           # Procesos del usuario en esta terminal
ps aux                       # TODOS los procesos (formato BSD)
ps -ef                       # TODOS los procesos (formato POSIX)

# Columnas importantes de ps aux:
#  USER  PID %CPU %MEM   VSZ  RSS TTY  STAT  START  TIME COMMAND

ps aux | grep nginx          # Buscar proceso
ps aux --sort=-%mem | head   # Top por memoria
ps aux --sort=-%cpu | head   # Top por CPU
ps -p 1234                   # Info de PID específico
ps -u ubuntu                 # Procesos de un usuario
ps --forest                  # Árbol de procesos
pstree                       # Árbol visual
```

## 17.2 top y htop

```bash
top                          # Monitor de procesos en tiempo real

# Dentro de top:
#   M = ordenar por memoria
#   P = ordenar por CPU
#   k = matar proceso (pide PID)
#   q = salir
#   1 = mostrar cada CPU
#   c = mostrar comando completo

htop                         # Versión mejorada (instalar: sudo apt install htop)
# Navegación con flechas, F5 = tree view, F9 = kill, F6 = sort
```

## 17.3 kill — Enviar señales a procesos

```bash
kill PID                     # Enviar SIGTERM (terminar gracefully)
kill -9 PID                  # Enviar SIGKILL (forzar terminación)
kill -HUP PID                # Reload configuración (muchos daemons)
kill -STOP PID               # Pausar proceso
kill -CONT PID               # Continuar proceso pausado

# Señales comunes:
#   SIGTERM (15) → "por favor termina" (default)
#   SIGKILL (9)  → "muere ahora" (no se puede atrapar)
#   SIGHUP  (1)  → "reload config" / "terminal cerrada"
#   SIGINT  (2)  → Ctrl+C
#   SIGSTOP (19) → pausar

# Matar por nombre:
killall nginx                # Matar todos los nginx
pkill -f "python app.py"    # Matar por patrón del comando completo
```

## 17.4 Procesos en background y foreground

```bash
# Ejecutar en background:
./long-task.sh &             # & al final
[1] 12345                    # Job number y PID

# Listar jobs:
jobs                         # Ver jobs del shell actual

# Traer a foreground:
fg %1                        # Job 1 al foreground

# Enviar a background un proceso suspendido:
# Ctrl+Z → suspende
bg %1                        # Continuar en background

# nohup — proceso sobrevive al cerrar la terminal:
nohup ./long-task.sh &
nohup ./server.sh > /var/log/server.log 2>&1 &

# disown — desvincular proceso del shell:
./server.sh &
disown %1
```

## 17.5 nice y renice — Prioridad

```bash
# Rango de prioridad: -20 (más alta) a 19 (más baja)
# Default: 0

nice -n 10 ./backup.sh          # Ejecutar con baja prioridad
nice -n -5 ./critical-task.sh   # Alta prioridad (requiere root)

renice -n 10 -p 12345           # Cambiar prioridad de proceso existente
renice -n -5 -u deploy          # Cambiar prioridad de procesos de un usuario
```

---

# 18. systemctl y Servicios

## 18.1 systemd y systemctl

```bash
# systemd es el init system de la mayoría de distros modernas.
# systemctl es el comando para controlarlo.

# ─── Estado ───
systemctl status nginx                  # Estado detallado
systemctl is-active nginx               # ¿Está corriendo?
systemctl is-enabled nginx              # ¿Arranca con el boot?

# ─── Control ───
sudo systemctl start nginx              # Iniciar servicio
sudo systemctl stop nginx               # Detener servicio
sudo systemctl restart nginx            # Reiniciar (stop + start)
sudo systemctl reload nginx             # Reload config sin downtime
sudo systemctl enable nginx             # Habilitar en boot
sudo systemctl disable nginx            # Deshabilitar en boot
sudo systemctl enable --now nginx       # Habilitar + iniciar

# ─── Listado ───
systemctl list-units                    # Todos los units activos
systemctl list-units --type=service     # Solo servicios
systemctl list-units --failed           # Servicios fallidos
systemctl list-unit-files               # Todos (habilitados y no)

# ─── Cloud: servicios comunes ───
sudo systemctl restart nginx
sudo systemctl restart sshd
sudo systemctl status docker
sudo systemctl enable docker
```

## 18.2 Crear un servicio personalizado

```bash
# Crear archivo de unit:
sudo nano /etc/systemd/system/myapp.service
```

```ini
[Unit]
Description=My Application
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/opt/myapp
ExecStart=/usr/bin/node /opt/myapp/server.js
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
# Activar:
sudo systemctl daemon-reload
sudo systemctl enable --now myapp
sudo systemctl status myapp
```

---

# 19. Logs con journalctl

## 19.1 Uso básico

```bash
journalctl                               # Todos los logs
journalctl -u nginx                      # Logs de un servicio
journalctl -u nginx --since "1 hour ago" # Última hora
journalctl -u nginx --since today        # Desde hoy
journalctl -u nginx -f                   # Follow (como tail -f)
journalctl -u nginx -n 50               # Últimas 50 líneas
journalctl -u nginx --no-pager          # Sin pager (para pipes)

# ─── Filtros avanzados ───
journalctl --since "2024-01-01" --until "2024-01-02"
journalctl -p err                        # Solo errores (priorities: emerg,alert,crit,err,warning,notice,info,debug)
journalctl -p err -u nginx              # Errores de nginx
journalctl _PID=1234                     # Por PID
journalctl -b                            # Desde el último boot
journalctl -b -1                         # Boot anterior

# ─── Cloud: debug de servicios ───
journalctl -u myapp -f                   # Seguir logs de tu app
journalctl -u myapp -p err --since today # Errores de hoy
journalctl --disk-usage                  # Espacio usado por logs
sudo journalctl --vacuum-size=500M       # Limpiar logs > 500MB
```

---

# 20. Cron Jobs y Automatización

## 20.1 crontab

```bash
crontab -l                     # Listar cron jobs del usuario
crontab -e                     # Editar cron jobs
crontab -r                     # Eliminar TODOS los cron jobs
sudo crontab -u deploy -l      # Ver cron de otro usuario
```

## 20.2 Formato cron

```text
┌───────────── minuto (0-59)
│ ┌───────────── hora (0-23)
│ │ ┌───────────── día del mes (1-31)
│ │ │ ┌───────────── mes (1-12)
│ │ │ │ ┌───────────── día de la semana (0-7, 0 y 7 = domingo)
│ │ │ │ │
* * * * * comando

Valores especiales:
  *     = cualquier valor
  ,     = lista de valores (1,3,5)
  -     = rango (1-5)
  /     = intervalo (*/5 = cada 5)
```

## 20.3 Ejemplos

```bash
# Cada minuto:
* * * * * /opt/check.sh

# Cada 5 minutos:
*/5 * * * * /opt/monitor.sh

# Cada hora en punto:
0 * * * * /opt/cleanup.sh

# Cada día a las 2:30 AM:
30 2 * * * /opt/backup.sh

# Lunes a viernes a las 9 AM:
0 9 * * 1-5 /opt/report.sh

# Primer día de cada mes:
0 0 1 * * /opt/monthly-report.sh

# Con redirección de output:
0 3 * * * /opt/backup.sh >> /var/log/backup.log 2>&1

# Con PATH (cron tiene un PATH muy limitado):
0 * * * * PATH=/usr/local/bin:/usr/bin:/bin /opt/script.sh
```

## 20.4 Alternativas a crontab directo

```bash
# /etc/cron.d/ — cron jobs del sistema
sudo nano /etc/cron.d/cleanup
# */10 * * * * root /opt/cleanup.sh

# Directorios predefinidos:
# /etc/cron.hourly/
# /etc/cron.daily/
# /etc/cron.weekly/
# /etc/cron.monthly/
# Solo pon un script ejecutable ahí y se correrá automáticamente.

# systemd timers (alternativa moderna):
# Más control, mejor logging con journalctl
```

---

# PARTE VI — NETWORKING

---

# 21. Comandos de Red

## 21.1 Información de red

```bash
ip addr                       # Interfaces y direcciones IP
ip addr show eth0             # Solo interfaz eth0
ip route                      # Tabla de rutas
ip link                       # Estado de interfaces

# Legacy (aún común):
ifconfig                      # Interfaces (depreciado, instalar net-tools)
route -n                      # Tabla de rutas
hostname -I                   # IPs del host
```

## 21.2 Conectividad

```bash
# ping — verificar conectividad
ping google.com               # Ping indefinido (Ctrl+C para parar)
ping -c 4 google.com          # Solo 4 pings
ping -c 1 -W 2 10.0.1.5      # 1 ping, timeout 2 segundos

# traceroute — ruta de paquetes
traceroute google.com
traceroute -n google.com      # Sin resolución DNS (más rápido)

# DNS lookup:
nslookup google.com           # Resolver DNS
dig google.com                # Resolver DNS (más detallado)
dig +short google.com         # Solo la IP
host google.com               # Resolver DNS (simple)
```

## 21.3 Puertos y conexiones

```bash
# ss — Socket Statistics (reemplazo de netstat)
ss -tlnp                      # TCP listening, numérico, con PID
ss -ulnp                      # UDP listening
ss -s                         # Resumen de sockets
ss -t state established       # Conexiones establecidas

# netstat (legacy, instalar net-tools):
netstat -tlnp                 # TCP listening
netstat -an                   # Todas las conexiones

# ¿Quién está usando el puerto 80?
ss -tlnp | grep :80
sudo lsof -i :80              # Alternativa con lsof

# Cloud: verificar que tu app está escuchando
ss -tlnp | grep :8080         # ¿Mi app está en el puerto 8080?
curl -s http://localhost:8080  # ¿Responde?
```

## 21.4 Firewall (iptables / ufw)

```bash
# UFW (Uncomplicated Firewall) — Ubuntu/Debian
sudo ufw status                   # Estado actual
sudo ufw enable                   # Activar firewall
sudo ufw allow 22/tcp             # Permitir SSH
sudo ufw allow 80/tcp             # Permitir HTTP
sudo ufw allow 443/tcp            # Permitir HTTPS
sudo ufw allow from 10.0.0.0/24   # Permitir subred
sudo ufw deny 3306                # Bloquear MySQL externamente
sudo ufw delete allow 80/tcp      # Eliminar regla

# iptables (más bajo nivel):
sudo iptables -L -n -v            # Listar reglas
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT   # Permitir puerto 80
sudo iptables -A INPUT -j DROP    # Bloquear todo lo demás (CUIDADO)
```

---

# 22. SSH — Secure Shell

## 22.1 Conexión básica

```bash
ssh user@hostname                     # Conexión básica
ssh -i key.pem user@ip                # Con llave privada
ssh -p 2222 user@hostname             # Puerto personalizado
ssh -v user@hostname                  # Verbose (debug)
ssh -vvv user@hostname                # Máximo verbose

# Cloud:
ssh -i ~/.ssh/my-key.pem ec2-user@54.123.45.67       # AWS
ssh -i ~/.ssh/my-key.pem ubuntu@ec2-54-123-45-67.compute-1.amazonaws.com
```

## 22.2 SSH Keys

```bash
# Generar par de llaves:
ssh-keygen -t ed25519 -C "email@example.com"    # Moderno (recomendado)
ssh-keygen -t rsa -b 4096 -C "email@example.com" # RSA (compatibilidad)

# Resultado:
#   ~/.ssh/id_ed25519       → llave PRIVADA (NUNCA compartir)
#   ~/.ssh/id_ed25519.pub   → llave pública (copiar a servidores)

# Copiar llave pública a un servidor:
ssh-copy-id user@hostname
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@hostname

# Manual:
cat ~/.ssh/id_ed25519.pub | ssh user@host "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

## 22.3 SSH Config

```bash
# ~/.ssh/config — configuración por host

cat << 'EOF' > ~/.ssh/config
Host production
    HostName 54.123.45.67
    User ubuntu
    IdentityFile ~/.ssh/prod-key.pem
    Port 22

Host staging
    HostName 10.0.1.50
    User deploy
    IdentityFile ~/.ssh/staging-key.pem
    ProxyJump bastion

Host bastion
    HostName 54.200.100.50
    User ec2-user
    IdentityFile ~/.ssh/bastion-key.pem

Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    StrictHostKeyChecking ask
EOF

# Ahora puedes conectarte con:
ssh production           # En lugar de ssh -i key ubuntu@54.123...
ssh staging              # Automáticamente usa ProxyJump
```

## 22.4 SSH Tunneling

```bash
# Local port forwarding (acceder a servicio remoto via puerto local):
ssh -L 5432:localhost:5432 user@db-server
# Ahora puedes conectar a localhost:5432 → accede al PostgreSQL remoto

# Remote port forwarding (exponer servicio local al servidor remoto):
ssh -R 8080:localhost:3000 user@server
# El servidor remoto:8080 → tu localhost:3000

# Dynamic (SOCKS proxy):
ssh -D 1080 user@server
# Configura tu browser para usar SOCKS proxy localhost:1080

# Cloud: acceder a RDS/base de datos en VPC privada
ssh -L 5432:my-rds-instance.xxx.rds.amazonaws.com:5432 -i key.pem ec2-user@bastion-ip
# Ahora: psql -h localhost -p 5432 -U dbuser
```

---

# 23. Transferencia de Archivos (scp, rsync)

## 23.1 scp — Secure Copy

```bash
# Local → Remoto:
scp file.txt user@host:/path/                    # Copiar archivo
scp -r dir/ user@host:/path/                     # Copiar directorio
scp -i key.pem file.txt ec2-user@ip:/tmp/        # Con llave

# Remoto → Local:
scp user@host:/var/log/app.log ./                # Descargar archivo
scp -r user@host:/opt/app/logs/ ./local-logs/    # Descargar directorio

# Remoto → Remoto:
scp user1@host1:/file user2@host2:/path/
```

## 23.2 rsync — Sincronización eficiente

```bash
# rsync es MEJOR que scp para:
#   → Solo copia lo que CAMBIÓ (incremental)
#   → Preserva permisos, timestamps
#   → Compresión durante transfer
#   → Puede resumir transferencias interrumpidas

# Sintaxis: rsync [opciones] origen destino

rsync -avz src/ user@host:/dest/            # Archive + verbose + compress
rsync -avz --progress src/ user@host:/dest/ # Con barra de progreso
rsync -avz --delete src/ dest/              # Sincronizar (borrar lo que no existe en src)
rsync -avz --exclude '*.log' src/ dest/     # Excluir archivos
rsync -avzn src/ dest/                      # Dry run (simular, no ejecutar)

# Flags importantes:
#   -a = archive (preservar todo: permisos, timestamps, links, recursivo)
#   -v = verbose
#   -z = comprimir durante transfer
#   -P = --progress + --partial (resume)
#   --delete = borrar en destino lo que no existe en origen
#   --exclude = excluir patrones
#   -n = dry run

# Cloud: deploy de aplicación
rsync -avz --exclude '.git' --exclude 'node_modules' \
  -e "ssh -i ~/.ssh/key.pem" \
  ./app/ ubuntu@production:/opt/app/

# Cloud: backup de servidor
rsync -avzP ubuntu@server:/var/www/ /local/backup/www/
```

---

# 24. curl y wget

## 24.1 curl

```bash
curl https://example.com                       # GET básico
curl -o file.html https://example.com          # Guardar en archivo
curl -O https://example.com/file.tar.gz        # Guardar con nombre original
curl -I https://example.com                    # Solo headers (HEAD)
curl -v https://example.com                    # Verbose (debug)
curl -s https://example.com                    # Silent (sin progress bar)
curl -L https://example.com                    # Follow redirects

# POST con datos:
curl -X POST -d "name=test" https://api.com/endpoint
curl -X POST -H "Content-Type: application/json" \
  -d '{"name":"test"}' https://api.com/endpoint

# Con autenticación:
curl -u user:pass https://api.com/endpoint
curl -H "Authorization: Bearer TOKEN" https://api.com/endpoint

# Descargar e instalar (patrón común en cloud):
curl -fsSL https://get.docker.com | sh

# Cloud: verificar health de un servicio
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health
# Retorna solo el código HTTP (200, 500, etc.)

# Cloud: metadata de EC2 (IMDS v1)
curl http://169.254.169.254/latest/meta-data/
curl http://169.254.169.254/latest/meta-data/public-ipv4
```

## 24.2 wget

```bash
wget https://example.com/file.tar.gz           # Descargar archivo
wget -O custom-name.tar.gz https://url         # Con nombre personalizado
wget -c https://url/big-file.tar.gz            # Continuar descarga interrumpida
wget -q https://url                            # Quiet mode
wget -r -l 2 https://example.com               # Descargar recursivo, 2 niveles
wget --mirror https://example.com              # Mirror completo del sitio

# curl vs wget:
#   curl: más flexible, soporta muchos protocolos, mejor para APIs
#   wget: mejor para descargas, recursivo, resume nativo
```

---

# PARTE VII — PACKAGE MANAGEMENT

---

# 25. APT (Debian/Ubuntu)

## 25.1 apt vs apt-get vs apt-cache

```text
┌──────────────┬────────────────────────────────────────────────┐
│  Herramienta │  Uso                                           │
├──────────────┼────────────────────────────────────────────────┤
│  apt         │  Interfaz unificada. Uso diario recomendado.  │
│              │  Combina lo de apt-get y apt-cache.            │
│  apt-get     │  Backend clásico. Mejor para scripts y         │
│              │  sistemas legacy/mínimos.                      │
│  apt-cache   │  Consultas de bajo nivel: policy, depends.     │
│  dpkg        │  Instalar .deb individuales. Sin dependencias. │
└──────────────┴────────────────────────────────────────────────┘
```

## 25.2 Comandos APT

```bash
# ─── Actualizar ───
sudo apt update                          # Actualizar lista de paquetes
sudo apt upgrade                         # Actualizar paquetes instalados
sudo apt full-upgrade                    # Upgrade + resolver dependencias nuevas
sudo apt dist-upgrade                    # = full-upgrade (apt-get)

# ─── Instalar / Desinstalar ───
sudo apt install nginx                   # Instalar paquete
sudo apt install nginx=1.18.0-1          # Versión específica
sudo apt install -y nginx curl git       # Múltiples, sin confirmación
sudo apt reinstall nginx                 # Reinstalar
sudo apt remove nginx                    # Desinstalar (mantener config)
sudo apt purge nginx                     # Desinstalar + borrar config
sudo apt autoremove                      # Eliminar dependencias huérfanas

# ─── Buscar / Información ───
apt search nginx                         # Buscar paquetes
apt show nginx                           # Info detallada
apt list --installed                     # Paquetes instalados
apt list --upgradable                    # Paquetes con actualizaciones
apt-cache policy nginx                   # Versión instalada vs candidata + repos
apt-cache depends nginx                  # Dependencias del paquete
dpkg -l | grep nginx                     # Buscar en instalados (dpkg)
dpkg -L nginx                            # Archivos instalados por un paquete

# ─── Repositorios ───
# /etc/apt/sources.list           → repositorios principales
# /etc/apt/sources.list.d/        → repos adicionales

sudo add-apt-repository ppa:owner/name  # Agregar PPA (Ubuntu)
sudo add-apt-repository --remove ppa:owner/name  # Eliminar PPA

# ─── Cloud: setup típico de un servidor ───
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx certbot python3-certbot-nginx \
  fail2ban ufw htop curl git
```

## 25.3 Resolver problemas de APT

```bash
# Dependencias rotas:
sudo apt --fix-broken install

# Lock file bloqueado:
sudo rm /var/lib/dpkg/lock-frontend
sudo rm /var/lib/apt/lists/lock
sudo dpkg --configure -a

# Reconstruir cache:
sudo apt clean
sudo apt update
```

---

# 26. YUM / DNF (RHEL/CentOS/Fedora)

## 26.1 dnf vs yum

```text
dnf = siguiente generación de yum (Fedora, RHEL 8+, Rocky, Alma).
yum = legado (CentOS 7, RHEL 7). En RHEL 8+ "yum" es un alias de dnf.

Los comandos son esencialmente los mismos.
```

## 26.2 Comandos

```bash
# ─── Actualizar ───
sudo dnf check-update                    # Ver actualizaciones disponibles
sudo dnf update                          # Actualizar todo
sudo dnf update curl                     # Actualizar paquete específico

# ─── Instalar / Desinstalar ───
sudo dnf install nginx                   # Instalar
sudo dnf install -y nginx curl git       # Sin confirmación
sudo dnf remove nginx                    # Desinstalar
sudo dnf autoremove                      # Eliminar dependencias huérfanas

# ─── Buscar / Información ───
dnf search nginx                         # Buscar
dnf info nginx                           # Info detallada
dnf list installed                       # Paquetes instalados
dnf list installed | grep nginx
dnf provides /usr/sbin/nginx             # ¿Qué paquete provee este archivo?

# ─── Grupos ───
dnf group list                           # Grupos disponibles
sudo dnf group install "Development Tools"  # Instalar grupo

# ─── Repos ───
dnf repolist                             # Repos habilitados
dnf repolist all                         # Todos los repos
sudo dnf config-manager --add-repo URL   # Agregar repo
sudo dnf config-manager --set-enabled repo-name

# ─── Historial (exclusivo de dnf) ───
dnf history list                         # Historial de transacciones
dnf history info 5                       # Detalle de transacción 5
sudo dnf history undo 5                  # DESHACER transacción 5 (rollback)

# ─── CentOS 7 EOL fix ───
# CentOS 7 mirrors ya no funcionan. Apuntar a vault:
sudo sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*.repo
sudo sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo
sudo yum update
```

---

# 27. Alpine apk y Snap

## 27.1 Alpine apk

```bash
# Alpine Linux usa apk — extremadamente ligero (para Docker)
apk update                        # Actualizar índice
apk add nginx curl bash           # Instalar
apk add --no-cache nginx          # Instalar sin cache (ideal para Docker)
apk del nginx                     # Desinstalar
apk search nginx                  # Buscar
apk info nginx                    # Info
apk list --installed              # Instalados

# Docker: patrón común
# RUN apk add --no-cache curl bash && rm -rf /var/cache/apk/*
```

## 27.2 Snap

```bash
# Snap es un sistema de paquetes universal de Canonical
sudo snap install code --classic        # Instalar VS Code
sudo snap install node --classic --channel=20
snap list                               # Paquetes instalados
sudo snap refresh                       # Actualizar todos
sudo snap remove code                   # Desinstalar
```

---

# PARTE VIII — DISCO Y ALMACENAMIENTO

---

# 28. Gestión de Disco

## 28.1 df — Disk Free

```bash
df                            # Uso de disco por filesystem
df -h                         # Human-readable (KB, MB, GB)
df -hT                        # Con tipo de filesystem
df -h /                       # Solo la partición root
df -i                         # Inodes (número de archivos)

# Cloud: verificar espacio en disco
df -h | grep -E "^/dev"      # Solo particiones físicas
```

## 28.2 du — Disk Usage

```bash
du -sh /var/log               # Tamaño total de directorio
du -sh /var/log/*             # Tamaño de cada subdirectorio
du -sh /*                     # Tamaño de cada directorio raíz
du -h --max-depth=1 /         # Un nivel de profundidad
du -ah /var/log | sort -rh | head -20   # Top 20 archivos más grandes

# Cloud: ¿qué está llenando el disco?
sudo du -sh /var/log/* | sort -rh | head
sudo du -sh /home/* | sort -rh
```

## 28.3 lsblk y mount

```bash
lsblk                         # Listar block devices (discos, particiones)
lsblk -f                      # Con filesystem type

# Montar disco:
sudo mkdir /mnt/data
sudo mount /dev/xvdf /mnt/data

# Desmontar:
sudo umount /mnt/data

# Montaje permanente (/etc/fstab):
echo "/dev/xvdf /mnt/data ext4 defaults 0 0" | sudo tee -a /etc/fstab

# Cloud: montar un EBS volume en AWS
lsblk                                    # Identificar el disco (xvdf)
sudo file -s /dev/xvdf                   # ¿Tiene filesystem?
sudo mkfs.ext4 /dev/xvdf                 # Crear filesystem (si es nuevo)
sudo mkdir /mnt/data
sudo mount /dev/xvdf /mnt/data
echo "/dev/xvdf /mnt/data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
```

## 28.4 Inodes

```bash
# Los inodes son estructuras que almacenan metadata de archivos.
# Si se agotan los inodes, no puedes crear archivos aunque haya espacio.

df -i                          # Ver uso de inodes
df -ih                         # Human-readable

# Encontrar directorio con más inodes:
find / -xdev -printf '%h\n' | sort | uniq -c | sort -rn | head -10

# Común en cloud: /tmp lleno de archivos pequeños agota inodes
```

---

# 29. Monitoreo del Sistema

## 29.1 Información del sistema

```bash
uname -a                      # Info completa del kernel
uname -r                      # Versión del kernel
cat /etc/os-release           # Distro y versión
hostnamectl                   # Hostname e info del sistema
uptime                        # Tiempo activo + load average
date                          # Fecha y hora
timedatectl                   # Zona horaria

# Cloud: identificar la instancia
curl -s http://169.254.169.254/latest/meta-data/instance-id    # AWS
curl -s http://169.254.169.254/latest/meta-data/instance-type
```

## 29.2 Memoria

```bash
free                          # Uso de memoria
free -h                       # Human-readable
free -h -s 5                  # Actualizar cada 5 segundos

# Entender la salida:
#              total    used    free    shared  buff/cache   available
# Mem:          16G     4.2G    1.1G     200M       10G        11G
#
# "available" es lo que realmente puedes usar (free + buff/cache reclaimable)
# Linux usa memoria libre para cache — eso es BUENO, no un problema.

# Cloud: ¿la instancia necesita más RAM?
free -h | awk '/^Mem:/ {printf "Total: %s, Used: %s, Available: %s\n", $2, $3, $7}'
```

## 29.3 CPU

```bash
nproc                         # Número de CPUs
lscpu                         # Info detallada de CPU
cat /proc/cpuinfo             # Info de cada core

# Load average:
uptime
# 10:20:30 up 5 days, load average: 0.50, 0.75, 1.00
#                                    1min  5min  15min
#
# Regla: si load average > número de CPUs, el sistema está sobrecargado
# 4 CPUs → load > 4.0 = problema
```

## 29.4 vmstat, iostat, iotop

```bash
vmstat 1 5                    # Stats cada 1 segundo, 5 veces
# procs   memory          swap      io       system       cpu
#  r  b   swpd   free     si  so    bi    bo   in    cs  us sy id wa
#  1  0      0  1024000    0   0     5    10  100   200  5  2 92  1
#
# r = processes running, b = blocked
# si/so = swap in/out (si hay mucho swap → necesitas más RAM)
# us = user CPU, sy = system CPU, id = idle, wa = IO wait

iostat -x 1                   # IO stats por disco
iotop                         # Top pero para IO (qué proceso lee/escribe más)
```

---

# PARTE IX — SHELL SCRIPTING

---

# 30. Fundamentos de Scripting

## 30.1 Crear y ejecutar un script

```bash
# Crear script:
cat << 'EOF' > script.sh
#!/bin/bash
# Este es un comentario
echo "Hello, $(whoami)!"
echo "Hoy es $(date)"
EOF

# Dar permisos de ejecución:
chmod +x script.sh

# Ejecutar:
./script.sh            # Ejecutar directamente
bash script.sh         # Ejecutar con bash explícito
source script.sh       # Ejecutar en el shell actual (variables persisten)
. script.sh            # Igual que source
```

## 30.2 Shebang

```bash
#!/bin/bash            # Usar bash
#!/bin/sh              # Usar sh (más portátil, menos features)
#!/usr/bin/env bash    # Buscar bash en PATH (más portátil)
#!/usr/bin/env python3 # Para scripts Python
```

## 30.3 Variables

```bash
# Asignación (SIN espacios alrededor del =):
NAME="World"
PORT=8080
DIR="/var/log"

# Uso:
echo "Hello, $NAME"
echo "Hello, ${NAME}"         # Con llaves (recomendado)
echo "Port: ${PORT:-3000}"    # Default: si PORT no está definida, usa 3000

# Variables especiales:
$0        # Nombre del script
$1..$9    # Argumentos posicionales
$#        # Número de argumentos
$@        # Todos los argumentos (como lista)
$*        # Todos los argumentos (como string)
$?        # Exit code del último comando
$$        # PID del script
$!        # PID del último proceso en background

# Leer input del usuario:
read -p "Enter your name: " NAME
echo "Hello, $NAME"

# Capturar output de un comando:
CURRENT_DATE=$(date +%Y-%m-%d)
NUM_FILES=$(ls | wc -l)
IP=$(hostname -I | awk '{print $1}')
```

---

# 31. Variables, Condicionales y Loops

## 31.1 Condicionales

```bash
# if / elif / else:
if [ "$1" == "start" ]; then
    echo "Starting..."
elif [ "$1" == "stop" ]; then
    echo "Stopping..."
else
    echo "Usage: $0 {start|stop}"
    exit 1
fi

# [[ ]] es preferible a [ ] en bash (más seguro, soporta regex):
if [[ -z "$VAR" ]]; then
    echo "VAR está vacía"
fi

if [[ "$NAME" =~ ^[A-Z] ]]; then
    echo "Empieza con mayúscula"
fi
```

## 31.2 Operadores de comparación

```text
┌─────────────────┬──────────────────┬─────────────────────────┐
│  Numéricos      │  Strings         │  Archivos               │
├─────────────────┼──────────────────┼─────────────────────────┤
│  -eq  (==)      │  ==  (igual)     │  -f  (es archivo)       │
│  -ne  (!=)      │  !=  (diferente) │  -d  (es directorio)    │
│  -gt  (>)       │  -z  (vacío)     │  -e  (existe)           │
│  -ge  (>=)      │  -n  (no vacío)  │  -r  (es legible)       │
│  -lt  (<)       │  <   (menor)     │  -w  (es escribible)    │
│  -le  (<=)      │  >   (mayor)     │  -x  (es ejecutable)    │
│                 │                  │  -s  (tamaño > 0)       │
│                 │                  │  -L  (es symlink)       │
└─────────────────┴──────────────────┴─────────────────────────┘

Lógicos:
  &&  (AND)     ||  (OR)     !  (NOT)
  -a  (AND dentro de [ ])     -o  (OR dentro de [ ])
```

## 31.3 Ejemplos prácticos de condicionales

```bash
# Verificar si archivo existe:
if [[ -f "/etc/nginx/nginx.conf" ]]; then
    echo "Nginx está instalado"
fi

# Verificar si comando existe:
if command -v docker &> /dev/null; then
    echo "Docker está instalado: $(docker --version)"
else
    echo "Docker no está instalado"
fi

# Verificar si root:
if [[ $EUID -ne 0 ]]; then
    echo "Este script necesita root. Usa sudo."
    exit 1
fi

# Verificar argumentos:
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <filename>"
    exit 1
fi
```

## 31.4 Loops

```bash
# ─── for loop ───
for i in 1 2 3 4 5; do
    echo "Número: $i"
done

for i in {1..10}; do
    echo "Número: $i"
done

for i in $(seq 1 2 10); do      # 1, 3, 5, 7, 9
    echo "Número: $i"
done

# C-style for:
for ((i=0; i<10; i++)); do
    echo "Iteración: $i"
done

# Iterar sobre archivos:
for file in /var/log/*.log; do
    echo "Procesando: $file ($(wc -l < "$file") líneas)"
done

# Iterar sobre líneas de archivo:
while IFS= read -r line; do
    echo "Línea: $line"
done < file.txt

# ─── while loop ───
count=0
while [[ $count -lt 5 ]]; do
    echo "Count: $count"
    ((count++))
done

# While infinito (útil para monitoreo):
while true; do
    echo "$(date): $(free -h | awk '/^Mem:/ {print $7}')"
    sleep 60
done

# ─── until loop ───
until ping -c 1 google.com &> /dev/null; do
    echo "Esperando red..."
    sleep 5
done
echo "Red disponible!"
```

## 31.5 case statement

```bash
case "$1" in
    start)
        echo "Starting service..."
        systemctl start myapp
        ;;
    stop)
        echo "Stopping service..."
        systemctl stop myapp
        ;;
    restart)
        echo "Restarting service..."
        systemctl restart myapp
        ;;
    status)
        systemctl status myapp
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
```

---

# 32. Funciones y Scripts Avanzados

## 32.1 Funciones

```bash
# Definir función:
greet() {
    local name="$1"        # local = variable local a la función
    echo "Hello, ${name}!"
}

# Llamar:
greet "World"

# Función con return:
is_running() {
    local service="$1"
    systemctl is-active --quiet "$service"
    return $?     # 0 si activo, non-zero si no
}

if is_running "nginx"; then
    echo "Nginx is running"
fi
```

## 32.2 Manejo de errores

```bash
#!/bin/bash
set -euo pipefail
# -e  = exit on error (si un comando falla, el script para)
# -u  = error on undefined variables
# -o pipefail = un pipe falla si cualquier comando falla

# Trap — ejecutar código al salir (cleanup):
cleanup() {
    echo "Limpiando archivos temporales..."
    rm -f /tmp/myapp_*
}
trap cleanup EXIT          # Se ejecuta siempre al terminar
trap cleanup ERR           # Se ejecuta si hay error

# Trap Ctrl+C:
trap "echo 'Cancelado'; exit 1" INT
```

## 32.3 Script completo: Health Check

```bash
#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════
#  Health Check Script para Cloud
# ═══════════════════════════════════

LOG_FILE="/var/log/health-check.log"
SERVICES=("nginx" "myapp" "docker")
DISK_THRESHOLD=90
MEM_THRESHOLD=90

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" | tee -a "$LOG_FILE"
}

check_services() {
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "OK" "$service is running"
        else
            log "CRITICAL" "$service is NOT running!"
            sudo systemctl restart "$service"
            log "ACTION" "Attempted to restart $service"
        fi
    done
}

check_disk() {
    local usage
    usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    if [[ $usage -gt $DISK_THRESHOLD ]]; then
        log "WARNING" "Disk usage at ${usage}%"
    else
        log "OK" "Disk usage at ${usage}%"
    fi
}

check_memory() {
    local usage
    usage=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
    if [[ $usage -gt $MEM_THRESHOLD ]]; then
        log "WARNING" "Memory usage at ${usage}%"
    else
        log "OK" "Memory usage at ${usage}%"
    fi
}

main() {
    log "INFO" "Starting health check..."
    check_services
    check_disk
    check_memory
    log "INFO" "Health check complete."
}

main "$@"
```

## 32.4 Script completo: Deployment

```bash
#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════
#  Simple Deployment Script
# ═══════════════════════════════════

APP_DIR="/opt/myapp"
BACKUP_DIR="/opt/backups"
REPO="git@github.com:user/myapp.git"
BRANCH="${1:-main}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# Backup current version
log "Creating backup..."
BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
cp -a "$APP_DIR" "$BACKUP_DIR/$BACKUP_NAME"

# Pull latest code
log "Pulling branch: $BRANCH"
cd "$APP_DIR"
git fetch origin
git checkout "$BRANCH"
git pull origin "$BRANCH"

# Install dependencies
log "Installing dependencies..."
npm install --production

# Restart service
log "Restarting application..."
sudo systemctl restart myapp

# Verify
sleep 3
if curl -sf http://localhost:8080/health > /dev/null; then
    log "✓ Deployment successful!"
else
    log "✗ Health check failed! Rolling back..."
    rm -rf "$APP_DIR"
    cp -a "$BACKUP_DIR/$BACKUP_NAME" "$APP_DIR"
    sudo systemctl restart myapp
    log "Rolled back to previous version."
    exit 1
fi
```

---

# PARTE X — CLOUD, SEGURIDAD Y TROUBLESHOOTING

---

# 33. Seguridad y Hardening

## 33.1 SSH Hardening

```bash
# Editar /etc/ssh/sshd_config:
sudo nano /etc/ssh/sshd_config

# Cambios recomendados:
#   PermitRootLogin no              ← no permitir login como root
#   PasswordAuthentication no       ← solo SSH keys
#   PubkeyAuthentication yes        ← habilitar keys
#   Port 2222                       ← cambiar puerto default (opcional)
#   MaxAuthTries 3                  ← intentos máximos
#   ClientAliveInterval 300         ← timeout 5 min sin actividad
#   ClientAliveCountMax 2
#   AllowUsers ubuntu deploy        ← solo estos usuarios pueden SSH

# Aplicar:
sudo systemctl restart sshd

# Verificar ANTES de cerrar la sesión actual:
# Abrir otra terminal y probar ssh con la nueva config.
```

## 33.2 Firewall

```bash
# ─── UFW (Ubuntu) ───
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp          # SSH
sudo ufw allow 80/tcp          # HTTP
sudo ufw allow 443/tcp         # HTTPS
sudo ufw enable
sudo ufw status verbose

# ─── Cloud: Security Groups (AWS, Azure, GCP) ───
# Los security groups son firewalls a nivel de nube.
# UFW es un firewall a nivel de OS — usa ambos como defense in depth.
```

## 33.3 fail2ban

```bash
# Protege contra brute-force attacks
sudo apt install fail2ban

# Config:
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local

# [sshd]
# enabled = true
# port = 22
# maxretry = 3
# bantime = 3600      # 1 hora
# findtime = 600      # Ventana de 10 min

sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
```

## 33.4 Auditoría

```bash
# Intentos de login:
grep "Failed password" /var/log/auth.log | tail -20
grep "Accepted publickey" /var/log/auth.log | tail -20

# Últimos logins:
last                           # Logins exitosos
lastb                          # Logins fallidos
who                            # Conectados ahora

# Archivos modificados recientemente:
find /etc -mtime -1 -type f   # Configs modificadas en 24h

# Procesos escuchando:
ss -tlnp                       # ¿Hay algo inesperado?
```

---

# 34. Troubleshooting en Cloud Servers

## 34.1 El servidor no responde

```bash
# 1. ¿Puedes hacer ping?
ping -c 3 <server-ip>

# 2. ¿El puerto está abierto?
nc -zv <server-ip> 22          # SSH
nc -zv <server-ip> 80          # HTTP
telnet <server-ip> 80

# 3. ¿El servicio está corriendo?
sudo systemctl status nginx
sudo systemctl status myapp

# 4. ¿El firewall bloquea?
sudo ufw status
sudo iptables -L -n

# 5. ¿La app escucha en el puerto correcto?
ss -tlnp | grep :80

# 6. Verificar DNS:
dig myapp.com
nslookup myapp.com
```

## 34.2 Disco lleno

```bash
# 1. Verificar:
df -h

# 2. ¿Qué está consumiendo espacio?
sudo du -sh /* | sort -rh | head
sudo du -sh /var/log/* | sort -rh | head

# 3. Limpiar:
sudo journalctl --vacuum-size=100M      # Logs de systemd
sudo apt autoremove                     # Paquetes huérfanos
sudo apt clean                          # Cache de APT
sudo find /var/log -name "*.gz" -mtime +30 -delete   # Logs comprimidos viejos
sudo find /tmp -mtime +7 -delete        # Temp files viejos

# 4. Encontrar archivos borrados pero aún abiertos:
sudo lsof | grep deleted | sort -k7 -rn | head
# Si un proceso tiene un archivo abierto que fue borrado, el espacio no se libera.
# Solución: reiniciar el proceso.
```

## 34.3 Alto uso de CPU/Memoria

```bash
# 1. ¿Qué consume CPU?
top -o %CPU
ps aux --sort=-%cpu | head -10

# 2. ¿Qué consume memoria?
top -o %MEM
ps aux --sort=-%mem | head -10

# 3. ¿OOM Killer actuó? (Linux mató un proceso por falta de RAM)
dmesg | grep -i "oom\|out of memory"
journalctl | grep -i "oom\|killed process"

# 4. ¿Hay swap en uso?
free -h
swapon --show

# 5. Load average alto:
uptime
# Si load > número de CPUs → sobrecarga
# Causas: CPU-bound, IO-bound, o demasiados procesos
```

## 34.4 Problemas de red

```bash
# 1. ¿Hay conectividad a internet?
ping -c 3 8.8.8.8             # Ping por IP
ping -c 3 google.com          # Ping por DNS

# Si IP funciona pero DNS no:
cat /etc/resolv.conf
# nameserver 8.8.8.8          # Google DNS
# nameserver 1.1.1.1          # Cloudflare DNS

# 2. ¿Cuál es mi IP pública?
curl -s ifconfig.me
curl -s icanhazip.com

# 3. Traceroute:
traceroute google.com

# 4. ¿La ruta es correcta?
ip route show

# 5. Verificar interfaces:
ip addr show
```

## 34.5 Servicio no arranca

```bash
# 1. Ver el error:
sudo systemctl status myapp
journalctl -u myapp -n 50 --no-pager

# 2. Ver la config del unit:
systemctl cat myapp

# 3. Verificar manualmente:
# Ejecutar el ExecStart a mano para ver el error directo:
sudo -u deploy /usr/bin/node /opt/myapp/server.js

# 4. Permisos:
ls -la /opt/myapp/
# ¿El usuario del servicio tiene acceso?

# 5. Puertos:
ss -tlnp | grep :8080
# ¿Otro proceso ya ocupa el puerto?
```

---

# 35. Tips y Buenas Prácticas

## 35.1 Seguridad

```text
┌──────────────────────────────────────────────────────────────────┐
│  1. NUNCA usar root directamente — siempre sudo                  │
│  2. SSH con keys, NUNCA con passwords                            │
│  3. chmod 400 para llaves privadas (.pem)                        │
│  4. Firewall: deny all, allow específico                         │
│  5. Mantener paquetes actualizados (sudo apt update && upgrade)  │
│  6. fail2ban contra brute force                                  │
│  7. No exponer bases de datos a internet (0.0.0.0:3306 = ❌)    │
│  8. Rotar SSH keys periódicamente                                │
│  9. Usar Security Groups de la nube + firewall del OS            │
│  10. Auditar /var/log/auth.log regularmente                      │
└──────────────────────────────────────────────────────────────────┘
```

## 35.2 Prevención de desastres

```text
┌──────────────────────────────────────────────────────────────────┐
│  1. SIEMPRE `ls` antes de `rm -rf`                               │
│  2. Usar `rm -i` o alias rm="rm -i" para confirmación           │
│  3. Backup ANTES de editar configs: cp file file.bak             │
│  4. Usar `--dry-run` o `-n` cuando esté disponible               │
│  5. Probar comandos destructivos con `echo` primero              │
│  6. Nunca ejecutar `curl URL | sh` sin leer el script primero   │
│  7. Usar `screen` o `tmux` para sesiones SSH largas             │
│  8. Verificar hostname antes de ejecutar comandos destructivos   │
│  9. En scripts: `set -euo pipefail`                              │
│  10. Mantener backups automatizados y verificados                │
└──────────────────────────────────────────────────────────────────┘
```

## 35.3 Productividad

```bash
# Aliases útiles (agregar a ~/.bashrc):
alias ll='ls -lah'
alias gs='git status'
alias dc='docker compose'
alias k='kubectl'
alias ..='cd ..'
alias ...='cd ../..'
alias ports='ss -tlnp'
alias myip='curl -s ifconfig.me'
alias update='sudo apt update && sudo apt upgrade -y'

# Historial mejorado:
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# tmux — terminal multiplexer (esencial para SSH):
tmux                         # Nueva sesión
tmux new -s deploy           # Sesión con nombre
tmux attach -t deploy        # Reconectar a sesión
# Ctrl+B D = detach (salir sin matar)
# Ctrl+B C = nueva ventana
# Ctrl+B N = siguiente ventana
# Ctrl+B % = split vertical
# Ctrl+B " = split horizontal
```

## 35.4 Cheat Sheet — Comandos más usados en Cloud

```text
┌────────────────────────────┬─────────────────────────────────────┐
│  Tarea                     │  Comando                            │
├────────────────────────────┼─────────────────────────────────────┤
│  Conectar a servidor       │  ssh -i key.pem user@ip             │
│  Ver logs en vivo          │  tail -f /var/log/app/app.log       │
│  Espacio en disco          │  df -h                              │
│  ¿Qué consume espacio?    │  du -sh /* | sort -rh | head        │
│  Procesos por CPU          │  ps aux --sort=-%cpu | head         │
│  Procesos por memoria      │  ps aux --sort=-%mem | head         │
│  ¿Servicio corriendo?     │  systemctl status nginx             │
│  Reiniciar servicio        │  sudo systemctl restart nginx       │
│  Ver errores del servicio  │  journalctl -u nginx -p err         │
│  ¿Puerto abierto?         │  ss -tlnp | grep :80                │
│  IPs con más requests      │  awk '{print $1}' access.log \     │
│                            │  | sort | uniq -c | sort -rn | head │
│  Buscar en archivos        │  grep -r "error" /var/log/          │
│  Copiar a servidor         │  scp file user@ip:/path/            │
│  Sincronizar               │  rsync -avzP src/ user@ip:/dest/    │
│  Firewall                  │  sudo ufw status                    │
│  Actualizar sistema        │  sudo apt update && apt upgrade -y  │
│  Crear usuario deploy      │  sudo useradd -m -s /bin/bash -G   │
│                            │  sudo deploy                        │
│  Verificar health          │  curl -s -o /dev/null -w "%{http_  │
│                            │  code}" http://localhost:8080/health│
└────────────────────────────┴─────────────────────────────────────┘
```