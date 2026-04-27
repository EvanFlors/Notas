# Módulo 08 — Hardware en Datacenters

## Propósito

Comprender el hardware a escala de datacenter: tipos de servidores (rack, blade), mecanismos de redundancia (PSU, RAID, red), y las topologías de red que conectan miles de servidores con ancho de banda predecible.

## Temas

| # | Archivo | Tema |
|---|---------|------|
| 8.1 | `8.1_Tipos_de_Servidores.md` | Rack servers, blade servers |
| 8.2 | `8.2_Redundancia.md` | PSU redundantes, RAID, network redundancy |
| 8.3 | `8.3_Topologias_de_Red.md` | Fat-tree, Clos network, spine-leaf |

## Dependencias

- Módulo 05 (RAID, almacenamiento)
- Módulo 07 (switches, routers, NICs)

## Conexión con el sistema

Un backend en producción corre en un datacenter. La topología de red (spine-leaf) determina la latencia entre cualquier par de servidores. La redundancia de PSU y red determina el uptime. Entender el hardware del datacenter explica por qué "la red entre dos pods de K8s" tiene la latencia que tiene, y por qué un fallo de un top-of-rack switch puede afectar a cientos de servidores.
