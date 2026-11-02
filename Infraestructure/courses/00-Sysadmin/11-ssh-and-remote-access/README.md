# sys-11 — SSH y acceso remoto

## Identificación

- **ID:** `sys-11-ssh-and-remote-access`
- **Curso:** `00-Sysadmin`
- **Nivel:** avanzado
- **Duración estimada:** 3 h
- **Prerrequisitos:** `sys-04` (usuarios y permisos), `sys-10` (red básica).

## Objetivo

Operar máquinas remotas con SSH de forma **segura y productiva**: autenticación por clave pública, `~/.ssh/config` modular, agente, port forwarding, bastiones y endurecimiento del servidor.

## Alcance

Este módulo cubre:

- Modelo de SSH: handshake, intercambio de claves, autenticación, canal cifrado.
- Cliente: `ssh`, `~/.ssh/config` (`Host`, `User`, `IdentityFile`, `ProxyJump`).
- Claves: `ssh-keygen` (ed25519), `ssh-copy-id`, `authorized_keys` con opciones (`from=`, `command=`, `no-pty`).
- Agente: `ssh-agent`, `AddKeysToAgent`, `UseKeychain` (macOS). Riesgos de **agent forwarding** y alternativas.
- Port forwarding: `-L` (local), `-R` (remoto), `-D` (SOCKS dinámico).
- Transferencia: `scp`, `sftp`, `rsync -e ssh`.
- Bastión / jump host con `ProxyJump`.
- Hardening del servidor (`sshd_config`): `PermitRootLogin no`, `PasswordAuthentication no`, `AllowUsers`, puerto no estándar (y por qué **no** es seguridad real), `fail2ban`.
- `known_hosts` y **TOFU** (Trust On First Use).

Lo que **no** cubre (se verá después):

- Certificados SSH y CA interna → `sys-12`.
- Túneles VPN y WireGuard → `sys-14`.
- Automatización con Ansible sobre SSH → curso `02-config-management`.

## Materiales

- **`theory/lesson.md`** — lección profunda (12 secciones) con diagrama del handshake, bloques de `~/.ssh/config`, topología de bastión ASCII y diagramas de `-L`/`-R`/`-D`.
- **`examples/`**:
  - `01-ssh-config-blocks/` — un `~/.ssh/config` real anotado.
  - `02-port-forward-variants/` — demostración paso a paso de las tres formas de forwarding.
- **`activities/`**:
  - `01-ssh-config-pyramid/` — guided-lab, 60 min. Construir `~/.ssh/config` con 3 hosts detrás de un bastión usando `ProxyJump` y claves distintas por host.
  - `02-harden-sshd/` — independent, 60 min. Endurecer un `sshd_config` laxo y validarlo con `sshd -t -f`.
- **`resources/links.md`** — manuales OpenSSH y guía Mozilla.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar las fases del handshake SSH, qué es TOFU y por qué `known_hosts` importa. Describir el riesgo de agent forwarding. |
| Operativa | Generar un par ed25519, publicarlo con `ssh-copy-id`, escribir un `~/.ssh/config` modular con `ProxyJump`, abrir túneles `-L`/`-R`/`-D`, endurecer un `sshd_config` y validarlo. |
| Arquitectónica | Diseñar un patrón de acceso con bastión único a una red privada. Justificar qué controles son seguridad real y cuáles son solo *security theater* (p. ej. cambio de puerto). |

## Criterios de evaluación

- `~/.ssh/config` con **al menos 3 hosts** detrás de un `bastion.example.com` usando `ProxyJump`.
- Conexión funcional con clave ed25519 (sin password), agente activo.
- `sshd_config` endurecido que pasa `sshd -t -f`.
- Capacidad de explicar por qué cambiar el puerto `22` **no** mitiga un atacante determinado, pero sí reduce ruido en logs.
- Respuesta argumentada a las preguntas de reflexión del final de `theory/lesson.md`.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, 60 min).
2. Revisa `examples/01-ssh-config-blocks/` y adapta uno a tu entorno de laboratorio.
3. Haz `activities/01-ssh-config-pyramid/` (60 min).
4. Reproduce `examples/02-port-forward-variants/` con dos VMs o contenedores.
5. Haz `activities/02-harden-sshd/` (60 min).
6. Responde las preguntas de reflexión sin consultar.

## Siguiente

→ `sys-12`: certificados SSH, CA interna y rotación de claves a escala.
