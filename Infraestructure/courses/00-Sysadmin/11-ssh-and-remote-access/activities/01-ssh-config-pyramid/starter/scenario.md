# Escenario — Piramide de ~/.ssh/config con bastion

## Topologia

```
          Internet
             │
             │ :22 (unico expuesto)
             ▼
      ┌──────────────┐
      │   bastion    │  bastion.example.com   (user: jump)
      │  (jump host) │  key:  id_ed25519_bastion
      └──────┬───────┘
             │ red privada 10.0.0.0/16
             │
       ┌─────┴─────┬───────────┐
       ▼           ▼           ▼
      app1        app2        db1
    10.0.1.10   10.0.1.11   10.0.2.10
    deploy      deploy      dbadmin
    id_..app1   id_..app2   id_..db1
```

## Requisitos

Escribe un archivo `ssh-config` (relativo al cwd, no `~/.ssh/config`) con los bloques necesarios para que:

- `ssh -F ssh-config bastion.example.com` conecte como `jump` con la clave `~/.ssh/id_ed25519_bastion`.
- `ssh -F ssh-config app1` conecte como `deploy` a `10.0.1.10` **saltando por el bastion**, con la clave `~/.ssh/id_ed25519_app1`.
- Lo analogo para `app2` (`10.0.1.11`, `id_ed25519_app2`) y `db1` (`10.0.2.10`, usuario `dbadmin`, `id_ed25519_db1`).
- Cada bloque especifico incluye `IdentitiesOnly yes`.
- Un bloque final `Host *` con `AddKeysToAgent yes` y `ServerAliveInterval 60`.

## Restricciones

- **No** definas una clave global en `Host *` (eso anularia el proposito de usar claves por host).
- **No** uses `ForwardAgent yes` globalmente.
- Mantén los nombres de los alias cortos: `bastion.example.com`, `app1`, `app2`, `db1`.

## Como validar sin red

```bash
ssh -G app1 -F ssh-config | head -40
bash tests/validate.sh ssh-config
```
