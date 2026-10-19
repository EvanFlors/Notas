# Actividad 01 — Diseñar Shared VPC (host + service projects) y firewall por SA

## 1. Identificación

- **ID:** `gcp-03-01-shared-vpc-host-and-service`
- **Tecnología:** `gcp`
- **Módulo:** `gcp-03-vpc-global-and-networking`
- **Dificultad:** foundational
- **Duración estimada:** 80–100 min
- **Tipo:** architecture (independent — sin dependencia de la actividad 02)

## 2. Contexto

La misma startup del escenario `aws-15` entra ahora en **GCP** y quiere arrancar "bien" la red desde el principio. Dos workloads como siempre:

- **`checkout`**: API crítica, PCI-light, residencia **Europa**. Equipo backend de 4 personas.
- **`analytics`**: pipeline interno, no toca datos de pago. 1 data engineer.

Más:

- Platform/Networking quiere operar la **red** desde un único project y que los equipos de aplicación no tengan permisos para modificarla.
- Finance quiere billing separado por workload.
- Todas las cargas deben vivir en Europa (compliance).
- Las VMs **no deben tener IP externa** por defecto; el egress a internet, si hace falta, va por Cloud NAT.
- Las VMs deben poder hablar con APIs de Google (GCS, Logging) sin salir a internet.

Tu encargo: **diseñar la Shared VPC** (host project + 2 service projects), el **CIDR**, las **firewall rules del baseline** por service account, y documentarlo en un ADR que un equipo de 5 personas pueda ejecutar en Fase 4 con Terraform.

**Importante**: no hay project GCP real. No se provisiona nada. Los entregables son un **documento Markdown** y un **JSON** de firewall rules. **No hay costo**.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Diseñar una Shared VPC con host + N service projects y justificar cada decisión.
- Planear CIDRs sin solapes dejando hueco para 3+ regiones futuras.
- Escribir firewall rules por `sourceServiceAccounts` / `targetServiceAccounts`.
- Justificar por qué SA es más fuerte que tag.
- Escribir un ADR legible por un ingeniero que no estuvo en la discusión.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (§1 VPC global, §4 firewall por SA, §5 Cloud NAT, §6 PGA, §7 Shared VPC).
- Haber recorrido los tres `examples/` del módulo.
- Haber completado `gcp-01` y `gcp-02` (service accounts, IAM roles).
- Herramientas: `bash`, `jq`, y un editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gcp-03-shared-vpc
cd /tmp/gcp-03-shared-vpc
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-SHARED-VPC.md`

Un **ADR** (Architecture Decision Record) es un documento corto y versionado. Formato que debes seguir:

```
# ADR 001 — Red compartida (Shared VPC) para la organizacion GCP

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(2-4 parrafos: que problema resuelves, que constraints hay)

## Decision
(La estructura concreta: host project, service projects, VPC, subnets con CIDR,
firewall rules por SA, Cloud NAT, PGA. Diagrama ASCII dentro de un code fence.)

## Consecuencias
(Que ganas, que pierdes.)

## Alternativas descartadas
(Al menos 2 alternativas: p. ej. VPCs separadas + peering, VPC auto.)
```

Secciones obligatorias (el validador las busca):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio (el validador lo exige):

- **Diagrama ASCII** de la topología Shared VPC (dentro de code fences).
- **Al menos 3 projects** nombrados: un **host project** (`net-host-prod` o similar) y al menos dos **service projects** (`checkout-prod`, `analytics-prod` o similar).
- **Al menos 2 regiones europeas** mencionadas (`europe-west1`, `europe-west4`, `europe-west3`, `europe-central2`, `europe-north1`…).
- **Al menos 2 subnets** con **CIDR** concreto (p. ej. `10.10.0.0/20`).
- **Service accounts** nombradas para `checkout` y para `analytics` (p. ej. `app-sa`, `db-sa`, `analytics-sa`).
- **Al menos 3 firewall rules** del baseline nombradas (`allow-health-checks`, `allow-app-to-db`, `deny-all-egress`, `allow-egress-google-apis`, u otras).
- Mención explícita de **Shared VPC** (`xpnAdmin` o `networkUser`) y de **Cloud NAT** o **Private Google Access**.
- Mención explícita del **patrón "firewall por service account vs por tag"** y por qué.

### 5.3 Escribe `firewall-rules.json`

Un array JSON con **al menos 3 reglas**. Formato por regla:

```json
{
  "name": "...",
  "network": "projects/<host-project>/global/networks/<vpc-name>",
  "direction": "INGRESS|EGRESS",
  "priority": 1000,
  "sourceServiceAccounts": ["..."],
  "targetServiceAccounts": ["..."],
  "sourceRanges": ["..."],
  "allowed": [{ "IPProtocol": "tcp", "ports": ["5432"] }],
  "denied":  [{ "IPProtocol": "all" }]
}
```

El validador exige:

- Es un array JSON **válido** (parsea con `jq`).
- Tiene al menos **3 elementos**.
- Al menos **una regla usa `targetServiceAccounts`** (lo que valida que practicaste el patrón por SA).
- Al menos **una regla referencia los rangos de health checks** (`35.191.0.0/16` **y/o** `130.211.0.0/22`).
- Al menos **una regla es `direction: EGRESS`** (práctica del baseline egress-closed).
- Cada regla tiene `name` y `direction`.

### 5.4 Entregable

Dos archivos:

```
/tmp/gcp-03-shared-vpc/ADR-SHARED-VPC.md
/tmp/gcp-03-shared-vpc/firewall-rules.json
```

> **Prohibido**: `ANALYSIS.md`. Toda la justificación va en el ADR.

## 6. Resultado esperado

- Los dos archivos existen y son coherentes.
- El validador pasa en verde (`0 issue(s)`).
- Un ingeniero externo puede leer el ADR y entender **qué** vas a montar y **por qué**.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada firewall rule está justificada en el ADR.
- **Reproducibilidad**: alguien podría tomar el ADR + JSON y convertirlo a Terraform sin ambigüedades mayores.
- **Mantenibilidad**: Markdown válido, JSON válido, diagramas en code fences.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gcp-03-shared-vpc
```

El validador comprueba **estructura**, no semántica. Compara tu entrega con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. Si en 12 meses aparecen 10 workloads más, ¿tu diseño escala o te obligaría a crear más VPCs?
2. ¿Qué rol IAM necesita el service account que crea VMs en `checkout-prod` para colocarlas en una subnet del host project?
3. ¿Por qué conviene cerrar el egress por defecto y abrir sólo lo necesario (Google APIs, DNS, destinos específicos)?
4. ¿Qué pasa el día que `analytics` quiere publicarse a internet con LB global? ¿Tu diseño lo permite sin tocar la red compartida?
5. Si un auditor pregunta "muéstrame qué VMs pueden abrir conexiones a la base de datos", ¿cómo le respondes con tu diseño por SA?

## 10. Extensiones

- Añade **Private Service Connect** para alcanzar un servicio SaaS por IP interna.
- Añade un **peering** adicional para una VPC heredada (p. ej. una cuenta GCP previa de la startup) y justifica.
- Añade una regla `allow-egress-google-apis` apuntando a `restricted.googleapis.com` para bloquear exfiltración.

## 11. Limpieza

```bash
rm -rf /tmp/gcp-03-shared-vpc
```

No hay procesos ni infraestructura que detener.
