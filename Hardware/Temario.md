```md
# Temario Teórico — Hardware de Computadoras y Dispositivos de Red

## Objetivo
Construir una comprensión profunda y formal de los componentes físicos de sistemas computacionales y de red, su funcionamiento interno y su impacto en sistemas backend (latencia, throughput, I/O, concurrencia).

---

# 1. Fundamentos de Electrónica Digital

## 1.1 Magnitudes eléctricas
- Voltaje (V)
- Corriente (I)
- Resistencia (R)
- Potencia (P)
- Ley de Ohm

## 1.2 Señales
- Señales analógicas vs digitales
- Ruido y tolerancia
- Frecuencia, periodo y duty cycle

## 1.3 Lógica booleana
- Álgebra booleana
- Puertas lógicas (AND, OR, NOT, XOR, NAND, NOR)
- Tablas de verdad

## 1.4 Circuitos secuenciales
- Flip-flops (SR, D, JK)
- Latches
- Registros
- Contadores

## 1.5 Representación de datos
- Sistema binario
- Complemento a 2
- Codificación (ASCII, Unicode)
- Endianness

---

# 2. Arquitectura de Computadoras

## 2.1 Modelos arquitectónicos
- Arquitectura de Von Neumann
- Arquitectura Harvard
- Separación memoria-instrucciones

## 2.2 Ciclo de instrucción
- Fetch
- Decode
- Execute
- Memory access
- Write-back

## 2.3 Pipeline
- Concepto de pipeline
- Etapas
- Hazards:
  - Data hazards
  - Control hazards
  - Structural hazards

## 2.4 Paralelismo
- Instruction-Level Parallelism (ILP)
- Data-Level Parallelism (SIMD)
- Thread-Level Parallelism (TLP)

---

# 3. CPU (Unidad Central de Procesamiento)

## 3.1 Componentes internos
- ALU (Arithmetic Logic Unit)
- FPU (Floating Point Unit)
- Unidad de control
- Registros (generales y especiales)

## 3.2 Microarquitectura
- Decodificación de instrucciones
- Ejecución fuera de orden (Out-of-Order)
- Reorder buffer

## 3.3 Branch Prediction
- Predicción estática
- Predicción dinámica
- Impacto en rendimiento

## 3.4 Multicore y multithreading
- Núcleos físicos vs lógicos
- SMT (Simultaneous Multithreading)
- Hyper-threading

## 3.5 Métricas de rendimiento
- Clock frequency
- IPC (Instructions per Cycle)
- CPI (Cycles per Instruction)

---

# 4. Jerarquía de Memoria

## 4.1 Niveles
- Registros
- Cache (L1, L2, L3)
- Memoria principal (RAM)
- Almacenamiento secundario

## 4.2 Cache
- Localidad temporal y espacial
- Políticas:
  - Write-through
  - Write-back
- Replacement policies (LRU, FIFO)

## 4.3 Coherencia de cache
- Protocolos (MESI)
- Cache coherence problem

## 4.4 Memoria principal
- DRAM vs SRAM
- Latencia vs ancho de banda

## 4.5 Memoria virtual
- Paginación
- Segmentación
- Page faults

## 4.6 TLB (Translation Lookaside Buffer)
- Traducción de direcciones
- TLB hit/miss

## 4.7 NUMA
- Acceso no uniforme a memoria
- Afinidad de memoria

---

# 5. Almacenamiento

## 5.1 Tipos
- HDD (Hard Disk Drive)
- SSD (Solid State Drive)
- NVMe (Non-Volatile Memory Express)

## 5.2 Internals HDD
- Platos, cabezales
- Seek time
- Rotational latency

## 5.3 Internals SSD
- NAND Flash
- Wear leveling
- Garbage collection
- Write amplification

## 5.4 Interfaces
- SATA
- PCIe
- NVMe protocol

## 5.5 Sistemas de archivos
- Inodos
- Bloques
- Journaling

## 5.6 RAID
- RAID 0, 1, 5, 10
- Redundancia vs rendimiento

---

# 6. Buses e Interconexión

## 6.1 Tipos de buses
- Bus de datos
- Bus de direcciones
- Bus de control

## 6.2 Interconexiones modernas
- PCIe lanes
- Topología de interconexión

## 6.3 DMA
- Transferencias sin CPU
- Uso en dispositivos de alto rendimiento

## 6.4 Interrupciones
- Hardware interrupts
- Interrupt controllers (APIC)

---

# 7. Hardware de Red

## 7.1 NIC (Network Interface Card)
- Dirección MAC
- Buffers RX/TX
- Offloading:
  - Checksum offload
  - TCP segmentation offload (TSO)
- Interrupt coalescing

## 7.2 Ethernet
- Frame structure
- MTU (Maximum Transmission Unit)
- Switching básico

## 7.3 Switches
- Switching de capa 2
- Tablas MAC
- Forwarding
- VLANs

## 7.4 Routers
- Routing table
- Forwarding plane vs control plane
- NAT (Network Address Translation)

## 7.5 Load Balancers
- Capa 4 (L4)
- Capa 7 (L7)

## 7.6 Firewalls
- Packet filtering
- Stateful inspection

---

# 8. Hardware en Datacenters

## 8.1 Tipos de servidores
- Rack servers
- Blade servers

## 8.2 Redundancia
- Power Supply Units (PSU)
- RAID
- Network redundancy

## 8.3 Topologías de red
- Fat-tree
- Clos network
- Spine-leaf

---

# 9. Performance y Bottlenecks

## 9.1 Métricas
- Latencia
- Throughput
- IOPS

## 9.2 Bottlenecks
- CPU-bound
- Memory-bound
- IO-bound

## 9.3 Principios
- Ley de Amdahl
- Ley de Little

---

# 10. Interacción Hardware-Software

## 10.1 Camino de datos
- NIC → Kernel → User space → CPU → Memoria → Disco

## 10.2 Syscalls relevantes
- read()
- write()
- send()
- recv()
- accept()

## 10.3 Buffers
- Kernel buffers
- User buffers

## 10.4 Zero-copy
- sendfile()
- mmap()

## 10.5 Kernel bypass
- DPDK
- RDMA

---

# 11. Hardware Avanzado

## 11.1 GPUs
- Arquitectura masivamente paralela
- CUDA / OpenCL

## 11.2 SmartNICs
- Offloading programable

## 11.3 FPGAs
- Reconfigurabilidad
- Uso en networking

## 11.4 ASICs
- Chips especializados (switching de alta velocidad)

---

# 12. Modelo Mental Integrado

## 12.1 Flujo de ejecución
Cliente → NIC → Kernel → CPU → RAM → Disco → Respuesta

## 12.2 Principios clave
- La latencia depende de la jerarquía de memoria
- El throughput depende del paralelismo
- El networking depende del NIC + kernel + protocolos
- El almacenamiento determina persistencia y durabilidad