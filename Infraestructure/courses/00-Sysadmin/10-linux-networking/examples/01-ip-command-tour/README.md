# Ejemplo 01 — Tour del comando `ip`

## Concepto que demuestra

Inventariar un host Linux (L2 + L3) usando únicamente `ip` del paquete `iproute2`. Todo el ejemplo es **read-only**: no modifica nada.

## Contexto

`ip` reemplaza a `ifconfig`, `route`, `arp`, `netstat -r`. Un sysadmin que todavía usa esos binarios en 2026 está perdiéndose información (IPv6, VRFs, policy routing).

## Objetivo

Al terminar, podrás responder sobre cualquier host:
- Qué interfaces tiene y en qué estado.
- Qué IPs (v4 y v6) tiene cada interfaz.
- Qué tabla de ruteo usa y cuál es la ruta por defecto.
- Quién hay en su segmento L2 (caché ARP).
- Qué contadores y errores reporta el kernel.

## Prerrequisitos

- Linux moderno (kernel ≥ 5.x, `iproute2` ≥ 5).
- Shell Bash o equivalente.
- No requiere `root`: todas las lecturas son no privilegiadas.

## Las 15 recetas

Ejecuta cada bloque y **lee la salida** antes de pasar al siguiente.

### 1. Interfaces en una línea cada una

```bash
ip -br -c link
```

`-br` = *brief* (una línea), `-c` = *color*. Columnas: nombre, estado (`UP`/`DOWN`/`UNKNOWN`), MAC, flags.

### 2. IPs en una línea cada una

```bash
ip -br -c addr
```

Rápido para ver "qué IP tengo". `UNKNOWN` en loopback es normal.

### 3. Detalle de una interfaz

```bash
ip addr show dev lo
ip addr show dev "$(ip -o -4 route show default | awk '{print $5}' | head -1)"
```

El segundo comando usa la interfaz por la que sale el tráfico por defecto, sin asumir el nombre.

### 4. Solo IPv4

```bash
ip -4 addr show
```

### 5. Solo IPv6

```bash
ip -6 addr show
```

Si no ves nada más que `::1` y `fe80::…`, tu red no usa IPv6 global.

### 6. Tabla de ruteo principal

```bash
ip route
```

Busca la línea `default via …`. Sin ella, no sales a Internet.

### 7. Decidir qué ruta usaría el kernel

```bash
ip route get 1.1.1.1
ip route get 8.8.8.8
```

Útil para preguntar "¿por qué interfaz y con qué source IP saldría este paquete?".

### 8. Rutas IPv6

```bash
ip -6 route
```

### 9. Caché ARP / NDP (vecinos)

```bash
ip neigh
```

Lectura: `IP  dev INTERFAZ lladdr MAC STATE`. `STATE` puede ser `REACHABLE`, `STALE`, `DELAY`, `PROBE`, `FAILED`. `FAILED` o entradas sin `lladdr` indican que no pudiste resolver ese vecino en L2 (típicamente, el host está apagado o filtrando ARP).

### 10. Estadísticas por interfaz

```bash
ip -s link show
```

Mira `RX: errors dropped` y `TX: errors dropped`. Cualquier número creciendo rápido es una pista de hardware o MTU mal configurada.

### 11. Reglas de policy routing

```bash
ip rule show
```

En un host "normal" verás tres entradas (`0: local`, `32766: main`, `32767: default`). Si ves más, hay routing avanzado (VPN con split-tunnel, VRF, multi-WAN).

### 12. Múltiples tablas de ruteo

```bash
ip route show table all | head -40
```

El kernel mantiene tablas separadas. La `main` es la del día a día; `local` es la que decide "esta IP soy yo".

### 13. Watch de vecinos en tiempo real

```bash
ip monitor neigh
```

Deja esta terminal corriendo y, en otra, haz `ping -c1 <IP_de_tu_router>`. Verás eventos ARP en vivo. `Ctrl-C` para salir.

### 14. Watch de rutas en tiempo real

```bash
ip monitor route
```

Útil cuando una VPN o `dhclient` modifican rutas y quieres ver *cuándo* lo hacen.

### 15. Formato JSON (para scripts)

```bash
ip -j -p addr show | head -40
```

`-j` = JSON, `-p` = pretty. En scripts, prefiere esto a parsear la salida de texto con `awk` — `iproute2` cambia formatos entre versiones.

## Resultado esperado

- Puedes citar sin consultar: tu MAC, tu IP v4 principal, tu gateway por defecto, tu DNS (ver siguiente ejemplo), y una entrada ARP válida.
- Entiendes que `-br` resume y `-j` es parseable; `-c` solo colorea.

## Interpretación

- `ip` es un verbo polimórfico: `ip <objeto> <acción> …`. Objetos frecuentes: `link`, `addr`, `route`, `neigh`, `rule`, `netns`, `monitor`.
- Casi todas las acciones de lectura (`show`) son no privilegiadas; las de escritura (`add`, `del`, `set`) requieren `root`.
- Si vienes de `ifconfig`: `ip link` + `ip addr` cubren todo lo que `ifconfig` mostraba, con mucha más precisión.

## Errores frecuentes

- **`Object "neigh" is unknown"`**: `iproute2` muy viejo. Actualiza (`apt install iproute2` o equivalente).
- **No veo IPs con `ip addr`**: puede que estés en un namespace vacío (`ip netns exec`), o que no haya DHCP activo.
- **`ip` no colorea**: tu terminal no reporta color. Añade `-c` igualmente o fija `COLORTERM`.

## Relación con escenarios reales

- Un pod de Kubernetes sin IP → `ip -br addr` dentro del pod lo demuestra en una línea.
- Una VM que "no sale a Internet" → `ip route` dirá si falta la ruta por defecto o si el gateway está apuntando a una red mal segmentada.
- Un host con dos NICs → `ip route get <ip>` dice por cuál saldría.

## Limpieza

Nada que limpiar: todo fue read-only.
