# REFERENCE — sec-11-02-exception-workflow

> Modelo. No es la única respuesta correcta.

## `ADR.md` (modelo)

### Contexto

Las policies de admisión (Kyverno `ClusterPolicy`) son contractuales: rechazan recursos que violen el baseline. Existen casos legítimos donde el baseline no debe aplicarse (legacy adapter que no se puede firmar, pruebas de performance con `hostNetwork`, etc.). Si no existe un camino formal, los equipos:

- Comentan la regla en el YAML de la policy y abren PR "temporal" que nunca se cierra.
- Editan la policy para añadir su namespace al `exclude` sin revisión.
- Dejan la policy en `Audit` indefinidamente.

Todo lo anterior **erosiona** el baseline y lo vuelve ficticio.

### Decisión

Las excepciones se expresan como objetos declarativos **`PolicyException`** con:

- Anotaciones obligatorias: `requested-by`, `approved-by` (distinto del requester), `ticket`, `expires-at` (ISO date).
- `match` lo más estrecho posible (nombres concretos, no namespaces enteros).
- Vida en Git bajo revisión por platform/security.

### Alternativas rechazadas

- *Editar la policy*: diluye el contrato; nadie revisa.
- *Supresiones en el pipeline* (p. ej. `kyverno apply --exclude`): no visibles en runtime.
- *Whitelist por label sin TTL*: se vuelve regla implícita.

### Consecuencias

- **Pro**: cada excepción es un objeto auditable, con dueño y fecha de muerte. `kubectl get polex -A` es el inventario.
- **Con**: añade un paso (PR + approver). Mitigación: template fácil + SLA de 48 h.

## `TEMPLATE.yaml` (modelo)

```yaml
apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: <team>-<policy>-<yyyy-mm-dd>
  namespace: <team-namespace>
  annotations:
    exception.requested-by: "<requester@acme.com>"
    exception.approved-by:  "<approver@acme.com>"   # distinto del requester
    exception.ticket:       "<SEC-####>"
    exception.expires-at:   "<YYYY-MM-DD>"           # <= 90 dias desde hoy
    exception.reason:       "<motivo tecnico corto>"
spec:
  exceptions:
    - policyName: <nombre-clusterpolicy>
      ruleNames: [<rule1>]
  match:
    any:
      - resources:
          kinds: [Pod]
          namespaces: [<team-namespace>]
          names: [<pod-name-glob-*>]
```

## `PROCESS.md` (modelo)

### Solicitud

- El equipo abre un PR en `platform/exceptions/` añadiendo un `PolicyException` basado en `TEMPLATE.yaml`.
- Debe incluir ticket Jira (`SEC-####`) con contexto técnico, impacto si no se concede, plan de remediación.

### Aprobación

- Reviewer requerido: platform-security team (CODEOWNERS).
- Approver **distinto** del requester (anotación `approved-by`).
- Criterio: la excepción está acotada, tiene TTL ≤ 90 días, y hay un plan de remediación con fecha.

### TTL

- Máximo 90 días. Renovación es un **nuevo** PR, no un `kubectl edit` al TTL.

### Expiración

- `CronJob` nightly que:
  1. Lista `PolicyException` con `expires-at` < hoy + 14 días.
  2. Abre PR automático removiéndolas.
  3. Notifica a `requested-by` por Slack.

### Auditoría

- Kyverno sigue generando `PolicyReport` en modo Audit para los recursos cubiertos por la excepción → nunca pierdes visibilidad.
- Retención: 180 días de `PolicyReport`s en el inventario centralizado (ver `sec-14`).
- Revisión trimestral: platform-security hace *tour* de todas las excepciones vivas y produce un informe (cuántas, cuáles reincidentes, qué equipos acumulan más).
