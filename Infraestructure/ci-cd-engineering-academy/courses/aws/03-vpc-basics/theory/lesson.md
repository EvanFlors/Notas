# aws-03 — Lección: VPC Basics

> 10 secciones. Nada se despliega: todo se razona con CIDR, diagramas y `terraform plan`.

---

## 1. VPC y CIDR: la planificación que casi nadie hace bien

Una **VPC** es una red privada virtual aislada dentro de una región. Su parámetro fundamental es el **bloque CIDR**: entre `/16` (65 536 direcciones) y `/28` (16 direcciones). AWS **no** permite más amplio que `/16` por VPC primaria.

Regla práctica: pide siempre `/16`. Es gratis. Cambiarlo después implica recrear la VPC.

Dentro del `/16` se cortan **subnets**, cada una ligada a **una** Availability Zone (AZ). Una subnet AWS **reserva 5 IPs** independientemente del tamaño:

- `.0` — network address.
- `.1` — VPC router.
- `.2` — reservado para DNS (`.2` del rango *de la VPC*, no del subnet).
- `.3` — reservado para uso futuro.
- `.255` — broadcast.

Por eso un `/28` (16 direcciones) te deja **11 hosts** usables, no 14 como en una red clásica.

### Plan de direccionamiento recomendado para una VPC `/16`

```
10.0.0.0/16   (65 536 IPs — toda la VPC)
├── 10.0.0.0/20     (4 096) — AZ-a
│   ├── 10.0.0.0/24   — public-a
│   ├── 10.0.1.0/24   — private-a (app)
│   ├── 10.0.2.0/24   — private-a (data)
│   └── 10.0.3.0/24   — reserva-a
├── 10.0.16.0/20    (4 096) — AZ-b
│   ├── 10.0.16.0/24  — public-b
│   ├── 10.0.17.0/24  — private-b (app)
│   ├── 10.0.18.0/24  — private-b (data)
│   └── 10.0.19.0/24  — reserva-b
└── 10.0.32.0/20    (4 096) — AZ-c
    ├── ...
```

Si tu empresa ya usa `10.0.0.0/8` en otras cuentas o on-prem, **no** uses `10.0.0.0/16`: elige `10.42.0.0/16` o similar. El conflicto se paga carísimo cuando quieres hacer peering o TGW.

---

## 2. Subnet pública vs privada: la única definición que importa

La definición operativa es muy simple:

> Una subnet es **pública** si y solo si su **route table** tiene una ruta `0.0.0.0/0` apuntando a un **Internet Gateway**.

Nada más. El flag `map_public_ip_on_launch=true` **ayuda** (asigna IP pública al lanzar), pero una subnet con ese flag y **sin** ruta al IGW sigue siendo privada en la práctica (las instancias no pueden salir ni ser alcanzadas).

Un error común en diagramas corporativos: pintar la subnet como "pública" por color sin mirar la route table real.

---

## 3. Internet Gateway (IGW) y NAT Gateway: egress y su precio

- **IGW**: componente lógico, horizontalmente escalable, **gratis**. Una VPC = un IGW. Habilita *ingress* y *egress* para instancias con IP pública en subnets públicas.
- **NAT Gateway (NGW)**: managed service que permite a instancias en subnets privadas iniciar conexiones *outbound* a Internet sin tener IP pública. **Se paga por hora Y por GB procesado.**

Costos aproximados (orden de magnitud, verificar vigencia):

- NAT Gateway: ~**$0.045/h** + ~**$0.045/GB** procesado.
- 3 AZ con NAT Gateway cada una, 24×7, **sin tráfico**: ~**$97/mes solo por existir**.
- Añade 1 TB de egress a S3 por mes: **+$45**.

Este es el motivo #1 por el que una factura AWS "pequeña" se dispara en el segundo mes.

### NAT Instance (opción barata)

- Es una EC2 (`t3.nano` o similar) con `source/dest check` deshabilitado y `iptables` haciendo NAT.
- Cuesta ~$4/mes vs $32/mes de un NGW.
- **No es HA por sí sola** (si muere, muere el egress). Requiere scripting manual o un ASG de 1.
- Buena opción para **dev/sandbox**. En prod paga el NGW.

### Alternativa correcta: endpoints (ver §9)

El 60–80 % del egress "a Internet" de una app típica es realmente **a servicios AWS en la misma región** (S3, DynamoDB, ECR, SSM, Secrets Manager, CloudWatch Logs...). Mover eso a endpoints baja la factura NAT drásticamente.

---

## 4. Route tables: una por intención

Una route table (RT) contiene rutas `destino CIDR → target`. Reglas:

- La ruta `local` (al CIDR de la VPC) está siempre y no se puede borrar.
- Prevalece la ruta con el **prefijo más largo** (longest prefix match).
- Cada subnet tiene **una** RT asociada (si no, se usa la *main*). Varias subnets pueden compartir RT.

Patrón mínimo multi-AZ:

```
rt-public         0.0.0.0/0  → igw-xxx          (asociada a public-a, public-b, public-c)
rt-private-a      0.0.0.0/0  → nat-az-a         (asociada a private-a)
rt-private-b      0.0.0.0/0  → nat-az-b         (asociada a private-b)
rt-private-c      0.0.0.0/0  → nat-az-c         (asociada a private-c)
```

Una **RT privada por AZ** evita que el fallo de una NAT se lleve el tráfico cross-AZ (y los $0.01/GB cross-AZ asociados). Si optimizas costo sobre HA, puedes tener **una sola NAT** y RTs privadas apuntando todas allí — asumes que si cae esa AZ, cae tu egress.

---

## 5. Security Groups (SG): stateful, allow-only

- **Allow-only**: no existe la regla *deny*. Si una regla permite, pasa; si ninguna permite, se bloquea.
- **Stateful**: si permites `in 443/tcp from 0.0.0.0/0`, la respuesta sale sola. No hace falta regla de retorno.
- Las reglas se evalúan como **unión**: cualquier regla que permita, basta.
- Se aplican a nivel de **ENI** (interface de red), no de subnet.
- Puedes **referenciar otros SGs por ID** como source/destination: `allow 5432/tcp from sg-app` es la forma correcta de decir "la DB acepta de las apps".
- Límite típico: 60 reglas inbound + 60 outbound por SG; una ENI puede tener hasta 5 SGs.

### Ejemplo de patrón limpio

```
sg-alb       in : 443/tcp from 0.0.0.0/0
             out: all
sg-app       in : 8080/tcp from sg-alb
             out: all               (al menos a sg-db, S3 endpoint, etc.)
sg-db        in : 5432/tcp from sg-app
             out: (vacío — una DB rara vez inicia conexiones)
```

Nunca abras `0.0.0.0/0` en el SG de una DB. Nunca uses `0.0.0.0/0` como atajo "para probar".

---

## 6. NACLs: stateless, ordenadas, allow+deny

- Se aplican a nivel de **subnet** (no de ENI).
- **Stateless**: necesitas regla de ingress **y** egress (para el puerto efímero de retorno).
- Tienen **allow** y **deny**.
- Se evalúan **por `rule_number` ascendente**; la primera que matchee gana.
- Hay una regla implícita `*` al final que deniega todo.
- Puertos efímeros: Linux `32768-60999`, Windows `49152-65535`; para ser portable usa `1024-65535`.

### ¿Cuándo añadir una NACL?

- Para **bloquear** rangos (p. ej. un IP malicioso) sin tocar cada SG.
- Para forzar un boundary (ej. "esta subnet nunca puede recibir SSH").
- Para cumplimiento (ej. PCI exige doble capa).

En el 90 % de los casos la NACL por defecto (allow all) es suficiente y toda la seguridad vive en SGs. Modificar NACLs mal es una de las formas más eficaces de dejar fuera a tu propia aplicación.

### Comparativa de bolsillo

| Propiedad          | Security Group       | NACL                   |
|--------------------|----------------------|------------------------|
| Nivel              | ENI                  | Subnet                 |
| State              | Stateful             | Stateless              |
| Tipos de regla     | Allow                | Allow + Deny           |
| Evaluación         | Unión (cualquiera)   | Orden por `rule_number`|
| Referencias por ID | Sí (otro SG)         | No (solo CIDRs)        |
| Default            | Deny all in / allow all out | Allow all      |

---

## 7. DNS en VPC

Dos flags, dos efectos:

- `enableDnsSupport=true`: la VPC resuelve nombres AWS (ej. `s3.<region>.amazonaws.com`) usando el resolver `.2`.
- `enableDnsHostnames=true`: a las instancias con IP pública se les asigna hostname público (`ec2-54-...compute.amazonaws.com`).

Para que los **Interface endpoints** con *private DNS* funcionen (y las SDK no se enteren de que están hablando al endpoint), ambos deben estar en `true`. Es la causa #1 de "mi endpoint existe pero mi app sigue saliendo por NAT".

---

## 8. VPC endpoints: Gateway vs Interface

Dos sabores, dos modelos de precio.

### Gateway endpoint (S3, DynamoDB)

- Se añade como **ruta** en una route table: `prefix-list de S3 → vpce-xxx`.
- **Gratis**. Sin cobro por hora, sin cobro por GB.
- Solo S3 y DynamoDB tienen este tipo.
- El tráfico queda dentro de AWS, nunca llega al NGW.

### Interface endpoint (casi todo lo demás)

- Es una **ENI** en tu subnet privada, con una IP interna. Hay un *private DNS name* que sobreescribe el endpoint público del servicio.
- Cobra ~**$0.01/h por AZ** + ~**$0.01/GB** procesado.
- Para ECR, SSM, Secrets Manager, STS, CloudWatch Logs, etc.
- Suele ser más barato que seguir pagando NAT para el mismo tráfico — depende del volumen.

### Regla de decisión rápida

```
¿El servicio es S3 o DynamoDB?        → Gateway endpoint (siempre, es gratis).
¿Tráfico constante a un servicio AWS? → Interface endpoint (comparar vs NAT).
¿Tráfico esporádico a Internet?       → Dejarlo por NAT.
```

---

## 9. Caso típico de reducción de factura NAT

App en subnet privada que:

- `aws s3 cp` grandes datasets (500 GB/mes).
- `docker pull` desde ECR al arrancar tareas Fargate (50 GB/mes).
- Obtiene secretos de Secrets Manager (0.5 GB/mes).
- Escribe logs a CloudWatch Logs (20 GB/mes).

**Sin endpoints** (todo por NAT): 570 GB × $0.045 = **~$26/mes** solo en procesamiento NAT (más las $0.045/h que ya pagas por tener el NGW).

**Con endpoints**:
- S3 Gateway → ahorra $22.5 (500 GB × $0.045), coste adicional $0.
- ECR + Secrets + Logs Interface → ~$7 por AZ de hora + ~$0.70 por GB = ~$25 (3 AZ) + ~$0.7 = más caro aún.

Lección: **el Gateway endpoint S3 siempre vale la pena**. Los Interface endpoints hay que calcularlos: salen a cuenta cuando el volumen es alto y constante (ECR en una fábrica de tareas, SSM intensivo), no cuando son 50 MB al mes.

---

## 10. Peering (preview, se profundiza en aws-07)

- **VPC peering**: conecta dos VPCs 1:1. **No es transitivo** (si A↔B y B↔C, A no habla con C vía B).
- Requiere que los CIDR **no se solapen**.
- Hay que añadir **rutas en ambas RTs** y abrir **SGs** del lado remoto por ID (sí, los SG peered pueden referenciarse cross-VPC).
- Para N:N o topologías mesh, no uses peering: usa **Transit Gateway** (lo verás en `aws-07`).

Esto cierra el bloque. Las dos actividades del módulo te hacen (a) escribir el módulo Terraform de VPC y leer su `plan`, y (b) auditar un stack caro y proponer endpoints.
