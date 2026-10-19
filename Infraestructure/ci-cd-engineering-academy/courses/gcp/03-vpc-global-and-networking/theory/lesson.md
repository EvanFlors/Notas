# gcp-03 — Lección: VPC global y networking en GCP

> 10 secciones. Mayoritariamente conceptual + contrastes con AWS. Prerrequisitos: `gcp-01`, `gcp-02`, y haber visto `aws-03` + `aws-07`.

---

## 1. La idea fuerza: la VPC es global

En AWS, una **VPC** vive en **una** región. Si tienes workloads en `eu-west-1` y en `eu-central-1`, tienes dos VPCs y, si quieres que se hablen, montas **VPC Peering** o un **Transit Gateway**. Es trabajo explícito.

En GCP, una **VPC** es **global**. Sus **subnets** son regionales — una por región donde quieras colocar recursos — pero **todas las subnets de la misma VPC se alcanzan directamente**, sin peering, usando la red privada de Google. Si tu app corre en `europe-west1` y la base de datos en `europe-west4`, ambas en la misma VPC, se hablan por IP privada sin trabajo adicional.

Consecuencia práctica: la **unidad de diseño** cambia.

- En AWS razonas "una VPC por región, cómo las conecto".
- En GCP razonas "una VPC global por entorno (dev/stg/prod), qué subnets pongo en cada región".

Esto simplifica la topología de red para la mayoría de startups y la hace más barata (menos peerings, menos TGW attachments). Es más complejo cuando la organización crece a cientos de workloads: ahí vuelves al patrón **Shared VPC** (sección 7) o **múltiples VPCs peereadas**.

> **Idea clave:** en GCP, el borde físico (región) y el borde lógico (VPC) **no coinciden**. Vive con eso.

---

## 2. Modos de VPC: `auto` vs `custom`

Cuando creas una VPC, GCP ofrece dos modos:

- **`auto`**: GCP crea automáticamente una subnet en **cada** región actual y futura, con CIDR predefinido en `10.128.0.0/9`. Cómodo para arrancar. Mal para producción: pierdes control del CIDR, puedes solaparte con on-prem o con otra VPC a peerear.
- **`custom`**: tú decides qué subnets crear, en qué regiones y con qué CIDR. **Es el modo correcto para cualquier cosa que no sea un sandbox**.

En este módulo trabajamos siempre con `custom`.

---

## 3. CIDR planning sin solapes

Como la VPC es global, planeas el CIDR a nivel de **toda** la VPC, no por región. Un esquema simple:

```
Env prod VPC          10.10.0.0/16
├── europe-west1      10.10.0.0/20     (4096 IPs)
├── europe-west4      10.10.16.0/20
├── europe-west3      10.10.32.0/20
└── reservado futuro  10.10.48.0/20..

Env stg VPC           10.20.0.0/16
Env dev VPC           10.30.0.0/16
```

Reglas:

1. **No solapar** con rangos on-prem (si vas a conectar por Interconnect/VPN) ni con otras VPCs a peerear.
2. **Dejar hueco** para subnets futuras — crecer un `/20` dentro de un `/16` es trivial, dentro de un `/24` no.
3. **No usar `/8` o `/9` de "auto"** en producción.
4. **Secondary ranges**: GKE y Alias IP ranges consumen rangos secundarios adicionales por subnet; dimensionarlos cuando sepas que vas a usarlos.

---

## 4. Firewall rules: por tag, por SA, por rango

Las **firewall rules** en GCP son **globales a la VPC** (no por subnet) y evaluan por **prioridad** (menor = más fuerte, igual que ACLs tradicionales). Cada regla define:

- **Direction**: `INGRESS` o `EGRESS`.
- **Action**: `allow` o `deny`.
- **Source** (ingress) o **Destination** (egress): rangos CIDR, **tags de red** o **service accounts**.
- **Target**: a qué instancias aplica (todas, o filtradas por tag/SA).
- **Protocolo y puertos**.
- **Prioridad** (0–65535, default 1000).

Las dos variantes **potentes** y específicas de GCP:

- **`targetTags` / `sourceTags`**: aplicar por **network tag** (etiqueta de red en la instancia). Útil, pero cualquier operador con permisos de edición de instancia puede ponerse un tag — es equivalente a "quien se autoasigne el SG". Suele usarse para separar roles (`web`, `db`).
- **`targetServiceAccounts` / `sourceServiceAccounts`**: aplicar por **service account asignada a la instancia**. Más fuerte: cambiar la SA de una instancia es una acción con un IAM role específico (`iam.serviceAccountUser` + permiso de editar la instancia), auditable. En entornos regulados: **preferir SA sobre tags**.

Diferencia conceptual con AWS: un **SG** AWS filtra "por adjunto a ENI". Una firewall rule GCP por SA filtra "por **quién es** la VM" — identidad. Esto se alinea con el modelo IAM de GCP ("principals").

### 4.1 Patrones mínimos de baseline

```
# allow-internal-health-checks   (ingress, prio 1000)
#   source: 35.191.0.0/16, 130.211.0.0/22  (rangos oficiales de LB health checks)
#   target: SAs de backends (app-sa@...)
#   protocol: tcp:80,443

# allow-internal-by-sa           (ingress, prio 1000)
#   sourceServiceAccounts: [app-sa@proj.iam.gserviceaccount.com]
#   targetServiceAccounts: [db-sa@proj.iam.gserviceaccount.com]
#   protocol: tcp:5432

# deny-all-ingress               (ingress, prio 65535, implícita)
#   action: deny
```

Y en egress, el baseline moderno es:

```
# deny-all-egress                (egress, prio 65535)
#   deny :0.0.0.0/0

# allow-egress-google-apis       (egress, prio 1000)
#   destination: Private Google Access ranges / restricted.googleapis.com
#   protocol: tcp:443
```

Dejar el egress abierto por defecto (como viene de fábrica) es cómodo pero cuando se escala a producción regulada se cierra y se abre explícitamente lo necesario.

---

## 5. Cloud NAT

Instancias **sin IP externa** no pueden salir a internet por defecto. Si necesitan actualizar paquetes, llamar a una API SaaS, etc., se usa **Cloud NAT**.

- **Regional**: una configuración de NAT se asocia a un **Cloud Router** regional y a una **o varias subnets**.
- **Managed**: Google gestiona capacidad y escalado; tú defines cuántas IPs externas asigna (y si auto-asigna más cuando se saturan los puertos).
- **Logging** opcional (puedes auditar qué IP salió a qué destino).

Alternativas y cuándo:

- **IP externa por instancia** → sólo para hosts específicos (bastión único, salida con IP conocida). Nunca a escala.
- **NAT gateway de terceros** → casi nunca. Cloud NAT es más barato y nativo.

> **Mapping con AWS**: Cloud NAT ≈ NAT Gateway. Diferencia: Cloud NAT escala automáticamente puertos y no necesitas una NAT GW por AZ.

---

## 6. Private Google Access y Private Service Connect

APIs de Google (GCS, BigQuery, Cloud Logging, Pub/Sub…) viven en **IPs públicas**. Instancias sin IP externa normalmente no las alcanzarían. Dos mecanismos:

- **Private Google Access (PGA)**: se habilita por subnet (`privateIpGoogleAccess=true`). Las VMs de esa subnet pueden alcanzar las APIs de Google por rutas internas, sin IP externa ni Cloud NAT. Útil y gratis.
- **Private Service Connect (PSC)**: expone APIs de Google (o servicios de terceros / tuyos) **a través de una IP interna de tu VPC**, con control por IAM. Más fuerte: ni siquiera sale del rango privado.

> **Mapping con AWS**: PGA ≈ *Gateway endpoints* para S3/DynamoDB (gratuitos). PSC ≈ *Interface endpoints* / *PrivateLink* (controlados, con IP en tu VPC). PSC es más general y es la dirección a largo plazo.

---

## 7. Shared VPC

Patrón enterprise: un **host project** posee la VPC; varios **service projects** colocan recursos (VMs, GKE nodes, Cloud Run con VPC connector) **dentro** de esa VPC compartida.

Beneficios:

- La red se diseña y opera **en un solo project** (equipo plataforma / networking).
- Los equipos de aplicación usan la red sin tener permisos para modificarla.
- El billing se mantiene por project (cada service project paga su compute, el host paga la red).

Roles IAM clave:

- `roles/compute.xpnAdmin` (en la **organización** o **folder**): quién puede marcar un project como host y attachar service projects.
- `roles/compute.networkAdmin` (en el host project): quién gestiona la VPC, subnets, firewall.
- `roles/compute.networkUser` (otorgado a un service project o a un grupo): permite **usar** subnets concretas desde ese project — sin este rol, un service project no puede crear VMs en la subnet.

> **Mapping con AWS**: Shared VPC ≈ *RAM-shared subnets* en AWS (compartir subnets entre cuentas de la misma Organization). GCP lo lleva más lejos: el flujo IAM está integrado desde el principio.

---

## 8. Peering, Network Connectivity Center, Interconnect/VPN

Si una VPC global no es suficiente (ej: una app en una VPC y una base de datos en otra VPC de otro project **no** compartido):

- **VPC Peering**: enlace privado entre dos VPCs. No es transitivo (A↔B, B↔C no implica A↔C). Simple y gratis como feature.
- **Network Connectivity Center (NCC)**: hub & spoke para múltiples VPCs y conexiones on-prem/multi-cloud, con enrutamiento centralizado. Es el equivalente moderno a *Transit Gateway* de AWS.
- **Cloud Interconnect** (fibra dedicada) o **Cloud VPN** (sobre internet): para conectar on-prem con GCP.

Decisión:

- 2 VPCs → peering.
- 3–5 VPCs con topología simple → peering si no hay transitividad; NCC si la hay.
- 5+ VPCs o multi-cloud → NCC.
- On-prem permanente → Interconnect; temporal / bajo ancho de banda → VPN.

---

## 9. Cloud Load Balancing: el LB global es la joya

El **external HTTPS Load Balancer global** de GCP tiene una propiedad que no existe nativamente en AWS: **una única IP anycast** que se anuncia desde todas las regiones de borde de Google. Los usuarios llegan al PoP más cercano, y Google enruta hacia el backend sano más cercano.

Consecuencias:

- **Un solo DNS A record** apuntando a esa IP. Nada de latency routing en Route 53.
- **Failover inmediato** si una región backend cae — el PoP envía al siguiente backend sano.
- **TLS termina en el borde** de Google, cerca del usuario.
- **TLS gratis** vía `google_compute_managed_ssl_certificate` (Google provisiona y renueva).

Piezas obligatorias (de arriba a abajo del request):

```
Cliente
  ↓ DNS → IP anycast
Forwarding rule (global, puerto 443)
  ↓
Target HTTPS proxy  +  Managed SSL cert
  ↓
URL map              (rutea por host/path)
  ↓
Backend service      (lista de backends, health check, afinidad, timeouts)
  ↓
Backends: Instance Group (MIG) | NEG (Cloud Run, GKE Pods, serverless)
```

Variantes:

- **Global external HTTPS LB** — el que usamos aquí; soporta Cloud CDN y Cloud Armor.
- **Regional external HTTPS LB** — una sola región; útil para apps con usuarios en una sola geografía o cuando se requiere residencia estricta.
- **Internal HTTPS LB** — para tráfico interno entre servicios (p. ej. microservicios en GKE).
- **Network LB** — L4 (TCP/UDP) para casos que no son HTTP.

### 9.1 Cloud Armor (WAF)

Políticas de seguridad adjuntas al backend service: bloquear por IP/país, aplicar OWASP rules (CRS), rate limiting, bot management. Se evalúa en el borde de Google **antes** de que el request llegue al backend.

### 9.2 Cloud CDN

Flag en el backend service (`enable_cdn = true`). Cachea respuestas con `Cache-Control` apropiado en los PoPs. Gratuito provisionarlo; pagas por el egress cacheado (más barato que egress sin cachear).

---

## 10. Mapping cheat-sheet con AWS

| GCP | AWS | Nota |
|-----|-----|------|
| VPC global | — | AWS no tiene equivalente directo; una VPC = una región. |
| Subnet regional | Subnet AZ-local | GCP subnet cubre toda la región, no una AZ. |
| Firewall rule por SA | SG por ENI | GCP permite filtrar por identidad; AWS filtra por adjunto. |
| Cloud NAT | NAT Gateway | Cloud NAT no requiere uno por AZ. |
| Private Google Access | Gateway endpoints S3/DDB | Ambos gratis. |
| Private Service Connect | Interface endpoints / PrivateLink | Modelo similar. |
| Shared VPC | RAM-shared subnets | GCP lo trae integrado desde el principio. |
| VPC Peering | VPC Peering | No transitivo en ambos. |
| Network Connectivity Center | Transit Gateway | Hub & spoke. |
| Cloud Interconnect | Direct Connect | Fibra dedicada. |
| Cloud VPN | Site-to-Site VPN | — |
| Global HTTPS LB | ALB + Route 53 latency | GCP ofrece IP anycast única — simplifica DNS y failover. |
| Cloud Armor | AWS WAF | — |
| Cloud CDN | CloudFront | — |
| Managed SSL cert | ACM | Ambos gratuitos; el de GCP vive atado al LB. |

---

## Cierre

La "VPC global + firewall por identidad + LB global con IP anycast" es la combinación distintiva de GCP. Diseñar para ella — en vez de intentar replicar la topología AWS — es la diferencia entre una red que escala con poco esfuerzo y una que arrastra complejidad accidental. Las dos actividades (`01-shared-vpc-host-and-service` y `02-publish-app-global-lb`) te hacen aterrizar exactamente estas dos piezas.
