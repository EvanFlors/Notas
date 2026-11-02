# Lección: SSH y acceso remoto

> **ID:** `sys-11-ssh-and-remote-access` · **Nivel:** avanzado · **Duración:** 3 h
> **Prerrequisitos:** `sys-04`, `sys-10`.

---

## 1. Introducción intuitiva

Trabajas en tu laptop. El servicio vive en una máquina en otra ciudad —o en otro continente—. Necesitas abrir una shell allí, mover un archivo, ejecutar un comando, ver un log. Hace treinta años se hacía con **Telnet** o **rlogin**: texto plano, contraseñas viajando sin cifrar, cualquiera en el camino podía leerlas o cambiarlas. Hoy esa forma de trabajar es inaceptable.

**SSH** (Secure Shell) resuelve esto: establece un canal cifrado entre tu cliente y un servidor remoto, autentica a ambos extremos y transporta por dentro no solo una terminal sino también transferencias de archivos (`scp`, `sftp`), ejecución de comandos puntuales (`ssh host cmd`), redirección de puertos (`-L`, `-R`, `-D`) e incluso otras sesiones SSH (`ProxyJump`).

En este módulo construyes el modelo mental correcto —cómo autentica, qué es `known_hosts`, qué hace el agente, qué es un bastión— y después aprendes a **endurecer** el servidor para que no quede expuesto como una puerta trasera a tu infraestructura.

---

## 2. Fundamentos

### 2.1 Qué es realmente SSH

SSH es **tres cosas** en un solo protocolo (RFC 4251–4254):

1. **Transporte cifrado** — negocia claves de sesión y cifra todo el tráfico.
2. **Autenticación** — prueba quién eres (clave pública, contraseña, teclado interactivo, GSSAPI).
3. **Canales multiplexados** — una sola conexión TCP puede llevar varias "cosas" simultáneas: una shell, un `scp`, dos port forwards, un túnel SOCKS.

Esta separación es importante: el canal cifrado se establece *antes* de que te autentiques, por eso tu contraseña (si usas contraseña) viaja ya cifrada.

### 2.2 Claves asimétricas en 30 segundos

Un par de claves tiene dos partes:

- **Clave privada** — queda **solo** en tu máquina, protegida con permisos `600` y, idealmente, con passphrase.
- **Clave pública** — se publica en el servidor dentro de `~/.ssh/authorized_keys`.

Autenticarte consiste en demostrar que posees la privada **sin enviarla**: el servidor te manda un reto, tú lo firmas con la privada, el servidor verifica con la pública que tiene almacenada. Si el verificador cuadra, dentro.

### 2.3 Elección de algoritmo

En 2026 la recomendación es simple:

- **ed25519** por defecto. Clave corta (~68 B pública), rápida, segura.
- **ecdsa-sha2-nistp256** solo si tu plataforma vieja no soporta ed25519.
- **rsa 4096** si hablas con sistemas legacy (Git servers antiguos, routers).
- **DSA / rsa < 2048** — prohibido, lo rechazan los `sshd` modernos.

```bash
ssh-keygen -t ed25519 -C "evan@laptop-2026"
```

Esto genera `~/.ssh/id_ed25519` (privada) y `~/.ssh/id_ed25519.pub` (pública).

---

## 3. Contexto histórico

SSH nace en **1995** por Tatu Ylönen en Finlandia, tras un sniff de contraseñas en la red universitaria. La versión 1 del protocolo tenía debilidades criptográficas; **SSH-2** (1998) las corrige y es la base del estándar actual.

**OpenSSH** nace en **1999** del equipo de OpenBSD a partir del último código libre de SSH 1.2.12 (antes de que la empresa fundada por Ylönen lo cerrara). Hoy OpenSSH es la implementación de referencia: viene preinstalada en prácticamente todo Linux, BSD y macOS, y desde Windows 10 1803 también en Windows.

GitHub popularizó masivamente SSH entre desarrolladores: no para abrir shells, sino para autenticar `git push`. Por eso mucha gente que "sabe SSH" solo sabe generar una clave y pegarla en una web — este módulo rellena todo lo demás.

---

## 4. Funcionamiento interno

### 4.1 El handshake, paso a paso

```
Cliente                                            Servidor (sshd)
   │                                                      │
   │── TCP SYN :22 ─────────────────────────────────────▶ │
   │◀───────────────────────────── TCP SYN-ACK ───────────│
   │── TCP ACK ──────────────────────────────────────────▶│
   │                                                      │
   │── SSH banner  "SSH-2.0-OpenSSH_9.6" ────────────────▶│
   │◀────────────── "SSH-2.0-OpenSSH_9.6"  SSH banner ────│
   │                                                      │
   │── KEXINIT (algoritmos soportados) ──────────────────▶│
   │◀────────────────────── KEXINIT (algoritmos) ─────────│
   │                                                      │
   │── ECDH público del cliente ─────────────────────────▶│
   │◀────────── ECDH público + firma del HostKey ─────────│
   │                                                      │
   │  (ambos derivan la misma clave de sesión)            │
   │  Cliente verifica HostKey contra ~/.ssh/known_hosts  │
   │                                                      │
   │══ TÚNEL CIFRADO ESTABLECIDO ═════════════════════════│
   │                                                      │
   │── userauth: method=publickey, user=evan ────────────▶│
   │◀───────────────────────────── userauth: challenge ───│
   │── respuesta firmada con id_ed25519 ─────────────────▶│
   │◀────────────────────────── userauth: SUCCESS ────────│
   │                                                      │
   │── CHANNEL_OPEN session ─────────────────────────────▶│
   │  (aquí empieza tu shell, scp, túnel, lo que sea)     │
```

Lo clave: la autenticación va **dentro** del túnel ya cifrado. Y antes de autenticar, el cliente **tiene que decidir si confía en el servidor**. Para eso: `known_hosts`.

### 4.2 `known_hosts` y TOFU

Al conectar por primera vez a un host:

```
The authenticity of host 'app.example.com (10.0.1.10)' can't be established.
ED25519 key fingerprint is SHA256:AbCdEf...xyz.
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

El cliente ha recibido la clave pública del host y no la tiene registrada. Dices "yes" y queda guardada en `~/.ssh/known_hosts`. A partir de ahí, si el fingerprint **cambia**, SSH **rehúsa conectar** y te muestra una alerta grande:

```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
```

Este modelo se llama **TOFU** (Trust On First Use): la primera vez confías "a ciegas"; a partir de entonces el sistema detecta sustituciones. Es *suficiente* para la mayoría de operaciones y *no suficiente* en entornos donde la primera conexión también puede estar interceptada — para eso existen **certificados SSH** (`sys-12`).

### 4.3 El archivo `~/.ssh/config`

Sin configuración, cada vez teclearías:

```bash
ssh -i ~/.ssh/id_ed25519_prod -p 2222 -l deploy app1.internal.example.com
```

Con `~/.ssh/config`:

```sshconfig
# ~/.ssh/config
Host app1
    HostName app1.internal.example.com
    User deploy
    Port 2222
    IdentityFile ~/.ssh/id_ed25519_prod
```

Ahora `ssh app1` basta. El archivo se evalúa **de arriba abajo**; la **primera** aparición de cada directiva gana. Por eso una buena práctica es poner lo específico arriba y los defaults al final:

```sshconfig
Host bastion.example.com
    User jump
    IdentityFile ~/.ssh/id_ed25519_bastion

Host app1 app2 app3
    User deploy
    IdentityFile ~/.ssh/id_ed25519_prod
    ProxyJump bastion.example.com

Host *.staging.example.com
    User deploy
    IdentityFile ~/.ssh/id_ed25519_staging
    ProxyJump bastion.example.com

Host *
    AddKeysToAgent yes
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

**`IdentitiesOnly yes`** importa: sin ella, el agente ofrece *todas* tus claves a cualquier host, lo que a) revela que tienes muchas y b) puede bloquearte por "too many authentication failures".

### 4.4 El agente (`ssh-agent`)

Sin agente, cada conexión te pide la passphrase. El agente guarda la clave descifrada en memoria y responde a los retos sin molestarte:

```bash
eval "$(ssh-agent -s)"       # arranca el agente, exporta env vars
ssh-add ~/.ssh/id_ed25519    # pide passphrase una vez
ssh-add -l                   # lista claves cargadas
```

En macOS, `UseKeychain yes` + `AddKeysToAgent yes` dentro de `~/.ssh/config` integra con Keychain y evita teclear la passphrase incluso tras reiniciar.

**Agent forwarding (`-A` o `ForwardAgent yes`)**: cuando saltas de laptop → bastión → servidor interno, el servidor interno puede pedir una firma a *tu* agente a través del bastión. Útil, pero **peligroso**: cualquier `root` del bastión puede usar tu agente mientras estés conectado. Por eso **`ProxyJump` es casi siempre mejor** que `ForwardAgent`: con `ProxyJump` tu cliente abre una sesión SSH directa al host destino *tunelizada* por el bastión, y la autenticación con el host destino ocurre entre tu laptop y el host, no toca el bastión.

---

## 5. Topologías con bastión

El patrón canónico de acceso a una red privada:

```
      Internet
         │
         │ :22 (único expuesto)
         ▼
  ┌──────────────┐
  │   bastion    │  bastion.example.com
  │  (jump host) │  -- auth: solo claves, usuarios allowlisted
  └──────┬───────┘
         │ red privada 10.0.0.0/16
         │
  ┌──────┴──────┬──────────┬──────────┐
  ▼             ▼          ▼          ▼
 app1          app2       db1        monitor
 10.0.1.10   10.0.1.11  10.0.2.10  10.0.3.10
```

El bastión es la **única** máquina con `:22` expuesto a Internet. Todas las demás están en red privada; para llegar a ellas, pasas por el bastión. Beneficios:

- **Superficie de ataque reducida**: una sola máquina a defender.
- **Auditoría centralizada**: todos los accesos quedan en el `journal` del bastión.
- **Rotación controlada**: cambiar `authorized_keys` en el bastión corta accesos sin tocar los nodos internos.

Con `ProxyJump`:

```sshconfig
Host app1
    HostName 10.0.1.10
    User deploy
    ProxyJump bastion.example.com
```

Luego: `ssh app1` abre dos sockets (laptop→bastión, laptop→app1 tunelizado) y te deja una shell en `app1`. En el bastión no queda shell abierta, solo un reenvío de puertos efímero.

---

## 6. Port forwarding

Tres tipos. Lo nemotécnico útil es "mapeo de direcciones": `-L` lleva *local* un servicio *remoto*; `-R` publica un servicio *local* en el *remoto*; `-D` crea un *proxy SOCKS* dinámico.

### 6.1 `-L` local forwarding

```
Caso: una DB en la red privada que solo el bastión alcanza; quieres conectarte
con tu cliente GUI local (DBeaver) como si estuviera en localhost.

   laptop :5432 ──┐
                   │  ssh -L 5432:db1.internal:5432 bastion
                   ▼
   ┌──────────┐           ┌──────────┐          ┌──────────┐
   │  laptop  │══SSH══════│ bastion  │──────────│   db1    │
   │          │           │          │  :5432   │          │
   └──────────┘           └──────────┘          └──────────┘
   DBeaver → localhost:5432  ↔  ↔ ↔ ↔ ↔ ↔ ↔ ↔ ↔ db1:5432
```

Comando:

```bash
ssh -L 5432:db1.internal.example.com:5432 bastion.example.com
```

### 6.2 `-R` remote forwarding

```
Caso: tienes un servidor local en :3000 y quieres que un compañero (o un webhook)
lo alcance desde Internet a través de una máquina pública.

   compañero → public.example.com:8080
                       │
                       ▼
   ┌──────────┐           ┌──────────┐          ┌──────────┐
   │  laptop  │══SSH══════│  public  │          │ compañero│
   │  :3000   │           │  :8080   │          │          │
   └──────────┘           └──────────┘          └──────────┘
   ssh -R 8080:localhost:3000 public.example.com
```

Comando (requiere `GatewayPorts yes` en el `sshd_config` del remoto para escuchar en `0.0.0.0`; por defecto escucha solo en `127.0.0.1` del remoto, útil solo para quien ya tenga shell ahí):

```bash
ssh -R 8080:localhost:3000 public.example.com
```

### 6.3 `-D` dynamic (SOCKS)

```
Caso: proxy SOCKS local que tuneliza por SSH toda conexión arbitraria.
Útil para navegar como si estuvieras en la red del remoto.

   browser → localhost:1080 (SOCKS5)
                 │
                 ▼
   ┌──────────┐           ┌──────────┐          Internet / intranet
   │  laptop  │══SSH══════│  remote  │─────────────▶  cualquier host
   └──────────┘           └──────────┘
   ssh -D 1080 remote.example.com
```

Comando:

```bash
ssh -D 1080 remote.example.com
```

Configuras el navegador para usar `socks5://localhost:1080`.

---

## 7. Transferencia de archivos

| Herramienta | Caso de uso | Nota |
|-------------|-------------|------|
| `scp src host:dst` | Copia puntual, un archivo | OpenSSH 9+ usa el backend SFTP por defecto; el viejo protocolo scp está deprecado. |
| `sftp host` | Sesión interactiva, exploración | Útil cuando no sabes rutas de antemano. |
| `rsync -avz -e ssh src host:dst` | Sync incremental, grandes volúmenes, retomas | Transfiere solo diferencias. **Preferido** para despliegues y backups. |

Ejemplo real con `rsync`:

```bash
rsync -avz --delete \
    -e "ssh -i ~/.ssh/id_ed25519_prod" \
    ./build/ deploy@app1:/var/www/app/
```

---

## 8. Opciones de `authorized_keys`

Una línea en `~/.ssh/authorized_keys` puede llevar **restricciones** antes de la clave:

```
from="203.0.113.0/24",command="/usr/local/bin/backup-only.sh",no-pty,no-port-forwarding,no-X11-forwarding ssh-ed25519 AAAAC3Nz... backup@laptop
```

Significado:

- `from="203.0.113.0/24"` — solo acepta esa clave si el cliente viene de ese rango.
- `command="..."` — ignora el comando que pida el cliente y ejecuta **ese** script. Útil para claves de automatización que solo deben hacer *una* cosa (backup, deploy).
- `no-pty`, `no-port-forwarding`, `no-X11-forwarding` — recorta capacidades: sin terminal, sin túneles.

Esto convierte una clave SSH en un **endpoint muy restringido**, equivalente a un token con alcance mínimo.

---

## 9. Endurecimiento de `sshd_config`

Archivo típico: `/etc/ssh/sshd_config`. Tras editar, **siempre** valida sintaxis antes de recargar:

```bash
sudo sshd -t -f /etc/ssh/sshd_config
sudo systemctl reload ssh    # Debian/Ubuntu
# o
sudo systemctl reload sshd   # RHEL/Fedora/Arch
```

**Mantén una sesión abierta mientras recargas** por si quedas fuera.

Directivas mínimas de un servidor sano en 2026:

```
# Solo SSH-2 (hoy es el único soportado, pero explicitarlo documenta intención)
Protocol 2

# Nunca root directo. Si necesitas root, entra como usuario y `sudo`.
PermitRootLogin no

# Sin contraseñas: solo claves.
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
UsePAM yes

# Allowlist explícita de usuarios autorizados a entrar por SSH.
AllowUsers deploy evan

# Timeouts contra sesiones zombies.
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 20

# No permitas forwarding de agente ni X11 por defecto.
AllowAgentForwarding no
X11Forwarding no

# Logging verboso para análisis forense.
LogLevel VERBOSE

# Puerto no estándar: ver sección 9.1.
# Port 2222
```

### 9.1 El puerto no estándar: `security theater` útil

Cambiar `Port 22` por `Port 2222` **no** detiene a un atacante serio: `nmap -p-` encuentra el puerto en segundos. Pero sí:

- **Reduce masivamente el ruido en logs** — los bots que escanean `:22` indiscriminadamente dejan de aparecer.
- **Hace que `fail2ban` sea más efectivo** — menos falsos positivos del ruido de fondo.
- **No es seguridad real**: no lo cuentes como un control.

### 9.2 `fail2ban`

Monitorea logs y añade reglas de firewall temporales contra IPs que fallan N veces:

```ini
# /etc/fail2ban/jail.local
[sshd]
enabled  = true
port     = ssh
filter   = sshd
backend  = systemd
maxretry = 5
findtime = 10m
bantime  = 1h
```

Útil contra fuerza bruta masiva. **No** sustituye deshabilitar password auth; si solo aceptas claves, el fuerza bruta de contraseñas es imposible y `fail2ban` es defensa en profundidad para ruido.

---

## 10. Errores frecuentes

- **Clave con permisos laxos** — `~/.ssh/id_ed25519` con `644` hace que SSH la rechace. Debe ser `600`. El directorio `~/.ssh` debe ser `700`.
- **`authorized_keys` con permisos laxos** — mismo problema del lado servidor. `.ssh/` a `700`, `authorized_keys` a `600`.
- **Olvidar `IdentitiesOnly yes`** — el agente ofrece todas tus claves y GitHub (u otros) te bloquea con "too many authentication failures".
- **Agent forwarding a bastiones no confiables** — un `root` del bastión puede firmar con tus claves mientras estés conectado. Usa `ProxyJump`.
- **Editar `sshd_config` sin `sshd -t`** — un typo deja el servicio sin arrancar y pierdes acceso.
- **Recargar `sshd` sin dejar sesión abierta** — si rompiste algo, no tienes forma de volver.
- **Confundir `scp` y `rsync`** — `scp` reemplaza; `rsync` sincroniza. Para despliegues, `rsync`.

---

## 11. Relación con otros módulos

- `sys-04` (usuarios/permisos) — `AllowUsers`, modos `600`/`700`, principio de mínimo privilegio.
- `sys-10` (red) — puertos, firewalls (ufw/nftables), por dónde pasa el tráfico cifrado.
- `sys-12` (SSH CA) — reemplazar TOFU con certificados firmados.
- Curso `02-config-management` — Ansible usa SSH como transporte universal.
- Curso `01-git-and-github` — `git@github.com` autentica con esta misma mecánica.

---

## 12. Preguntas de reflexión

1. Si el handshake cifra el canal *antes* de autenticarte, ¿por qué sigue siendo importante verificar `known_hosts`? ¿Qué ataque *no* mitiga el cifrado por sí solo?
2. Diferencia entre `ProxyJump` y `ForwardAgent` cuando pasas por un bastión. ¿Cuál es más seguro y por qué?
3. En un `authorized_keys` con `from="203.0.113.5",command="/opt/deploy.sh",no-pty`, ¿qué puede y qué no puede hacer esa clave? Pensar en: `ssh host whoami`, `scp archivo host:/tmp/`, `ssh -L …`.
4. Un atacante tiene una IP residencial que cambia a diario y una lista de 10 M contraseñas. Tienes `PasswordAuthentication no` y `fail2ban` con `maxretry=5`. ¿Cuál de los dos controles importa más y cuál es "defensa en profundidad"?
5. Cambiar de `Port 22` a `Port 2222` reduce ~95 % el ruido en logs. ¿Es eso "más seguro"? Argumenta tu respuesta separando "superficie de ataque" de "ergonomía operativa".
6. `-L 5432:db:5432 bastion` vs `-R 8080:localhost:3000 public`. En cada caso, ¿quién inicia la conexión TCP interna al servicio final, y por qué eso importa para el firewall del lado opuesto?
