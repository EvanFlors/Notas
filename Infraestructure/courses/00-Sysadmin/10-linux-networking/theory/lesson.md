# Lección — sys-10 Linux Networking

> La red en Linux no es "una cosa": son varias capas apiladas, varias herramientas que las observan y varios *frontends* que las configuran. Este documento te da el modelo mental y las recetas para operar un host moderno.

---

## 1. Modelo OSI resumido, visto desde un host

El modelo OSI tiene 7 capas; en la práctica un sysadmin trata con 4 a 5 niveles reales. Lo importante no es memorizar los nombres: es saber **a qué capa pertenece el síntoma** cuando algo falla.

```
┌─────────────────────────────────────────────────────────────────┐
│  L7  APLICACIÓN         HTTP, DNS, SSH, SMTP                    │  curl, dig, ssh
│                         (texto estructurado sobre un socket)    │
├─────────────────────────────────────────────────────────────────┤
│  L6  PRESENTACIÓN       TLS 1.3, serialización, charset         │  openssl s_client
├─────────────────────────────────────────────────────────────────┤
│  L5  SESIÓN             Sockets, handshake, keepalive           │  ss -tulpn
├─────────────────────────────────────────────────────────────────┤
│  L4  TRANSPORTE         TCP, UDP, QUIC                          │  ss, tcpdump
│                         (puertos, retransmisión, control flujo) │
├─────────────────────────────────────────────────────────────────┤
│  L3  RED                IP (v4/v6), ICMP, enrutamiento          │  ip route, ping, mtr
│                         (direcciones lógicas, next-hop)         │
├─────────────────────────────────────────────────────────────────┤
│  L2  ENLACE             Ethernet, Wi-Fi, ARP/NDP, MAC, VLAN     │  ip link, ip neigh
├─────────────────────────────────────────────────────────────────┤
│  L1  FÍSICA             Cable, radio, señal, portadora          │  ethtool, dmesg
└─────────────────────────────────────────────────────────────────┘
```

Síntoma → capa:

- "cable desenchufado" / interface `DOWN` → L1/L2.
- "no me da IP" (DHCP mudo) → L2 (DHCP viaja en broadcast L2).
- "no hay ruta al host" → L3 (`ip route`).
- "connection refused" → L4 (el host contesta, nadie escucha).
- "timeout" en TCP → L3/L4 (filtro intermedio o host muerto).
- "x509: certificate signed by unknown authority" → L6 (TLS).
- "HTTP 500" → L7 (la red funciona, la app falla).

Regla: antes de tocar nada, decide la capa.

---

## 2. Flujo completo "del teclado al byte"

Qué pasa cuando ejecutas `curl https://ejemplo.com/`:

```
Usuario tipea comando
        │
        ▼
┌────────────────────────────────────────────────┐
│ 1. Resolución de nombre (NSS → DNS)            │
│    ejemplo.com → 93.184.216.34                 │
│    - nsswitch.conf decide orden de lookup      │
│    - resolver pregunta a 127.0.0.53 (resolved) │
│    - resolved pregunta a los DNS upstream      │
└────────────────────────────────────────────────┘
        │
        ▼
┌────────────────────────────────────────────────┐
│ 2. Decisión de ruta (tabla main)               │
│    "para 93.184.216.34, next-hop = 192.168.1.1 │
│     por interfaz wlp3s0, source IP 192.168.1.42│
└────────────────────────────────────────────────┘
        │
        ▼
┌────────────────────────────────────────────────┐
│ 3. ARP (si el next-hop no está en la caché)    │
│    "¿quién tiene 192.168.1.1? Dímelo en L2"    │
│    respuesta: MAC aa:bb:cc:dd:ee:ff            │
└────────────────────────────────────────────────┘
        │
        ▼
┌────────────────────────────────────────────────┐
│ 4. TCP SYN → SYN/ACK → ACK (handshake)         │
└────────────────────────────────────────────────┘
        │
        ▼
┌────────────────────────────────────────────────┐
│ 5. TLS 1.3 handshake (ClientHello, cert, keys) │
└────────────────────────────────────────────────┘
        │
        ▼
┌────────────────────────────────────────────────┐
│ 6. HTTP request → HTTP response                │
└────────────────────────────────────────────────┘
```

Cada paso puede romperse de manera observable. La sección 7 (triage) usa este flujo como mapa.

---

## 3. Interfaces, direcciones, rutas y vecinos: `ip`

El binario moderno para L2/L3 en Linux es **`ip`** (paquete `iproute2`). Reemplaza a `ifconfig`, `route`, `arp`, `netstat -r`. Si ves tutoriales con esos binarios viejos, no los sigas.

Subcomandos imprescindibles:

| Comando | Capa | Qué muestra / hace |
|---------|------|--------------------|
| `ip link show` | L2 | interfaces físicas y lógicas, estado (`UP/DOWN`), MAC |
| `ip -c addr show` | L3 | IPs asignadas por interfaz (v4 y v6) |
| `ip route show` | L3 | tabla de ruteo (default y específicas) |
| `ip -6 route show` | L3 | tabla IPv6 |
| `ip neigh show` | L2 | caché ARP/NDP (quién-es-quién en el segmento) |
| `ip -s link show <if>` | L2 | contadores: paquetes, errores, drops |
| `ip rule show` | L3 | reglas de policy routing (si existen) |

### Receta: inventariar un host en 30 segundos

```bash
ip -br -c link                 # interfaces + estado, 1 línea cada una
ip -br -c addr                 # IPs, 1 línea cada una
ip route                       # tabla de ruteo principal
ip neigh                       # caché ARP (quién hay en mi LAN)
cat /etc/resolv.conf           # qué DNS uso (ver nota 'systemd-resolved')
ss -tulpn | head -30           # qué puertos escucho
```

Si estos cinco comandos no te dan una fotografía mental del host, vuelve a leer esta sección.

### Lectura de `ip addr`

```
2: enp3s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether aa:bb:cc:dd:ee:ff brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.42/24 brd 192.168.1.255 scope global dynamic noprefixroute enp3s0
       valid_lft 86312sec preferred_lft 86312sec
    inet6 fe80::aabb:ccff:fedd:eeff/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
```

Qué leer:

- `UP,LOWER_UP` → interfaz administrativamente arriba y con *carrier* (cable/radio OK).
- `inet 192.168.1.42/24` → IP v4 con máscara `/24` (255.255.255.0).
- `dynamic` + `valid_lft 86312sec` → IP vino por DHCP, lease expira pronto.
- `inet6 fe80::…/64 scope link` → dirección link-local IPv6 (nunca sale del segmento).

### Lectura de `ip route`

```
default via 192.168.1.1 dev enp3s0 proto dhcp src 192.168.1.42 metric 100
192.168.1.0/24 dev enp3s0 proto kernel scope link src 192.168.1.42 metric 100
```

- `default via 192.168.1.1` → ruta por defecto (todo lo no específico va al router).
- `proto dhcp` → la aprendimos por DHCP (no es estática).
- `192.168.1.0/24 dev enp3s0 scope link` → ruta "directamente conectada", no hay next-hop.
- `metric 100` → prioridad (menor = preferida) si hay varias rutas candidatas.

Si `ip route` **no muestra `default via …`** → no vas a salir a Internet aunque DNS funcione.

---

## 4. Resolución de nombres: NSS, `/etc/hosts`, `systemd-resolved`

Resolver un nombre en Linux pasa por **NSS** (Name Service Switch), configurado en `/etc/nsswitch.conf`:

```
hosts: files mymachines resolve [!UNAVAIL=return] dns
```

Significado: para `hosts`, consulta en orden: `files` (`/etc/hosts`) → `mymachines` → `resolve` (plugin de `systemd-resolved`) → DNS clásico. `[!UNAVAIL=return]` corta si el plugin anterior no está disponible.

### `/etc/hosts`

Un archivo plano `IP   nombre1 nombre2 ...`. Útil para forzar un valor en desarrollo o inhibir DNS:

```
127.0.0.1       localhost
::1             localhost
127.0.0.1       api.local
```

Siempre se consulta antes que DNS si `files` está primero en `nsswitch.conf`.

### `systemd-resolved` y `/etc/resolv.conf`

En distros modernas (Ubuntu 20.04+, Debian 12+, Fedora, Arch con systemd) el resolver real es **`systemd-resolved`**. Escucha en `127.0.0.53:53` y publica un `/etc/resolv.conf` que apunta ahí:

```
nameserver 127.0.0.53
options edns0 trust-ad
search lan
```

El estado real se consulta con:

```bash
resolvectl status                  # DNS por interfaz, dominios de búsqueda, DNSSEC
resolvectl query ejemplo.com       # resolución pasando por el stub
resolvectl flush-caches            # limpia la caché del resolver
```

Si editas `/etc/resolv.conf` directamente en un sistema con `systemd-resolved`, tu cambio **será sobrescrito**. Para fijar DNS: configúralo en el gestor (NetworkManager, netplan, networkd) o en `/etc/systemd/resolved.conf`.

### Flujo de una resolución

```
getaddrinfo("ejemplo.com")
     │
     ▼
┌────────────────────┐
│ libc → NSS         │  lee /etc/nsswitch.conf
└──────────┬─────────┘
           │ orden: files → resolve → dns
           ▼
┌────────────────────┐
│ /etc/hosts         │  ¿match? → devuelve y termina
└──────────┬─────────┘
           │ no
           ▼
┌────────────────────┐
│ systemd-resolved   │  consulta a 127.0.0.53
│ (stub resolver)    │
└──────────┬─────────┘
           │ caché miss
           ▼
┌────────────────────┐
│ DNS upstream       │  (del DHCP, del gestor, o fijo)
│ UDP/53 o DoT/853   │
└──────────┬─────────┘
           │
           ▼
       respuesta → cache → libc → app
```

Herramienta para auditar: `dig +short ejemplo.com @1.1.1.1` consulta directo a un recursor y evita cualquier capa local — útil para separar "DNS roto en mi stub" de "DNS roto en el upstream".

---

## 5. Configuración persistente: NM, netplan, networkd

El kernel aplica configuración de red; **nadie debería tocarla a mano** salvo para pruebas. Un *frontend* persistente la aplica al boot. En 2026 conviven tres grandes:

| Frontend | Dónde reina | Herramienta CLI | Config |
|----------|-------------|-----------------|--------|
| **NetworkManager** | Fedora, RHEL/CentOS, Arch, Ubuntu desktop, laptops en general | `nmcli`, `nmtui` | `/etc/NetworkManager/system-connections/*.nmconnection` |
| **netplan** | Ubuntu Server 18.04+ (es un *generador*, no gestor) | `netplan apply` | `/etc/netplan/*.yaml` |
| **`systemd-networkd`** | Servidores minimalistas, contenedores, cloud images | `networkctl` | `/etc/systemd/network/*.network` |

Clave que la gente nueva confunde: **netplan es un generador que escribe para NetworkManager o para `systemd-networkd`**. Es decir, netplan **no** reemplaza al backend; lo configura.

### Cómo saber qué tengo

```bash
# NetworkManager activo?
systemctl is-active NetworkManager

# systemd-networkd activo?
systemctl is-active systemd-networkd

# netplan presente?
ls /etc/netplan/ 2>/dev/null && command -v netplan

# resolvedo cuál es el "renderer" real de netplan:
grep -r '^\s*renderer' /etc/netplan/ 2>/dev/null
```

### Receta: IP estática con `nmcli`

```bash
# Listar conexiones
nmcli -t -f NAME,DEVICE,TYPE connection show

# Crear una conexión Ethernet estática (ejemplo didáctico)
sudo nmcli connection add type ethernet con-name static-lab ifname enp3s0 \
    ipv4.method manual \
    ipv4.addresses 192.168.56.42/24 \
    ipv4.gateway 192.168.56.1 \
    ipv4.dns "1.1.1.1 9.9.9.9" \
    ipv4.dns-search lab.local \
    autoconnect yes

sudo nmcli connection up static-lab
```

Para revertir:

```bash
sudo nmcli connection down static-lab
sudo nmcli connection delete static-lab
```

### Receta equivalente con netplan

`/etc/netplan/99-static.yaml`:

```yaml
network:
  version: 2
  renderer: networkd        # o 'NetworkManager' según distro
  ethernets:
    enp3s0:
      dhcp4: false
      addresses: [192.168.56.42/24]
      routes:
        - to: default
          via: 192.168.56.1
      nameservers:
        addresses: [1.1.1.1, 9.9.9.9]
        search: [lab.local]
```

Aplicar: `sudo netplan generate && sudo netplan try` (hace rollback automático a los 120 s si pierdes conexión y no confirmas).

### Receta equivalente con `systemd-networkd`

`/etc/systemd/network/10-enp3s0.network`:

```ini
[Match]
Name=enp3s0

[Network]
Address=192.168.56.42/24
Gateway=192.168.56.1
DNS=1.1.1.1
DNS=9.9.9.9
Domains=lab.local
```

Aplicar: `sudo systemctl restart systemd-networkd`.

**Nunca mezcles los tres.** Elige uno y asegúrate de que los otros estén `disabled` o no entren en conflicto. La actividad `01-static-ip-with-nmcli` detecta el stack activo y aborta si encuentra ambigüedad.

---

## 6. Puertos y sockets: `ss`

`netstat` está deprecado. Usa `ss` (del paquete `iproute2`). Formulario mínimo:

```bash
ss -tulpn
# -t TCP, -u UDP, -l listening, -p processes (requiere root o CAP_SYS_PTRACE),
# -n numeric (no resuelve puertos a nombres ni IPs a hostnames)
```

Salida ejemplo (recortada):

```
Netid  State   Recv-Q  Send-Q   Local Address:Port    Peer Address:Port   Process
tcp    LISTEN  0       128      127.0.0.53%lo:53      0.0.0.0:*           users:(("systemd-resolve",pid=812,fd=14))
tcp    LISTEN  0       128      0.0.0.0:22            0.0.0.0:*           users:(("sshd",pid=1104,fd=3))
tcp    LISTEN  0       4096     *:443                 *:*                 users:(("nginx",pid=2341,fd=6))
```

Lectura:

- `127.0.0.53%lo:53` → `systemd-resolved` escucha DNS solo en loopback. Nadie fuera del host le llega.
- `0.0.0.0:22` → `sshd` escucha SSH en **todas** las interfaces IPv4.
- `*:443` → nginx escucha HTTPS en todas las interfaces, v4 y v6.

Para preguntar "¿quién abrió el puerto X?":

```bash
sudo ss -tulpn 'sport = :443'
```

Para conexiones establecidas (no `-l`):

```bash
ss -tnp state established
```

---

## 7. Triage: árbol de decisión

Cuando algo "no funciona", **la primera herramienta no es la que conoces, es la que separa hipótesis**. Este árbol baja por capas:

```
                   ┌────────────────────────────────┐
                   │  "No puedo acceder a X"         │
                   └───────────────┬────────────────┘
                                   │
                   ┌───────────────▼────────────────┐
                   │  dig +short X @1.1.1.1          │
                   │  ¿resuelve a una IP?            │
                   └───────┬────────────────┬───────┘
                       NO  │                │ SÍ
                           ▼                ▼
            ┌──────────────────────┐   ┌──────────────────────────┐
            │ DNS roto             │   │ ping -c3 <IP>            │
            │ - resolvectl status  │   │ ¿llegan respuestas?       │
            │ - revisa resolv.conf │   └────┬──────────────┬──────┘
            │ - /etc/hosts override│    NO  │              │ SÍ
            │ - firewall UDP/53    │        ▼              ▼
            └──────────────────────┘  ┌────────────┐  ┌──────────────────────┐
                                      │ ip route   │  │ curl -v https://X     │
                                      │ ¿hay       │  │ ¿qué pasa en TCP/TLS? │
                                      │  default?  │  └──────┬───────────────┘
                                      └─────┬──────┘         │
                                            │                ▼
                                            ▼         ┌───────────────────┐
                                   ┌────────────────┐│ connection refused│
                                   │ sin ruta       ││ → nadie en el puerto│
                                   │ → arreglar     ││ timeout            │
                                   │   gateway/NM   ││ → filtro/firewall  │
                                   │ mtr <IP>       ││ cert error         │
                                   │ para ver dónde ││ → ca o SNI malos   │
                                   │ cae el salto   │└───────────────────┘
                                   └────────────────┘
```

Patrones típicos y la herramienta que los confirma:

| Síntoma CLI | Capa probable | Herramienta de confirmación |
|-------------|---------------|------------------------------|
| `curl: (6) Could not resolve host` | DNS (L7-pre) | `dig +short X @1.1.1.1`, `resolvectl status` |
| `curl: (7) Failed to connect ... No route to host` | L3 | `ip route`, `mtr <ip>` |
| `curl: (7) Failed to connect ... Connection refused` | L4 | `ss -tulpn 'sport = :<port>'` **en el servidor** |
| `curl: (28) Operation timed out` | L3/L4 (filtro) | `tcpdump -i any -nn host <ip>` ambos lados |
| `curl: (60) SSL certificate problem` | L6 (TLS) | `openssl s_client -connect host:443 -servername host` |
| `HTTP/1.1 500 Internal Server Error` | L7 (app) | logs del servicio, `journalctl -u` |

Regla: **no abras `tcpdump` antes de haber usado `dig`, `ip route`, `ss` y `curl -v`**. El 80 % de las "fallas de red" se diagnostican con esos cuatro.

### Diferenciar refused vs timeout

- **refused** → el paquete llegó al host destino, el kernel contestó `RST` porque nadie escuchaba. Problema del *servicio* o del *puerto*.
- **timeout** → nada contestó. Un filtro intermedio (firewall, security group, política netfilter) está *descartando* el paquete. Problema de *filtrado* o *host muerto*.

Esta distinción es la más valiosa que puedes llevarte del módulo.

---

## 8. Captura: `tcpdump`

Cuando las capas superiores no explican el problema, bajas al cable. `tcpdump` escribe los paquetes que el kernel entrega a la interfaz.

Receta segura y legible (ejemplo detallado en `examples/02-tcpdump-starter/`):

```bash
sudo tcpdump -i any -nn 'tcp port 443' -c 10
```

- `-i any` → captura en todas las interfaces (útil cuando no sabes por cuál sale).
- `-nn` → no resuelve ni IPs ni puertos (si tu DNS está roto, resolver dentro de `tcpdump` ahorca el comando).
- `-c 10` → corta a 10 paquetes. **Casi siempre** quieres este flag; sin él, llenas la terminal en segundos.
- `'tcp port 443'` → filtro BPF, se evalúa en el kernel.

Filtros útiles:

```bash
sudo tcpdump -i any -nn host 1.1.1.1 -c 20
sudo tcpdump -i any -nn 'udp port 53' -c 20            # DNS en vuelo
sudo tcpdump -i any -nn 'icmp' -c 10                   # ping y errores ICMP
sudo tcpdump -i any -nn 'tcp[tcpflags] & tcp-syn != 0' # solo SYN (quién inicia)
```

Para análisis posterior: `-w captura.pcap` y abrir en Wireshark.

**Advertencia:** `tcpdump` requiere `root` o capabilities (`CAP_NET_RAW`, `CAP_NET_ADMIN`). Nunca lo dejes corriendo sin `-c` en producción.

---

## 9. Internals breves

### 9.1 Netfilter (introductorio)

El kernel procesa cada paquete pasándolo por una serie de **cadenas** del subsistema **netfilter**:

```
Paquete entra por interfaz
        │
        ▼
   PREROUTING ──► ¿para mí? ──► INPUT ──► (proceso local)
        │                                        │
        │                                        ▼
        │                                     OUTPUT
        │                                        │
        │ ─────► FORWARD (si enruto) ────────────┘
        │                                        │
        │                                        ▼
        └─────────────────────────► POSTROUTING ──► interfaz sale
```

Las herramientas que usas para ver/escribir reglas son `iptables` (legacy) y `nft`/`nftables` (moderno). En este módulo solo lo nombramos; `sys-12-firewall-and-selinux` lo cubre en profundidad.

Para inspeccionar sin modificar:

```bash
sudo nft list ruleset         # sistemas con nftables
sudo iptables -S              # sistemas con iptables legacy
```

### 9.2 Network namespaces (toque)

Un **net namespace** es una copia aislada del stack de red del kernel: sus propias interfaces, tablas de ruteo, reglas netfilter. Es la primitiva sobre la que están construidos los contenedores.

```bash
ip netns list                     # listar namespaces nombrados
sudo ip netns add demo            # crear uno
sudo ip netns exec demo ip link   # ver sus interfaces (solo lo tiene)
sudo ip netns delete demo         # limpiar
```

Un pod de Kubernetes es *literalmente* un conjunto de contenedores que **comparten el mismo net namespace**. Esta primitiva reaparece en todo el programa.

---

## 10. Reflexión

1. En tu máquina ahora mismo, ¿cuál es el frontend de red (NM, netplan, networkd)? ¿Cómo lo supiste?
2. Si `dig ejemplo.com` funciona pero `curl https://ejemplo.com` falla con `No route to host`, ¿a qué capa pertenece el problema y qué comando lo confirma?
3. Un servicio nuevo escucha en `127.0.0.1:8080`. Un compañero en la misma LAN no puede acceder. ¿Qué debe cambiar y por qué?
4. ¿Por qué `tcpdump -i any -nn host X` a veces no muestra tráfico que sí ves con `-i eth0`? (pista: `any` tiene caveats con VLANs y bridges).
5. En un host con `systemd-resolved`, modificas `/etc/resolv.conf` directamente. ¿Cuánto duran tus cambios?
6. ¿Cuál es la diferencia operativa entre `Connection refused` y `Operation timed out` para un cliente TCP?

---

## 11. Siguiente

En `sys-11` operas máquinas remotas con SSH. En `sys-12` configuras `nftables` y `firewalld` en producción. Las bases de capas, triage y configuración persistente que aprendiste aquí son prerrequisitos directos.
