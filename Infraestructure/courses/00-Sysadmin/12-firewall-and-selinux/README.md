# sys-12 — Firewall y SELinux

## Identificación

- **ID:** `sys-12-firewall-and-selinux`
- **Curso:** `00-Sysadmin`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `sys-10` (redes y servicios). Comodidad con `systemd`, `journalctl` y una terminal con `sudo`.

## Objetivo

Controlar el tráfico de red del host con **nftables** (y sus frontends `firewalld` y `ufw`) y **confinar procesos** con SELinux (contextos, booleans, módulos de política). Al terminar deberías poder abrir una política mínima default-deny, diagnosticar un fallo "funciona en permissive, no en enforcing", y arreglarlo sin desactivar SELinux.

## Alcance

Este módulo cubre:

- Historia útil: `netfilter` → `iptables` (legado) → `nftables` (actual).
- Anatomía de una ruleset nftables: tablas, cadenas, hooks, prioridades, reglas.
- `conntrack` y por qué toda política realista empieza por `ct state established,related accept`.
- Frontends: `firewalld` (RHEL, zonas, servicios, rich rules) y `ufw` (Debian/Ubuntu, perfiles simples).
- NAT básico (masquerade, DNAT) a nivel conceptual.
- SELinux: modos (`enforcing`/`permissive`/`disabled`), contextos (`ls -Z`, `ps -Z`), tipos, booleans, puertos (`semanage port`), `restorecon`, `audit2allow`.
- Breve contraste con AppArmor (Ubuntu).
- Caso real: cambiar el puerto de `nginx` falla bajo SELinux enforcing hasta añadir el contexto del puerto.

Lo que **no** cubre:
- Firewalls perimetrales (hardware), IDS/IPS → fuera del curso.
- Políticas SELinux desde cero con `.te` complejos → sólo lo mínimo con `audit2allow`.
- VPN, Wireguard → `sys-13`.

## Materiales

- **`theory/lesson.md`** — ~600 líneas. Diagrama de los hooks de netfilter, anatomía de ruleset nftables, modelo de zonas de firewalld, árbol de decisión SELinux (enforcing + denegación → qué mirar primero), ciclo `audit2allow` comentado y comparación DAC vs MAC.
- **`examples/`**
  - `01-nftables-minimal-ruleset/` — ruleset default-deny inbound comentada.
  - `02-selinux-context-tour/` — recorrido por `ls -Z /etc`, `ps -eZ` y `semanage port -l`.
- **`activities/`**
  - `01-nftables-first-ruleset/` — guided-lab 75 min. Construir default-deny + SSH desde una /24 + HTTPS.
  - `02-selinux-port-and-fcontext/` — debug 60 min. `nginx` en 8443 bajo enforcing: diagnosticar y arreglar con `semanage port` + `restorecon`.
- **`resources/links.md`** — nftables wiki, firewalld docs, SELinux Notebook, Red Hat SELinux User's and Administrator's Guide.

## Advertencias

- **Las dos actividades requieren `root` o `sudo` y, idealmente, una VM desechable.** Un firewall mal escrito te deja sin SSH; una política SELinux mal aplicada puede impedir que un servicio arranque.
- **No ejecutes `iptables -F`, `nft flush ruleset`, ni `setenforce 0` en una máquina de la que dependes para seguir trabajando.** Los scripts del módulo que hacen operaciones destructivas exigen `CONFIRM=1` antes de correr.
- Si trabajas remoto por SSH, deja una segunda sesión abierta antes de aplicar reglas, y usa el patrón `at now + 2 minutes` para programar un rollback automático.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar los hooks de netfilter (`prerouting`, `input`, `forward`, `output`, `postrouting`), diferencia DAC vs MAC, por qué `conntrack` es imprescindible, y qué hace `semanage port`. |
| Operativa | Escribir una ruleset nftables mínima, cargarla con `nft -c -f` + `nft -f`, listar zonas y servicios de `firewalld`, leer `ausearch -m AVC`, correr el ciclo `audit2allow -a -M mymodule` y entender si vale la pena cargarlo. |
| Arquitectónica | Decidir entre `firewalld`, `ufw` o nftables puro según la distro y el equipo. Decidir cuándo basta `setsebool -P` y cuándo hace falta un módulo custom. |

## Criterios de evaluación

- Ruleset nftables que pasa `nft -c -f` sin errores y cumple el escenario de la actividad 1.
- Diagnóstico escrito del incidente de nginx en 8443 (actividad 2) con los comandos usados y la razón de cada uno.
- Capacidad de responder, sin consultar, qué comando aplica a cada síntoma: puerto bloqueado, contexto incorrecto, boolean apagado, módulo de política faltante.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-nftables-minimal-ruleset/` en una VM.
3. Haz `activities/01-nftables-first-ruleset/` (guided).
4. Lee `examples/02-selinux-context-tour/`.
5. Haz `activities/02-selinux-port-and-fcontext/` (debug — ésta es la que valida comprensión real).
6. Revisa `resources/links.md` y marca lo que quieras profundizar.

## Siguiente

→ `sys-13`: VPN, túneles y endurecimiento adicional del host.
