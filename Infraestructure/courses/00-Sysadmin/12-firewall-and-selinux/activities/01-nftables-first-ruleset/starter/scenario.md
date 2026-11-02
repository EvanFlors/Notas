# Escenario

Administras un pequeño servidor de aplicaciones en una VM Linux. Vas a instalar tu primera política nftables desde cero.

## Entorno

- **Host:** `app01`, una VM con una única interfaz pública (`eth0`).
- **Red administrativa:** `10.0.0.0/24` — desde aquí llega el equipo de operaciones por SSH.
- **Servicio público:** una aplicación web en HTTPS (443) accesible desde Internet.
- **No es router:** `forward` debe estar cerrado.

## Requisitos de la política

| Caso | Decisión |
|------|----------|
| Loopback | aceptar |
| Respuestas a conexiones salientes | aceptar (`conntrack established,related`) |
| Paquetes `invalid` | descartar |
| ICMP útil (ping, destination-unreachable, time-exceeded) IPv4 | aceptar |
| ICMPv6 | aceptar (no romper IPv6) |
| SSH (22/tcp) desde `10.0.0.0/24` | aceptar |
| SSH (22/tcp) desde cualquier otro origen | descartar (política por defecto) |
| HTTPS (443/tcp) desde cualquier origen | aceptar |
| HTTP (80/tcp) | descartar |
| Cualquier otro puerto entrante | descartar |
| Forwarding | descartar |
| Tráfico saliente | aceptar |

## Pistas de implementación

- Familia `inet` (una tabla cubre IPv4 e IPv6).
- Una única tabla llamada `filter` con tres chains: `input`, `forward`, `output`.
- Comentarios abundantes: cuando vuelvas a esta ruleset en 6 meses lo agradecerás.

## Entregable

Un fichero `nftables.conf` que pasa `sudo nft -c -f` y la validación de `tests/validate.sh`.
