# Actividad 01 — Tu primera ruleset nftables

**Tipo:** guided-lab · **Duración:** 75 min · **Nivel:** avanzado

## Objetivo

Escribir, validar y aplicar una ruleset nftables default-deny inbound que:

1. Acepta loopback.
2. Acepta `established,related`, descarta `invalid`.
3. Acepta ICMP útil y todo ICMPv6.
4. Acepta SSH **sólo desde `10.0.0.0/24`**.
5. Acepta HTTPS (443) desde cualquier origen.
6. `forward` queda en `drop`.
7. `output` queda en `accept`.

## Requisitos

- **Root o `sudo`** y, muy recomendable, una **VM desechable**.
- `nftables` instalado (`nft --version`).
- Opcional: `at` para programar un rollback (`sudo apt install at` / `sudo dnf install at`).

> Si trabajas por SSH, **deja una segunda sesión abierta** antes de aplicar reglas. Si te quedas fuera, usa la consola de tu hipervisor.

## Pasos

1. Lee `starter/scenario.md` para entender el entorno.
2. Escribe tu propia `nftables.conf` en el directorio que elijas.
3. Valida con `sudo nft -c -f <tu-fichero>`. Debe salir sin errores.
4. Si vas a aplicarla en la VM:
   - Programa rollback: `sudo bash -c 'at now + 2 minutes <<< "nft flush ruleset"'`.
   - Aplica: `sudo nft -f <tu-fichero>`.
   - Verifica desde fuera (SSH entra sólo si tu IP cliente está en la /24; HTTPS debería alcanzar un servicio escuchando en 443; otros puertos deben dar timeout).
   - Cancela el rollback: `atq` y `sudo atrm <id>`.
5. Ejecuta la validación: `bash tests/validate.sh <ruta-a-tu-fichero>`.

## Validación

`tests/validate.sh <ruta>` verifica:

- Sintaxis correcta (`nft -c -f`).
- Default-deny en `input` y `forward` (`policy drop`).
- Regla con `iif "lo" accept`.
- Regla con `ct state established,related accept`.
- Regla con `ct state invalid drop`.
- Regla que acepta HTTPS en 443/tcp.
- Regla que restringe SSH (22/tcp) a `10.0.0.0/24` (acepta variaciones de orden de match).

El validador **no aplica** la ruleset: sólo verifica sintaxis y contenido.

## Entregable

- La ruta a tu `nftables.conf`.
- Salida de `bash tests/validate.sh` con `RESULT: OK`.

## Pistas

- Para match combinado: `tcp dport 22 ip saddr 10.0.0.0/24 accept`.
- Para varios puertos de un golpe: `tcp dport { 80, 443 } accept`.
- Si olvidas `iif "lo" accept`, muchos servicios locales (p. ej. cliente/servidor DNS vía 127.0.0.53) dejan de funcionar.

## Solución

En `solution/nftables.conf` tienes una referencia. `solution/install.sh` muestra el patrón seguro de aplicación con rollback programado. **Léelos sólo después de intentarlo.**
