# Plan de trabajo — IP estática persistente

Antes de ejecutar nada, respóndete por escrito:

## Decisiones previas

1. **¿Es esta máquina desechable?**
   - Si no, **detente**. Crea una VM y empieza allí.
   - Si sí, exporta `I_UNDERSTAND_THIS_IS_DISPOSABLE=1`.

2. **¿Qué stack gestiona la red?**

   ```bash
   systemctl is-active NetworkManager   || true
   systemctl is-active systemd-networkd || true
   ls /etc/netplan/ 2>/dev/null         || true
   ```

   Resultados posibles:
   - **Solo NM activo** → usarás `nmcli`.
   - **Solo networkd activo**, sin netplan → archivo `/etc/systemd/network/*.network`.
   - **networkd activo + netplan presente** → netplan es el frontend; edita YAML.
   - **NM activo + netplan presente** con `renderer: NetworkManager` → netplan sigue siendo el frontend.
   - **NM + networkd activos simultáneamente** → ambigüedad; apaga uno antes.

3. **¿Qué interfaz vas a configurar?**

   ```bash
   ip -br -c link | awk '$1!="lo" && $2=="UP"'
   ```

   Toma la primera Ethernet que no sea Wi-Fi (`wlp…` o `wlan…`) ni virtual (`docker0`, `br-…`, `veth…`).

4. **¿Qué valores aplicarás?**

   | Variable | Valor por defecto | Tu valor |
   |----------|-------------------|----------|
   | `LAB_IFACE` | autodetectado | |
   | `LAB_ADDR`  | `192.0.2.42/24` | |
   | `LAB_GW`    | `192.0.2.1`     | |
   | `LAB_DNS`   | `1.1.1.1 9.9.9.9` | |
   | `LAB_CONN`  | `sys10-static-lab` | |

   `192.0.2.0/24` es TEST-NET-1 (RFC 5737), nunca ruteada públicamente — ideal para labs.

5. **¿Cómo revertirás si algo sale mal?**

   - Si tienes consola física/VM console → `solution/configure.sh --revert`.
   - Si estás por SSH → **lo haces desde consola de la VM**, no por SSH, porque puedes perder la sesión.

## Secuencia

1. Lee este plan completo.
2. Lee `solution/configure.sh` **antes** de ejecutarlo. Nunca ejecutes a ciegas scripts privilegiados.
3. Ejecuta `sudo -E bash solution/configure.sh`.
4. Verifica con `ip -br -c addr` y `ip route`.
5. Reinicia el servicio del stack correspondiente (`systemctl restart …`) y vuelve a verificar.
6. Ejecuta `sudo -E bash tests/validate.sh`.
7. Reverse: `sudo -E bash solution/configure.sh --revert`.

## Si algo falla

- `ip -br -c addr` → ¿la IP está?
- `ip route` → ¿la default route está?
- `journalctl -u NetworkManager -n 50` (o `systemd-networkd`) → errores del gestor.
- `nmcli connection show` → listado de perfiles conocidos por NM.
- `networkctl status` → estado por interfaz según networkd.
