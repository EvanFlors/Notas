# Actividad 01 — Pirámide de `~/.ssh/config` con bastión

## 1. Identificación

- **ID:** `sys-11-01-ssh-config-pyramid`
- **Tecnología:** `00-Sysadmin`
- **Módulo:** `sys-11-ssh-and-remote-access`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Diseñarás un `~/.ssh/config` modular para una red con **un bastión** y **tres hosts internos** (`app1`, `app2`, `db1`). Cada host usa una **clave distinta**. El entregable es un archivo `ssh-config` autosuficiente que valida contra `tests/validate.sh`.

## 3. Objetivos

Al terminar deberías poder:

- Modelar un acceso a red privada con `ProxyJump` sin exponer los nodos internos.
- Elegir el orden correcto de bloques `Host` (específico → genérico).
- Usar `IdentitiesOnly yes` para evitar fugas de identidades por el agente.
- Validar un config con `ssh -G <alias> -F <archivo>` sin conectar.

## 4. Prerrequisitos

- Actividades previas del módulo leídas; `theory/lesson.md` repasado.
- Cliente OpenSSH ≥ 8.0 (`ssh -V`).
- No se requiere red real: la validación es *estática* sobre el archivo generado.

**Costos:** ninguno.

## 5. Instrucciones

### 5.1 Lee el escenario

```bash
cat starter/scenario.md
```

Diseña mentalmente la topología antes de teclear.

### 5.2 Crea tu respuesta

```bash
mkdir -p /tmp/sys-11-01 && cd /tmp/sys-11-01
cp "$OLDPWD/starter/scenario.md" .
# Crea aqui tu propuesta:
$EDITOR ssh-config
```

Requisitos obligatorios del archivo `ssh-config`:

- Bloque para `bastion.example.com` con `User jump` e `IdentityFile ~/.ssh/id_ed25519_bastion`.
- Bloque para `app1` → `HostName 10.0.1.10`, `User deploy`, `IdentityFile ~/.ssh/id_ed25519_app1`, `ProxyJump bastion.example.com`.
- Bloque para `app2` → `HostName 10.0.1.11`, `User deploy`, `IdentityFile ~/.ssh/id_ed25519_app2`, `ProxyJump bastion.example.com`.
- Bloque para `db1` → `HostName 10.0.2.10`, `User dbadmin`, `IdentityFile ~/.ssh/id_ed25519_db1`, `ProxyJump bastion.example.com`.
- `IdentitiesOnly yes` en todos los bloques específicos.
- Un bloque final `Host *` con `AddKeysToAgent yes` y `ServerAliveInterval 60`.

### 5.3 Comprueba sin conectar

```bash
ssh -G app1 -F ssh-config | grep -E '^(user|hostname|identityfile|proxyjump) '
ssh -G db1  -F ssh-config | grep -E '^(user|hostname|identityfile|proxyjump) '
```

### 5.4 Valida

```bash
bash tests/validate.sh ssh-config
```

Debe terminar con `OK`.

## 6. Resultado esperado

- `ssh -G app1 -F ssh-config` imprime `user deploy`, `hostname 10.0.1.10`, `proxyjump bastion.example.com`, `identityfile ~/.ssh/id_ed25519_app1`.
- Lo análogo para `app2`, `db1`.
- `tests/validate.sh` pasa.

## 7. Criterios de aceptación

- [ ] Funcionalidad: los 4 bloques específicos resuelven correctamente con `ssh -G`.
- [ ] Calidad: cada host usa su **propia** clave; `IdentitiesOnly yes` presente.
- [ ] Reproducibilidad: `tests/validate.sh` pasa.
- [ ] Comprensión: puedes explicar por qué `Host *` va al **final**.

## 8. Validación

```bash
bash tests/validate.sh ssh-config
```

Chequea con `ssh -G` que `app1`, `app2`, `db1` tienen `user`, `hostname`, `identityfile` y `proxyjump` esperados, y que `bastion.example.com` **no** tiene `proxyjump`.

## 9. Preguntas de reflexión

1. Si pusieras `Host *` al principio del archivo, ¿qué dejaría de funcionar y por qué?
2. ¿Qué pasaría si quitaras `IdentitiesOnly yes` y tu agente tiene cargadas 6 claves?
3. Alguien propone exponer `app1` directo a Internet para "evitar la molestia del bastión". Enumera 3 razones concretas por las que es mala idea.

## 10. Extensiones (opcional)

- **E1** — Añade un wildcard `Host *.staging.example.com` con otra clave y mismo bastión.
- **E2** — Usa `Match User evan Host app1` para que *tú* uses `id_ed25519_personal` y el usuario `deploy` siga usando la clave de servicio.
- **E3** — Reescribe el `ProxyJump` como `ProxyCommand ssh -W %h:%p bastion.example.com` y verifica que `ssh -G` muestra lo equivalente.

## 11. Limpieza

```bash
rm -rf /tmp/sys-11-01
```
