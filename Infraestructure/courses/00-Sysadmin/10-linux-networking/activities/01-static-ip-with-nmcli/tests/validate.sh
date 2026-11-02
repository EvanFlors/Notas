#!/usr/bin/env bash
# sys-10-01 — Valida que la IP estática está aplicada y persistente.
# Requiere mismas variables que configure.sh y root.

set -euo pipefail

LAB_ADDR="${LAB_ADDR:-192.0.2.42/24}"
LAB_GW="${LAB_GW:-192.0.2.1}"
LAB_DNS="${LAB_DNS:-1.1.1.1 9.9.9.9}"
LAB_CONN="${LAB_CONN:-sys10-static-lab}"
LAB_NETPLAN_FILE="/etc/netplan/99-${LAB_CONN}.yaml"
LAB_NETWORKD_FILE="/etc/systemd/network/90-${LAB_CONN}.network"

fail=0
check() {
    local label="$1" status="$2"
    if [[ "${status}" -eq 0 ]]; then
        echo "  OK   ${label}"
    else
        echo "  FAIL ${label}"
        fail=$((fail+1))
    fi
}

echo "== Validando sys-10-01 =="

if [[ "${EUID}" -ne 0 ]]; then
    echo "FAIL: ejecutar con sudo."
    exit 1
fi

if [[ "${I_UNDERSTAND_THIS_IS_DISPOSABLE:-}" != "1" ]]; then
    echo "FAIL: I_UNDERSTAND_THIS_IS_DISPOSABLE=1 no está definido en el entorno."
    exit 1
fi

# Detectar iface igual que configure.sh
if [[ -n "${LAB_IFACE:-}" ]]; then
    iface="${LAB_IFACE}"
else
    iface="$(ip -br link show up \
        | awk '{print $1}' \
        | grep -Ev '^(lo|docker|br-|veth|wl|tun|tap|cni|flannel|cali)' \
        | head -n1 || true)"
fi

if [[ -z "${iface}" ]]; then
    echo "FAIL: no detecté interfaz Ethernet."
    exit 1
fi
echo "  iface detectada: ${iface}"

# Detectar stack
stacks_active=0
stack=""
if systemctl is-active --quiet NetworkManager; then
    stacks_active=$((stacks_active+1))
    stack="networkmanager"
fi
if systemctl is-active --quiet systemd-networkd; then
    stacks_active=$((stacks_active+1))
    [[ -z "${stack}" ]] && stack="networkd"
fi
if compgen -G "/etc/netplan/*.yaml" > /dev/null; then
    stack="netplan"
fi
if [[ "${stacks_active}" -gt 1 && "${stack}" != "netplan" ]]; then
    echo "FAIL: varios stacks activos simultáneamente."
    exit 1
fi
echo "  stack detectado: ${stack}"

# 1. IP presente
if ip -4 -br addr show "${iface}" | grep -Fq "${LAB_ADDR}"; then
    check "IP ${LAB_ADDR} presente en ${iface}" 0
else
    check "IP ${LAB_ADDR} presente en ${iface}" 1
fi

# 2. Default route
if ip route | grep -Eq "^default via ${LAB_GW}([[:space:]]|$)"; then
    check "default route via ${LAB_GW}" 0
else
    check "default route via ${LAB_GW}" 1
fi

# 3. Al menos un DNS del lab configurado
dns_found=1
if command -v resolvectl >/dev/null 2>&1; then
    for d in ${LAB_DNS}; do
        if resolvectl dns 2>/dev/null | grep -Fq "${d}"; then
            dns_found=0
            break
        fi
    done
fi
if [[ "${dns_found}" -ne 0 ]]; then
    for d in ${LAB_DNS}; do
        if grep -Eq "^nameserver[[:space:]]+${d}" /etc/resolv.conf 2>/dev/null; then
            dns_found=0
            break
        fi
    done
fi
check "al menos un DNS de LAB_DNS configurado" "${dns_found}"

# 4. Persistencia (archivo o perfil existe donde corresponde)
persisted=1
case "${stack}" in
    networkmanager)
        if nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "${LAB_CONN}"; then
            persisted=0
        fi
        ;;
    netplan)
        [[ -f "${LAB_NETPLAN_FILE}" ]] && persisted=0
        ;;
    networkd)
        [[ -f "${LAB_NETWORKD_FILE}" ]] && persisted=0
        ;;
esac
check "configuración persistida en disco (${stack})" "${persisted}"

echo
if [[ "${fail}" -gt 0 ]]; then
    echo "RESULT: ${fail} check(s) fallaron."
    exit 1
fi
echo "OK: actividad completada correctamente."
exit 0
