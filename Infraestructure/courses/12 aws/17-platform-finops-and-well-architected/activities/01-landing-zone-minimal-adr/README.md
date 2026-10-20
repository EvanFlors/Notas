# Actividad 01 — ADR de landing zone AWS mínima

## 1. Identificación

- **ID:** `aws-17-01-landing-zone-minimal-adr`
- **Tecnología:** `aws`
- **Módulo:** `aws-17-platform-finops-and-well-architected`
- **Dificultad:** advanced
- **Duración estimada:** 75–90 min
- **Tipo:** architecture (independiente de las actividades 02 y 03)

## 2. Contexto

Una scaleup de 60 ingenieros ha crecido con **una sola cuenta AWS**. Síntomas:

- La factura es un bloque opaco; nadie sabe cuánto cuesta `checkout` vs `search`.
- Un `terraform destroy` erróneo tiró un entorno "staging" el mes pasado.
- Auditores externos piden separación entre workloads y "the thing that stores the audit logs".
- Hay 7 NAT Gateways sueltos, uno por VPC, y nadie recuerda por qué.
- Un intento previo de IAM roles cross-account quedó a medias.

La dirección aprueba 2 semanas de trabajo para **sentar la landing zone**. Tu tarea: escribir el **ADR** que la define.

**No** se trata de ejecutar `terraform apply`. Se trata de **decidir y defender** la estructura.

## 3. Objetivos

Al terminar deberías poder:

- Nombrar las **cuentas canónicas mínimas** (al menos: `management`, `log-archive`, `audit`, `network`, `shared-services`, `workload-dev`, `workload-stg`, `workload-prd`) y explicar qué pone cada una.
- Elegir patrón de **red** (hub-and-spoke con Transit Gateway) y defenderlo frente a full-mesh VPC peering.
- Definir al menos **3 SCPs base** y adscribirlas a la OU correcta.
- Elegir el patrón de **logging centralizado** (CloudTrail Org Trail, Config aggregator, Security Hub delegated admin).
- Articular el **trade-off de coste** de centralizar NAT en una *inspection VPC* vs tener uno por cuenta.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md`, en particular §2 (landing zone) y §7 (governance).
- Haber recorrido `../../examples/01-tagging-strategy-and-enforcement-scp/`.
- Haber completado `aws-15` (Organizations + IdC).
- Herramientas: `bash`, editor Markdown. **Ninguna** credencial AWS.

**Costos**: ninguno. No se crea nada en AWS.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-17-landing-zone
cd /tmp/aws-17-landing-zone
```

Puedes usar otro directorio y pasárselo al validador:
`bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `LANDING-ZONE-ADR.md` con 7 secciones

Sigue el formato ADR clásico de Michael Nygard, con secciones adicionales específicas de este caso.

#### Sección 1 — Contexto

Describe la organización, el estado actual y los problemas que llevan a la decisión (puedes partir del contexto del §2 de esta actividad y añadir tus propias asunciones). 1–2 párrafos.

#### Sección 2 — Decisión

Enuncia **la decisión** en una línea. Ejemplo plantilla (adáptala): *"Adoptamos una landing zone multi-cuenta sobre AWS Organizations con 4 OUs y red hub-and-spoke centralizada con Transit Gateway."*

#### Sección 3 — Estructura de cuentas y OUs

Dibuja (ASCII o Markdown anidado) la estructura. **Debe nombrar al menos las cuentas**:

- `management` (root de la Org, pagos, Organizations)
- `log-archive`
- `audit`
- `network`
- `shared-services`
- `workload-dev`
- `workload-stg`
- `workload-prd`

Para cada una, 1 línea de propósito.

> Usa IDs ficticios o placeholders `111111111111`, no cuentas reales.

#### Sección 4 — Red

Describe:

- Patrón: **hub-and-spoke** con **Transit Gateway** en `network`.
- **Inspection VPC** central con **NAT Gateway(s)** compartidos.
- **Route 53 Resolver** endpoints inbound/outbound, PHZ en `shared-services`.
- Un diagrama ASCII mínimo mostrando `workload-* VPC` → `TGW` → `inspection VPC` → `NAT` → `Internet`.

Añade **un párrafo** sobre coste: cuánto cambia el fijo si hay N cuentas con NAT propio vs 1 NAT central. (Puedes usar las cifras orientativas del lesson.)

#### Sección 5 — SCPs base

Lista al menos **3 SCPs** con su propósito en 1 línea cada una. Ejemplos:

1. `deny-non-approved-regions` — denegar operaciones fuera de regiones aprobadas (p. ej. `us-east-1`, `eu-west-1`).
2. `require-mandatory-tags-on-create` — denegar creación sin los tags obligatorios.
3. `deny-log-archive-delete` — denegar `s3:DeleteObject*` sobre el bucket central de logs incluso al root de la cuenta `log-archive`.

Para cada una, indica **a qué OU se adscribe** y **por qué**.

#### Sección 6 — Logging y governance

Describe:

- **CloudTrail Organization Trail** → bucket versionado en `log-archive` con Object Lock + SSE-KMS.
- **Config aggregator** en `audit`.
- **Security Hub + GuardDuty**: `audit` como *delegated administrator*.
- 1–2 líneas sobre cómo esto habilita FinOps indirectamente (tags en inventario, recursos sin dueño detectables).

#### Sección 7 — Alternativas consideradas y rechazadas

Al menos **2 alternativas** con el motivo del rechazo. Ejemplos:

- **Alternativa A: single-account con tags.** Rechazada por blast radius y por la petición explícita de los auditores de separación entre `audit`/`log-archive`/`workload`.
- **Alternativa B: full-mesh VPC peering en vez de Transit Gateway.** Rechazada por `O(N²)` conexiones a mantener a partir de ~5 VPCs y por la fricción operativa de cambiar peerings cada vez que se añade cuenta.

#### Sección 8 — Consecuencias

Qué cambia (positivo y negativo). Al menos:

- **Positivo**: blast radius, auditabilidad, ahorro NAT centralizado, FinOps habilitado.
- **Negativo**: coste de operar la plataforma (overhead humano), coste fijo de Transit Gateway + inspection VPC, curva de aprendizaje de IAM cross-account.

### 5.3 Entregable

Un único archivo:

```
/tmp/aws-17-landing-zone/LANDING-ZONE-ADR.md
```

con las secciones 1–8.

## 6. Resultado esperado

- El ADR existe, es coherente y defendible.
- Nombra las cuentas canónicas requeridas.
- Nombra Transit Gateway, inspection VPC, NAT central.
- Define al menos 3 SCPs con OU asignada.
- Compara al menos 2 alternativas rechazadas.
- `bash tests/validate.sh /tmp/aws-17-landing-zone` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada SCP tiene propósito y OU; cada alternativa tiene motivo de rechazo.
- **Reproducibilidad**: otro ingeniero puede dibujar el mismo diagrama después de leerlo.
- **Realismo**: no inventa servicios AWS inexistentes; usa IDs placeholder, no reales.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-17-landing-zone
```

El validador comprueba **estructura**, no semántica. Compara tu ADR con `solution/REFERENCE.md` para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué `management` **no** debe ejecutar workloads nunca?
2. ¿Qué pasaría si colocas Security Hub como *delegated admin* en `log-archive` en vez de `audit`?
3. ¿En qué momento del crecimiento de la organización dejar de usar OUs planas y empezar a anidar OUs tiene sentido?
4. Si un equipo pide "mi propia cuenta `workload-prd-equipo-X`", ¿cómo decides si decir sí o no?
5. ¿Qué tag **nunca** incluirías en la SCP de tags obligatorios y por qué?

## 10. Extensiones

- Añade una SCP para **region deny** con lista blanca.
- Añade una cuenta `backup` separada (patrón recomendado por AWS Backup).
- Dibuja un segundo diagrama "fase 2" con **Firewall Manager** / **Network Firewall** en inspection VPC.
- Añade un apartado "runbook de alta de nueva cuenta" (10 pasos máximo).

## 11. Limpieza

```bash
rm -rf /tmp/aws-17-landing-zone
```

No hay procesos ni recursos AWS que destruir (no se creó nada real).
