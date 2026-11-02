# Escenarios — Triage de red

Para cada caso: identifica la **capa**, elige **un comando** que lo confirme y escribe la **causa raíz** en `answers.md`.

---

## Caso 1 — "No puedo entrar a la wiki"

Un desarrollador dice que su CI falla al clonar un repo interno. El símptoma reproducible:

```bash
$ curl -v https://wiki.ejemplo.invalid/
* Could not resolve host: wiki.ejemplo.invalid
* Closing connection
curl: (6) Could not resolve host: wiki.ejemplo.invalid
```

Contexto:
- Internet funciona en el host (`curl https://1.1.1.1` responde).
- Otros dominios resuelven bien (`dig github.com +short` da IPs).

Preguntas:
- ¿Qué capa está rota?
- ¿Qué comando te lo confirma con un resolver conocido (p. ej. `1.1.1.1`) para separar "mi resolver" de "el dominio"?

---

## Caso 2 — "La API nueva responde lentísimo… hasta que no responde"

Un equipo acaba de levantar un servicio en `10.255.0.17:8443` en otra VLAN. Desde tu máquina:

```bash
$ curl -v --max-time 5 https://10.255.0.17:8443/health
*   Trying 10.255.0.17:8443...
* Connection timed out after 5001 milliseconds
* Closing connection
curl: (28) Operation timed out after 5001 milliseconds with 0 bytes received
```

Un `ping` da el mismo panorama:

```bash
$ ping -c3 -W2 10.255.0.17
PING 10.255.0.17 (10.255.0.17) 56(84) bytes of data.
From 192.168.1.42 icmp_seq=1 Destination Host Unreachable
From 192.168.1.42 icmp_seq=2 Destination Host Unreachable
From 192.168.1.42 icmp_seq=3 Destination Host Unreachable
```

Contexto:
- Internet funciona (`curl https://1.1.1.1` responde).
- DNS funciona (no aplica aquí, el destino es IP literal).

Preguntas:
- ¿Qué capa está rota?
- ¿Qué comando `ip` te dice si existe o no camino hacia `10.255.0.17`?

Nota: no te pedimos arreglar la ruta (podrías no tener el gateway); te pedimos **demostrar** que la ruta es el problema.

---

## Caso 3 — "Mi script Python revienta en producción"

Un script Python falla al conectarse a un endpoint externo con `ssl.SSLCertVerificationError: certificate has expired`. Para reproducir fuera de Python, usas:

```bash
$ curl -v https://expired.badssl.com/
*   Trying 104.154.89.105:443...
* Connected to expired.badssl.com (104.154.89.105) port 443
* ALPN: curl offers h2,http/1.1
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* SSL certificate problem: certificate has expired
* Closing connection
curl: (60) SSL certificate problem: certificate has expired
```

Contexto:
- DNS resuelve (ves la IP conectada).
- TCP se completa (ves `Connected to`).
- El fallo ocurre durante el handshake TLS.

Preguntas:
- ¿Qué capa está rota?
- ¿Qué comando `openssl` te permite ver el certificado sin pasar por `curl`?

(**Nota de seguridad**: `expired.badssl.com` es un servicio público pensado para pruebas — no hay riesgo real.)
