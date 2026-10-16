# REFERENCE — sec-12-01-trigger-and-detect-shell-in-pod

> Modelo de respuesta. No es la **única** correcta — es un patrón contra el que compararte.

## Seccion A — Evento (modelo, usando `sample-events.json`)

- Regla: `Terminal shell in container`
- Prioridad: `Notice`
- Pod: `attacker` (ns `default`)
- Imagen: `alpine:latest`
- Usuario: `root` (`user.loginuid=-1`, indica entrada via `kubectl exec` sin loginuid real)
- Cmdline: `sh`

Para el segundo evento del mismo JSON:

- Regla: `Read sensitive file untrusted`
- Prioridad: `Warning`
- Pod: `attacker` / `default`
- Imagen: `alpine:latest`
- Usuario: `root`
- Cmdline: `cat /etc/shadow`
- Fichero: `/etc/shadow`

Las dos alertas correlacionadas en el **mismo** container_id (`0a1b2c3d4e5f`) son el patrón clásico: entrada → recon de credenciales.

## Seccion B — Analisis (modelo)

- **Qué ocurrió:** alguien entró por un shell interactivo a un Pod (`sh` con TTY) y leyó un archivo sensible (`/etc/shadow`).
- **Ancestros:** `proc.pname=runc` indica que el shell nació del process reaper del container runtime — típico de `kubectl exec`. En `cat` el padre es `sh` y el abuelo `runc`, confirmando que la lectura vino desde el shell interactivo recién abierto.
- **Diferencia con debug legítimo:** un debug operativo también produce la alerta; se diferencia por **quién** (correlación con audit log del API server: `verb=create resource=pods/exec user=<quien>`), **cuándo** (fuera de ventana de mantenimiento) y **qué siguió** (si la primera acción es `cat /etc/shadow`, no es debug).
- **Alertas correlacionadas esperadas:** `Read sensitive file untrusted`, posibles `Mkdir binary dirs` si el atacante despliega herramientas, `Unexpected egress connection` si intenta exfiltrar.

## Seccion C — Runbook (modelo)

1. **Confirmar fuente.** Query audit log del API server por `pods/exec` sobre `pod=attacker ns=default` en ±2 min del evento. Identificar `user.username` y `sourceIPs`.
2. **Cuarentena.** `kubectl label pod attacker quarantine=true` + NetworkPolicy que aísle el pod del resto; **no** borrarlo todavía (perderías evidencia).
3. **Captura forense.** `kubectl debug attacker` con una imagen con `tcpdump`/`strace`; snapshot del filesystem si el runtime lo soporta.
4. **Rotación de credenciales.** Rotar cualquier secret montado en ese Pod (`kubectl describe pod attacker | grep -i secret`). Rotar tokens de ServiceAccount usados por la workload.
5. **Postmortem.** Ticket con timeline (Falco time → audit log time → acciones del respondedor), checklist de MITRE ATT&CK touched (`T1059`, `T1555`), action items (regla nueva, policy nueva, control preventivo).

## Seccion D — Decision (modelo)

- **Recomendación para `Terminal shell in container`: detect** (Falco).
- **Justificación:** el `kubectl exec` es, hoy por hoy, parte legítima del toolkit operativo (debug incidentes, pod sin probes). Bloquearlo con Tetragon rompería flujos de soporte. Falco **detecta** y manda la señal; un humano decide.
- **Si eliges enforce** (caso: namespaces de producción con política "zero exec"), la TracingPolicy mínima observaría `execve` de `sh`/`bash`/`zsh` con `proc.tty != 0` en un selector por namespace y `matchActions: Sigkill`. Dejaría fuera los namespaces de staging.

Para `Read sensitive file untrusted` sobre `/etc/shadow` la recomendación sería **enforce** con Tetragon (ejemplo 03): ningún Pod de aplicación tiene razón legítima para leerlo.
