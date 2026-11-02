# sys-12 — Firewall y SELinux: control de red y confinamiento de procesos

> Este módulo cubre dos herramientas que viven en capas distintas del kernel pero se complementan: **nftables** (quién puede hablar con quién por la red) y **SELinux** (qué puede hacer cada proceso con cada recurso). La mayoría de los incidentes de "esto funcionaba y ahora no" en servidores RHEL/Fedora caen en una de las dos.

Lectura estimada: 90–120 min. Las dos actividades asumen que leíste al menos las secciones 1–4 y 7–10.

---

## 1. ¿Por qué dos capas distintas?

El modelo clásico Unix usa **DAC** (*Discretionary Access Control*): el dueño de un fichero decide los permisos, y `root` puede todo. Si un atacante compromete un demonio que corre como `root` (o escala a `root`), DAC ya no te protege.

**MAC** (*Mandatory Access Control*) añade una política impuesta por el sistema que **ni siquiera `root` puede saltarse** sin modificar la política. SELinux implementa MAC en Linux. AppArmor es la alternativa en Ubuntu/SUSE: mismo objetivo, modelo distinto (perfiles por path en vez de etiquetas en inodos).

El firewall es ortogonal: filtra tráfico de red **antes** de que llegue a un proceso o **después** de que un proceso lo emita. Un firewall no te protege de un proceso local que lee `/etc/shadow`; SELinux sí. SELinux no te protege de alguien que escanea tu puerto 22 abierto a Internet; el firewall sí.

Regla mental: **firewall = quién puede llegar; SELinux = qué puede hacer una vez dentro**.

---

## 2. Netfilter: el framework del kernel

Netfilter es la infraestructura del kernel Linux donde se enganchan filtros, NAT y mangling. **No se configura directamente**: se configura a través de una herramienta de usuario (`iptables`, `nftables`, `bpfilter`…) que escribe reglas en estructuras del kernel.

### 2.1 Hooks

Un paquete atraviesa el stack de red pasando por puntos fijos llamados **hooks**:

```
                        +----------------+
   paquete entrante --> | PREROUTING     | --+
                        +----------------+   |
                                             v
                                      ¿es para mí?
                                       /          \
                                      sí           no
                                      |             |
                               +-----------+   +-----------+
                               |  INPUT    |   | FORWARD   |
                               +-----------+   +-----------+
                                    |               |
                              proceso local         |
                                    |               |
                               +-----------+        |
                               |  OUTPUT   |        |
                               +-----------+        |
                                    |               |
                                    +------+--------+
                                           v
                                    +--------------+
                                    | POSTROUTING  | --> paquete saliente
                                    +--------------+
```

- **PREROUTING** — justo después de que el paquete entra. Se usa para DNAT.
- **INPUT** — paquetes destinados a este host. Aquí van las reglas que protegen tus servicios.
- **FORWARD** — paquetes que atraviesan este host hacia otro (router, gateway, contenedores).
- **OUTPUT** — paquetes generados localmente.
- **POSTROUTING** — justo antes de salir. Se usa para SNAT/masquerade.

Cada hook tiene una **prioridad**: varios subsistemas pueden engancharse en el mismo hook y se ejecutan ordenados por ese número (más bajo = antes).

### 2.2 Linaje de herramientas

- **`iptables`** (legacy). Sintaxis separada por protocolo (`iptables`, `ip6tables`, `arptables`, `ebtables`). Cada regla una línea. Lento al escalar.
- **`nftables`** (`nft`). Sustituto moderno (kernel ≥ 3.13, utilidad desde 2014). Una sola herramienta para IPv4, IPv6, ARP y bridge. Sintaxis declarativa, atómica, con sets y maps.
- **`bpfilter`**, **eBPF/XDP**. Experimentales o para casos de alto rendimiento. Fuera del alcance.

En RHEL 8+ y Debian 11+ el default es nftables. En muchas distros `iptables` ahora es un *wrapper* (`iptables-nft`) que traduce a nftables por detrás. **Para nuevas políticas: aprende nftables directo**.

---

## 3. nftables: anatomía de una ruleset

Una ruleset nftables tiene tres niveles:

```
table <family> <name> {
    chain <name> {
        type <type> hook <hook> priority <n>; policy <action>;
        <rule>
        <rule>
    }
}
```

### 3.1 Familias (`family`)

- `ip` — sólo IPv4.
- `ip6` — sólo IPv6.
- `inet` — IPv4 **e** IPv6 en una sola tabla. **Casi siempre lo que quieres.**
- `arp`, `bridge`, `netdev` — casos específicos.

### 3.2 Tablas

Un contenedor nombrado. Nombre libre; convención: `filter`, `nat`, `mangle`, pero puede ser cualquiera.

### 3.3 Cadenas

Dos tipos:

- **Base chain** — enganchada a un hook de netfilter. Lleva `type`, `hook`, `priority` y `policy`.
- **Regular chain** — no engancha; se usa como *subrutina* a la que saltas con `jump` o `goto`.

Tipos de base chain: `filter`, `nat`, `route`.

Políticas: `accept` o `drop`. **Default-deny** significa `policy drop`: si ninguna regla hace match, el paquete se descarta.

### 3.4 Reglas

Match + statement. Ejemplos:

```nft
ct state established,related accept
tcp dport 22 ip saddr 10.0.0.0/24 accept
tcp dport { 80, 443 } accept
ip saddr @blocklist drop
```

### 3.5 Un ruleset mínimo comentado

```nft
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Loopback: imprescindible, muchos servicios lo asumen.
        iif "lo" accept

        # Conntrack: aceptar todo lo que ya es parte de una conexión conocida.
        ct state established,related accept
        ct state invalid drop

        # ICMP útil para diagnóstico y descubrimiento de MTU.
        ip protocol icmp icmp type { echo-request, destination-unreachable, time-exceeded } accept
        ip6 nexthdr icmpv6 accept

        # Servicios expuestos.
        tcp dport 22 accept
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}
```

Cosas que suelen fallar en la primera ruleset:

1. **Olvidar `iif "lo" accept`.** Rompe `localhost`, incluidos sockets Unix emulados vía TCP.
2. **Olvidar `ct state established,related accept`.** Puedes abrir SSH entrante, pero el tráfico de respuesta a conexiones salientes no vuelve.
3. **Dropear ICMPv6.** En IPv6, ICMPv6 es parte del protocolo (NDP, PMTUD). Dropearlo rompe conectividad IPv6 silenciosamente.

### 3.6 Carga segura

```bash
# Validar sintaxis sin aplicar
sudo nft -c -f /etc/nftables.conf

# Aplicar (atómico: todo o nada)
sudo nft -f /etc/nftables.conf

# Listar lo cargado
sudo nft list ruleset
```

**Patrón de red segura sobre SSH:**

```bash
# Programa un rollback por si pierdes conexión
sudo bash -c 'at now + 2 minutes <<< "nft flush ruleset"'

# Aplica
sudo nft -f /etc/nftables.conf

# Si todo bien, cancela el rollback
atq
sudo atrm <job-id>
```

---

## 4. Frontends: firewalld y ufw

Escribir nftables a mano está bien para servidores dedicados, pero muchos equipos quieren una capa más declarativa.

### 4.1 firewalld (RHEL, Fedora, CentOS Stream)

**Modelo mental: zonas**. Cada interfaz pertenece a una zona; cada zona tiene un conjunto de servicios permitidos.

Zonas incluidas:

| Zona     | Para |
|----------|------|
| `drop`   | Deniega todo entrante sin responder. |
| `block`  | Deniega todo entrante respondiendo ICMP. |
| `public` | Default. Sólo servicios explícitos. |
| `work`, `home`, `internal` | Más permisivas, para redes de confianza. |
| `trusted`| Acepta todo. |

Comandos básicos:

```bash
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=public --list-all

# Añadir un servicio predefinido
sudo firewall-cmd --zone=public --add-service=https --permanent

# Añadir un puerto no estándar
sudo firewall-cmd --zone=public --add-port=8443/tcp --permanent

# Rich rule: SSH sólo desde /24
sudo firewall-cmd --zone=public --permanent \
     --add-rich-rule='rule family="ipv4" source address="10.0.0.0/24" service name="ssh" accept'

# Recargar para activar lo permanent
sudo firewall-cmd --reload
```

**`--permanent` vs runtime.** Sin `--permanent` el cambio es en memoria y desaparece al reiniciar. Con `--permanent` queda en disco pero **no se activa** hasta `--reload` o `--runtime-to-permanent`. Patrón habitual: probar sin permanent, confirmar, y luego repetir con permanent.

Por detrás, firewalld genera reglas nftables. Puedes verlas con `sudo nft list ruleset`.

### 4.2 ufw (Debian, Ubuntu)

Más simple, orientado a estaciones de trabajo.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 10.0.0.0/24 to any port 22 proto tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status verbose
```

ufw también genera nftables por detrás en Ubuntu moderno.

### 4.3 ¿Cuál usar?

- Servidor RHEL con equipo mixto → **firewalld**.
- Estación Ubuntu personal → **ufw**.
- Appliance, imagen inmutable, configuración declarativa versionada → **nftables puro** en `/etc/nftables.conf`.

Lo que **no** debes hacer: mezclar varios en el mismo host. `firewalld` y `ufw` compiten por el control del ruleset.

---

## 5. NAT con nftables

NAT se hace en cadenas `type nat`. Dos usos típicos:

**Masquerade (SNAT dinámico), típico en un router:**

```nft
table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100;
        oif "eth0" masquerade
    }
}
```

**DNAT (publicar un servicio interno):**

```nft
table ip nat {
    chain prerouting {
        type nat hook prerouting priority -100;
        iif "eth0" tcp dport 443 dnat to 10.0.0.10:443
    }
}
```

Si el host no está haciendo de router, no hace falta tocar NAT.

---

## 6. Mini-referencia: iptables → nftables

| iptables | nftables |
|----------|----------|
| `iptables -A INPUT -p tcp --dport 22 -j ACCEPT` | `add rule inet filter input tcp dport 22 accept` |
| `iptables -L -n -v` | `nft list ruleset` |
| `iptables-save > backup` | `nft list ruleset > backup.nft` |
| `iptables -F` (destructivo) | `nft flush ruleset` (destructivo) |

Si heredas una política en `iptables` legacy, usa `iptables-translate` y `iptables-restore-translate` para pasarla a nftables antes de añadir nada nuevo.

---

## 7. SELinux: etiquetas, no paths

SELinux etiqueta **cada** objeto del sistema (ficheros, procesos, puertos, sockets) con un **contexto de seguridad** y aplica reglas sobre esas etiquetas.

Un contexto tiene cuatro componentes:

```
user:role:type:level
system_u:object_r:httpd_sys_content_t:s0
```

En la práctica diaria, **el type es lo que importa**. SELinux "targeted" (el default) confina procesos específicos (demonios como `httpd`, `sshd`, `nginx`) y deja al resto en el dominio permisivo `unconfined_t`.

Ver contextos:

```bash
ls -Z /var/www/html/      # contextos de ficheros
ps -eZ | grep nginx       # contexto del proceso
ss -ltnpZ                 # contexto del socket
```

### 7.1 Modos

```bash
getenforce        # Enforcing | Permissive | Disabled
sudo setenforce 0 # pasar a permissive (temporal, hasta reboot)
sudo setenforce 1 # volver a enforcing
```

`Disabled` requiere reboot (y en RHEL 9+ está desaconsejado; use permissive si necesita diagnosticar). **No se desactiva SELinux "para hacer que funcione"**: se diagnostica.

### 7.2 El árbol de decisión cuando algo falla bajo enforcing

```
¿Falla bajo enforcing?
   |
   `-- setenforce 0 → ¿funciona ahora?
         |
         sí (es SELinux)                       no (no es SELinux: revisa firewall,
         |                                         permisos DAC, config del servicio)
         v
   ausearch -m AVC -ts recent  → lee el denial
         |
         +-- ¿pide escribir en un path "ajeno"?
         |     → cambiar fcontext con semanage fcontext -a -t ...
         |       y restorecon -Rv <path>
         |
         +-- ¿pide bindear a un puerto no estándar?
         |     → semanage port -a -t <tipo> -p tcp <puerto>
         |
         +-- ¿el denial corresponde a un comportamiento documentado
         |   gobernado por un boolean?
         |     → getsebool -a | grep <servicio>
         |       setsebool -P <boolean> on
         |
         `-- ¿ninguno de los anteriores?
               → audit2allow -a -M mymodule
                 revisar mymodule.te a mano
                 semodule -i mymodule.pp
```

Vuelve a `setenforce 1` y repite. **Nunca** cargues la salida de `audit2allow` sin leerla; es sugerencia, no verdad.

### 7.3 Booleans

Interruptores predefinidos de la política. Permiten activar/desactivar permisos comunes sin editar nada:

```bash
getsebool -a | grep httpd
# httpd_can_network_connect --> off
sudo setsebool -P httpd_can_network_connect on
```

El `-P` lo hace **persistente**. Sin `-P` se pierde al reiniciar.

### 7.4 Puertos

El caso canónico. Si cambias el puerto de un servicio confinado, el bind falla:

```bash
# nginx escuchando en 8443 → bind: Permission denied
sudo ausearch -m AVC -ts recent | grep -i 8443
# ... type=AVC ... name_bind ... scontext=...:httpd_t ... tcontext=...:unreserved_port_t ...
```

El puerto 8443 no está etiquetado como `http_port_t`. Solución:

```bash
sudo semanage port -l | grep http_port_t
sudo semanage port -a -t http_port_t -p tcp 8443
sudo systemctl restart nginx
```

### 7.5 Contextos de ficheros

Si colocas contenido web en un path no estándar (p. ej. `/srv/web`):

```bash
sudo semanage fcontext -a -t httpd_sys_content_t "/srv/web(/.*)?"
sudo restorecon -Rv /srv/web
```

`semanage fcontext` escribe la regla; `restorecon` **aplica** el contexto correcto a los inodos existentes.

### 7.6 `audit2allow`: ciclo comentado

```bash
# 1. Pon el servicio en permissive temporalmente para que se generen todos los denials
sudo semanage permissive -a httpd_t

# 2. Reproduce el escenario que falla
# ... (haz la petición, ejecuta el workload, lo que sea)

# 3. Recolecta los denials y genera un módulo candidato
sudo ausearch -m AVC -ts recent | audit2allow -M myhttpd

# 4. LEE el .te generado. Si no entiendes una regla, no la cargues.
cat myhttpd.te

# 5. Si está limpio, instala el módulo
sudo semodule -i myhttpd.pp

# 6. Quita el permissive y re-prueba
sudo semanage permissive -d httpd_t
sudo setenforce 1
```

`audit2allow` es una herramienta de **generación de hipótesis**, no un fixer. Si te pide `allow <proceso> self:capability sys_admin`, para y piensa; probablemente la aplicación esté haciendo algo que no debería.

---

## 8. DAC vs MAC (vs capabilities)

| | DAC | MAC (SELinux) | Capabilities |
|---|---|---|---|
| Quién define | dueño del recurso | administrador vía política | kernel, por proceso |
| ¿`root` lo salta? | sí | **no** (sin modificar política) | reduce, no expande |
| Granularidad | usuario/grupo/otros | tipo/dominio por par (sujeto, objeto, clase, operación) | ~40 "permisos de root" individuales |
| Dónde se guarda | inodos | xattr `security.selinux` + política | bits del proceso |

Los tres se combinan: una operación se permite sólo si **todas** las capas la permiten.

---

## 9. AppArmor en 90 segundos

Ubuntu usa AppArmor por defecto. Diferencias clave con SELinux:

- **Perfiles por path** (p. ej. `/usr/sbin/nginx`) en vez de etiquetas en inodos. No necesita xattrs.
- Más fácil de aprender; menos poderoso para expresar políticas finas.
- Modos equivalentes: `enforce` y `complain` (como permissive).
- Herramientas: `aa-status`, `aa-complain`, `aa-enforce`, `aa-logprof`.

Si administras Ubuntu, AppArmor es con lo que vas a tratar. El resto del módulo asume SELinux (RHEL/Fedora), pero las dos actividades están redactadas para que puedas ejecutarlas en una VM Fedora/Rocky.

---

## 10. Patrón operacional recomendado

1. **Firewall primero, con default-deny inbound y `established,related accept`.** Sin esto nada funciona.
2. **Deja SELinux en enforcing.** Si algo no funciona, diagnostica; no desactives.
3. **Los cambios peligrosos van detrás de `at` o de una ventana de mantenimiento.** Si pierdes SSH, pierdes el host.
4. **Versiona `/etc/nftables.conf` y los módulos SELinux custom.** Son código.
5. **Para servicios en puertos no estándar: añade siempre `semanage port -a` *antes* de cambiar el `listen` del servicio.**

---

## 11. Preguntas de evaluación

Responde sin consultar. Las respuestas están implícitas en el texto.

1. Dibuja el camino de un paquete entrante destinado a `sshd` por los hooks de netfilter. ¿Por qué `FORWARD` no se toca?
2. ¿Qué hace exactamente `ct state established,related accept` y por qué toda política realista la incluye?
3. Explica la diferencia práctica entre `firewall-cmd --add-port=8443/tcp` y `firewall-cmd --add-port=8443/tcp --permanent`.
4. Un compañero propone `nft flush ruleset` para "empezar limpio". ¿Qué le dirías antes de que lo ejecute en producción?
5. `nginx` arranca pero `curl` da `503` después de cambiar el puerto a `8443`. Enumera los tres primeros comandos que ejecutarías, en orden.
6. ¿Qué hace `setsebool` sin `-P` y por qué casi nunca es lo que quieres?
7. ¿Cuándo basta un boolean, cuándo basta `semanage port`/`semanage fcontext`, y cuándo necesitas `audit2allow`?
8. ¿Por qué DAC solo no basta si un demonio escucha en Internet corriendo como `root`?
9. Si administras Ubuntu, ¿qué es el equivalente a `setenforce 0` para una aplicación?
10. ¿Por qué nunca debes cargar la salida de `audit2allow` sin leerla?

---

## 12. Resumen ejecutivo

- Netfilter es el framework; **nftables es la herramienta moderna**.
- Toda política razonable empieza por: loopback, `established,related`, ICMP útil, y luego los servicios.
- `firewalld` y `ufw` son frontends que escriben nftables por detrás.
- SELinux etiqueta todo y aplica una política MAC sobre esas etiquetas.
- La inmensa mayoría de "fallos SELinux" se arreglan con un boolean, un `semanage port` o un `semanage fcontext` + `restorecon`.
- `audit2allow` genera hipótesis, no soluciones. Lee antes de cargar.
- No desactives SELinux. Diagnostica.
