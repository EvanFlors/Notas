# Lección — sys-06 Gestión de paquetes y upgrades

> Objetivo pedagógico: construir un **modelo mental único** que sirva para apt, dnf y apk, y después mapear ese modelo a los comandos concretos. Un sysadmin no "sabe apt" o "sabe dnf"; sabe **gestión de paquetes** y recuerda la sintaxis cuando toca.

---

## 1. ¿Qué es un gestor de paquetes y por qué existe?

Antes de los gestores de paquetes, instalar software en Unix era `./configure && make && sudo make install`. Problemas:

- **Sin inventario**: ¿qué archivos puso ese programa? ¿dónde? ¿sigue instalado?
- **Sin dependencias declaradas**: si el programa necesita `libssl`, lo descubres al ejecutarlo.
- **Sin actualización coherente**: parchear OpenSSL implicaba recompilar todo lo que lo enlazara.
- **Sin verificación de autenticidad**: cualquier tarball podía estar manipulado.

Un gestor de paquetes resuelve estos cuatro problemas de golpe:

1. **Inventario**: cada archivo del sistema pertenece a un paquete (o es "huérfano", y eso es dato).
2. **Dependencias**: cada paquete declara qué necesita; el gestor resuelve el grafo.
3. **Transaccionalidad** (en los modernos): instalar/actualizar/eliminar es una operación atómica — todo o nada.
4. **Autenticidad**: los paquetes vienen firmados; la firma se valida contra una clave que *tú* decidiste confiar.

Tres familias dominantes en Linux:

| Familia | Formato | Distros típicas | Herramientas |
|---------|---------|-----------------|--------------|
| **Debian** | `.deb` | Debian, Ubuntu, Mint, Pop!_OS | `apt`, `apt-get`, `aptitude`, `dpkg` |
| **RHEL** | `.rpm` | RHEL, Rocky, Alma, Fedora, CentOS Stream, openSUSE (usa zypper) | `dnf` / `dnf5`, `yum` (legacy), `rpm` |
| **Alpine** | `.apk` | Alpine, muchas imágenes de contenedores | `apk` |

> Nota: existen otros modelos (Nix, Guix, pacman en Arch, portage en Gentoo). No los cubrimos aquí porque este módulo apunta a servidores de producción típicos; el modelo mental es extrapolable.

---

## 2. Las dos capas: alto y bajo nivel

Toda familia tiene **dos capas**:

- **Bajo nivel**: opera sobre *un* archivo de paquete ya descargado. No resuelve dependencias, no habla con repos.
- **Alto nivel**: habla con repos remotos, resuelve dependencias, descarga y delega en la capa baja.

| Familia | Bajo nivel | Alto nivel |
|---------|-----------|------------|
| Debian | `dpkg` | `apt` (`apt-get`, `apt-cache`) |
| RHEL   | `rpm`  | `dnf` / `dnf5` |
| Alpine | `apk`  | `apk` (unificado) |

**¿Por qué importa la distinción?** Cuando algo falla, bajas de capa. Si `apt install` dice "paquete X depende de libY", `dpkg -l libY` te dice si ya está (en qué versión), `dpkg -L libY` te dice qué archivos puso, `dpkg -S /ruta/archivo` te dice de qué paquete viene *ese* archivo.

Regla práctica: **lee con la de bajo nivel, escribe con la de alto nivel**. Instalar manualmente con `dpkg -i` o `rpm -i` tiene su hueco (paquete único sin repo), pero rompe el ciclo normal porque no resuelve dependencias.

---

## 3. Modelo mental común: repo → metadatos → caché → transacción

Todo gestor moderno sigue el mismo flujo. Vale la pena interiorizarlo:

```
[REPO]   servidor HTTP(S) con paquetes + un índice firmado
   │
   │   (1) update: descarga metadatos
   ▼
[CACHÉ local de metadatos]    (p.ej. /var/lib/apt/lists/)
   │
   │   (2) resolve: dado "quiero instalar X", calcula el conjunto
   │       completo de paquetes + versiones que satisfacen todas
   │       las dependencias (SAT solving en dnf, heurística en apt)
   ▼
[PLAN DE TRANSACCIÓN]
   │
   │   (3) download: descarga .deb/.rpm/.apk a caché
   ▼
[CACHÉ de paquetes]           (p.ej. /var/cache/apt/archives/)
   │
   │   (4) verify: GPG + sha256 por paquete
   ▼
[TRANSACCIÓN ATÓMICA]
   │   pre-scripts → unpack → post-scripts
   ▼
[SISTEMA ACTUALIZADO]
   │   + REGISTRO en historial (en dnf: /var/lib/dnf/history.sqlite)
   ▼
[FIN]
```

El punto (2) es el más interesante teóricamente: resolver dependencias con restricciones (versiones mínimas/máximas, conflictos, alternativas) es un problema **NP-completo**. `dnf` lo trata explícitamente como SAT y usa el solver [libsolv](https://github.com/openSUSE/libsolv). `apt` usa heurísticas más antiguas con un backtracking acotado — rápido en el caso común, pero puede atascarse en casos patológicos (los usuarios de Debian testing conocen bien `apt install -f` y `aptitude`).

---

## 4. Tabla comparativa: operaciones comunes

Memoriza las dos columnas de la izquierda y traduce a `apk` cuando toque Alpine.

| Operación | Debian/Ubuntu (`apt`) | RHEL-family (`dnf`) | Alpine (`apk`) |
|-----------|----------------------|---------------------|----------------|
| Refrescar índices | `sudo apt update` | `sudo dnf makecache` (automático antes de la mayoría de acciones) | `sudo apk update` |
| Buscar paquete | `apt search <q>` | `dnf search <q>` | `apk search <q>` |
| Mostrar detalles | `apt show <pkg>` | `dnf info <pkg>` | `apk info <pkg>` |
| Instalar | `sudo apt install <pkg>` | `sudo dnf install <pkg>` | `sudo apk add <pkg>` |
| Eliminar (deja config) | `sudo apt remove <pkg>` | `sudo dnf remove <pkg>` | `sudo apk del <pkg>` |
| Eliminar + config | `sudo apt purge <pkg>` | `sudo dnf remove <pkg>` + limpieza manual | `sudo apk del --purge <pkg>` |
| Listar instalados | `apt list --installed` o `dpkg -l` | `dnf list --installed` o `rpm -qa` | `apk info` |
| ¿De qué paquete es `/x`? | `dpkg -S /x` | `rpm -qf /x` | `apk info --who-owns /x` |
| Archivos de un paquete | `dpkg -L <pkg>` | `rpm -ql <pkg>` | `apk info -L <pkg>` |
| Actualizar índice + ver qué subiría | `apt update && apt list --upgradable` | `dnf check-update` | `apk update && apk version -l '<'` |
| Upgrade conservador (no elimina) | `sudo apt upgrade` | `sudo dnf upgrade` (equivale al conservador también) | `sudo apk upgrade` |
| Upgrade "full" (puede eliminar) | `sudo apt full-upgrade` | `sudo dnf distro-sync` (misma idea) | `sudo apk upgrade -a` |
| Solo seguridad | `sudo unattended-upgrade --dry-run` | `sudo dnf upgrade --security` | n/a oficialmente |
| Historial | n/a nativo (hay logs en `/var/log/apt/`) | `dnf history` | `/var/log/apk.log` |
| Deshacer transacción | parcial: `apt install pkg=version` | `sudo dnf history undo <id>` | manual |
| Pinnear versión | `sudo apt-mark hold <pkg>` + preferences | `sudo dnf versionlock add <pkg>` (plugin) | `apk add 'pkg=1.2.3-r0'` (no persistente) |
| Autoremove huérfanos | `sudo apt autoremove` | `sudo dnf autoremove` | `sudo apk cache clean` (caché), huérfanos manual |
| Limpiar caché | `sudo apt clean` | `sudo dnf clean all` | `sudo apk cache clean` |

**Diferencia conceptual importante** entre `upgrade` y `full-upgrade`/`dist-upgrade`:

- `apt upgrade`: actualiza paquetes **sin eliminar nada ni instalar paquetes nuevos que no estuvieran ya**. Si un paquete requiere eliminar otro para avanzar, lo deja atrás ("kept back").
- `apt full-upgrade`: puede eliminar paquetes para resolver el grafo. Es lo que necesitas en upgrades de release (Debian 11 → 12).

En dnf la línea es menos marcada: `dnf upgrade` por defecto hace lo "razonable", y `dnf distro-sync` fuerza al estado exacto de los repos (puede *bajar* versiones).

---

## 5. Firmas GPG de repositorios: qué garantizan y qué no

Un repositorio firmado da **autenticidad** e **integridad**:

- **Autenticidad**: el índice (y por transitividad los paquetes) fue firmado por quien controla la clave privada correspondiente al *fingerprint* que tienes en `/etc/apt/keyrings/` o `/etc/pki/rpm-gpg/`.
- **Integridad**: nadie modificó los paquetes en tránsito ni en el mirror.

Lo que **NO** garantiza:

- Que el software **haga lo correcto**. Un paquete malicioso firmado por su autor es "auténtico" y "íntegro".
- Que la clave **sea de quien dice ser**. Esa parte es *tu* responsabilidad: verificar el *fingerprint* contra la fuente oficial (web del proyecto por HTTPS con certificado válido, idealmente también anuncio en más de un canal).

### 5.1 Debian/Ubuntu: patrón moderno `signed-by=`

El patrón **antiguo** era usar `apt-key add -` para meter una clave en el *keyring* global `/etc/apt/trusted.gpg`. Problema: cualquier repo así confiado podía firmar actualizaciones para *cualquier* paquete, incluyendo los del sistema base. `apt-key` está **deprecado** desde Debian 11 / Ubuntu 22.04.

El patrón **moderno** aísla la clave por repositorio con `signed-by=`:

```bash
# 1. Descarga la clave desde la fuente oficial (HTTPS, dominio del proyecto)
curl -fsSL https://download.example.com/pubkey.asc -o /tmp/pubkey.asc

# 2. (MANUAL) Verifica el fingerprint contra lo que publica el proyecto
gpg --show-keys --with-fingerprint /tmp/pubkey.asc
# Comparar visualmente con el fingerprint publicado en https://example.com/security

# 3. Dearmor y mover a /etc/apt/keyrings/ (modo 0644, propietario root)
sudo install -d -m 0755 /etc/apt/keyrings
sudo gpg --dearmor -o /etc/apt/keyrings/example-archive-keyring.gpg /tmp/pubkey.asc
sudo chmod 0644 /etc/apt/keyrings/example-archive-keyring.gpg

# 4. Crear el .sources (formato DEB822, preferible al .list clásico)
sudo tee /etc/apt/sources.list.d/example.sources >/dev/null <<'EOF'
Types: deb
URIs: https://download.example.com/debian
Suites: bookworm
Components: main
Signed-By: /etc/apt/keyrings/example-archive-keyring.gpg
EOF

# 5. Refresca y confirma que apt reconoce el repo
sudo apt update
```

El resultado: la clave de `example.com` **solo** valida paquetes del repo `example.com`. Si mañana se compromete esa clave, el *blast radius* queda contenido a los paquetes de ese repo.

> **Equivalente formato .list** (si no quieres DEB822):
> ```
> deb [signed-by=/etc/apt/keyrings/example-archive-keyring.gpg] https://download.example.com/debian bookworm main
> ```

### 5.2 RHEL-family: `.repo` con `gpgkey=` y `gpgcheck=1`

El esquema es paralelo:

```bash
# 1. Descargar la clave
curl -fsSL https://download.example.com/RPM-GPG-KEY-example \
  -o /tmp/RPM-GPG-KEY-example

# 2. Verificar fingerprint
gpg --show-keys --with-fingerprint /tmp/RPM-GPG-KEY-example

# 3. Importar al keyring de rpm
sudo rpm --import /tmp/RPM-GPG-KEY-example

# 4. Definir el .repo
sudo tee /etc/yum.repos.d/example.repo >/dev/null <<'EOF'
[example]
name=Example repo
baseurl=https://download.example.com/rhel/9/$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-example
EOF

# 5. Mover la clave a su ubicación convencional (y referenciarla por file://)
sudo install -o root -g root -m 0644 /tmp/RPM-GPG-KEY-example \
  /etc/pki/rpm-gpg/RPM-GPG-KEY-example

# 6. Refrescar
sudo dnf makecache
```

Con `gpgcheck=1`, dnf **rehúsa** instalar paquetes del repo si la firma no valida.

### 5.3 Alpine: `/etc/apk/keys/`

Alpine es más minimalista: pones el `.rsa.pub` del firmante en `/etc/apk/keys/` y añades la URL del repo en `/etc/apk/repositories`. Mismo principio: una clave aislada por repo.

---

## 6. Pinning y hold: congelar una versión

Casos reales en los que necesitas que un paquete **no** suba:

- Un driver propietario que solo funciona con una versión concreta del kernel.
- Una base de datos que estás certificando en una versión mayor concreta.
- Una regresión conocida en la última versión; esperas a la siguiente.

### Debian: `apt-mark hold` + `preferences.d/`

Simple (congelar completo):

```bash
sudo apt-mark hold postgresql-15
# Para quitarlo:
sudo apt-mark unhold postgresql-15
# Ver todos:
apt-mark showhold
```

Más fino (prioridades Pin-Priority, útil para mezclar repos o preferir un repo sobre otro):

```bash
# /etc/apt/preferences.d/postgresql-pin
sudo tee /etc/apt/preferences.d/postgresql.pref >/dev/null <<'EOF'
Package: postgresql-15
Pin: version 15.4-*
Pin-Priority: 1001
EOF
```

Prioridades típicas: `100` instalado por defecto, `500` candidato normal, `1001` fuerza downgrade. Documentado en `man apt_preferences`.

### RHEL-family: plugin `versionlock`

```bash
sudo dnf install python3-dnf-plugin-versionlock
sudo dnf versionlock add postgresql-server
sudo dnf versionlock list
sudo dnf versionlock delete postgresql-server
```

### Alpine

Alpine no tiene un *hold* persistente de serie. El patrón es poner la versión concreta en el comando de instalación: `apk add 'postgresql15=15.4-r0'` y, para un sistema reproducible, fijar `/etc/apk/world` con el nombre del paquete y versión.

---

## 7. Upgrades controlados

Un upgrade no es "pulsar Enter y rezar". Receta mínima:

1. **Antes**: snapshot del FS si tienes LVM/btrfs/ZFS (lo verás en `sys-08`), o al menos backup de `/etc` y de la base de datos de paquetes (`/var/lib/dpkg/`, `/var/lib/dnf/`).
2. **Antes**: `apt update` o `dnf makecache` y revisar `apt list --upgradable` / `dnf check-update` **leyendo** la lista. Si hay algo crítico (kernel, systemd, openssl, el motor de BD), decide la ventana en consecuencia.
3. **Antes**: anotar la lista de servicios a validar después (ssh, nginx, postgresql, el servicio de aplicación).
4. **Durante**: aplicar el upgrade. En Debian puede ser `apt upgrade` (conservador) o `apt full-upgrade` (puede eliminar). En RHEL, `dnf upgrade --security` si solo quieres parches de seguridad.
5. **Durante**: si el gestor pregunta por *conffiles* modificados (`/etc/foo.conf` cambiado por ti vs. versión nueva del paquete), **lee el diff** antes de responder. En apt: `D` muestra el diff; en dnf: los nuevos quedan como `.rpmnew` / `.rpmsave` y toca mergearlos a mano después.
6. **Después**: reiniciar servicios cuyos binarios cambiaron. `needrestart` (Debian) y `dnf needs-restarting` (RHEL) lo detectan. Si cambió el kernel: reboot.
7. **Después**: validar la lista de servicios del paso 3. Si algo falla → rollback.

### `unattended-upgrades` (Debian/Ubuntu)

Automatiza la aplicación de **actualizaciones de seguridad** diariamente. Por defecto en Ubuntu Server. Config en `/etc/apt/apt.conf.d/50unattended-upgrades`:

- `Unattended-Upgrade::Allowed-Origins`: qué suites se consideran (por defecto solo `-security`).
- `Unattended-Upgrade::Automatic-Reboot "false";`: si reinicia por sí solo tras un upgrade de kernel.
- `Unattended-Upgrade::Package-Blacklist`: qué nunca tocar automáticamente.

Útil en flotas, pero **planifica la ventana de reinicio** si lo pones en servicios con estado.

---

## 8. Rollback: el salvavidas de dnf

### 8.1 `dnf history`

Cada transacción de dnf (install, upgrade, remove) queda registrada:

```bash
sudo dnf history
# ID | Command line           | Date and time      | Action(s)   | Altered
# ---------------------------------------------------------------
#  42 | upgrade --security     | 2026-10-30 10:14   | U           | 37
#  41 | install postgresql     | 2026-10-28 09:02   | I, D        |  8
# ...

sudo dnf history info 42
# Muestra qué paquetes exactos subieron, de qué versión a qué versión.
```

### 8.2 `dnf history undo <id>`

Revierte una transacción concreta — baja los paquetes que subieron, reinstala los eliminados, elimina los recién instalados:

```bash
sudo dnf history undo 42
```

Precondición: dnf necesita poder **encontrar las versiones anteriores**. Esto depende de:

- Si el repo todavía las publica (muchos repos retienen varias versiones; otros solo la última).
- Si tienes caché local (`/var/cache/dnf/`) con los `.rpm` previos.

Por eso en producción conviene o bien un **mirror interno** que preserve histórico, o bien combinar `dnf history undo` con **snapshots de FS** (verlo así: dnf cubre el escenario "el paquete rompió"; el snapshot cubre el escenario "el paquete rompió *y además* dnf no tiene cómo volver atrás").

### 8.3 Debian no tiene equivalente nativo

`apt` no mantiene un historial transaccional. Lo más parecido:

- `/var/log/apt/history.log` registra qué comandos corriste.
- Puedes reinstalar manualmente una versión anterior si el repo la tiene: `sudo apt install nginx=1.24.0-2`.
- Herramientas como `apt-btrfs-snapshot` (Ubuntu) o `snapper` + btrfs integran snapshots con apt.

Patrón de producción Debian: **snapshot antes de upgrade** (btrfs, LVM, ZFS, o incluso instantánea de VM/EBS). El rollback es "revertir el snapshot".

---

## 9. Internals: por qué dnf resuelve mejor casos difíciles

Instalar un paquete puede tener como solución 0, 1 o infinitas combinaciones válidas. El solver debe:

- Satisfacer todas las dependencias (`Requires`, `Depends`).
- Respetar conflictos (`Conflicts`, `Breaks`).
- Preferir una versión sobre otra (más nueva, misma rama, mismo origen).

`dnf` traduce el problema a cláusulas booleanas y lo resuelve con un **SAT solver** (libsolv), lo que le permite encontrar soluciones no obvias y, cuando no hay solución, explicar *por qué* ("Problem: nothing provides libfoo >= 2 needed by bar"). `apt` usa un algoritmo más antiguo basado en heurísticas y backtracking; en el caso común es más rápido, pero en escenarios complicados puede quedarse corto (y por eso existe `aptitude`, que sí trae un solver más potente).

**Transacciones atómicas**: tanto `apt` como `dnf` descargan y verifican **todos** los paquetes antes de empezar a desempaquetar. Si una parte falla a mitad, intentan deshacer. No es un *rollback* perfecto a nivel FS, pero evita el estado clásico "la mitad instalado, la otra mitad corrupto".

---

## 10. Anti-patrón: `curl … | sudo bash`

Es tentador. Está en los README de muchos proyectos:

```
# NO HAGAS ESTO
curl -fsSL https://get.example.com | sudo bash
```

Por qué es malo, incluso con HTTPS:

1. **Ejecutas código remoto como root sin verlo.** Nada garantiza que mañana el servidor no sirva un script distinto a tu User-Agent específico (ataques `curl | bash` dirigidos están documentados).
2. **No hay firma.** HTTPS valida el canal, no el contenido. Un compromiso del servidor (clave privada robada, cuenta de CDN tomada) sirve payload malicioso con `200 OK` perfectamente válido.
3. **No hay inventario.** El script hace lo que quiera: suelta binarios en `/usr/local/bin/`, modifica `/etc/`, añade crontabs. Mañana no sabrás qué puso ni cómo desinstalarlo limpiamente.
4. **No hay actualizaciones.** No hay repo, no hay `apt update`. Para parchear vuelves a correr el script, y vuelta a empezar.

Qué hacer en su lugar:

- Si el proyecto publica un **repo APT/DNF firmado**: añádelo con el patrón de la sección 5. Es la vía profesional.
- Si publica un **`.deb` / `.rpm`** firmado: `wget` → verificar firma con `dpkg-sig --verify` o `rpm --checksig` → instalar con `dpkg -i` / `rpm -i`.
- Si publica solo un **binario único**: descárgalo, verifica sha256 contra la publicada (idealmente también firma `.sig` con `gpg --verify`), y guárdalo en `/usr/local/bin/` tú mismo.
- Si solo hay script y lo quieres igualmente: `curl -fsSL … -o /tmp/install.sh`, **leer el script**, y entonces `sudo bash /tmp/install.sh`. Al menos sabes qué ejecutaste.

> Esta lección y las actividades **nunca** usan `curl | sudo bash`. Si ves ese patrón en el material oficial de un vendor, considéralo *olor* a mala práctica de empaquetado.

---

## 11. Demo: rollback end-to-end con dnf

Reproduce esto en una VM Rocky/Alma/Fedora:

```bash
# Estado inicial
sudo dnf install -y httpd
rpm -q httpd
# httpd-2.4.57-5.el9.x86_64   (versión ejemplo)

# Supongamos que después hacemos un upgrade que rompe algo
sudo dnf upgrade -y httpd    # (si hubiera versión más nueva)

# Mirar historial
sudo dnf history | head
#  ID | Command line  | Date      | Action(s) | Altered
#  12 | upgrade httpd | 2026-10-28| U         | 1
#  11 | install httpd | 2026-10-28| I         | 1

# Deshacer el upgrade (vuelve a la versión que había antes)
sudo dnf history undo 12 -y

rpm -q httpd
# httpd-2.4.57-5.el9.x86_64   (volvió)

# Deshacer también la instalación inicial (desinstala httpd)
sudo dnf history undo 11 -y
rpm -q httpd
# package httpd is not installed
```

Lo importante: **dnf sabe qué pasó en cada transacción y puede invertirla**. Si tus repos conservan versiones anteriores y tu caché no se vació, el rollback funciona en segundos.

---

## 12. Preguntas de evaluación

Responde sin consultar la lección:

1. ¿Por qué `apt upgrade` nunca eliminaría un paquete y `apt full-upgrade` sí puede hacerlo? Da un ejemplo concreto en el que esa diferencia importa.
2. Un repo de terceros firmado está en `/etc/apt/trusted.gpg.d/foo.gpg` (patrón viejo). ¿Qué riesgo adicional representa frente a tenerlo en `/etc/apt/keyrings/foo.gpg` + `signed-by=`?
3. Describe el flujo completo (6 pasos) desde `dnf install nginx` hasta que nginx está instalado.
4. ¿Qué diferencia hay entre `apt-mark hold` y una entrada `Pin-Priority: 1001` en `preferences.d/`? ¿Cuándo preferirías cada una?
5. Un compañero propone instalar una herramienta con `curl https://get.example.com | sudo bash`. Da tres razones técnicas (no "porque sí") para rechazarlo y propón la alternativa que usarías.
6. ¿Por qué `dnf history undo` puede fallar y qué estrategia complementaria lo cubre?
7. Explica, para alguien que viene de Windows, qué garantiza la firma GPG de un repo y qué **no** garantiza.
