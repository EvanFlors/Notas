# Módulo 06 — Buses e Interconexión

## Propósito

Comprender cómo los componentes de una computadora se comunican entre sí a través de buses (datos, direcciones, control), interconexiones modernas como PCIe, mecanismos de transferencia directa (DMA), y el sistema de interrupciones que permite a los dispositivos notificar a la CPU.

## Temas

| # | Archivo | Tema |
|---|---------|------|
| 6.1 | `6.1_Tipos_de_Buses.md` | Bus de datos, de direcciones, de control |
| 6.2 | `6.2_Interconexiones_Modernas.md` | PCIe lanes, topología de interconexión |
| 6.3 | `6.3_DMA.md` | Direct Memory Access, transferencias sin CPU |
| 6.4 | `6.4_Interrupciones.md` | Hardware interrupts, interrupt controllers (APIC) |

## Dependencias

- Módulo 03 (CPU como destino de interrupciones)
- Módulo 04 (memoria como destino de DMA)

## Conexión con el sistema

Los buses son las autopistas del sistema. El ancho de banda de PCIe determina la velocidad máxima de GPUs, NVMe, y NICs. DMA permite que dispositivos transfieran datos a RAM sin involucrar la CPU, liberándola para cómputo. Las interrupciones determinan la latencia de respuesta a eventos de I/O. Sin entender buses e interrupciones, no se puede diagnosticar por qué una NIC de 100Gbps no alcanza su throughput teórico.
