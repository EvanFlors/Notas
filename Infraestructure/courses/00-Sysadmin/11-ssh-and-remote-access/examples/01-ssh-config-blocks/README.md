# Ejemplo 01 — Bloques de `~/.ssh/config` anotados

## Concepto que demuestra

Cómo estructurar un `~/.ssh/config` **real**: específico arriba, defaults abajo, uso de `ProxyJump`, claves distintas por entorno y `Match` por usuario/host.

## Contexto

Un `~/.ssh/config` bien organizado ahorra decenas de banderas por comando y evita filtrar claves equivocadas a los hosts equivocados.

## Objetivo

Al terminar, podrás responder:

- ¿Por qué el orden de los bloques `Host` importa?
- ¿Qué hace `IdentitiesOnly yes` y por qué deberías ponerlo?
- ¿Cómo se escribe un salto por bastión con `ProxyJump`?
- ¿Cuándo usar `Match` en vez de `Host`?

## Prerrequisitos

- OpenSSH cliente (`ssh -V` ≥ 8.0).
- Al menos un par de claves generado (`~/.ssh/id_ed25519`).

## Ejecución

Lee `files/example-ssh-config` entero. **No lo copies tal cual** a tu `~/.ssh/config` — es un ejemplo didáctico con placeholders.

Para probar que un bloque aplica a un alias, usa `ssh -G` (dump del config efectivo sin conectar):

```bash
ssh -G app1 -F files/example-ssh-config | head -20
```

Verás `hostname`, `user`, `port`, `identityfile` resueltos.

Para ver la **cadena de ProxyJump** sin conectar:

```bash
ssh -vvv -o ConnectTimeout=1 -F files/example-ssh-config app1 2>&1 | grep -i proxy
```

## Resultado esperado

- `ssh -G app1` muestra `user deploy`, `hostname 10.0.1.10`, `proxyjump bastion.example.com`.
- `ssh -G db1` muestra `user dbadmin`, `identityfile ~/.ssh/id_ed25519_db`.
- `ssh -G github.com` muestra `user git`, `identityfile ~/.ssh/id_ed25519_github`, **sin** `proxyjump`.

## Interpretación

- SSH recorre el config de arriba abajo; para cada directiva, **gana la primera que aparece**. Por eso lo específico va arriba y el bloque `Host *` final solo pone defaults (como `AddKeysToAgent`, `ServerAliveInterval`).
- `IdentitiesOnly yes` fuerza a usar **solo** la `IdentityFile` del bloque — sin esta directiva el agente ofrecería todas tus claves y muchos servicios (notablemente GitHub) te bloquean con "too many authentication failures".
- `ProxyJump bastion.example.com` abre un túnel tunelizando por el bastión, sin dejar shell en él. Comparado con `ProxyCommand ssh -W %h:%p bastion` es equivalente y más moderno.
- `Match` evalúa condiciones (`user`, `host`, `exec ...`); útil cuando el mismo hostname requiere config distinto según con qué usuario conectas (p. ej. `evan@app1` vs `deploy@app1`).

## Errores frecuentes

- **Pones `Host *` al principio** — todo bloque posterior hereda esos defaults pero sus propias directivas pierden si son `Host` menos específicos. Siempre al **final**.
- **Olvidas `IdentityFile` dentro de un bloque y asumes "cae al default"** — cae, pero sin `IdentitiesOnly yes` el agente ofrecerá todas tus claves igual.
- **`ProxyJump` apunta a un alias que no existe** — SSH no te avisa claramente; `ssh -G` sí resuelve el nombre y te muestra el error.

## Relación con escenarios reales

- Cuando onboardeas en una empresa con 50 hosts, un `~/.ssh/config` así bien escrito reemplaza un documento de 10 páginas.
- Cuando CI/CD falla con "Permission denied (publickey)" sobre GitHub, el culpable casi siempre es un `IdentityFile` erróneo o la falta de `IdentitiesOnly`.
- Cuando migran un bastión, cambias **una** línea del `ProxyJump` y los 20 hosts internos siguen funcionando.

## Limpieza

Ninguna; es un archivo de referencia local.
