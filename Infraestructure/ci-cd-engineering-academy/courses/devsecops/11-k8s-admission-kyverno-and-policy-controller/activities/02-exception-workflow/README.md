# Actividad 02 — Workflow de excepciones (`PolicyException` + ADR)

## 1. Identificación

- **ID:** `sec-11-02-exception-workflow`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-11-k8s-admission-kyverno-and-policy-controller`
- **Dificultad:** advanced
- **Duración:** 45–60 min
- **Tipo:** independent

## 2. Contexto

Toda policy sana necesita un camino para la excepción legítima. Sin él los equipos saltan la policy por detrás ("la quito un ratito y luego la pongo"), y "excepción temporal" se vuelve permanente.

Vas a producir:

1. Un **ADR** (`ADR.md`) que fije *por qué* las excepciones viven como objetos declarativos (`PolicyException`) y no como edits al código de la policy ni como supresiones no auditables.
2. Una **plantilla** `TEMPLATE.yaml` de `PolicyException` lista para que un equipo la rellene.
3. Un **proceso** (`PROCESS.md`) describiendo quién pide, quién aprueba, cuándo expira, cómo se audita.

No requiere cluster.

## 3. Objetivos

- Documentar el workflow (solicitante, approver distinto, ticket, TTL).
- Producir una `PolicyException` plantilla con anotaciones de auditoría.
- Escribir un ADR corto defendiendo la decisión.
- Detallar el proceso de expiración (quién detecta vencidas, cómo se re-evalúa).

## 4. Prerrequisitos

- `../../theory/lesson.md` §8.
- Haber visto la actividad 01 ayuda (misma familia de policies) pero **no** es prerrequisito.
- **Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar directorio

```bash
mkdir -p /tmp/sec-11-exception
cd /tmp/sec-11-exception
```

### 5.2 Escribir `ADR.md`

Formato ADR corto:

- **Contexto** — por qué hace falta un workflow.
- **Decisión** — "Las excepciones viven como `PolicyException` con anotaciones de auditoría; no se suprimen en el código de la policy ni en el pipeline."
- **Alternativas rechazadas** — p.ej. "comentar la regla temporalmente", "whitelist de labels sin TTL", "editar la policy".
- **Consecuencias** — qué gana, qué cuesta.

### 5.3 Escribir `TEMPLATE.yaml`

Una `PolicyException` plantilla con placeholders (`<...>`) para:

- `metadata.name`, `metadata.namespace`.
- Anotaciones `exception.requested-by`, `exception.approved-by`, `exception.ticket`, `exception.expires-at`.
- `spec.exceptions[].policyName` y `ruleNames`.
- `spec.match` con el scope mínimo (namespace / nombres).

### 5.4 Escribir `PROCESS.md`

Secciones mínimas:

- **Solicitud** — formulario / PR / issue; qué datos.
- **Aprobación** — approver distinto del solicitante; criterio de aprobación.
- **TTL** — máximo 90 días; cómo se renueva.
- **Expiración** — CronJob / scheduled workflow que lista las vencidas y abre PR para removerlas.
- **Auditoría** — qué queda en `PolicyReport`; retención.

## 6. Entregable

```
/tmp/sec-11-exception/
├── ADR.md
├── TEMPLATE.yaml
└── PROCESS.md
```

## 7. Validación

```bash
bash tests/validate.sh /tmp/sec-11-exception
```

## 8. Limpieza

```bash
rm -rf /tmp/sec-11-exception
```

## 9. Preguntas de reflexión

1. Un equipo pide una excepción "permanente" porque su legacy adapter no se puede firmar. ¿Qué contrapropones?
2. ¿Qué métrica medirías para detectar que el workflow se está volviendo un rubber-stamp?
3. ¿Dónde debería vivir el `PolicyException`: en el repo del equipo o en el repo de platform? ¿Por qué?
