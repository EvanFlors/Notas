# Módulo 02 — Networking: Protocolos de Transporte

## Propósito

Cada request HTTP viaja sobre TCP (o QUIC). Sin entender la capa de transporte, no puedes diagnosticar latencia, pérdida de paquetes, retransmisiones ni problemas de conexión entre microservicios.

## Relevancia en producción

- Diagnosticar por qué un servicio tarda: ¿es DNS? ¿TCP handshake? ¿retransmisiones?
- Configurar timeouts y keep-alives correctamente
- Entender por qué HTTP/3 usa UDP en vez de TCP
- Capturar y analizar tráfico con tcpdump/Wireshark para debugging

## Temas

| Archivo | Tema | Conceptos clave |
|---------|------|-----------------|
| 2.1 | Modelos de red | OSI vs TCP/IP, encapsulación, multiplexing |
| 2.2 | Internet Protocol (IP) | IPv4/IPv6, routing, CIDR, ARP, ICMP, fragmentación |
| 2.3 | UDP | Datagrama, connectionless, casos de uso (DNS, QUIC) |
| 2.4 | TCP | Handshake, flow/congestion control, estados, sockets, kernel queues |
| 2.5 | Captura y análisis de tráfico | tcpdump, Wireshark, diagnóstico de retransmisiones |

## Dependencias

```
Módulo 1 (OS: sockets, file descriptors, syscalls)
    │
    ▼
Módulo 2 (Networking) ──► Módulo 3 (HTTP sobre TCP/UDP)
                      ──► Módulo 4 (TLS sobre TCP)
```
