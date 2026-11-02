# Recursos — sys-10

## Man pages (lectura obligada)

- **`ip(8)`** — <https://man7.org/linux/man-pages/man8/ip.8.html>
- **`ip-link(8)`** — <https://man7.org/linux/man-pages/man8/ip-link.8.html>
- **`ip-address(8)`** — <https://man7.org/linux/man-pages/man8/ip-address.8.html>
- **`ip-route(8)`** — <https://man7.org/linux/man-pages/man8/ip-route.8.html>
- **`ip-neighbour(8)`** — <https://man7.org/linux/man-pages/man8/ip-neighbour.8.html>
- **`ss(8)`** — <https://man7.org/linux/man-pages/man8/ss.8.html>
- **`tcpdump(1)`** — <https://man7.org/linux/man-pages/man1/tcpdump.1.html>
- **`pcap-filter(7)`** (sintaxis de filtros BPF) — <https://man7.org/linux/man-pages/man7/pcap-filter.7.html>
- **`nsswitch.conf(5)`** — <https://man7.org/linux/man-pages/man5/nsswitch.conf.5.html>
- **`resolv.conf(5)`** — <https://man7.org/linux/man-pages/man5/resolv.conf.5.html>

## NetworkManager

- **`nmcli(1)`** — <https://networkmanager.dev/docs/api/latest/nmcli.html>
- **NetworkManager docs (root)** — <https://networkmanager.dev/docs/>
- **`nm-settings(5)`** (todas las keys que puedes `modify`) — <https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html>

## netplan (Ubuntu)

- **Netplan reference** — <https://netplan.readthedocs.io/en/stable/>
- **Netplan YAML syntax** — <https://netplan.readthedocs.io/en/stable/netplan-yaml/>
- **Renderers (networkd vs NetworkManager)** — <https://netplan.readthedocs.io/en/stable/explanation/#default-renderer>

## systemd-networkd / resolved

- **`systemd.network(5)`** — <https://www.freedesktop.org/software/systemd/man/latest/systemd.network.html>
- **`networkctl(1)`** — <https://www.freedesktop.org/software/systemd/man/latest/networkctl.html>
- **`systemd-resolved(8)`** — <https://www.freedesktop.org/software/systemd/man/latest/systemd-resolved.service.html>
- **`resolvectl(1)`** — <https://www.freedesktop.org/software/systemd/man/latest/resolvectl.html>
- **`resolved.conf(5)`** — <https://www.freedesktop.org/software/systemd/man/latest/resolved.conf.html>

## DNS

- **BIND / `dig(1)`** — <https://man7.org/linux/man-pages/man1/dig.1.html>
- **ISC BIND docs** — <https://bind9.readthedocs.io/en/latest/>
- **RFC 1034/1035** (DNS fundacional) — <https://www.rfc-editor.org/rfc/rfc1034>, <https://www.rfc-editor.org/rfc/rfc1035>
- **RFC 5737** (TEST-NETs, útiles para labs) — <https://www.rfc-editor.org/rfc/rfc5737>

## TLS y certificados

- **`openssl s_client(1)`** — <https://docs.openssl.org/master/man1/openssl-s_client/>
- **`openssl x509(1)`** — <https://docs.openssl.org/master/man1/openssl-x509/>
- **badssl.com** (galería de certificados "rotos" para pruebas) — <https://badssl.com/>

## netfilter / nftables (introductorio; se profundiza en `sys-12`)

- **nftables wiki** — <https://wiki.nftables.org/wiki-nftables/index.php/Main_Page>
- **`nft(8)`** — <https://man7.org/linux/man-pages/man8/nft.8.html>

## Namespaces de red

- **`ip-netns(8)`** — <https://man7.org/linux/man-pages/man8/ip-netns.8.html>
- **`network_namespaces(7)`** — <https://man7.org/linux/man-pages/man7/network_namespaces.7.html>

## Lectura larga (opcional pero recomendado)

- **"TCP/IP Illustrated, Volume 1"**, W. Richard Stevens / Kevin Fall — libro de referencia.
- **"Linux Networking Cookbook"**, Carla Schroder.
- **Julia Evans — zines de networking** — <https://wizardzines.com/> (resúmenes visuales excelentes).

## Nota de verificación

Última verificación de enlaces: pendiente de validar en Fase 4 (lecciones ejecutables). Todos los enlaces son dominios oficiales (`man7.org`, `freedesktop.org`, `networkmanager.dev`, `netplan.readthedocs.io`, `docs.openssl.org`, `rfc-editor.org`, `wiki.nftables.org`); verificar fecha y disponibilidad al momento de desarrollar el curso en producción.
