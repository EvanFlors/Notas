# Ejemplo 02 — Variantes de port forwarding

## Concepto que demuestra

Las tres formas de redirección de puertos sobre SSH:

- **`-L`** — expone un servicio *remoto* como si estuviera en tu *localhost*.
- **`-R`** — expone un servicio *local* como si estuviera en el *remoto*.
- **`-D`** — levanta un proxy *SOCKS* local que tuneliza cualquier conexión.

## Contexto

El port forwarding es una de las razones por las que SSH sigue siendo el navaja suiza del sysadmin: sin VPN, sin exponer puertos nuevos, abres accesos puntuales que mueren con la sesión.

## Objetivo

Al terminar, podrás elegir sin dudar qué forma usar en cada escenario y explicar quién abre qué conexión TCP en cada caso.

## Prerrequisitos

- Dos máquinas con SSH funcionando: tu **laptop** y un host llamado `remote.example.com` donde tienes shell.
- Para `-L`: en el remoto (o alcanzable desde él) un servicio escuchando, p. ej. PostgreSQL en `db.internal:5432`.
- Para `-R`: en tu laptop un servidor local, p. ej. `python3 -m http.server 3000`.

## Ejecución

### Variante `-L` (local forwarding)

```bash
# Terminal 1 (en laptop): abre el tunel y queda la shell del remoto
ssh -N -L 5432:db.internal:5432 user@remote.example.com
#   -N = no shell, solo tunel

# Terminal 2 (en laptop): conecta como si la DB fuera local
psql -h 127.0.0.1 -p 5432 -U appuser mydb
```

**Quien conecta a `db.internal:5432`**: el proceso `sshd` en `remote.example.com`. Por eso el firewall debe permitir `remote → db.internal:5432`.

### Variante `-R` (remote forwarding)

```bash
# En laptop: arranca un servicio local
python3 -m http.server 3000

# En otra terminal (en laptop): publica ese :3000 como :8080 en el remoto
ssh -N -R 8080:localhost:3000 user@remote.example.com
```

Desde el remoto:

```bash
# En remote.example.com:
curl http://localhost:8080
```

Por defecto escucha solo en `127.0.0.1` del remoto. Para publicar en `0.0.0.0` del remoto (y que terceros alcancen) necesitas `GatewayPorts yes` en el `sshd_config` del remoto **y** `-R 0.0.0.0:8080:localhost:3000`.

**Quien conecta a tu `:3000`**: el `sshd` del remoto cuando alguien hace `curl` en `remote:8080`. El sentido de la conexion TCP interna es **laptop ← remote**, nunca cruza tu firewall entrante.

### Variante `-D` (SOCKS dinamico)

```bash
# En laptop:
ssh -N -D 1080 user@remote.example.com

# En otra terminal:
curl --socks5-hostname localhost:1080 https://internal-wiki.example.com
```

O configura el navegador: SOCKS5 en `localhost:1080`. Toda la navegacion sale por `remote.example.com`.

## Resultado esperado

- `-L`: `psql -h 127.0.0.1` llega a la DB privada.
- `-R`: `curl localhost:8080` **en el remoto** descarga el `index.html` servido por tu laptop.
- `-D`: `curl --socks5-hostname localhost:1080 ifconfig.me` responde con la IP publica del remoto, no la tuya.

## Interpretacion

| Flag | Direccion efectiva del dato | Caso canonico |
|------|-----------------------------|----------------|
| `-L src:dst:port` | laptop → remoto → servicio | DB privada, dashboard interno |
| `-R src:dst:port` | internet → remoto → laptop | Webhook, demo local a terceros |
| `-D port` | laptop → remoto → cualquier destino | Navegar "como si estuvieras alla" |

Nemotecnica: **L**ocal trae lo de **a**lla aqui; **R**emote lleva lo de **a**qui alla; **D**ynamic es un proxy generico.

## Errores frecuentes

- **`-L` escucha en `0.0.0.0` por accidente** — expone tu tunel a toda tu red local. Por defecto es `127.0.0.1`, no lo cambies sin pensarlo.
- **`-R` sin `GatewayPorts yes`** — nadie externo al remoto llega, solo quien tenga shell en el remoto.
- **`-D` con DNS filtrado** — `curl --socks5` resuelve en local; usa `--socks5-hostname` para que el DNS tambien pase por el tunel.
- **Dejar los tuneles abiertos indefinidamente** — son accesos a tus sistemas; cierra la sesion al terminar.

## Relacion con escenarios reales

- `-L` sustituye a montar una VPN para una tarea puntual de DBA.
- `-R` es como ngrok, pero sin terceros: usa tu propio host publico.
- `-D` saca a un dev de un hotel con red filtrada: todo el trafico HTTP sale por su servidor.

## Limpieza

Cierra las sesiones SSH con `Ctrl-C` (si usaste `-N`) o `exit` (si tenias shell).
