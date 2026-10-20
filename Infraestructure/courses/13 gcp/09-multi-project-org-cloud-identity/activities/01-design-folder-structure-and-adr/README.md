# Actividad 01 — Diseñar folder structure y escribir ADR

## 1. Identificación

- **ID:** `gcp-09-01-design-folder-structure-and-adr`
- **Tecnología:** `gcp`
- **Módulo:** `gcp-09-multi-project-org-cloud-identity`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** architecture (independiente — sin dependencia de la actividad 02)

## 2. Contexto

Una fintech de 25 personas (12 ingenieros, 4 data, 3 security, 6 negocio) va a entrar en GCP "en serio" después de un año en un único project con un `roles/editor` repartido. Dos workloads reales:

- **`checkout`**: API HTTP crítica en Cloud Run, procesa pagos, SLA 99.9%, obligaciones de residencia de datos (EU) y PCI-light. Equipo backend de 5 personas.
- **`analytics`**: pipeline BigQuery + dashboards internos, no toca datos de pago, uso en horario laboral. 1 data engineer.

Más:

- **Finance** quiere ver billing agregado y por entorno (ya hay una Billing Account corporativa).
- **Security** quiere Audit Logs centralizados y una base para Security Command Center.
- Toda carga debe vivir en Europa (**compliance**): `europe-west1` y `europe-west4` son las regiones objetivo.
- Los developers deben poder experimentar sin arrancar nada caro accidentalmente.
- No hay Google Workspace; **Cloud Identity Free** se acaba de verificar sobre el dominio corporativo.

Tu encargo: **diseñar la folder structure, el inventario de projects, el baseline de Org Policies, el catálogo de grupos Cloud Identity y un bosquejo de perímetro VPC Service Controls**, y documentarlo en un ADR que un equipo de 5 personas pueda leer y ejecutar en Fase 4 con Terraform.

**Importante**: no hay organization GCP real. No se provisiona nada. El entregable es un **documento**.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Diseñar una jerarquía Organization → Folders → Projects para una org pequeña y defender cada folder.
- Decidir *"un project por app"* vs *"un project por app × ambiente"* por workload y defender el criterio.
- Nombrar las Org Policies del baseline, dónde las adjuntas y por qué.
- Mapear grupos de Cloud Identity a roles por folder (no a tuplas usuario-project).
- Bosquejar un perímetro VPC-SC para datos regulados.
- Escribir un ADR legible por un ingeniero que no estuvo en la discusión.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §3 Folders, §6 Org Policy, §7 Billing, §8 VPC-SC, §10 patrones de projects).
- Haber recorrido los tres `examples/` del módulo.
- Haber completado `gcp-01` (model/projects) y `gcp-02` (IAM core, deny policies, SA impersonation).
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno. Todo es papel.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gcp-09-folder-adr
cd /tmp/gcp-09-folder-adr
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-ORG-STRUCTURE.md`

Un **ADR** (Architecture Decision Record) es un documento corto y versionado. Formato que debes seguir:

```
# ADR 001 — Estructura de la organización GCP

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(2-4 párrafos: qué problema resuelves, qué constraints hay)

## Decisión
(La estructura que eliges, concreta: Folders, Projects, patrón por workload,
Org Policies, grupos Cloud Identity, perímetro VPC-SC. Con diagrama ASCII.)

## Consecuencias
(Qué ganas, qué pierdes, qué se vuelve más fácil, qué más caro.
Debe cubrir tanto positivas como negativas.)

## Alternativas descartadas
(Al menos 2 alternativas consideradas y por qué no.)
```

Secciones obligatorias (el validador las busca):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio (el validador lo exige):

- **Diagrama ASCII** de la jerarquía propuesta (con fences de código).
- **Al menos 4 projects** nombrados (p. ej. `org-admin`, `logging-prod`, `checkout-prod`, `analytics-dev`…).
- **Al menos 3 Org Policies** del baseline nombradas por su constraint (`iam.disableServiceAccountKeyCreation`, `compute.vmExternalIpAccess`, `storage.publicAccessPrevention`, `iam.allowedPolicyMemberDomains`, …).
- **Al menos 3 grupos** de Cloud Identity (p. ej. `gcp-org-admins@`, `gcp-prod-sre@`, `gcp-dev-engineers@`, `gcp-security@`…).
- Mención explícita de **Cloud Identity** y de **Organization / Resource Manager**.
- Mención explícita de **VPC Service Controls** (al menos un párrafo describiendo el perímetro).
- Una decisión explícita sobre **"un project por app" vs "un project por app × ambiente"** para `checkout` y para `analytics`.
- Mención de **Europa** / `europe-west` / `europe-west1` (compliance de región).
- **No incluir** project IDs reales (los `gcp.foo-bar-1234` oficiales están publicados; usa siempre nombres descriptivos o placeholders).

### 5.3 Entregable

Un archivo:

```
/tmp/gcp-09-folder-adr/ADR-ORG-STRUCTURE.md
```

con las 6 secciones y el contenido mínimo listado.

> **No llames al archivo `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa `ADR-ORG-STRUCTURE.md`.

## 6. Resultado esperado

- `ADR-ORG-STRUCTURE.md` existe y es coherente.
- El validador pasa en verde.
- Un ingeniero externo puede leerlo y entender **qué** vas a montar y **por qué**.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada decisión está justificada (no solo listada).
- **Reproducibilidad**: alguien en Fase 4 podría tomar este ADR y convertirlo a Terraform (`project-factory`, `folders`) sin ambigüedades mayores.
- **Mantenibilidad**: Markdown válido, diagramas en code fences.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gcp-09-folder-adr
```

El validador comprueba **estructura**, no semántica. Compara tu ADR con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué `checkout` conviene en 3 projects (dev/stg/prod) y `analytics` quizás en 1 solo? ¿Qué criterio aplicaste?
2. Si en 2 años aparecen 10 workloads más, ¿tu estructura escala o la tendrías que rehacer?
3. ¿Dónde pondrías el pipeline de CI/CD (project de *tools*)? ¿Por qué no en `org-admin`?
4. ¿Qué pasa el día que `Finance` pide ver *solo* el gasto de `checkout-prod`? ¿Tu estructura y labels lo hacen fácil?
5. Si un auditor pregunta "muéstrame todo lo que puede hacer el grupo `gcp-dev-engineers@` en `checkout-prod`", ¿cómo le respondes?
6. ¿Qué pasaría si olvidas `iam.allowedPolicyMemberDomains` y alguien añade a `attacker@gmail.com` como owner de un project?

## 10. Extensiones

- Añade una sección **"Fase 2"** al ADR describiendo cambios previsibles cuando la org crezca a 10+ workloads o se incorpore Shared VPC.
- Dibuja un **diagrama de assignments** (grupos × roles × folders) como tabla.
- Añade una Org Policy custom (fuera del baseline) justificada por el contexto PCI-light de `checkout` (p. ej. `custom.requireLabelCostCenter`).

## 11. Limpieza

```bash
rm -rf /tmp/gcp-09-folder-adr
```

No hay procesos ni infraestructura que detener.
