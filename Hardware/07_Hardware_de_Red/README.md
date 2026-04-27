# Módulo 07 — Hardware de Red

## Propósito

Entender los dispositivos físicos que mueven paquetes a través de una red: NICs (con sus buffers y offloading), Ethernet como medio de transmisión, switches para forwarding L2, routers para forwarding L3, load balancers para distribución de tráfico, y firewalls para filtrado.

## Temas

| # | Archivo | Tema |
|---|---------|------|
| 7.1 | `7.1_NIC.md` | Dirección MAC, buffers RX/TX, offloading, interrupt coalescing |
| 7.2 | `7.2_Ethernet.md` | Frame structure, MTU, switching básico |
| 7.3 | `7.3_Switches.md` | Switching L2, tablas MAC, forwarding, VLANs |
| 7.4 | `7.4_Routers.md` | Routing table, forwarding/control plane, NAT |
| 7.5 | `7.5_Load_Balancers.md` | L4 vs L7, hardware vs software |
| 7.6 | `7.6_Firewalls.md` | Packet filtering, stateful inspection |

## Dependencias

- Módulo 06 (buses, DMA, interrupciones — la NIC usa todos)
- Módulo 03 (CPU — procesa paquetes)

## Conexión con el sistema

Cada request HTTP que llega a tu backend atraviesa NIC → kernel → CPU. La NIC con offloading reduce la carga de CPU. El switch determina el forwarding dentro del datacenter. El router conecta redes. El load balancer distribuye tráfico entre servidores. Entender el hardware de red explica por qué la latencia de red a veces no es "la red" sino la NIC o el kernel.
