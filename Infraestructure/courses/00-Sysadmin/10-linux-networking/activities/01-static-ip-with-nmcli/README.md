# Actividad 01 — IP estática persistente con el gestor correcto

## 1. Identificación

- **ID:** `sys-10-01-static-ip-with-nmcli`
- **Tecnología:** `sysadmin`
- **Módulo:** `sys-10-linux-networking`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** guided-lab (**lab privilegiado**: modifica configuración de red persistente)

## 2. Contexto

Un host "estático" (servidor, bastión, nodo de laboratorio) no debería depender de DHCP. En producción se asigna IP, gateway y DNS fijos vía el *frontend* que gobierne la distro: **NetworkManager** (laptops, Fedora/RHEL, Arch), **netplan** (Ubuntu Server) o **`systemd-networkd`** (imágenes cloud, servidores minimalistas).

Esta actividad te hace **detectar primero el stack** y luego configurar con la herramienta adecuada. El script de solución y el validador no asumen un stack: detectan y actúan, o abortan limpio si hay ambigüedad.

## 3. Objetivos

Al terminar deberías poder:

- Identificar qué frontend de red está activo en un host.
- Configurar una conexión Ethernet con IP estática, gateway y DNS persistentes.
- Validar que la conexión aplica en caliente y sobrevive un `systemctl restart` del servicio responsable.
- Revertir sin dejar restos.

## 4. Prerrequisitos

- VM Linux **desechable** (Multipass, Lima, UTM, VirtualBox) con snapshot previo.
- Acceso `sudo`.
- Al menos una interfaz Ethernet (no Wi-Fi) con nombre predecible (`enpXsY`, `ensX`, `eth0`).
- Variable de confirmación exportada:

  ```bash
  export I_UNDERSTAND_THIS_IS_DISPOSABLE=1
  ```

  Sin ella, los scripts abortan.

**Costos**: ninguno (todo local).

## 5. Advertencia

> Esta actividad **puede dejarte sin red** si la haces en tu laptop de trabajo. El script hace *best effort* para no cortar tu sesión actual, pero el riesgo real existe. **Usa una VM desechable con snapshot.**

## 6. Parámetros del lab

Edita si tu red lo requiere. Los valores por defecto usan la red privada `192.0.2.0/24` (TEST-NET-1 de RFC 5737, segura para labs):

| Variable | Valor por defecto | Significado |
|----------|-------------------|-------------|
| `LAB_IFACE` | *autodetectado* | interfaz Ethernet |
| `LAB_ADDR` | `192.0.2.42/24` | IP estática a asignar |
| `LAB_GW` | `192.0.2.1` | gateway |
| `LAB_DNS` | `1.1.1.1 9.9.9.9` | DNS |
| `LAB_CONN` | `sys10-static-lab` | nombre lógico de la conexión |

## 7. Instrucciones

### 7.1 Preparación

```bash
cd /path/to/activities/01-static-ip-with-nmcli
export I_UNDERSTAND_THIS_IS_DISPOSABLE=1
cat starter/plan.md    # lee el plan y las decisiones
```

### 7.2 Detectar el stack

```bash
systemctl is-active NetworkManager   || true
systemctl is-active systemd-networkd || true
ls /etc/netplan/ 2>/dev/null         || true
```

- Si **solo** NetworkManager está `active` → usarás `nmcli`.
- Si **solo** `systemd-networkd` → usarás un archivo `.network`.
- Si existe `/etc/netplan/*.yaml` → usarás un archivo YAML y `netplan try`.
- Si **varios** están activos → el script aborta. Decide uno y desactiva los otros antes de continuar.

### 7.3 Ejecutar la solución (o escribir la tuya)

Opción A — guiada:

```bash
sudo -E bash solution/configure.sh
```

El script:

1. Comprueba `I_UNDERSTAND_THIS_IS_DISPOSABLE=1`.
2. Detecta el stack activo. Si hay ambigüedad, aborta con mensaje claro.
3. Autodetecta `LAB_IFACE` (primera Ethernet `UP` que no sea loopback).
4. Aplica la configuración en el stack correcto.
5. Verifica que la IP está asignada y que el gateway responde (`ping -c1 -W2`).

Opción B — manual (recomendado la segunda vez): sigue las recetas de `theory/lesson.md` sección 5.

### 7.4 Verificar persistencia

Reinicia el servicio del stack correspondiente y vuelve a comprobar:

```bash
# ejemplo si fue NetworkManager
sudo systemctl restart NetworkManager
sleep 3
ip -br -c addr show "$LAB_IFACE"
ip route | grep '^default'
```

### 7.5 Validar

```bash
sudo -E bash tests/validate.sh
```

Debe terminar con `OK: actividad completada correctamente`.

### 7.6 Revertir

```bash
sudo -E bash solution/configure.sh --revert
```

Esto elimina la conexión creada y vuelve el host a su estado anterior. Verifica con `ip -br -c addr`.

## 8. Resultado esperado

- `ip -br -c addr show $LAB_IFACE` muestra `$LAB_ADDR` como estática.
- `ip route` muestra `default via $LAB_GW dev $LAB_IFACE`.
- `resolvectl status` (o `/etc/resolv.conf`) incluye los DNS del lab.
- Un `systemctl restart` del servicio responsable mantiene la configuración.
- `tests/validate.sh` pasa.

## 9. Criterios de aceptación

- [ ] Stack detectado correctamente (NM / netplan / networkd).
- [ ] IP estática aplicada en el stack correcto.
- [ ] Persistencia verificada tras `systemctl restart`.
- [ ] Reverso limpio: `ip addr` vuelve a lo anterior sin basura en `/etc/`.
- [ ] `tests/validate.sh` pasa.

## 10. Validación

```bash
sudo -E bash tests/validate.sh
```

Chequea:

- `I_UNDERSTAND_THIS_IS_DISPOSABLE=1` definido.
- Stack único activo.
- IP `$LAB_ADDR` presente en `$LAB_IFACE`.
- Default route hacia `$LAB_GW`.
- Al menos un DNS de `$LAB_DNS` configurado.
- Persistencia (archivo de configuración existe donde corresponde).

## 11. Preguntas de reflexión

1. ¿Por qué `netplan` no es un *gestor* sino un *generador*? ¿Qué backends soporta?
2. En un host con `systemd-resolved`, ¿dónde se persisten los DNS que configuras vía `nmcli`?
3. ¿Qué sucede si configuras una IP estática pero DHCP sigue habilitado en el mismo stack?
4. ¿Por qué el script del lab usa `192.0.2.0/24` como red por defecto? Busca RFC 5737.
5. Si pierdes conectividad al aplicar la nueva configuración, ¿qué hace `netplan try` por ti que `nmcli up` **no** hace?

## 12. Extensiones (opcional)

- **E1** — Añade IPv6 estática. Para `nmcli`: `ipv6.method manual ipv6.addresses 2001:db8::42/64 ipv6.gateway 2001:db8::1`.
- **E2** — Configura MTU 1400 (típico de VPN/VXLAN) en la misma conexión y verifica con `ip link show`.
- **E3** — Añade una segunda IP (alias) en la misma interfaz y una ruta estática adicional.

## 13. Limpieza

```bash
sudo -E bash solution/configure.sh --revert
unset I_UNDERSTAND_THIS_IS_DISPOSABLE
```
