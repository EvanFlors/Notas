# aws-07 — Lección: networking avanzado en AWS

> 10 secciones. Diseño + Terraform `plan` + ADR. **Sin aplicar** nada contra AWS real.

---

## 1. Punto de partida: la VPC ya la tienes

Vienes de `aws-03` con una VPC multi-AZ, subnets públicas y privadas, NAT Gateway, Gateway Endpoints para S3/DynamoDB y Security Groups con criterio. Ya sabes que el NAT es la fuente #1 de facturas sorpresa y que SGs son stateful. Lo que **no** sabes todavía:

1. Cómo **publicar** una app con TLS en un nombre bonito (`api.midominio.com`) sin tocar certificados a mano.
2. Cómo elegir **qué balanceador** usar — y por qué poner un ALB donde tocaba un NLB se paga en estabilidad y en facturas.
3. Cómo **conectar** 5 VPCs sin terminar con un spaghetti de peerings 5×4/2 = 10.
4. Cómo **exponer** un servicio interno a otra cuenta sin abrirlo a internet.
5. Cómo recortar el coste de NAT cambiándolo por **Interface Endpoints** cuando el egreso principal es a servicios AWS.

Este módulo responde las cinco.

---

## 2. ELB: ALB vs NLB vs GWLB

AWS ofrece tres balanceadores modernos bajo el paraguas "Elastic Load Balancing v2" (el *Classic Load Balancer* es legacy y no lo usamos). Cada uno vive en una capa distinta del modelo OSI y resuelve un problema distinto.

| Dimensión | ALB (Application) | NLB (Network) | GWLB (Gateway) |
|-----------|-------------------|---------------|----------------|
| Capa | L7 (HTTP/HTTPS/gRPC/WebSocket) | L4 (TCP, UDP, TLS) | L3 (IP) + GENEVE |
| Routing | Host, path, header, query, source IP | 5-tuple hash | Transparente — redirige a appliances |
| Static IP | No (DNS A/AAAA) | Sí (una por AZ, opcional **EIP**) | No (via endpoints) |
| TLS termination | Sí (ACM) | Sí (ACM) o passthrough | N/A (fluye L3) |
| mTLS cliente | Sí (desde 2023) | Sí (TLS termination + CA) | N/A |
| OIDC / Cognito auth | Sí (nativo) | No | No |
| WAF | Sí (directamente) | No (indirecto via CloudFront) | No |
| PrivateLink | No se expone directamente | **Sí** (es el único que publica Endpoint Services) | No |
| Target types | `instance`, `ip`, `lambda`, `alb` | `instance`, `ip`, `alb` | `instance`, `ip` |
| Precio base | LCU-horas (3 dim.) | NLCU-horas (bytes + conexiones nuevas) | GLCU-horas |
| Caso típico | APIs REST, websockets, web apps | gRPC pesado, bases ad-hoc, IP fija, PrivateLink | Firewall/IDS transparente |

> **Heurística:** si hablas HTTP, ALB. Si necesitas IP fija, UDP, TLS passthrough o PrivateLink, NLB. Si estás insertando un *appliance* (p. ej. una familia de firewalls de un vendor), GWLB.

Trampas frecuentes:

- Poner **ALB** porque "es más barato" y luego descubrir que necesitas IP fija para un cliente que whitelistaa IPs — rehacer la publicación.
- Poner **NLB** para una API HTTP solo porque "va más rápido" y perder host/path routing, WAF y OIDC.
- Olvidar que **ALB puede ser target de NLB** (desde 2021): te permite preservar la IP fija del NLB pero conservar las features L7 del ALB.

### Target groups y health checks

Un **target group** es un conjunto de destinos (instancias, IPs, lambdas) con un *health check* común. El LB manda tráfico solo a los targets `healthy`. Puntos finos:

- **Deregistration delay** (default 300 s): tiempo que el LB mantiene conexiones abiertas a un target `draining`. Si lo bajas, deployment rolling más rápido; si lo subes, menos *connection reset* a clientes.
- **Health check path** (ALB): debe devolver `200-399`; evita que apunte a `/` si `/` toca la DB — mejor `/healthz` liviano.
- **Slow start** (ALB): sube el peso del target gradualmente los primeros N segundos. Útil con JVMs con JIT caliente.

---

## 3. ACM: certificados sin dolor

**AWS Certificate Manager** emite certificados **públicos gratis** (DV) y los **rota automáticamente**. Validación por **DNS** (recomendada: añades un `CNAME` que ACM te da; funciona siempre, no requiere acceso al email del dominio) o por **email** (hereda del dominio).

Reglas de oro:

1. **Un certificado por región donde lo uses.** No existe un cert "global". Para ALB → cert en la región del ALB. Para CloudFront → cert **en `us-east-1`** (único caso especial).
2. **SANs** (Subject Alternative Names) incluyen hasta ~10 nombres sin coste extra. Usa esto para `midominio.com` + `*.midominio.com` + `api.midominio.com` en un solo cert.
3. **Validación DNS automatizable con Route 53**: `aws_acm_certificate_validation` + `aws_route53_record` crea el CNAME y espera a que ACM lo vea.
4. ACM **no** emite certs para dominios que no controles (prueba de posesión obligatoria). Si tu dominio está en otro DNS, igual sirve, pero tú metes el CNAME a mano.

### Private CA (opcional)

**ACM Private CA** emite certificados internos (para TLS entre microservicios en VPC). Cuesta ~$400/mes solo por tenerla encendida — no para labs.

---

## 4. Route 53: DNS como herramienta de arquitectura

Route 53 es un DNS autoritativo con *routing policies* más allá de un `A record`:

| Policy | Usa cuándo |
|--------|------------|
| Simple | Un solo valor, caso base. |
| Weighted | A/B testing, canary (10 % a `v2`, 90 % a `v1`). |
| Latency | Cliente va al endpoint con menor latencia hacia la región. |
| Geolocation | Cumplimiento regulatorio ("usuarios de EU van a EU"). |
| Geoproximity | Como latency pero con *bias* configurable (Traffic Flow). |
| Failover | Primary + secondary con health check. |
| Multivalue answer | Devuelve hasta 8 IPs sanas, cliente elige (poor-man's LB). |

### Hosted zones

- **Pública** — resuelve desde internet.
- **Privada** — asociada a una o más VPCs, solo resuelve dentro de ellas. Útil para `db.internal.midominio.com`.
- Una **misma zona** no puede ser pública y privada; se solapan con nombres distintos o con *split-horizon* usando una pública en el apex y privada para `internal.`.

### Alias records

Un **alias** es un tipo propio de Route 53 que **apunta a un recurso AWS** (ALB, NLB, CloudFront, S3 website, otra zona Route 53) resolviendo a su IP(s) actuales **sin cobrar** por la query. Equivale a un CNAME pero:

- Puede vivir en el **apex** (algo que un CNAME no puede: no se puede `CNAME` el apex por RFC).
- Es **gratis** (los queries alias no se cobran si apuntan a un recurso AWS).
- Se actualiza solo cuando AWS cambia las IPs del ALB.

> **Regla:** para apuntar a un ALB/NLB/CloudFront, siempre **alias**, nunca `CNAME`.

---

## 5. Conectividad multi-VPC: peering, Transit Gateway, Cloud WAN

### VPC Peering

Enlace **1:1** entre dos VPCs (misma o distinta cuenta/región). Non-transitive: si A↔B y B↔C, A **no** habla con C. Barato (solo pagas tráfico), pero no escala.

Fórmula: N VPCs totalmente malladas → **N·(N-1)/2** peerings. Con 10 VPCs, 45 peerings y 45 route-tables tocadas. Operación insostenible.

### Transit Gateway (TGW)

Un **hub** regional. Cada VPC se "attachea" al TGW (una vez). El TGW tiene *route tables* propias; decides qué attachment ve qué prefijo. Beneficios:

- Topología **hub-and-spoke** con N attachments en lugar de N² peerings.
- **Attachments** no solo de VPC: también VPN, Direct Connect, otro TGW (peering TGW-to-TGW inter-región).
- **Segmentación**: múltiples TGW route tables te permiten "producción no habla con dev" sin SGs.

Coste real: **$0.05/attachment-hora** + **$0.02/GB** procesado (US regions, orientativo). Con 10 attachments: ~$360/mes solo por existir. Para labs, **plan + diseño**, nada de apply.

### Cloud WAN

Capa encima de TGW multi-región con *segmentos* globales y políticas declarativas. Útil a escala enterprise multi-región; fuera del alcance operativo de este módulo (se menciona para que no te sorprenda en una entrevista).

### Direct Connect y Site-to-Site VPN

- **VPN**: túneles IPsec sobre internet. Dos túneles por conexión para HA. Barato (~$0.05/h/túnel).
- **Direct Connect (DX)**: fibra dedicada al PoP de AWS. Latencia predecible, ancho de banda garantizado, caro. Combinable con TGW vía *DX Gateway*.

Ambos se **attachean al TGW** si tienes topología hub-and-spoke.

---

## 6. PrivateLink: exponer servicios sin internet

PrivateLink convierte un servicio **detrás de un NLB** en un endpoint consumible desde otras VPCs/cuentas vía **Interface Endpoint**. El consumidor ve una ENI con IP privada en su propia subnet; AWS maneja el *túnel* por su red interna.

Arquitectura mínima:

```
Productor (cuenta A)                    Consumidor (cuenta B)
┌────────────────────────┐              ┌────────────────────────┐
│  App ──► NLB ──► TG    │              │  Cliente ──► ENI (VPCE)│
│          │             │              │                 │      │
│          ▼             │ PrivateLink  │                 ▼      │
│  Endpoint Service ─────┼──────────────┼──► Interface Endpoint  │
│  (allowed_principals:  │   (red       │     (DNS: svc-xyz      │
│   arn:aws:iam::B:root) │    interna)  │      .vpce.amazonaws)  │
└────────────────────────┘              └────────────────────────┘
```

Por qué importa:

- **No pasa por internet.** No hay IGW ni NAT en el camino.
- **No pasa por peering/TGW.** No necesitas abrir la VPC del consumidor a la del productor.
- **Pago por VPCE-hora y GB.** Más barato que NAT si consumes mucho de un servicio concreto.
- **Modelo de permisos explícito**: `allowed_principals` del Endpoint Service decide quién puede *descubrir* el servicio; la *aceptación* de la conexión puede ser manual (`acceptance_required = true`) o automática.

AWS mismo usa PrivateLink para publicar **Interface Endpoints** de sus servicios (Secrets Manager, Kinesis, SSM, ECS API, STS, etc.). Son los que usas desde una subnet privada para evitar que el tráfico a AWS salga por NAT.

---

## 7. Egress controlado y el cálculo NAT vs Interface Endpoint

Una subnet privada que necesita hablar con **servicios AWS** tiene tres opciones:

1. **NAT Gateway** → tráfico sale a internet, llega al endpoint público de AWS. Pagas NAT por hora + GB.
2. **Gateway Endpoint** (S3, DynamoDB) → gratis. Tráfico va por la red interna.
3. **Interface Endpoint** (resto de servicios) → ENI en tu subnet. Pagas por VPCE-hora + GB.

### Ejemplo de cálculo (precios US-east-1 orientativos, 2026)

Supón 2 AZs, workload que consume mucho de **S3**, **Secrets Manager**, **SSM**, **KMS** y **ECR**, con 500 GB/mes a servicios AWS.

**Opción A — Solo NAT:**

- 2 × NAT Gateway: 2 × $0.045 × 730 h ≈ **$65.70/mes**.
- Procesamiento NAT: 500 GB × $0.045 ≈ **$22.50/mes**.
- **Total ≈ $88.20/mes**.

**Opción B — Gateway Endpoint S3 + Interface Endpoints para Secrets/SSM/KMS/ECR (4 servicios × 2 AZs = 8 ENIs):**

- Gateway endpoint S3: **$0**.
- 8 ENIs × $0.01 × 730 h ≈ **$58.40/mes**.
- Procesamiento Interface Endpoint: digamos 200 GB × $0.01 ≈ **$2.00/mes**.
- NAT residual (300 GB restantes a otros servicios y a internet): sigue necesario, mantén 1 NAT: $32.85 + ~$13.50 ≈ **$46.35/mes**.
- **Total ≈ $106.75/mes**.

En este escenario, **A gana por poco**. Pero si el tráfico a servicios con endpoint fuera 2 TB/mes:

- A: 2000 × $0.045 = $90 ⇒ total ≈ **$155.70/mes**.
- B: 2000 × $0.01 = $20 ⇒ total ≈ **$124.75/mes**.

B gana con margen. **La respuesta depende del volumen y de la proporción internet vs AWS.** Haz el cálculo por workload; no asumas.

> **Red flag:** si tu CloudWatch muestra NAT Gateway procesando TBs/mes y tu app es "90 % hablar con S3 y Secrets", estás pagando NAT por tráfico que debería ir por endpoints.

---

## 8. Network Firewall (mención)

AWS **Network Firewall** es un servicio *stateful* (Suricata rules bajo el capó) que inspecciona tráfico entre subnets o hacia internet. Útil para:

- Egress allowlist por dominio (bloquear exfiltración).
- Deep packet inspection sobre tráfico este-oeste.

Caro (~$0.395/endpoint-hora + GB). Fuera del lab, pero sepas que existe: en una entrevista "cómo controlas egress" la respuesta madura es "NAT + endpoints como primer nivel; Network Firewall o un proxy explícito si necesito allowlist por dominio".

---

## 9. Trampas y antipatrones

1. **CNAME en el apex** (`midominio.com`) hacia un ALB → no cumple RFC; usa **alias**.
2. **Health check hacia `/`** que toca la DB → cuando la DB tiembla, el ALB marca todo *unhealthy* y amplifica el fallo. Usa `/healthz` liviano.
3. **NLB sin cross-zone load balancing** → por default, un NLB **no cruza AZs** (y cobra inter-AZ si lo activas). Si una AZ tiene 1 target y otra 10, la primera recibe 50 % del tráfico. Decisión consciente: `enable_cross_zone_load_balancing = true` casi siempre para ALB (gratis), **a sabiendas** para NLB (de pago).
4. **ACM en región incorrecta** → cert válido pero el ALB no lo monta porque está en otra región.
5. **Hosted zone privada sin `enableDnsHostnames = true`** en la VPC → no resuelve.
6. **TGW en una sola AZ** → single point of failure. Usa attachments multi-AZ.
7. **PrivateLink confundido con VPC endpoint "a secas"** → *Interface Endpoint* y *Endpoint Service* son los dos lados; el primero *consume*, el segundo *publica*.
8. **Dejar NAT y Interface Endpoints encendidos** sin calcular — pagas los dos sin ahorrar en ninguno.

---

## 10. Qué deberías llevarte

- **Un criterio claro** ALB vs NLB vs GWLB con 2–3 ejemplos de cada uno.
- La **mecánica de ACM** (DNS validation + Terraform) para publicar HTTPS sin tocar certs.
- **Peering vs TGW**: fórmula N·(N-1)/2 y cuándo cruza el umbral de dolor.
- **PrivateLink** entendido como productor+consumidor, con *allowed_principals* explícito.
- Un **cálculo de coste** NAT vs Interface Endpoint que puedas hacer de cabeza con precios orientativos.
- Costumbre de **nunca apply** sin haber mirado el `plan` y el `ADR` que justifica la decisión.

Lo siguiente (`aws-08`) asume que esta red ya está diseñada: montarás RDS/Aurora/DynamoDB sobre subnets privadas con SGs mínimos y, cuando corresponda, Interface Endpoints para no pagar NAT por el tráfico de administración.
