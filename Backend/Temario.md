# 🧠 Backend Engineering — Temario Completo

## Objetivo

Dominar la ingeniería backend desde los fundamentos del sistema operativo hasta sistemas distribuidos en producción. Cada módulo construye sobre el anterior.

---

## Mapa de dependencias

```
  ┌─────────────────────────────────────────────────────────────────┐
  │                    RUTA DE APRENDIZAJE                          │
  │                                                                 │
  │  Módulo 1: Fundamentos          Módulo 2: Redes (IP/UDP/TCP)    │
  │  (OS, procesos, memoria)        (protocolos de transporte)      │
  │         │                               │                       │
  │         └───────────┬───────────────────┘                       │
  │                     ▼                                           │
  │          Módulo 3: HTTP & Protocolos de Aplicación              │
  │                     │                                           │
  │          Módulo 4: Seguridad & TLS                              │
  │                     │                                           │
  │         ┌───────────┼───────────────────┐                       │
  │         ▼           ▼                   ▼                       │
  │  Módulo 5:    Módulo 6:          Módulo 7:                      │
  │  Comunicación Backend            Proxies &                      │
  │  Patterns     Execution          Load Balancing                 │
  │         │           │                   │                       │
  │         └───────────┼───────────────────┘                       │
  │                     ▼                                           │
  │          Módulo 8: Bases de Datos & Persistencia                │
  │                     │                                           │
  │          Módulo 9: Arquitectura Backend                         │
  │                     │                                           │
  │         ┌───────────┼───────────┐                               │
  │         ▼           ▼           ▼                               │
  │  Módulo 10:  Módulo 11:  Módulo 12:                             │
  │  Seguridad   Observa-    Testing &                              │
  │  Backend     bilidad     Performance                            │
  │         │           │           │                               │
  │         └───────────┼───────────┘                               │
  │                     ▼                                           │
  │          Módulo 13: Sistemas Distribuidos                       │
  │                     │                                           │
  │          Módulo 14: Infraestructura & DevOps                    │
  └─────────────────────────────────────────────────────────────────┘
```

---

# Módulo 1 — Sistemas Operativos y Fundamentos

> Sin entender cómo funciona la máquina debajo, no puedes optimizar ni debuggear lo que corre encima.

## 1.1 Arquitectura de computadoras

- CPU: ALU, registros, pipeline, caches L1/L2/L3
- Jerarquía de memoria: registros → cache → RAM → disco
- Interrupciones (hardware vs software)
- DMA (Direct Memory Access) — I/O sin involucrar la CPU
- Bus de sistema y latencias reales (ns → ms)

## 1.2 Procesos e hilos

- Proceso: espacio de memoria aislado, PCB (Process Control Block)
- Hilo: unidad de ejecución dentro de un proceso, TCB (Thread Control Block)
- Context switching: costo real (guardar/restaurar registros, TLB flush)
- User-space threads vs kernel threads
- Green threads y coroutines (Go goroutines, Python asyncio)

## 1.3 Memoria

- Stack vs Heap: qué va en cada uno y por qué
- Memory allocation: `malloc`/`free` vs Garbage Collection
- Virtual memory: por qué cada proceso "ve" su propia memoria
- Paging: pages, page tables, page faults
- Segmentation
- TLB (Translation Lookaside Buffer): cache de traducciones virtuales → físicas
- Memory-mapped files (mmap)

## 1.4 Kernel y system calls

- System calls: interfaz entre user space y kernel space
- Syscalls clave para backend: `read`, `write`, `accept`, `socket`, `bind`, `listen`, `connect`, `close`, `fork`, `exec`
- File descriptors: todo es un archivo (sockets, pipes, archivos, dispositivos)
- Buffers de kernel: cómo el kernel almacena datos antes de entregarlos

## 1.5 CPU scheduling

- Algoritmos: FIFO, Round Robin, Priority-based, CFS (Completely Fair Scheduler)
- Preemption: cuándo el OS interrumpe un proceso
- Starvation y priority inversion
- CPU affinity y NUMA

## 1.6 Modelos de I/O y concurrencia

- **Blocking I/O**: el hilo se bloquea hasta que hay datos
- **Non-blocking I/O**: retorna inmediatamente (EAGAIN)
- **I/O Multiplexing**: `select`, `poll`, `epoll` (Linux), `kqueue` (macOS/BSD)
- **Async I/O**: `io_uring` (Linux moderno)
- **Event loops**: modelo de Node.js, Nginx, Envoy
- `epoll` vs `kqueue`: edge-triggered vs level-triggered

## 1.7 CLI y entorno

- Shell: bash/zsh, scripting básico
- Gestión de procesos: `ps`, `top`, `htop`, `kill`, `nohup`
- Variables de entorno y configuración
- Permisos Unix (users, groups, chmod, chown)
- Herramientas: `strace`/`dtrace`, `lsof`, `ss`, `netstat`

---

# Módulo 2 — Networking: Protocolos de Transporte

> Cada request HTTP es TCP (o QUIC). Sin entender la capa de transporte, no puedes diagnosticar latencia, pérdida de paquetes, ni problemas de conexión.

## 2.1 Modelos de red

- Modelo OSI (7 capas) vs TCP/IP (4 capas)
- Encapsulación: cómo cada capa envuelve los datos de la superior
- Multiplexing vs Demultiplexing (puertos)

## 2.2 Internet Protocol (IP)

- IP packet: header fields (TTL, protocol, source/dest, checksum)
- IPv4 vs IPv6
- Subnetting y CIDR notation
- Routing básico: cómo los paquetes llegan a su destino
- Fragmentación y Path MTU Discovery
- ARP: resolución IP → MAC address (ARP cache, ARP poisoning)
- ICMP: mensajes de control (PING, traceroute)

## 2.3 UDP (User Datagram Protocol)

- Estructura del datagrama UDP (header mínimo: 8 bytes)
- Características: connectionless, no ordering, no reliability
- Pros: bajo overhead, baja latencia
- Cons: sin retransmisión, sin control de flujo
- Casos de uso: DNS, VoIP, streaming, gaming, QUIC
- Packet loss y reordering en la práctica

## 2.4 TCP (Transmission Control Protocol)

- TCP segment: header, flags (SYN, ACK, FIN, RST, PSH, URG)
- **3-way handshake**: SYN → SYN-ACK → ACK
- **4-way teardown**: FIN → ACK → FIN → ACK
- **Flow Control**: sliding window, receiver window (rwnd)
- **Congestion Control**: slow start, congestion avoidance, fast retransmit, fast recovery
- Retransmissions: RTO, duplicate ACKs
- **TCP connection states**: LISTEN, SYN_SENT, SYN_RCVD, ESTABLISHED, FIN_WAIT_1/2, TIME_WAIT, CLOSE_WAIT, LAST_ACK, CLOSED
- NAT (Network Address Translation) y port mapping
- **Sockets**: la API real de programación de red (`socket`, `bind`, `listen`, `accept`, `connect`, `send`, `recv`)
- **Kernel queues**: SYN backlog (half-open connections), accept queue (completed connections)

## 2.5 Captura y análisis de tráfico

- `tcpdump`: captura de IP, ARP, ICMP, UDP, TCP
- Filtros: por puerto, host, protocolo
- Wireshark: análisis visual, seguimiento de streams
- Diagnóstico: retransmisiones, TCP zero window, slow connections
- Decrypting HTTPS en Wireshark (SSLKEYLOGFILE)

---

# Módulo 3 — HTTP y Protocolos de Aplicación

> HTTP es el idioma que habla tu API. Cada versión resuelve limitaciones de la anterior.

## 3.1 Fundamentos HTTP

- Request/Response model
- Anatomía de un request: method, URL, headers, body
- Methods: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS
- Status codes: 1xx (info), 2xx (success), 3xx (redirect), 4xx (client error), 5xx (server error)
- Headers esenciales: Content-Type, Authorization, Cache-Control, Accept, Host, User-Agent

## 3.2 Serialización de datos

- JSON: formato estándar, parsing, limitaciones (no schema, verbose)
- XML: legacy pero presente (SOAP)
- Protocol Buffers (Protobuf): schema tipado, binario, eficiente
- MessagePack: JSON binario, más compacto
- Cuándo usar cada uno (trade-offs)

## 3.3 Evolución de HTTP

- **HTTP/1.0**: una conexión por request
- **HTTP/1.1**: keep-alive, pipelining (roto en la práctica), head-of-line blocking
- **HTTP/2**: multiplexing de streams sobre una conexión TCP, compresión de headers (HPACK), server push
- **HTTP/3**: QUIC sobre UDP, elimina head-of-line blocking a nivel de transporte, 0-RTT
- Cuándo usar cada versión

## 3.4 Protocolos modernos de comunicación

- **WebSockets**: conexión persistente full-duplex sobre TCP, handshake HTTP upgrade
- **gRPC**: RPC sobre HTTP/2 con Protobuf, streaming bidireccional
- **WebRTC**: peer-to-peer, media streaming, data channels
- **Server-Sent Events (SSE)**: streaming unidireccional servidor → cliente

## 3.5 Propiedades de protocolos

- Stateful vs Stateless
- Full duplex vs Half duplex
- Reliable vs Unreliable
- Connection-oriented vs Connectionless

---

# Módulo 4 — Seguridad: TLS y Criptografía

> Todo tráfico en producción va sobre TLS. Entender el handshake te permite diagnosticar problemas de latencia, certificados y seguridad.

## 4.1 Criptografía aplicada

- Symmetric encryption: AES (rápido, para datos en tránsito)
- Asymmetric encryption: RSA, ECDSA (para intercambio de claves)
- Hashing: SHA-256, SHA-3 (integridad, no reversible)
- HMAC: hash + clave secreta (autenticación de mensajes)
- Key derivation: PBKDF2, bcrypt, scrypt, Argon2

## 4.2 TLS (Transport Layer Security)

- TLS 1.2: handshake de 2 round-trips (ClientHello → ServerHello → KeyExchange → Finished)
- TLS 1.3: handshake de 1 round-trip, forward secrecy obligatorio
- Certificados X.509: estructura, cadena de confianza, CA
- PKI (Public Key Infrastructure)
- Certificate pinning
- mTLS (mutual TLS): autenticación bidireccional

## 4.3 Rutas de HTTPS (deep networking)

- HTTPS over TCP + TLS 1.2: 3 RTT total (TCP + TLS)
- HTTPS over TCP + TLS 1.3: 2 RTT total
- HTTPS over QUIC (HTTP/3): 1 RTT (o 0-RTT con session resumption)
- TCP Fast Open: datos en el SYN
- Comparación de latencia real entre las tres rutas

---

# Módulo 5 — Backend Communication Patterns

> No todo es request/response. Elegir el patrón correcto define la escalabilidad y la experiencia del usuario.

## 5.1 Request/Response

- Anatomía completa: parsing del request → routing → procesamiento → serialización → respuesta
- Content negotiation (Accept header)
- Chunked transfer encoding vs Content-Length

## 5.2 Synchronous vs Asynchronous

- Sync: el caller espera la respuesta
- Async: el caller no espera, recibe notificación después
- Blocking vs Non-blocking: ortogonal a sync/async
- Cuándo usar cada combinación

## 5.3 Patrones de comunicación en tiempo real

- **Short Polling**: cliente pregunta repetidamente (wasteful)
- **Long Polling**: servidor mantiene la conexión abierta hasta tener datos
- **Server-Sent Events (SSE)**: stream unidireccional, reconexión automática
- **WebSockets**: bidireccional full-duplex, baja latencia
- Push vs Pull: trade-offs de cada modelo
- Cuándo usar cada uno (chat, notificaciones, dashboards, trading)

## 5.4 Mensajería y eventos

- **Message queues**: RabbitMQ, SQS — punto a punto, garantías de entrega
- **Pub/Sub**: Kafka, Redis Pub/Sub — broadcasting a múltiples consumidores
- **Event-driven architecture**: eventos como fuente de verdad
- Dead letter queues, retry policies, backoff exponencial

## 5.5 Estado y sesiones

- Stateful vs Stateless backends
- Gestión de sesiones: cookies, tokens, sticky sessions
- Idempotency: por qué es crítica, idempotency keys
- Exactly-once vs at-least-once vs at-most-once delivery

## 5.6 Multiplexing y connection management

- HTTP/2 streams multiplexed
- Connection pooling: reutilizar conexiones TCP
- Kernel-level demultiplexing (puertos → sockets)

## 5.7 Sidecar Pattern

- Concepto: proxy adyacente al servicio (mismo pod/host)
- Service mesh: Istio, Linkerd
- Proxying: Envoy como sidecar
- Beneficios: observabilidad, mTLS, rate limiting sin modificar el código

---

# Módulo 6 — Backend Execution Patterns

> Cómo tu servidor acepta, lee, procesa y responde connections determina su rendimiento bajo carga.

## 6.1 Lifecycle de una request (dentro del servidor)

```
  Cliente
    │
    ▼
  Listener (socket en LISTEN)
    │
    ▼
  Acceptor (accept() → nuevo fd)
    │
    ▼
  Reader (read() del socket)
    │
    ▼
  Processor (lógica de negocio)
    │
    ▼
  Writer (write() al socket)
    │
    ▼
  Cliente recibe respuesta
```

## 6.2 Patrones de ejecución

- **Single thread blocking**: un hilo hace todo (simple, no escala)
- **Thread-per-connection**: un hilo por cliente (escalable hasta cierto punto, alto costo de memoria)
- **Thread pool**: N hilos fijos, cola de trabajo (balance entre recursos y throughput)
- **Event loop (async)**: un hilo con `epoll`/`kqueue`, no bloquea en I/O (Node.js, Nginx)
- **Reactor pattern**: event loop + dispatching a handlers
- **Proactor pattern**: async I/O + completion callbacks (Windows IOCP, `io_uring`)

## 6.3 Variaciones de arquitectura de servidor

- Single listener + single reader (trivial)
- Single listener + multiple readers (thread pool)
- Multiple acceptors (multiple threads/processes en el mismo socket)
- Socket sharding (SO_REUSEPORT): cada thread tiene su propia accept queue
- Pre-fork model (Apache prefork)

## 6.4 Optimización a nivel de kernel y TCP

- **Nagle's Algorithm**: agrega datos pequeños en un solo segmento (latencia vs throughput)
- **Delayed ACK**: espera antes de ACKear (interactúa mal con Nagle)
- **TCP_NODELAY**: desactiva Nagle (baja latencia para apps interactivas)
- **Zero-copy**: `sendfile()` — datos del disco al socket sin pasar por user space
- **Buffer tuning**: `SO_SNDBUF`, `SO_RCVBUF`, `tcp_wmem`, `tcp_rmem`
- **Backpressure**: qué pasa cuando el producer es más rápido que el consumer

---

# Módulo 7 — Proxies y Load Balancing

> Todo tráfico de producción pasa por al menos un proxy. Entender las capas te permite diagnosticar cuellos de botella.

## 7.1 Tipos de proxy

- **Forward proxy**: cliente → proxy → destino (VPN, corporate proxy)
- **Reverse proxy**: cliente → proxy → backend (Nginx, Envoy, HAProxy)
- Diferencia fundamental: quién controla el proxy

## 7.2 Load Balancing

- **Layer 4 (TCP)**: basado en IP + puerto, no inspecciona contenido (rápido, simple)
- **Layer 7 (HTTP)**: basado en URL, headers, cookies (flexible, más costoso)
- Algoritmos: Round Robin, Least Connections, IP Hash, Weighted, Random
- Health checks: active vs passive
- Session persistence (sticky sessions): cuándo usarlas y sus problemas

## 7.3 Casos especiales

- WebSocket proxying: upgrade de conexión, sticky sessions necesarias
- gRPC proxying: requiere L7 con soporte HTTP/2
- SSL/TLS termination vs passthrough vs re-encryption

## 7.4 Herramientas

- Nginx: reverse proxy + web server + load balancer
- HAProxy: especializado en load balancing de alto rendimiento
- Envoy: proxy L7 moderno, base de service meshes
- Traefik: auto-discovery con Docker/K8s

---

# Módulo 8 — Bases de Datos y Persistencia

> Los datos son el activo más valioso. Elegir la base correcta y entender sus internals define la escalabilidad.

## 8.1 Modelos de datos

- **Relacional** (PostgreSQL, MySQL): tablas, SQL, ACID, joins
- **Key-Value** (Redis, DynamoDB): ultra rápido, datos simples
- **Document** (MongoDB, CouchDB): JSON/BSON, schema flexible
- **Wide-Column** (Cassandra, HBase): escrituras masivas, distribuido
- **Graph** (Neo4j): relaciones complejas, traversals
- **Time-Series** (InfluxDB, TimescaleDB): datos temporales, métricas
- Cuándo usar cada uno (decision tree)

## 8.2 Internals de bases de datos

- **B-Trees**: estructura de índices en bases relacionales (lecturas rápidas)
- **LSM Trees** (Log-Structured Merge): escrituras rápidas, compactación (Cassandra, RocksDB)
- **WAL (Write-Ahead Log)**: durabilidad antes de escribir a disco
- **MVCC (Multi-Version Concurrency Control)**: lecturas sin bloqueo
- **Buffer pool / page cache**: cómo la DB cachea páginas en RAM

## 8.3 Transacciones

- ACID: Atomicity, Consistency, Isolation, Durability
- Isolation levels: Read Uncommitted, Read Committed, Repeatable Read, Serializable
- Locking: pessimistic (row locks, table locks) vs optimistic (versioning)
- Deadlocks: detección y prevención
- Distributed transactions: 2PC, Saga pattern

## 8.4 Indexación

- Tipos: B-Tree, Hash, GIN, GiST, BRIN
- Covering indexes, partial indexes, composite indexes
- Index scan vs sequential scan
- `EXPLAIN ANALYZE`: leer query plans

## 8.5 Escalabilidad de datos

- **Replication**: master-slave, master-master, sync vs async
- **Sharding**: horizontal partitioning por key (hash, range, directory)
- **Partitioning**: table partitioning dentro de una instancia
- Connection pooling: PgBouncer, ProxySQL

## 8.6 Caching

- **Redis**: in-memory key-value, data structures, pub/sub, TTL
- Cache patterns: cache-aside (lazy loading), write-through, write-behind, read-through
- Cache invalidation: el problema más difícil de CS
- CDN: caching geográfico para contenido estático
- Multi-level caching: CDN → reverse proxy → app cache → DB cache

---

# Módulo 9 — Arquitectura Backend

> La arquitectura es el trade-off entre simplicidad y escalabilidad. Empieza simple, evoluciona según la demanda real.

## 9.1 Estilos arquitectónicos

- **Monolito**: todo en un proceso — simple, rápido de desarrollar
- **Modular monolith**: monolito con boundaries claros entre módulos
- **Microservicios**: servicios independientes con sus propias DBs
- **Serverless**: funciones efímeras (Lambda, Cloud Functions)
- Progresión natural: monolito → modular → microservicios (si es necesario)

## 9.2 Componentes de infraestructura

- **API Gateway**: entry point, routing, auth, rate limiting (Kong, AWS API Gateway)
- **Load Balancer**: distribución de tráfico (L4/L7)
- **Service Discovery**: encontrar servicios dinámicamente (Consul, DNS, K8s services)
- **Service Mesh**: comunicación entre servicios (Istio, Linkerd)
- **Message Broker**: comunicación asíncrona (Kafka, RabbitMQ)

## 9.3 Resiliencia

- **Circuit Breaker**: detener llamadas a servicios fallidos (estados: closed → open → half-open)
- **Retry**: reintentos con exponential backoff + jitter
- **Timeout**: siempre poner timeouts (connect timeout + read timeout)
- **Bulkhead**: aislar recursos por servicio (thread pools separados)
- **Fallback**: respuesta degradada cuando falla un servicio
- **Graceful degradation**: mantener funcionalidad parcial

## 9.4 Rate limiting

- **Token bucket**: tokens se rellenan a tasa constante, cada request consume uno
- **Leaky bucket**: requests procesadas a tasa constante, exceso descartado
- **Fixed window vs Sliding window**: granularidad del conteo
- Rate limiting distribuido: Redis-based counters

## 9.5 API Design

- RESTful conventions
- Versioning: URL path vs header vs query param
- Pagination: offset vs cursor-based
- Error handling: formatos consistentes, error codes
- HATEOAS (opcional)

---

# Módulo 10 — Seguridad Backend

> La seguridad no es un feature — es un requisito. Cada capa necesita protección.

## 10.1 Autenticación y autorización

- **JWT**: estructura (header.payload.signature), access tokens + refresh tokens
- **OAuth 2.0**: authorization code flow, PKCE, client credentials
- **OpenID Connect**: identidad sobre OAuth 2.0
- **Session-based auth**: cookies HttpOnly, Secure, SameSite
- **API Keys**: simple pero limitado
- **mTLS**: autenticación mutua entre servicios

## 10.2 Vulnerabilidades comunes (OWASP Top 10)

- **SQL Injection**: prepared statements, parameterized queries
- **XSS** (Cross-Site Scripting): sanitización de output, CSP headers
- **CSRF** (Cross-Site Request Forgery): tokens CSRF, SameSite cookies
- **SSRF** (Server-Side Request Forgery): validación de URLs
- **Broken Access Control**: autorización en cada endpoint
- **Insecure Deserialization**: no deserializar input no confiable

## 10.3 Hardening

- TLS configuration: cipher suites, HSTS, certificate rotation
- Secrets management: Vault, AWS Secrets Manager, nunca en código
- Principle of least privilege
- Security headers: Content-Security-Policy, X-Frame-Options, etc.
- Input validation y sanitización en cada capa
- Dependency scanning (CVEs)

---

# Módulo 11 — Observabilidad

> No puedes arreglar lo que no puedes ver. Los tres pilares de la observabilidad son logs, métricas y traces.

## 11.1 Logs

- Structured logging: JSON logs con campos consistentes
- Log levels: DEBUG, INFO, WARN, ERROR, FATAL
- Correlation IDs: rastrear un request a través de múltiples servicios
- Centralización: ELK stack (Elasticsearch + Logstash + Kibana), Loki + Grafana
- Log rotation y retention

## 11.2 Métricas

- **RED method**: Rate, Errors, Duration (para servicios)
- **USE method**: Utilization, Saturation, Errors (para recursos)
- Tipos de métricas: counters, gauges, histograms, summaries
- Herramientas: Prometheus + Grafana
- SLI / SLO / SLA: definir y medir calidad de servicio

## 11.3 Distributed Tracing

- Concepto: seguir un request a través de múltiples servicios
- Span, trace, context propagation
- **OpenTelemetry**: estándar unificado (traces + metrics + logs)
- Herramientas: Jaeger, Zipkin, Tempo
- Sampling strategies: head-based vs tail-based

## 11.4 Profiling

- CPU profiling: flame graphs, hot paths
- Memory profiling: heap snapshots, leak detection
- Continuous profiling en producción (Pyroscope, Parca)

## 11.5 Herramientas de diagnóstico de red

- DevTools Networking: waterfall, timing breakdown (DNS, TLS, TTFB, download)
- `mitmproxy` / `mitmdump` / `mitmweb`: intercepción SSL, debugging de APIs
- Diagnóstico: slow DNS, slow TLS handshake, slow backend processing

---

# Módulo 12 — Testing y Performance

> El código sin tests es deuda técnica. El código sin benchmarks es una caja negra.

## 12.1 Estrategia de testing

- **Unit tests**: lógica aislada, mocks/stubs
- **Integration tests**: componentes reales (DB, API, queues)
- **Contract tests**: verificar interfaces entre servicios (Pact)
- **End-to-end tests**: flujo completo del usuario
- Testing pyramid: muchos unit, pocos e2e

## 12.2 Performance testing

- **Load testing**: comportamiento bajo carga esperada (k6, Locust, JMeter)
- **Stress testing**: encontrar el punto de quiebre
- **Soak testing**: estabilidad bajo carga sostenida (memory leaks)
- **Spike testing**: comportamiento ante picos súbitos
- Métricas clave: p50, p95, p99 latency, throughput, error rate

## 12.3 Chaos Engineering

- Principio: inyectar fallos controlados para validar resiliencia
- Fault injection: latencia, errores, particiones de red
- Herramientas: Chaos Monkey, Litmus, Gremlin
- Game days: ejercicios de equipo en entorno controlado

## 12.4 Network performance engineering

- MSS vs MTU vs Path MTU Discovery
- Handshake overhead: TCP + TLS latency budget
- Keep-alive vs new connections: cuándo reutilizar
- Head-of-line blocking: HTTP/1.1 vs HTTP/2 vs HTTP/3
- Impacto del proxy en latencia (cada hop suma)

---

# Módulo 13 — Sistemas Distribuidos

> En producción, tu backend no es un servidor — es una red de sistemas que deben coordinarse.

## 13.1 Fundamentos

- **CAP theorem**: Consistency, Availability, Partition tolerance (elige 2)
- **PACELC**: extensión de CAP (en caso de Partición: A o C; Else: Latency o Consistency)
- Modelos de consistencia: strong, eventual, causal, read-your-writes

## 13.2 Coordinación

- Leader election: Raft-based, lease-based
- Distributed locks: Redlock, ZooKeeper, etcd
- Distributed consensus: por qué es difícil (Byzantine Generals)

## 13.3 Algoritmos de consenso

- **Raft**: líder + log replication (etcd, Consul)
- **Paxos**: teórico, base de muchas implementaciones
- **PBFT**: tolerancia a faltas bizantinas (blockchain)

## 13.4 Mensajería distribuida

- **Kafka**: log distribuido, particiones, consumer groups, garantías de orden
- **RabbitMQ**: message broker AMQP, routing flexible
- Comparación: Kafka (event log) vs RabbitMQ (message queue)
- Event sourcing y CQRS

## 13.5 Escalabilidad real

- Horizontal scaling: stateless services + load balancer
- Data partitioning: consistent hashing, range partitioning
- Replication strategies: sync, async, semi-sync
- Global load balancing: GeoDNS, anycast

## 13.6 Patrones de sistemas distribuidos

- Saga pattern: transacciones distribuidas sin 2PC
- Outbox pattern: garantías de publicación de eventos
- Idempotency: retry safety en sistemas distribuidos
- Exactly-once delivery: por qué es casi imposible y cómo acercarse

---

# Módulo 14 — Infraestructura y DevOps

> El código que no está en producción no genera valor. La infraestructura es el puente.

## 14.1 Contenedores

- Docker internals: namespaces (PID, NET, MNT), cgroups (límites de recursos), overlay filesystem
- Dockerfile best practices: multi-stage builds, layers, caching
- Container networking: bridge, host, overlay

## 14.2 Orquestación

- Kubernetes: Pods, Deployments, Services, Ingress, ConfigMaps, Secrets
- Scheduling, auto-scaling (HPA/VPA), rolling updates
- Helm: package manager para K8s
- Operators: automatización de operaciones complejas

## 14.3 CI/CD

- Pipelines: build → test → deploy
- Deployment strategies: blue/green, canary, rolling update, feature flags
- GitOps: Git como fuente de verdad (ArgoCD, Flux)
- Infrastructure as Code: Terraform, Pulumi

## 14.4 Cloud

- Compute: VMs, containers, serverless
- Networking: VPC, subnets, security groups, load balancers
- Storage: block (EBS), object (S3), file (EFS)
- Managed services: RDS, ElastiCache, SQS, etc.

---

# 🔗 Modelo mental: anatomía de un request en producción

```
  Cliente (browser/app)
      │
      ├── DNS resolution (puede estar cacheado)
      │
      ├── TCP 3-way handshake (o QUIC 0/1-RTT)
      │
      ├── TLS handshake (1.2 = 2 RTT, 1.3 = 1 RTT, QUIC = 0 RTT)
      │
      ├── HTTP request (GET /api/users)
      │
      ▼
  CDN / Edge (cache hit? → responde directo)
      │
      ▼
  Load Balancer (L4 o L7)
      │ routing, health check
      ▼
  API Gateway
      │ auth, rate limit, routing
      ▼
  Reverse Proxy (Nginx/Envoy)
      │ TLS termination, compression
      ▼
  Backend Service
      │ accept() → read() → process → write()
      │
      ├── Cache (Redis) ← hit? → responde
      │
      ├── Database (PostgreSQL) ← query + index
      │
      ├── Message Queue (Kafka) ← evento async
      │
      └── Otro Microservicio (gRPC/HTTP)
            │
            └── ... (misma cadena)
      │
      ▼
  Response (mismo camino de regreso)
      │
      ▼
  Cliente recibe los datos
```

> 💡 **Cada capa agrega latencia**. Conocer cada eslabón te permite identificar exactamente dónde está el cuello de botella.
