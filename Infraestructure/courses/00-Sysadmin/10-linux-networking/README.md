# sys-10 — Linux Networking

## Identificación

- **ID:** `sys-10-linux-networking`
- **Curso:** `00-Sysadmin`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `sys-05-processes-and-job-control`, `sys-06-package-management-upgrades`.

## Objetivo

Inspeccionar y configurar los canales de comunicación de un host Linux moderno. Al terminar deberías poder, frente a un host desconocido, responder: qué interfaces tiene, qué IPs y rutas, qué resuelve DNS, qué puertos escucha, y por dónde se rompe cuando "no funciona la red".

## Alcance

Este módulo cubre:

- Modelo OSI resumido (L1→L7), aplicado a lo que se ve en un host.
- Interfaces: `ip link`, `ip addr`. Rutas: `ip route`. Vecindario: `ip neigh` (ARP/NDP).
- Resolución de nombres: `/etc/hosts`, `/etc/resolv.conf`, `systemd-resolved`, `nsswitch.conf`.
- Configuración persistente: **NetworkManager** (`nmcli`), **netplan** (Ubuntu), **`systemd-networkd`**. Detección del stack activo.
- Puertos abiertos y sockets: `ss -tulpn`.
- Conectividad: `ping`, `traceroute`, `mtr`, `dig`, `curl -v`, `openssl s_client`.
- Captura: `tcpdump -i … -nn`.
- Internals (introductorio): netfilter chains y namespaces de red.

Lo que **no** cubre (se verá después):
- Reglas de firewall productivas (`nftables`, `firewalld`) → `sys-12`.
- SSH y acceso remoto → `sys-11`.
- VPNs, overlays, CNI de contenedores → cursos siguientes del programa.

## Materiales

- **`theory/lesson.md`** — lección profunda (modelo por capas, recetas `ip`, flujo DNS, árbol de triage).
- **`examples/`** — ejemplos demostrativos:
  - `01-ip-command-tour/` — 15 recetas del comando `ip` para inventariar un host.
  - `02-tcpdump-starter/` — primera captura legible de tráfico HTTPS saliente.
- **`activities/`** — dos actividades:
  - `01-static-ip-with-nmcli/` — asignar IP estática persistente (guided-lab, 60 min, lab privilegiado).
  - `02-network-triage/` — tres escenarios de red rota, usar la herramienta de la capa correcta (debug, 60 min).
- **`resources/links.md`** — man pages y documentación oficial.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué pasa entre teclear `curl https://x` y recibir bytes: resolución, routing, ARP, TCP, TLS. Diferenciar NetworkManager, netplan y `systemd-networkd` como *frontends* sobre el mismo kernel. |
| Operativa | Asignar IP estática persistente con el stack correcto. Leer `ss -tulpn` para saber qué proceso escucha dónde. Capturar 10 paquetes relevantes con `tcpdump`. |
| Arquitectónica | Diagnosticar un fallo de red clasificándolo correctamente: DNS vs ruta vs filtro vs TLS vs aplicación. Elegir la herramienta mínima para cada hipótesis. |

## Criterios de evaluación

- IP estática configurada y sobreviviendo a `reboot` (o `systemctl restart` del gestor correspondiente), validada por el script.
- Triage de los tres escenarios resuelto con la herramienta correcta y la causa raíz anotada.
- Capacidad de leer una captura `tcpdump` de ≤ 10 paquetes y narrarla.
- Respuesta a las preguntas de reflexión de la lección sin consultar.

## Secuencia recomendada

1. Lee `theory/lesson.md` entero (una pasada, sin ejecutar).
2. Reproduce `examples/01-ip-command-tour/` sobre tu máquina — es *read-only*.
3. Reproduce `examples/02-tcpdump-starter/` (requiere `sudo` para capturar).
4. Haz la actividad `activities/01-static-ip-with-nmcli/` **en una VM desechable** (lab privilegiado: modifica red).
5. Haz la actividad `activities/02-network-triage/`.
6. Vuelve a `theory/lesson.md` sección "triage decision tree" y respóndela de memoria.

## Advertencia sobre labs privilegiados

La actividad `01-static-ip-with-nmcli` **modifica configuración de red persistente**. Hacerla sobre tu laptop de trabajo puede dejarte sin red. Usa una VM (Multipass, Lima, UTM, VirtualBox) con snapshot previo, o un contenedor con capacidades suficientes. El `activity.yaml` marca `requires_privileged: true` y la actividad aborta si detecta un host no desechable sin la variable `I_UNDERSTAND_THIS_IS_DISPOSABLE=1`.

## Siguiente

→ `sys-11-ssh-and-remote-access`: operar máquinas remotas con SSH, modelo de llaves, `ProxyJump`, forwarding y hardening de `sshd`.
