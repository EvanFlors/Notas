# Solución — Triage de red (sys-10-02)

> Léelo solo después de haber resuelto por tu cuenta.

---

## case1 — `Could not resolve host`

- **Capa:** `dns`.
- **Por qué:** `curl` nunca llegó a abrir TCP; el fallo es antes, en la resolución de nombres (`getaddrinfo`).
- **Probe mínima:**

  ```bash
  dig +short wiki.ejemplo.invalid @1.1.1.1
  ```

  - Si responde vacío o `NXDOMAIN` → el dominio no existe públicamente (es un nombre interno, un typo, o DNS split-horizon).
  - Si responde una IP con `@1.1.1.1` pero no con tu resolver local → el problema es tu `systemd-resolved` o `/etc/resolv.conf`.

- **Causa raíz (ejemplos aceptables):** "dominio inexistente", "DNS interno no accesible desde esta red", "typo en el nombre".

Herramienta complementaria: `resolvectl status` para ver DNS por interfaz y dominios de búsqueda.

---

## case2 — `Operation timed out` + `Destination Host Unreachable`

- **Capa:** `route`.
- **Por qué:** `ping` devuelve `Destination Host Unreachable` **desde tu propio host** (`From 192.168.1.42`), lo que significa que el **kernel local** no tiene cómo enrutar hacia `10.255.0.17`. No es un filtro remoto; es ausencia de ruta.
- **Probe mínima:**

  ```bash
  ip route get 10.255.0.17
  ```

  Si responde `RTNETLINK answers: Network is unreachable` o devuelve una ruta extraña (p. ej. pasando por default sin next-hop apropiado), ahí lo tienes.

- **Causa raíz (ejemplos aceptables):** "sin ruta hacia la subred `10.255.0.0/x`", "VPN que debería inyectar la ruta no está arriba", "falta un `ip route add 10.255.0.0/24 via <gw>`".

Diferencia clave con "filtro remoto": si fuera firewall, `ping` daría `100% packet loss` sin mensajes `Destination Host Unreachable` desde tu IP.

---

## case3 — `SSL certificate problem: certificate has expired`

- **Capa:** `tls`.
- **Por qué:** DNS resolvió, TCP completó handshake (`Connected to`), el fallo apareció durante el handshake TLS al verificar la cadena de certificados.
- **Probe mínima:**

  ```bash
  openssl s_client -connect expired.badssl.com:443 -servername expired.badssl.com </dev/null \
      | openssl x509 -noout -dates -subject -issuer
  ```

  Las líneas `notBefore=` y `notAfter=` te dicen el periodo de validez; `subject` te confirma el CN; `issuer` la CA emisora.

- **Causa raíz (ejemplos aceptables):** "certificado expirado", "cert fuera de su `notAfter`", "cadena de certificados inválida por expiración".

Nota: `-servername` es necesario con SNI (lo normal en servidores modernos que alojan múltiples sitios).

---

## Patrón general

```
Síntoma                              → capa      → probe canónica
"Could not resolve host"             → dns       → dig +short NAME @1.1.1.1
"No route to host" / "Destination    → route     → ip route get <ip>
   Host Unreachable" (local)
"Connection refused"                 → L4 server → ss -tulpn 'sport = :<port>' (en el server)
"Operation timed out"                → L3 filter → tcpdump en ambos lados; ip route
"SSL certificate problem"            → tls       → openssl s_client -connect H:443 -servername H
"HTTP 5xx" o payload inesperado      → app       → logs del servicio, journalctl -u
```
