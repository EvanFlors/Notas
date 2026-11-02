# Ejemplo 02 — Primera captura con `tcpdump`

## Concepto que demuestra

Capturar un número **acotado** de paquetes TCP/443 (HTTPS) saliendo del host y leer la salida sin ahogarse.

## Contexto

`tcpdump` es la navaja suiza del L3/L4. Mal usado llena la terminal en segundos. Bien usado, resuelve en 10 paquetes lo que mil líneas de log no responden.

## Objetivo

- Ejecutar una captura segura con `-c` (límite) y `-nn` (sin resolución).
- Interpretar un *three-way handshake* TCP en la salida.
- Entender por qué filtrar en el kernel con BPF (`'tcp port 443'`) es orden(es) de magnitud más barato que filtrar en user-space.

## Prerrequisitos

- `tcpdump` instalado (`sudo apt install tcpdump`, `sudo dnf install tcpdump`).
- `sudo` disponible — la captura requiere `CAP_NET_RAW` + `CAP_NET_ADMIN`.
- Conectividad a Internet para generar el tráfico HTTPS.

## Ejecución

Abre **dos terminales** en el mismo host.

### Terminal A — la captura

```bash
sudo tcpdump -i any -nn 'tcp port 443' -c 10
```

Desglose:

- `-i any` → escucha en todas las interfaces. En lugar de adivinar `eth0`/`enp3s0`/`wlp3s0`, deja que el kernel elija.
- `-nn` → **no** resolver nombres de host **ni** de puerto. Dos `n` son clave: si tu DNS está roto, `tcpdump` sin esto se cuelga intentando resolver.
- `'tcp port 443'` → filtro BPF (Berkeley Packet Filter). Se evalúa dentro del kernel: solo los paquetes que matchean suben a `tcpdump`.
- `-c 10` → corta en 10 paquetes y sale. Casi siempre lo quieres.

Observa que el comando queda bloqueado esperando tráfico.

### Terminal B — generar tráfico

```bash
curl -s -o /dev/null https://example.com
```

Vuelve a la terminal A.

## Resultado esperado

La terminal A imprime algo similar a:

```
13:21:04.112 IP 192.168.1.42.52110 > 93.184.216.34.443: Flags [S], seq 123456, win 64240, ...
13:21:04.145 IP 93.184.216.34.443 > 192.168.1.42.52110: Flags [S.], seq 987654, ack 123457, win 65535, ...
13:21:04.145 IP 192.168.1.42.52110 > 93.184.216.34.443: Flags [.], ack 1, win 64240, length 0
13:21:04.146 IP 192.168.1.42.52110 > 93.184.216.34.443: Flags [P.], seq 1:518, ack 1, length 517  # ClientHello
13:21:04.180 IP 93.184.216.34.443 > 192.168.1.42.52110: Flags [.], ack 518, win 65535, length 0
...
10 packets captured
10 packets received by filter
0 packets dropped by kernel
```

## Interpretación

Lee los Flags:

- `[S]` → SYN (cliente inicia).
- `[S.]` → SYN+ACK (servidor responde). Esto confirma que el servidor existe y acepta en 443.
- `[.]` → solo ACK.
- `[P.]` → PUSH+ACK (datos de aplicación — aquí el ClientHello de TLS).
- `[F.]` → FIN+ACK (cierre ordenado).
- `[R]` → RST (cierre abrupto — algo rechazó).

Si **no** ves `[S.]` después de tu `[S]`:
- Probablemente el paquete nunca llegó o un firewall descartó la respuesta → timeout en `curl`.
- Si en cambio ves `[R]` casi inmediato → *connection refused* (nadie escucha).

El filtro `'tcp port 443'` se compila a bytecode BPF y corre en el kernel: millones de paquetes/segundo se descartan sin despertar user-space. Comparado con `tcpdump -i any | grep 443`, el filtro BPF es incomparablemente más barato.

## Variaciones útiles

```bash
# Solo tráfico hacia un host concreto
sudo tcpdump -i any -nn host 93.184.216.34 -c 10

# Solo DNS (UDP/53) saliente — ver quién pregunta qué
sudo tcpdump -i any -nn 'udp port 53' -c 20

# Solo SYNs (quién inicia conexiones hacia 443)
sudo tcpdump -i any -nn 'tcp port 443 and tcp[tcpflags] & tcp-syn != 0' -c 20

# Escribir a archivo para abrir en Wireshark después
sudo tcpdump -i any -nn 'tcp port 443' -c 100 -w /tmp/https.pcap
```

## Errores frecuentes

- **`tcpdump: no suitable device found`** → falta `root` o la capability. Usa `sudo`.
- **La terminal se llena a toda velocidad** → olvidaste `-c`. `Ctrl-C` y añádelo.
- **Veo IPs y puertos como nombres y es más lento** → usa `-nn`, no `-n` solo.
- **En `-i any` no veo el VLAN tag o veo paquetes "huérfanos"** → `any` tiene limitaciones. Especifica la interfaz real para análisis fino.

## Seguridad y legalidad

- Capturar tráfico de **otros usuarios** o en una red que no administras puede ser ilegal según tu jurisdicción. Captura solo lo que te corresponde depurar.
- `tcpdump` ve credenciales en texto plano si existen. Protege los `.pcap`.

## Relación con escenarios reales

- "El cliente dice que no le llega la petición" → captura en el servidor con filtro al puerto; si no ves SYNs, el problema es antes del servidor.
- "La VPN se cae y vuelve" → `sudo tcpdump -i tun0 -nn icmp` suele mostrar ICMP *Destination Unreachable* útil.
- Load balancer que responde `503` sporádico → captura con `-w` y abre en Wireshark para ver retransmisiones y RSTs.

## Limpieza

Nada que limpiar. Si guardaste `.pcap`, bórralo cuando termines (`rm /tmp/https.pcap`).
