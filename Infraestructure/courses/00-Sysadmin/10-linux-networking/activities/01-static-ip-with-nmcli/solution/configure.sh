#!/usr/bin/env bash
# sys-10-01 — Configura IP estática persistente en el stack detectado.
# USO:
#   sudo -E bash configure.sh            # aplicar
#   sudo -E bash configure.sh --revert   # revertir
#
# Requiere: I_UNDERSTAND_THIS_IS_DISPOSABLE=1 en el entorno.
# Variables opcionales: LAB_IFACE LAB_ADDR LAB_GW LAB_DNS LAB_CONN

set -euo pipefail

# --- Defaults ---------------------------------------------------------------
LAB_ADDR="${LAB_ADDR:-192.0.2.42/24}"
LAB_GW="${LAB_GW:-192.0.2.1}"
LAB_DNS="${LAB_DNS:-1.1.1.1 9.9.9.9}"
LAB_CONN="${LAB_CONN:-sys10-static-lab}"
LAB_NETPLAN_FILE="/etc/netplan/99-${LAB_CONN}.yaml"
LAB_NETWORKD_FILE="/etc/systemd/network/90-${LAB_CONN}.network"

ACTION="${1:-apply}"

# --- Helpers ----------------------------------------------------------------
log()  { printf '[configure.sh] %s\n' "$*" >&2; }
die()  { log "ERROR: $*"; exit 1; }

require_root() {
    [[ "${EUID}" -eq 0 ]] || die "este script requiere root (usa sudo -E)."
}

require_disposable() {
    [[ "${I_UNDERSTAND_THIS_IS_DISPOSABLE:-}" == "1" ]] \
        || die "exporta I_UNDERSTAND_THIS_IS_DISPOSABLE=1 antes de continuar. Esta acción modifica red persistente."
}

detect_stack() {
    local nm="no" nd="no" np="no"
    systemctl is-active --quiet NetworkManager   && nm="yes"
    systemctl is-active --quiet systemd-networkd && nd="yes"
    [[ -d /etc/netplan ]] && compgen -G "/etc/netplan/*.yaml" > /dev/null && np="yes"

    if [[ "${nm}" == "yes" && "${nd}" == "yes" ]]; then
        die "NetworkManager y systemd-networkd ambos activos. Desactiva uno y vuelve a correr."
    fi

    if [[ "${np}" == "yes" ]]; then
        # netplan presente → es el frontend; detectamos renderer
        local renderer
        renderer="$(awk '/^\s*renderer:/ {print $2; exit}' /etc/netplan/*.yaml 2>/dev/null || true)"
        if [[ -z "${renderer}" ]]; then
            renderer="networkd"   # default moderno
        fi
        echo "netplan:${renderer}"
        return
    fi

    if [[ "${nm}" == "yes" ]]; then
        echo "networkmanager"
        return
    fi

    if [[ "${nd}" == "yes" ]]; then
        echo "networkd"
        return
    fi

    die "no detecté stack de red (ni NM, ni networkd, ni netplan). Aborto."
}

detect_iface() {
    if [[ -n "${LAB_IFACE:-}" ]]; then
        echo "${LAB_IFACE}"
        return
    fi
    # Primera interfaz UP que no sea lo, docker, veth, br-, wl*, tun*, tap*
    local candidate
    candidate="$(ip -br link show up \
        | awk '{print $1}' \
        | grep -Ev '^(lo|docker|br-|veth|wl|tun|tap|cni|flannel|cali)' \
        | head -n1 || true)"
    [[ -n "${candidate}" ]] || die "no pude autodetectar una interfaz Ethernet UP. Exporta LAB_IFACE."
    echo "${candidate}"
}

# --- Apply paths ------------------------------------------------------------
apply_networkmanager() {
    local iface="$1"
    log "aplicando con NetworkManager en ${iface}"
    if nmcli -t -f NAME connection show | grep -Fxq "${LAB_CONN}"; then
        log "conexión '${LAB_CONN}' ya existe. Reconfigurando."
        nmcli connection modify "${LAB_CONN}" \
            ipv4.method manual \
            ipv4.addresses "${LAB_ADDR}" \
            ipv4.gateway "${LAB_GW}" \
            ipv4.dns "${LAB_DNS}" \
            connection.autoconnect yes
    else
        # shellcheck disable=SC2086
        nmcli connection add type ethernet \
            con-name "${LAB_CONN}" \
            ifname "${iface}" \
            ipv4.method manual \
            ipv4.addresses "${LAB_ADDR}" \
            ipv4.gateway "${LAB_GW}" \
            ipv4.dns "${LAB_DNS}" \
            autoconnect yes
    fi
    nmcli connection up "${LAB_CONN}" >/dev/null
}

apply_netplan() {
    local iface="$1" renderer="$2"
    log "aplicando con netplan (renderer=${renderer}) en ${iface}"
    local dns_yaml
    dns_yaml="$(printf '%s\n' ${LAB_DNS} | awk '{printf "        - %s\n", $1}')"
    cat > "${LAB_NETPLAN_FILE}" <<EOF
network:
  version: 2
  renderer: ${renderer}
  ethernets:
    ${iface}:
      dhcp4: false
      addresses: [${LAB_ADDR}]
      routes:
        - to: default
          via: ${LAB_GW}
      nameservers:
        addresses:
${dns_yaml}
EOF
    chmod 600 "${LAB_NETPLAN_FILE}"
    netplan generate
    netplan apply
}

apply_networkd() {
    local iface="$1"
    log "aplicando con systemd-networkd en ${iface}"
    {
        printf '[Match]\nName=%s\n\n' "${iface}"
        printf '[Network]\nAddress=%s\nGateway=%s\n' "${LAB_ADDR}" "${LAB_GW}"
        for d in ${LAB_DNS}; do
            printf 'DNS=%s\n' "${d}"
        done
    } > "${LAB_NETWORKD_FILE}"
    chmod 644 "${LAB_NETWORKD_FILE}"
    systemctl restart systemd-networkd
}

# --- Revert paths -----------------------------------------------------------
revert_networkmanager() {
    if nmcli -t -f NAME connection show | grep -Fxq "${LAB_CONN}"; then
        nmcli connection down "${LAB_CONN}" >/dev/null 2>&1 || true
        nmcli connection delete "${LAB_CONN}" >/dev/null
        log "conexión NM '${LAB_CONN}' eliminada."
    else
        log "no había conexión NM '${LAB_CONN}'."
    fi
}

revert_netplan() {
    if [[ -f "${LAB_NETPLAN_FILE}" ]]; then
        rm -f "${LAB_NETPLAN_FILE}"
        netplan generate
        netplan apply
        log "archivo netplan '${LAB_NETPLAN_FILE}' eliminado."
    else
        log "no había archivo netplan '${LAB_NETPLAN_FILE}'."
    fi
}

revert_networkd() {
    if [[ -f "${LAB_NETWORKD_FILE}" ]]; then
        rm -f "${LAB_NETWORKD_FILE}"
        systemctl restart systemd-networkd
        log "archivo networkd '${LAB_NETWORKD_FILE}' eliminado."
    else
        log "no había archivo networkd '${LAB_NETWORKD_FILE}'."
    fi
}

# --- Main -------------------------------------------------------------------
main() {
    require_root
    require_disposable

    local stack iface
    stack="$(detect_stack)"
    iface="$(detect_iface)"
    log "stack=${stack}  iface=${iface}  addr=${LAB_ADDR}  gw=${LAB_GW}"

    case "${ACTION}" in
        --revert|revert)
            case "${stack}" in
                networkmanager)      revert_networkmanager ;;
                netplan:*)           revert_netplan ;;
                networkd)            revert_networkd ;;
                *)                   die "stack desconocido: ${stack}" ;;
            esac
            log "revert completado."
            ;;
        apply|"")
            case "${stack}" in
                networkmanager)      apply_networkmanager "${iface}" ;;
                netplan:*)           apply_netplan "${iface}" "${stack#netplan:}" ;;
                networkd)            apply_networkd "${iface}" ;;
                *)                   die "stack desconocido: ${stack}" ;;
            esac
            sleep 2
            ip -br -c addr show "${iface}"
            ip route | grep -E '^default' || log "aviso: no veo default route todavía"
            log "apply completado."
            ;;
        *)
            die "acción desconocida: ${ACTION}"
            ;;
    esac
}

main "$@"
