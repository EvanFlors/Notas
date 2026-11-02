# Actividad 01 — Añadir un repo de terceros con seguridad

- **Tipo:** guided-lab
- **Duración estimada:** 50 min
- **Entorno:** **VM o contenedor Debian 12 / Ubuntu 22.04+ desechable** (no tu máquina principal).

## Qué vas a conseguir

Añadir el repositorio APT de **HashiCorp** siguiendo el patrón moderno de `signed-by=` + `/etc/apt/keyrings/`, **verificando antes el *fingerprint* GPG** contra la fuente oficial.

Al terminar, un `apt update` reconocerá el repo sin warnings y la clave estará aislada por `signed-by=` (no en el keyring global).

## Por qué importa

El 80% de los incidentes de supply-chain en Linux pasan por repos de terceros mal configurados: clave aceptada a ciegas, patrón `apt-key add -` que confía la clave para todo el sistema, o directamente `curl | sudo bash`. Este laboratorio te enseña a hacerlo bien **una vez** para que lo repliques siempre.

## Prerrequisitos

- Módulo `sys-04` completado (`sudo` funcional, entiendes propietarios de archivos del sistema).
- VM/contenedor Debian 12 o Ubuntu 22.04+ con red saliente.
- `curl`, `gpg`, `apt` instalados (vienen de serie).

## Instrucciones

Lee `starter/instructions.md` entero antes de teclear nada. **El paso de verificación del fingerprint es manual y crítico; no puede saltarse ni automatizarse ciegamente.**

## Validación

```bash
bash tests/validate.sh
```

Debe terminar con `OK:`. Verifica:

- La clave está en `/etc/apt/keyrings/` (no en `/etc/apt/trusted.gpg.d/`).
- El `.sources` o `.list` incluye `signed-by=`.
- `apt update` termina sin errores de firma para ese repo.
- Permisos canónicos (0644 root:root para la clave).

## Entregables

- `/etc/apt/keyrings/hashicorp-archive-keyring.gpg` presente con permisos correctos.
- `/etc/apt/sources.list.d/hashicorp.sources` (o `.list`) con `Signed-By`/`signed-by=`.
- Captura o nota del *fingerprint* que viste y de dónde lo verificaste.

## Solución de referencia

En `solution/add-repo.sh`. **Léela después de intentarlo por tu cuenta.** La solución no omite el paso manual de verificación: lo hace explícito con un `read -p` que te obliga a confirmar que viste el fingerprint.
