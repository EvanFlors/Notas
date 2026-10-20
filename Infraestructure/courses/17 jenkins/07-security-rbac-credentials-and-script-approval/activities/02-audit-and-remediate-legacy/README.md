# Actividad 02 — Audit y plan de remediación de un Jenkins legacy

## 1. Identificación

- **ID:** `jk-07-02-audit-and-remediate-legacy`
- **Tecnología:** `jenkins`
- **Módulo:** `jk-07-security-rbac-credentials-and-script-approval`
- **Dificultad:** advanced
- **Duración estimada:** 85–95 min
- **Tipo:** independent

## 2. Contexto

Heredas un Jenkins legacy de ~4 años en producción. Nadie activo en el equipo lo conoce al 100%. El SRE te entrega un **snapshot** con:

- Lista de plugins instalados con versión.
- Export de la config de seguridad (realm, authorizationStrategy, roles).
- Inventario de credentials (sin valores — solo id, tipo, scope, descripción).
- `scriptApproval.xml` tal cual.

Tu trabajo: producir `AUDIT.md` con hallazgos clasificados y `REMEDIATION-PLAN.md` con fases temporales y criterios de éxito. No vas a tocar el controller — es un ejercicio de análisis y planificación.

El snapshot está en `starter/legacy-snapshot/` (archivos de solo lectura: `plugins.txt`, `jenkins-security-export.yaml`, `credentials-inventory.md`, `scriptApproval.xml`).

## 3. Objetivos

Al terminar deberías poder:

- Leer un snapshot de instalación legacy y producir un `AUDIT.md` con hallazgos clasificados por severidad (`Critical` / `High` / `Medium` / `Low`).
- Priorizar los hallazgos con la matriz **severidad × esfuerzo** de §9.3 de la lección.
- Producir un `REMEDIATION-PLAN.md` con fases temporales (`hoy` / `esta semana` / `esta quincena` / `backlog`) y criterios de éxito por fase.
- Identificar al menos **uno** de cada: plugin con CVE crítica, credential en scope inadecuado, script approval con escape de sandbox, rol asignado a `anonymous`.
- Argumentar por qué la primera medida de hardening suele ser **desinstalar plugins**, no "configurar algo".

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§3, §4, §5, §9).
- Herramientas: `bash`, un editor Markdown.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/jk-07-audit
cd /tmp/jk-07-audit
```

Copia el snapshot al directorio de trabajo (solo para que esté a mano):

```bash
cp -r <ruta-repo>/courses/jenkins/07-security-rbac-credentials-and-script-approval/\
activities/02-audit-and-remediate-legacy/starter/legacy-snapshot ./legacy-snapshot
```

### 5.2 Explora el snapshot

Pregúntate, archivo a archivo:

- `plugins.txt`: ¿cuántos plugins hay? ¿cuáles tienen uso evidente? ¿cuáles sospechas de "nadie los usa"?
- `jenkins-security-export.yaml`: ¿qué roles existen? ¿quién es admin? ¿`anonymous` tiene algo?
- `credentials-inventory.md`: ¿algún `SYSTEM` que debería ser `GLOBAL`? ¿algún `GLOBAL` que debería ser folder? ¿descripciones vacías?
- `scriptApproval.xml`: ¿alguna firma con `invoke`/`evaluate`? ¿alguna sin contexto claro?

Pistas: el snapshot está **sembrado** con problemas realistas. Debes encontrar al menos uno de cada categoría del objetivo.

### 5.3 Escribe `AUDIT.md`

Secciones **mínimas** (el validador las busca por heading):

- `## Resumen ejecutivo` — 5–10 líneas; punteos principales.
- `## Hallazgos`
  - Cada hallazgo con subheading `### [SEV] titulo` donde `[SEV]` ∈ `Critical`, `High`, `Medium`, `Low`.
  - Mínimo **6 hallazgos**, repartidos entre al menos 3 severidades distintas.
  - Cada hallazgo: 1 párrafo contexto + 1 línea impacto + 1 línea fix propuesta.
- `## Matriz severidad por esfuerzo` — tabla con los hallazgos ubicados.

Debe mencionar explícitamente:

- Al menos un **plugin** por nombre instalado (de `plugins.txt`).
- La palabra **`anonymous`** en el contexto del hallazgo de autorización.
- La palabra **`sandbox`** o **`invoke`** o **`evaluate`** en el hallazgo de script approval.
- Al menos un **`id` de credential** (del inventario).

### 5.4 Escribe `REMEDIATION-PLAN.md`

Secciones **mínimas**:

- `## Fase 1 - Hoy`
- `## Fase 2 - Esta semana`
- `## Fase 3 - Esta quincena`
- `## Fase 4 - Backlog`
- `## Criterios de exito`
- `## Rollback`

En cada fase, bullet list con acciones concretas (verb + objeto + owner propuesto). En `Criterios de exito`, cómo sabrás que la fase terminó (ej. "0 CVEs Critical pendientes", "0 roles asignados a anonymous").

### 5.5 Valida

```bash
bash <ruta-repo>/courses/jenkins/07-security-rbac-credentials-and-script-approval/\
activities/02-audit-and-remediate-legacy/tests/validate.sh /tmp/jk-07-audit
```

Resultado esperado: `OK: AUDIT.md y REMEDIATION-PLAN.md pasan validacion estructural.`

### 5.6 Autoevaluación

Lee `solution/REFERENCE.md` **después** de intentar. Tu lista de hallazgos puede diferir — lo relevante es que cubras las 4 categorías del objetivo y la priorización sea coherente.

## 6. Entregables

- `/tmp/jk-07-audit/AUDIT.md`
- `/tmp/jk-07-audit/REMEDIATION-PLAN.md`

## 7. Criterios de éxito

- El validador imprime `OK: ...` (0 fallos estructurales).
- La priorización es defendible ante "¿por qué este primero y no este?".
- El plan incluye explícitamente **desinstalar plugins no usados** como medida de reducción de superficie — no solo "actualizar".
