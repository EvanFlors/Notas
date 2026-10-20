# Actividad 02 — ADR de gobernanza para una org GitLab de 50 proyectos

## 1. Identificación

- **ID:** `gl-09-02-governance-adr`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-09-compliance-approvals-and-governance`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** architecture (independent — sin dependencia de la actividad 01)

## 2. Contexto

Una empresa fintech de 180 personas (90 ingenieros, 20 data, 10 security, resto negocio) viene de GitHub Enterprise Cloud y está evaluando migrar a **GitLab SaaS Premium o Ultimate** como su single-source-of-truth. Hoy tiene **50 proyectos** repartidos en 6 equipos, entre ellos:

- **`checkout`** — procesa pagos, scope PCI-DSS, SLA 99.9%, equipo de 6 ingenieros.
- **`fraud-detection`** — ML interno, lee datos de `checkout`, no toca tarjetas directamente.
- **`internal-tools`** — 20+ projects pequeños que nadie "quiere" mantener. Vulnerabilidad crónica.
- **`website`** — marketing, cambios diarios, nada regulado.

Más:

- Compliance interno pide alinear con **ISO 27001** y preparar auditoría **SOC2 Type II** en 12 meses.
- IT corporativo ya tiene **Okta** como IdP; quieren SCIM obligatorio.
- Security tiene **Splunk** y quiere los audit events de GitLab ahí.
- Los developers vienen de GHA y "no quieren que GitLab les frene".

Tu encargo: **diseñar el baseline de gobernanza GitLab** — Compliance Frameworks, approval rules, push rules, SSO/SCIM, audit stream, IP allowlist (si aplica) — y documentarlo en un ADR que la Dirección pueda firmar y que el equipo de plataforma pueda ejecutar en Fase 4.

**Importante**: no hay instancia GitLab real. No se provisiona nada. El entregable es un **documento**.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Diseñar un baseline de gobernanza completo y defender cada decisión.
- Decidir y justificar el tier (Premium vs Ultimate) por el conjunto de features necesarias.
- Mapear al menos 3 controles del baseline a controles concretos de ISO 27001 o SOC2.
- Dibujar el flujo end-to-end `push → pipeline → approvals → merge → audit stream` como ASCII.
- Escribir un ADR legible por un ingeniero externo y por un auditor.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo.
- Haber recorrido los tres `examples/` del módulo.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gl-09-governance
cd /tmp/gl-09-governance
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-GOVERNANCE-BASELINE.md`

Un **ADR** (Architecture Decision Record) es un documento corto y versionado. Formato que debes seguir:

```
# ADR 001 — Baseline de gobernanza GitLab

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(2-4 párrafos: qué problema resuelves, qué constraints hay — compliance, DX, Okta...)

## Decisión
(La estructura concreta: Compliance Frameworks, approval rules, push rules,
protected branches, SSO/SCIM, audit stream, tier (Premium/Ultimate).
Debe incluir un diagrama ASCII del flujo end-to-end.)

## Consecuencias
(Qué ganas, qué pierdes. Positivas y negativas. Impacto en DX, en coste, en auditoría.)

## Alternativas descartadas
(Al menos 2, con razón explícita.)
```

Secciones obligatorias (el validador las busca):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio (el validador lo exige):

- **Diagrama ASCII** del flujo `push → pipeline → approvals → merge → audit` (dentro de code fences).
- Mención explícita de **Compliance Framework** (o `Compliance Pipeline`).
- Al menos **3 nombres** de MR approval rules o conceptos de approval (`approvals_required`, `code_owner_approval_required`, `security_findings`, `prevent_author_approval`...).
- Al menos **3 push rules** nombradas (regex commit, deny secrets, author domain, unsigned commits, file size, branch name...).
- Mención explícita de **CODEOWNERS**.
- Mención explícita de **protected branches**.
- Mención de **SAML**/**SSO** y de **SCIM**.
- Mención de **audit events** (o **audit log** / `audit stream`).
- Mención de un **SIEM** concreto o genérico (Splunk, Elastic, Datadog, SIEM).
- Decisión explícita sobre el **tier** (Premium vs Ultimate) con justificación.
- Mención de los dos workloads (`checkout` y `internal-tools`) con tratamiento diferenciado.
- Mapeo a al menos un marco: **ISO 27001** o **SOC2**.

### 5.3 Entregable

Un archivo:

```
/tmp/gl-09-governance/ADR-GOVERNANCE-BASELINE.md
```

con las 6 secciones y el contenido mínimo listado.

## 6. Resultado esperado

- `ADR-GOVERNANCE-BASELINE.md` existe y es coherente.
- Validador en verde.
- Un auditor externo puede leerlo y entender **qué** controles vas a aplicar, **a qué** mapean en ISO 27001 / SOC2, y **cómo** se verifican.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada decisión está justificada (no sólo listada).
- **Reproducibilidad**: alguien en Fase 4 podría tomar este ADR y configurar GitLab sin ambigüedades mayores.
- **Mantenibilidad**: Markdown válido, diagrama en code fences, tier justificado.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-09-governance
```

El validador comprueba **estructura y presencia de términos clave**, no semántica. Compara tu ADR con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué tiene sentido tener **más de un** Compliance Framework (uno `Internal-Baseline`, otro `PCI-Light`)?
2. ¿Qué pasa el día que un developer pide bajar `approvals_required` de 2 a 1 "porque es una fix urgente"?
3. Si Splunk cae, ¿GitLab sigue aceptando merges o se cae el merge también? ¿Qué prefieres?
4. ¿Cómo probarías un cambio en el Compliance Framework sin romper los 50 projects?
5. ¿Qué controles **no** has aplicado y por qué (p. ej. IP allowlist, require password on approve)?

## 10. Extensiones

- Añade un **gap analysis** entre lo que hoy tienen (GHA + Enterprise Cloud) y el baseline propuesto.
- Dibuja un **mapa de responsabilidad** (RACI) entre plataforma, compliance, security y los equipos de product.
- Añade una sección **"Fase 2"** describiendo controles futuros (p. ej. attestations SLSA L3, break-glass workflow).
- Escribe un apéndice con un ejemplo de **audit event** JSON que el SIEM debería alertar.

## 11. Limpieza

```bash
rm -rf /tmp/gl-09-governance
```

No hay infraestructura que detener.
