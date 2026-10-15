# Recursos — `dkr-05-networking-basics`

> Verificar fecha de consulta. Las rutas de `docs.docker.com` cambian ocasionalmente.

## Documentación oficial de Docker

- **Networking overview** — mapa general de drivers y modelos. <https://docs.docker.com/network/>
- **Bridge network driver** — default + user-defined; DNS embebido. <https://docs.docker.com/network/drivers/bridge/>
- **Host network driver** — qué comparte, qué pierde, caveats por plataforma. <https://docs.docker.com/network/drivers/host/>
- **None network driver** — sandbox hermético. <https://docs.docker.com/network/drivers/none/>
- **Macvlan network driver** — contenedores como hosts L2 propios. <https://docs.docker.com/network/drivers/macvlan/>
- **Container networking (publishing)** — `-p`, `-P`, binding por interfaz. <https://docs.docker.com/network/#published-ports>
- **Packet filtering and firewalls** — qué hace Docker con `iptables`. <https://docs.docker.com/network/packet-filtering-firewalls/>
- **Networking in Docker Desktop** — comportamiento específico Mac/Windows, `host.docker.internal`. <https://docs.docker.com/desktop/networking/>

## Kernel Linux (para entender qué hay debajo)

- **network_namespaces(7)** — man page sobre net namespaces. <https://man7.org/linux/man-pages/man7/network_namespaces.7.html>
- **veth(4)** — veth pairs. <https://man7.org/linux/man-pages/man4/veth.4.html>
- **bridge(8)** — bridges Linux. <https://man7.org/linux/man-pages/man8/bridge.8.html>
- **iptables(8)** — tablas y cadenas. <https://man7.org/linux/man-pages/man8/iptables.8.html>
- **nftables Wiki** — sucesor de iptables; `iptables` en kernels modernos vive sobre nf_tables. <https://wiki.nftables.org/>

## Herramientas de diagnóstico

- **nicolaka/netshoot** — imagen con `ip`, `ss`, `tcpdump`, `dig`, `curl`, `iptables`, `nmap`, etc. <https://github.com/nicolaka/netshoot>
- **ctop** — top-like para contenedores con métricas de red por contenedor. <https://github.com/bcicen/ctop>
- **tcpdump** — captura dentro del namespace (`docker run --rm --net container:<c> nicolaka/netshoot tcpdump -i eth0`). <https://www.tcpdump.org/>

## Lectura complementaria

- **Deep dive into Docker Networking** — artículo clásico sobre bridges, iptables, overlay. <https://neuvector.com/network-security/docker-networking/>
- **The container networking landscape** (CNI / CNM) — contexto para entender por qué Kubernetes usa otra abstracción. <https://kubernetes.io/docs/concepts/cluster-administration/networking/>
- **Jérôme Petazzoni — "Container networking"** (slides/talks) — material pedagógico de uno de los primeros ingenieros de Docker. <https://jpetazzo.github.io/>

## En este curso

- Previo: `dkr-02-install-engine-and-first-container`.
- Siguiente: `dkr-06-dockerfile-idiomatic-and-caching`.
- Compose networks (una red por proyecto, DNS por servicio): `dkr-08-compose-for-development`.
- Hardening de red del runtime (`--cap-drop=NET_RAW`, `--network=none`, egress policies): `dkr-13-runtime-security-and-hardening`.
