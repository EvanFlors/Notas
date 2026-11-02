# Actividad 02 — Endurecer un `sshd_config`

## 1. Identificación

- **ID:** `sys-11-02-harden-sshd`
- **Tecnología:** `00-Sysadmin`
- **Módulo:** `sys-11-ssh-and-remote-access`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

Parte de un `sshd_config` **laxo** (defaults inseguros deliberados): permite root, acepta contraseñas, acepta cualquier usuario, timeouts enormes. Debes producir una versión endurecida y validarla con `sshd -t -f`.

## 3. Objetivos

Al terminar deberías poder:

- Convertir un `sshd_config` laxo en uno endurecido justificando cada cambio.
- Validar sintaxis offline con `sshd -t -f` **antes** de recargar el servicio.
- Explicar qué controles son **seguridad real** y cuáles son solo *security theater* útil (p. ej. cambio de puerto).

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` secciones 9 y 10.
- Binario `sshd` disponible en PATH para validar sintaxis (`which sshd`). En macOS normalmente en `/usr/sbin/sshd`.

**Costos:** ninguno. **No** reinicies ningún `sshd` real durante la actividad; se trabaja sobre archivos sueltos.

## 5. Instrucciones

### 5.1 Preparar

```bash
mkdir -p /tmp/sys-11-02 && cd /tmp/sys-11-02
cp "$OLDPWD/starter/sshd_config.lax" .
```

Lee `sshd_config.lax` entero. **Marca cada línea** que te parezca problemática.

### 5.2 Producir la versión endurecida

Crea `sshd_config.hardened` cumpliendo **todos** estos requisitos (el validador los comprueba):

| Directiva | Valor requerido | Por qué |
|-----------|-----------------|---------|
| `PermitRootLogin` | `no` | No root directo; `sudo` desde cuenta nominal. |
| `PasswordAuthentication` | `no` | Solo claves. |
| `KbdInteractiveAuthentication` | `no` | Cierra el keyboard-interactive como vector de contraseñas. |
| `PermitEmptyPasswords` | `no` | Obvio. |
| `PubkeyAuthentication` | `yes` | Habilitado explícitamente. |
| `X11Forwarding` | `no` | No necesario; superficie extra. |
| `AllowAgentForwarding` | `no` | Evita abuso de agentes forwardeados. |
| `AllowUsers` | contener `deploy` **y** `evan` | Allowlist explícita. |
| `ClientAliveInterval` | número entre `60` y `600` | Mata sesiones zombies. |
| `ClientAliveCountMax` | entre `1` y `3` | Idem. |
| `LoginGraceTime` | ≤ `30` | Reduce ventana de ataques colgados. |
| `LogLevel` | `VERBOSE` | Forense. |
| `MaxAuthTries` | ≤ `4` | Menos superficie para fuerza bruta. |
| `Protocol` | ausente o `2` | Hoy solo SSH-2. |

### 5.3 Validar sintaxis offline

```bash
sshd -t -f ./sshd_config.hardened && echo "SYNTAX OK"
```

Si falla, `sshd -t` imprime la línea exacta.

### 5.4 Validar criterios con el script

```bash
bash tests/validate.sh ./sshd_config.hardened
```

Debe terminar con `OK`.

## 6. Resultado esperado

- `sshd_config.hardened` pasa `sshd -t -f`.
- `tests/validate.sh` pasa todas las comprobaciones.
- Puedes defender cada cambio en 30 s.

## 7. Criterios de aceptación

- [ ] Funcionalidad: sintaxis válida (`sshd -t -f`).
- [ ] Calidad: todas las directivas exigidas en la tabla, sin dejar comentada ninguna.
- [ ] Reproducibilidad: `tests/validate.sh` pasa.
- [ ] Comprensión: puedes responder las preguntas de reflexión sin consultar.

## 8. Validación

```bash
sshd -t -f ./sshd_config.hardened
bash tests/validate.sh ./sshd_config.hardened
```

El script:

1. Corre `sshd -t -f` para validar sintaxis.
2. Verifica cada directiva mínima de la tabla con `grep -E` tolerante a espacios.
3. Comprueba que `AllowUsers` incluye `deploy` y `evan`.

## 9. Preguntas de reflexión

1. Tienes `PasswordAuthentication no` y además `fail2ban`. ¿Para qué sirve `fail2ban` entonces? ¿Qué protege que la deshabilitación de passwords no?
2. Cambiar de `Port 22` a `Port 2222` reduce 95 % el ruido en logs. ¿Lo contarías como un control de seguridad en una auditoría? ¿Por qué sí/no?
3. Pones `AllowUsers deploy evan` y mañana entra un contratista `maria`. ¿Qué proceso defines para añadirla sin que alguien lo olvide en 3 meses y le dé root?
4. `AllowAgentForwarding no` por defecto rompe un flujo real de desarrolladores que saltan por bastión y luego hacen `git push` desde el host interno. ¿Qué alternativa segura propondrías? (Pista: `ProxyJump` + clave local).

## 10. Extensiones (opcional)

- **E1** — Añade `Match Group sftp-only` con `ChrootDirectory` para usuarios de solo-SFTP.
- **E2** — Define `Ciphers`, `KexAlgorithms`, `MACs` siguiendo las [guías de Mozilla OpenSSH (modern)](https://infosec.mozilla.org/guidelines/openssh).
- **E3** — Escribe un *drop-in* `/etc/ssh/sshd_config.d/99-hardening.conf` en vez de editar el archivo principal (practica de distros modernas).

## 11. Limpieza

```bash
rm -rf /tmp/sys-11-02
```
