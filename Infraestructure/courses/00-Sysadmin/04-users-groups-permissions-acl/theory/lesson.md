# Lección: Usuarios, grupos, permisos y ACL

> **ID:** `sys-04-users-groups-permissions-acl` · **Nivel:** intermedio · **Duración:** 4 h
> **Prerrequisitos:** `sys-03` (sistema de archivos y procesos), acceso `sudo` a una VM Linux descartable.

---

## 1. Introducción intuitiva

Imagina una oficina con una sola llave maestra. Al principio sois dos personas, confianza total, nadie se preocupa. Entra una tercera: ya no quiere que vean su cajón. Entra un becario: sólo debería poder entrar a la sala común. Un día tenéis que dejar entrar al técnico de la caldera, pero sólo a la caldera, y sólo este martes. La solución "todas las llaves maestras" (`chmod 777`) deja de valer: alguien va a borrar un archivo que no debía, por error, no por malicia.

Linux resuelve exactamente este problema con tres capas superpuestas:

- **DAC** (Discretionary Access Control): cada archivo tiene un dueño, un grupo y tres ternas `rwx`. Es el modelo de los 70 que todavía manda.
- **POSIX ACL**: cuando "dueño/grupo/otros" no basta (ej. "dos grupos tienen que escribir, pero no todo el mundo"), añades entradas finas sin pervertir el modelo DAC.
- **sudoers**: cuando una persona necesita *puntualmente* actuar como otra (típicamente como `root`), no le das la contraseña ni un shell de root — le autorizas un comando concreto.

En paralelo, el kernel ofrece **capabilities**: trocear "ser root" en ~40 superpoderes independientes (`CAP_NET_BIND_SERVICE`, `CAP_SYS_TIME`...) y dar sólo el que hace falta.

Esta lección construye ese modelo desde los archivos planos que lo definen (`/etc/passwd`, `/etc/shadow`, `/etc/group`) hasta las decisiones de diseño ("¿sudo o capability?", "¿grupo o ACL?") que separan a un sysadmin que entiende de uno que copia-pega de StackOverflow.

---

## 2. Fundamentos: identidad en Linux

Antes de permisos hay que entender **quién eres** para el kernel. "Eres" un número: tu **UID** (User ID). Pertenecer a un grupo es tener su **GID** en tu lista de grupos. Nombres como `evan` o `developers` son comodidad humana; el kernel sólo ve números.

### 2.1 `/etc/passwd`

Un registro por usuario, siete campos separados por `:`:

```
evan:x:1000:1000:Evan Flores,,,:/home/evan:/bin/bash
```

| Campo | Significado |
|-------|-------------|
| `evan` | Nombre de login. |
| `x` | *Placeholder*; la contraseña real vive en `/etc/shadow`. |
| `1000` | UID. |
| `1000` | GID primario (grupo por defecto al crear archivos). |
| `Evan Flores,,,` | GECOS (nombre completo y campos opcionales). |
| `/home/evan` | Home. |
| `/bin/bash` | Shell de login. Un `/usr/sbin/nologin` deniega sesión interactiva. |

Es un archivo de texto. Lo lee todo el mundo (tiene que, porque `ls -l` necesita traducir UIDs a nombres). Esto significa: **no guardes nada secreto aquí**.

### 2.2 `/etc/shadow`

Mismo índice que `passwd`, pero legible sólo por `root` (modo `0640` o `0000`, grupo `shadow`). Contiene el hash de la contraseña y la **política de expiración**:

```
evan:$y$j9T$...:19845:0:90:7:::
```

Campos relevantes: hash (`$y$` = yescrypt, `$6$` = SHA-512-crypt), fecha del último cambio (días desde epoch), mínimo entre cambios, máximo (expiración), aviso previo, periodo de inactividad, fecha de bloqueo.

Un hash que empieza con `!` o `*` significa cuenta **bloqueada para contraseña** (puede seguir pudiendo entrar por SSH key, cuidado).

### 2.3 `/etc/group`

```
developers:x:1200:evan,ana,diego
```

Nombre, placeholder, GID, miembros (coma, sin espacios). El **grupo primario** del usuario *no* suele aparecer en esta lista — está en `passwd`. Los grupos **secundarios** sí.

Dato importante: los grupos secundarios de una sesión se cargan **al login**. Si añades a `evan` a `developers` mientras tiene una sesión abierta, no los verá hasta cerrar y volver a entrar (o usar `newgrp developers`, que abre una subshell con el GID como primario temporal).

### 2.4 UID real, efectivo y guardado

Un proceso tiene **tres** UIDs:

- **Real (ruid)**: quién lo lanzó.
- **Efectivo (euid)**: qué permisos usa el kernel para comprobaciones DAC.
- **Guardado (suid)**: copia para poder restaurar.

Normalmente los tres coinciden. Un binario **setuid root** arranca con `ruid=tú, euid=0, suid=0`. Puede bajar temporalmente a tu UID (`seteuid(ruid)`) para operaciones no privilegiadas, y volver cuando necesita el poder. Esto es la base de `passwd`, `sudo` o `ping` (clásico).

Lo mismo existe para grupos: `rgid`, `egid`, `sgid`, más una lista de **grupos suplementarios** (`getgroups(2)`).

### 2.5 Usuarios de sistema vs humanos

Convención (no ley del kernel): UIDs **< 1000** son "del sistema" — `root` (0), `daemon`, `www-data`, `postgres`, `sshd`... Son identidades para **procesos**, no para personas. Tienen shell `/usr/sbin/nologin` y home en `/var/lib/<servicio>` o inexistente.

`useradd` sin flags crea un humano (UID ≥ 1000, home, shell). `useradd --system` crea uno de sistema (UID bajo, sin home por defecto). Esta distinción es crítica para auditoría: si ves actividad del UID 33 (`www-data`) a las 3am, es Nginx; si ves actividad del UID 1004 a las 3am, es una persona (o alguien que robó su cuenta).

---

## 3. Gestión de cuentas

### 3.1 Alta: `useradd` / `adduser`

Dos herramientas distintas:

- `useradd` (shadow-utils, universal): bajo nivel, hace exactamente lo que le pides.
- `adduser` (perl wrapper en Debian/Ubuntu): interactivo, aplica políticas distro.

En scripts siempre `useradd`. Ejemplo canónico:

```bash
sudo useradd \
  --create-home \
  --shell /bin/bash \
  --user-group \
  --comment "Ana Lopez" \
  ana
sudo passwd ana   # establece contraseña inicial
```

- `--create-home`: crea `/home/ana` copiando `/etc/skel/`.
- `--shell`: por defecto suele ser `/bin/sh`; ponlo explícito.
- `--user-group`: crea también un grupo `ana` con el mismo GID (**UPG**, User Private Group; estándar en Red Hat/Debian).
- `--comment`: nombre humano, va al campo GECOS.

Para una cuenta de servicio:

```bash
sudo useradd --system --shell /usr/sbin/nologin --home-dir /var/lib/myapp --no-create-home myapp
```

### 3.2 Modificación: `usermod`

```bash
sudo usermod -aG developers ana          # añade a grupo secundario (OJO con -a: APPEND)
sudo usermod -s /bin/zsh ana             # cambia shell
sudo usermod -L ana                      # bloquea login por contraseña (añade ! al hash)
sudo usermod -U ana                      # desbloquea
```

El error más caro del novato: `usermod -G developers ana` **sin `-a`**. Esto *reemplaza* la lista completa de grupos secundarios: la saca de `sudo`, `docker`, `wheel`... Siempre `-aG` al añadir.

### 3.3 Baja: `userdel`

```bash
sudo userdel ana           # sólo borra la cuenta, deja /home/ana
sudo userdel -r ana        # borra también home y mail spool
```

En producción raramente borras: **bloqueas** (`usermod -L`, deshabilitas la shell) y archivas el home para auditoría. Borrar el UID y luego crear otro usuario con el mismo UID significa que el nuevo "hereda" archivos que ya no debería tener.

### 3.4 Política de contraseñas: `chage`

```bash
sudo chage -l ana                        # lista política actual
sudo chage -M 90 -W 7 -I 30 ana          # max 90d, aviso 7d antes, bloqueo 30d tras expirar
sudo chage -E 2026-12-31 ana             # cuenta expira esa fecha (becario con contrato fijo)
sudo chage -d 0 ana                      # fuerza cambio en el próximo login
```

Es el único control de rotación "nativo" sin PAM extra. Para complejidad real (longitud, histórico, diccionario) necesitas `pam_pwquality`, que veremos en `sys-07`.

### 3.5 Grupos: `groupadd` / `gpasswd`

```bash
sudo groupadd --system docker            # grupo del sistema
sudo groupadd developers
sudo gpasswd -a ana developers           # añadir
sudo gpasswd -d ana developers           # eliminar
sudo gpasswd -A diego developers         # delegar admin del grupo a diego
```

`gpasswd -A` es poco usado pero útil: permite que `diego` administre miembros de `developers` sin ser root.

---

## 4. Permisos POSIX: `rwx`

### 4.1 El modelo mental

Cada inodo guarda:

- `owner` (UID) + `group` (GID).
- Tres ternas de bits: owner, group, other, cada una con `r`, `w`, `x`.

Cuando un proceso quiere acceder, el kernel comprueba en este orden:

1. ¿Es `euid` del proceso = owner? → usa la terna `owner` y para.
2. ¿Está `egid` o algún grupo suplementario entre los grupos del archivo? → usa la terna `group` y para.
3. En otro caso → usa la terna `other`.

**Esto implica que la terna `other` sólo se consulta si no eres ni dueño ni miembro del grupo.** Un propietario con `0` en su terna no puede leer su archivo, aunque `other` tenga `rwx`.

### 4.2 Qué significa `rwx` en archivos vs directorios

| Bit | En archivo | En directorio |
|-----|------------|---------------|
| `r` | Leer contenido. | Listar nombres (`ls`). |
| `w` | Modificar contenido. | **Crear/renombrar/borrar entradas** (independiente de los permisos del archivo). |
| `x` | Ejecutar como programa. | **Atravesar**: hacer `cd`, abrir inodos por nombre. |

Dos consecuencias contra-intuitivas:

- Puedes borrar un archivo que no te pertenece y no puedes modificar, **si** tienes `w` en el directorio que lo contiene.
- Puedes tener `rw-` en un archivo y no poder leerlo si no tienes `x` en algún directorio del path.

El bit `x` en directorio sin `r` ("search-only") es una técnica real: permite acceder a `/srv/datos/informe.pdf` si conoces el nombre exacto, pero `ls /srv/datos/` falla.

### 4.3 `chmod` numérico y simbólico

Numérico (octal): cada dígito es una terna.

```
r=4  w=2  x=1
rwx = 7, rw- = 6, r-x = 5, r-- = 4
```

```bash
chmod 640 config.yaml   # rw- r-- ---
chmod 750 bin/tool      # rwx r-x ---
chmod 755 /srv/public   # rwx r-x r-x
```

Simbólico: `[ugoa][+-=][rwxXst]`.

```bash
chmod g+w file          # añade w al grupo
chmod o-rwx file        # quita todo a other
chmod a+X dir           # añade x a all SOLO si ya era directorio o algún x existía (útil con -R)
```

El `X` mayúscula es oro para `chmod -R`: aplica `x` a directorios (para poder entrar) pero no convierte en ejecutable cada `.txt`.

### 4.4 Bits especiales: setuid, setgid, sticky

Un cuarto dígito octal al frente:

| Bit | Octal | En archivo ejecutable | En directorio |
|-----|-------|------------------------|---------------|
| setuid | 4 | Se ejecuta con `euid` del *dueño del binario*. | (ignorado en Linux). |
| setgid | 2 | Se ejecuta con `egid` del *grupo del binario*. | **Archivos nuevos heredan el grupo del directorio** (no del creador). |
| sticky | 1 | (histórico). | Sólo el dueño del archivo (o root) puede borrarlo, aunque others tengan `w`. Es el bit de `/tmp`. |

```bash
ls -l /usr/bin/passwd
# -rwsr-xr-x  1 root root  ...   la 's' en la terna owner = setuid
ls -ld /tmp
# drwxrwxrwt  ...                la 't' final = sticky
ls -ld /srv/team
# drwxrws---  ...                la 's' en group = setgid directorio
```

**setgid en directorios es la pieza clave de un directorio compartido**: sin él, cada archivo que `evan` cree ahí tendrá grupo `evan`; con él, tendrá grupo del directorio (`developers`), y sus compañeros podrán editarlo.

**setuid en scripts shell**: Linux lo **ignora** por seguridad (race conditions imposibles de cerrar). Si lo necesitas, es señal de que debes usar `sudo` o una capability.

### 4.5 `umask`

Al crear un archivo, los permisos "pedidos" por el programa (típicamente `0666` archivos, `0777` dirs) se enmascaran con tu `umask`, que es lo que **restas**:

```
pedido 0666
umask  0022   (quita w a group y other)
real   0644
```

```bash
umask           # muestra tu valor
umask 0027      # dir=750, archivo=640 (nada para 'other')
```

En `/etc/profile` o `/etc/login.defs` (`UMASK 027`) se fija la del sistema. Para servicios, systemd permite `UMask=` por unidad.

### 4.6 `chown` / `chgrp`

```bash
sudo chown ana:developers informe.md     # dueño y grupo a la vez
sudo chown -R ana /home/ana              # recursivo
sudo chgrp developers informe.md         # sólo grupo
```

Sólo `root` puede cambiar el dueño (en Linux estándar). Cambiar el grupo lo puede hacer el dueño del archivo *si* pertenece al grupo destino.

### 4.7 Ejemplo trabajado: directorio compartido para `developers`

Queremos `/srv/team` donde los miembros del grupo `developers` colaboren: todos leen, todos escriben, los archivos nuevos heredan el grupo correcto.

```bash
sudo groupadd developers
sudo usermod -aG developers ana
sudo usermod -aG developers diego

sudo mkdir -p /srv/team
sudo chown root:developers /srv/team
sudo chmod 2770 /srv/team         # 2 = setgid, 770 = rwx rwx ---
```

Verificación:

```bash
ls -ld /srv/team
# drwxrws---  2 root developers  ...  ← 's' en el grupo
```

Prueba:

```bash
sudo -u ana touch /srv/team/notas.md
ls -l /srv/team/notas.md
# -rw-r--r--  1 ana developers  ...   ← grupo heredado por setgid
```

Pero fíjate: el archivo nuevo salió `0644` por el `umask 0022` default. `diego` no puede escribir. Esto nos lleva a las ACL.

---

## 5. POSIX ACL (Access Control Lists)

### 5.1 Por qué ACL

El modelo `user/group/other` tiene un límite duro: **un** grupo propietario. Si dos grupos distintos (digamos `developers` y `qa`) necesitan escribir sobre el mismo directorio, con permisos distintos, no te alcanza. Alternativas malas:

- Hacer que `qa` sea miembro de `developers` → explosión transitiva de permisos.
- `chmod 777` → cualquiera del sistema entra.

ACL permite añadir entradas tipo "usuario X: rwx", "grupo Y: r-x", sin tocar el modelo DAC.

### 5.2 Habilitar y consultar

En la mayoría de distros modernas, ext4/xfs/btrfs montan con ACL por defecto. Si no:

```bash
sudo mount -o remount,acl /
```

```bash
getfacl /srv/team
# file: srv/team
# owner: root
# group: developers
# flags: -s-                 (s = setgid)
# user::rwx
# group::rwx
# other::---
```

### 5.3 Añadir entradas

```bash
# dar rwx al usuario 'qa-bot' sobre /srv/team
sudo setfacl -m u:qa-bot:rwx /srv/team

# dar r-x al grupo 'qa'
sudo setfacl -m g:qa:rx /srv/team
```

`-m` = modify. Las entradas se añaden; para quitar: `setfacl -x u:qa-bot /srv/team`. Para borrar todas: `setfacl -b`.

### 5.4 Default ACL: herencia

El problema del ejemplo anterior era que archivos nuevos salían `0644`. Con **default ACL** (prefijo `d:`) decimos "los hijos de este directorio heredan esto":

```bash
sudo setfacl -d -m u::rwx,g::rwx,o::---,g:developers:rwx /srv/team
```

Desde ahora, un `touch /srv/team/x` crea el archivo con una ACL que da `rwx` al grupo `developers` sin depender del `umask` del creador.

### 5.5 La mask: el detalle que confunde a todo el mundo

Cuando un archivo tiene ACL extendida, aparece una entrada `mask::`. Es un **techo**: ninguna entrada efectiva puede dar más permisos que la mask. En la salida verás columnas `effective`:

```
group::rwx                      #effective:r-x
mask::r-x
```

Significa: aunque `group::` pide `rwx`, la mask lo recorta a `r-x`.

**`chmod` sobre un archivo con ACL** no modifica `group::`, modifica la **mask**. Esto sorprende: haces `chmod g-w` y de pronto una entrada `user:ana:rwx` se queda en `r-x` effective. Es por diseño: `chmod` sigue dando una "lectura POSIX clásica" correcta.

Si quieres actualizar la mask para que vuelva a abarcar todo: `setfacl -m m::rwx file`.

### 5.6 Camino de resolución en el kernel

Cuando llamas a `open("/srv/team/x", O_WRONLY)`, el kernel evalúa en este orden (resumido):

1. **DAC**: owner → ACL `user:X` → owning group → ACL `group:Y` → other.
2. Si DAC/ACL conceden, consulta **MAC** (SELinux/AppArmor). Un `deny` MAC gana contra un `allow` DAC.
3. Si MAC permite, consulta **capabilities** del proceso para operaciones que las requieren (p. ej. `chown` requiere `CAP_CHOWN`).

Moraleja: aunque DAC te deje pasar, SELinux puede denegarte. "Me da permiso denegado y los permisos están bien" suele ser esto, especialmente en RHEL/Fedora.

---

## 6. `sudo` y `/etc/sudoers`

### 6.1 Qué resuelve

Dar la contraseña de `root` o dejar un shell de root abierto no escala: no hay auditoría ("¿quién reinició nginx a las 3am?"), un error (`rm -rf /`) es terminal, y la rotación de contraseña es un drama. `sudo` permite:

- Autorizar a usuario `X` ejecutar comando `C` **como** usuario `Y` (típicamente `root`).
- Pedir **su propia** contraseña, no la del destino.
- **Loguear** cada invocación (`/var/log/auth.log`, `journalctl _COMM=sudo`).

### 6.2 Edición segura: `visudo`

**Nunca edites `/etc/sudoers` con `vim` directamente**. Un error de sintaxis te deja sin forma de volverte root. `visudo` valida antes de guardar:

```bash
sudo visudo                       # /etc/sudoers
sudo visudo -f /etc/sudoers.d/dev # un fragmento aparte
sudo visudo -cf archivo           # sólo valida, no abre editor
```

### 6.3 Patrón recomendado: `sudoers.d/`

`/etc/sudoers` suele incluir `#includedir /etc/sudoers.d`. Trabajamos ahí, un archivo por propósito, modo `0440`:

```bash
sudo visudo -f /etc/sudoers.d/10-nginx-ops
```

Nombres sin punto y sin tilde (los que tienen `.` o `~` se ignoran — es *feature*, no bug).

### 6.4 Sintaxis básica

```
# Quién   Dónde=(Como quién)   NOPASSWD: Qué
ana       ALL=(ALL:ALL)        ALL
%devops   ALL=(root)           /usr/bin/systemctl restart nginx
```

- `ana ALL=(ALL:ALL) ALL`: ana en cualquier host, como cualquier usuario:grupo, puede correr cualquier comando. **Esto no se da nunca** fuera de prototipos.
- `%devops ...`: el `%` indica *grupo* (el grupo Unix `devops`).
- `NOPASSWD:` elimina el prompt — útil para automatización, peligroso para cuentas humanas.

### 6.5 Ejemplo trabajado: regla sudoers mínima

Queremos que miembros del grupo `webops` reinicien **solo** nginx, sin más.

Archivo `/etc/sudoers.d/10-webops-nginx`:

```
# Permitir a webops reiniciar nginx (y sólo nginx)
Cmnd_Alias NGINX_RESTART = /usr/bin/systemctl restart nginx, \
                           /usr/bin/systemctl reload nginx, \
                           /usr/bin/systemctl status nginx

%webops ALL=(root) NOPASSWD: NGINX_RESTART
```

Validar antes de salir:

```bash
sudo visudo -cf /etc/sudoers.d/10-webops-nginx
```

Como usuario del grupo:

```bash
sudo -l                          # lista lo autorizado
sudo systemctl restart nginx     # OK
sudo systemctl restart sshd      # Sorry, user is not allowed
sudo bash                        # Sorry, user is not allowed
```

Errores comunes:

- **Rutas relativas**: `systemctl restart nginx` (sin `/usr/bin/`) no coincide por defecto, salvo con `Defaults secure_path`.
- **Argumentos abiertos**: `/usr/bin/systemctl *` permite `systemctl poweroff`. Sé específico.
- **Shells**: autorizar `vim` o `less` como root da shell (`:!bash`). Si no hay más remedio, usa el comando correcto o `rbash`.

### 6.6 Logging y auditoría

Cada ejecución genera una línea en `/var/log/auth.log` (Debian) o `/var/log/secure` (RHEL), y también en el journal:

```bash
sudo journalctl _COMM=sudo --since "1 hour ago"
```

Para registrar también la salida del comando (sesión completa), `Defaults log_output` + `Defaults!NGINX_RESTART !log_output` por si acaso.

---

## 7. Linux capabilities

### 7.1 Problema con `setuid root`

`setuid root` da **todos** los superpoderes al proceso. `ping` necesita abrir un socket raw: históricamente era setuid root. Si tenía un bug, el atacante no se quedaba en "socket raw", se quedaba en root.

### 7.2 Troceando root

Desde Linux 2.2, "ser root" se divide en ~40 **capabilities**. Algunas:

- `CAP_NET_BIND_SERVICE` — bindear puertos < 1024.
- `CAP_NET_RAW` — sockets raw (ping).
- `CAP_SYS_TIME` — cambiar la hora.
- `CAP_SYS_ADMIN` — "la nueva root"; la mayoría de operaciones privilegiadas acaban aquí (evítala).
- `CAP_CHOWN`, `CAP_DAC_OVERRIDE`, `CAP_KILL`, ...

Lista completa: `capabilities(7)`.

### 7.3 Asignar capabilities a un binario

```bash
sudo setcap cap_net_bind_service=+ep /usr/local/bin/mi-servidor
getcap /usr/local/bin/mi-servidor
# /usr/local/bin/mi-servidor cap_net_bind_service=ep
```

`+ep` = effective + permitted. Ahora un usuario normal puede ejecutar `mi-servidor` escuchando en el puerto 80, **sin ser root**, y si el binario tiene un bug no te comprometen la máquina.

### 7.4 Ejemplo trabajado: `cap_net_bind_service` en vez de `setuid`

Antes (mal):

```bash
sudo chown root:root /usr/local/bin/webapi
sudo chmod 4755 /usr/local/bin/webapi      # setuid root
```

Después (bien):

```bash
sudo chown root:root /usr/local/bin/webapi
sudo chmod 755 /usr/local/bin/webapi
sudo setcap cap_net_bind_service=+ep /usr/local/bin/webapi
```

El binario sólo puede hacer eso extra; no puede leer `/etc/shadow`, no puede matar procesos de otro, no puede cambiar la hora.

En systemd lo mismo se consigue sin tocar el ejecutable:

```ini
[Service]
ExecStart=/usr/local/bin/webapi
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=yes
User=webapi
```

### 7.5 ¿sudo o capability?

Regla práctica:

- **Capability**: el *binario* necesita siempre ese superpoder (servicio, utilidad). Es permanente, no interactiva.
- **sudo**: una *persona* necesita ejecutar algo privilegiado de forma puntual y auditada.

No son competidores exactos; resuelven dos problemas distintos.

---

## 8. Camino de resolución completo

Cuando un proceso intenta una operación privilegiada, el kernel aplica aproximadamente:

```
┌─────────────────────────┐
│  Syscall (open, chown…) │
└────────────┬────────────┘
             │
             ▼
   ¿euid == 0 y la op lo permite sin cap?  ──► sí ─► allow
             │
             no
             ▼
   DAC + POSIX ACL  ──► deny ─► EACCES
             │
             allow
             ▼
   MAC (SELinux/AppArmor)  ──► deny ─► EACCES
             │
             allow
             ▼
   Capabilities (si la op las requiere)  ──► deny ─► EPERM
             │
             allow
             ▼
         allow
```

Dos consecuencias prácticas:

- Ver `Permission denied` con permisos aparentemente correctos → sospecha SELinux (`ausearch -m avc -ts recent`) o una cap que falta (`capsh --print`).
- `root` **no lo puede todo**: dentro de un contenedor sin `CAP_SYS_TIME`, root tampoco cambia la hora.

---

## 9. Antipatrones a evitar

| Antipatrón | Por qué es malo | Alternativa |
|-----------|-----------------|-------------|
| `chmod -R 777` | Da todo a todos; además rompe setuid y sticky. | Grupo correcto + setgid + ACL default. |
| `sudo ALL=(ALL) NOPASSWD: ALL` | Equivale a dar la contraseña de root sin auditoría granular. | `Cmnd_Alias` + comandos concretos. |
| `setuid` en scripts shell | Ignorado por el kernel; si "funciona" vía wrapper, es race condition. | Capability o `sudo`. |
| Reusar UIDs borrados | El nuevo usuario puede heredar archivos del antiguo. | No borrar, bloquear + archivar. |
| Añadir con `usermod -G` (sin `-a`) | Reemplaza grupos; saca al usuario de `sudo`/`wheel`. | Siempre `usermod -aG`. |
| Compartir cuenta `ops` | Pierdes "quién hizo qué". | Cuentas individuales + sudoers por grupo. |

---

## 10. Herramientas de diagnóstico

```bash
id                                 # tu identidad: UID, GID, grupos suplementarios
id ana                             # la de otro usuario
groups ana                         # sólo grupos
getent passwd ana                  # resuelve vía NSS (passwd + LDAP + ...)
getent group developers

sudo -l                            # qué tienes autorizado vía sudo
sudo -l -U ana                     # qué tiene ana (si tú eres root)

getfacl /srv/team
stat /srv/team                     # modos, uid/gid, timestamps

capsh --print                      # capabilities del proceso actual
getpcaps $$                        # capabilities por PID

lastlog                            # último login por cuenta
last -n 20                         # sesiones recientes
```

---

## 11. Preguntas de evaluación

Responde sin consultar la lección (puedes consultar man pages):

1. Un archivo tiene `-rw-r--r-- ana developers informe.md`. El usuario `diego` pertenece a `developers`. Explica paso a paso qué consulta el kernel cuando `diego` hace `open("informe.md", O_RDWR)` y qué devuelve.
2. Diferencia entre `usermod -G developers ana` y `usermod -aG developers ana`. ¿Qué puede pasar con la primera si `ana` estaba en `sudo`?
3. Diseña una regla sudoers para que el grupo `backup` pueda ejecutar `/usr/local/bin/snapshot.sh` como root sin contraseña, pero no modificar el script. ¿Dónde deben vivir los permisos del script?
4. Tienes `/srv/datos` con `drwxrws--- root:devs`. `ana` (en `devs`) crea `/srv/datos/proy/sub/x`. ¿Qué grupo tiene `x`? ¿Y si el nivel intermedio no tuviera setgid?
5. Un archivo con ACL muestra `group::rwx #effective:r-x` y `mask::r-x`. ¿Cómo quedó así? ¿Qué comando devuelve el `effective` a `rwx`?
6. ¿Por qué `setuid` en un script bash no funciona en Linux? ¿Qué dos alternativas hay y cuándo elegir cada una?
7. Un binario escucha en el puerto 443 como usuario `webapi`. Explica dos formas correctas de permitirlo sin que `webapi` sea root.
8. Un usuario reporta `Permission denied` creando archivos en `/srv/team` donde parece tener grupo y `rwx`. Enumera tres causas posibles y cómo descartarlas.

---

## 12. Resumen

- Identidad = UID/GID. Lo demás (`/etc/passwd`, `getent`) es traducción humana.
- DAC `rwx` sigue siendo la base; entiende `x` en directorios y los bits especiales (setuid, **setgid en dir**, sticky).
- POSIX ACL extiende el modelo cuando "un grupo propietario" no basta; cuidado con la **mask** y usa **default ACL** para herencia.
- `sudo` autoriza personas a ejecutar comandos concretos; `visudo` y `sudoers.d/` son no negociables.
- Capabilities trocean "ser root"; sustituyen a `setuid` en la mayoría de servicios modernos.
- La resolución real combina DAC → ACL → MAC → capabilities. "Root lo puede todo" es sólo cierto fuera de contenedores sin confinamiento.
- Antipatrón universal: `chmod 777` y `NOPASSWD: ALL`. Hay siempre una alternativa quirúrgica.

→ Siguiente módulo: `sys-05-package-management-and-services`.
