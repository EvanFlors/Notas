# Ejemplo 01 — Ruleset nftables mínima (default-deny inbound)

Este ejemplo muestra una ruleset nftables comentada apta para un servidor estándar: default-deny en `input` y `forward`, loopback abierto, `conntrack` aceptando lo ya establecido, ICMP útil permitido, y SSH expuesto.

**Es un ejemplo demostrativo, no un script a ejecutar sobre tu máquina diaria.** Pruébalo en una VM.

## Fichero

- `files/nftables.conf` — ruleset lista para `nft -c -f` y `nft -f`.

## Lectura línea por línea

```nft
flush ruleset
```

Vacía todo lo que ya hubiera cargado. Si lo ejecutas en un host remoto por SSH sin tener la nueva política correcta, pierdes la conexión. Por eso en producción se usa el patrón `at now + 2 minutes` descrito en la lección.

```nft
table inet filter {
```

Familia `inet`: la misma tabla cubre IPv4 e IPv6.

```nft
    chain input {
        type filter hook input priority 0; policy drop;
```

Base chain enganchada al hook `input` con política `drop` (default-deny).

```nft
        iif "lo" accept
        ct state established,related accept
        ct state invalid drop
```

Loopback, conntrack. Sin esto nada funciona.

```nft
        ip protocol icmp icmp type { echo-request, destination-unreachable, time-exceeded } accept
        ip6 nexthdr icmpv6 accept
```

ICMP útil para diagnóstico; ICMPv6 completo porque es parte del protocolo (NDP, PMTUD).

```nft
        tcp dport 22 accept
```

Único servicio expuesto: SSH, desde cualquier origen. Para restringir a una /24, cambia a `tcp dport 22 ip saddr 10.0.0.0/24 accept`.

## Cómo probarlo

En una VM desechable:

```bash
# 1. Validar sintaxis sin aplicar
sudo nft -c -f files/nftables.conf

# 2. (Opcional) Programar rollback a los 2 min
sudo bash -c 'at now + 2 minutes <<< "nft flush ruleset"'

# 3. Aplicar
sudo nft -f files/nftables.conf

# 4. Verificar
sudo nft list ruleset

# 5. Si todo bien, cancelar el rollback
atq
sudo atrm <job-id>
```

## Qué observar

- `sudo nft list ruleset` muestra la ruleset efectiva, con contadores si añades `counter` a reglas concretas.
- Prueba `curl http://<ip>:80` desde otra máquina: debe fallar con timeout (política `drop`).
- `ssh usuario@<ip>` debe seguir funcionando.
- `ping <ip>` debe responder (echo-request permitido).
