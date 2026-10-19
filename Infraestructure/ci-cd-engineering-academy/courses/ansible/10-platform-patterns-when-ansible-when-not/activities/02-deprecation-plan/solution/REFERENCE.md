# REFERENCE — ans-10-02-deprecation-plan

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

---

# ADR 011 — Deprecación de `playbooks/deploy-checkout-to-eks.yml`

## Estado

Propuesto (Fase 3). Aceptado tras revisión conjunta platform-sre + tech lead del team `checkout` + SRE on-call lead. Ejecución agendada en Fase 4.

## Contexto

El playbook `playbooks/deploy-checkout-to-eks.yml` existe en `ops/ansible` desde hace 18 meses. Se escribió cuando Argo CD aún no estaba estable; usa `kubernetes.core.k8s` para aplicar los manifiestos del servicio `checkout` al cluster EKS `prod-eu-west-1` desde `files/manifests/checkout/*.yaml`.

Hoy la situación cambió:

- Argo CD lleva **12 meses sin incidentes mayores**.
- Existe un `ApplicationSet` en `platform-gitops/apps/checkout/`, propiedad del team `checkout`, que **es la fuente de verdad** del despliegue.
- En los últimos 60 días el playbook se ejecutó **4 veces**: 1 durante un incidente que no estaba relacionado con el deploy, 3 "por costumbre". Las 4 veces Argo CD revirtió el diff y disparó alerts en `#platform-oncall`.
- El contrato de plataforma Ansible (ADR 010) sitúa "apps en Kubernetes" como anti-patrón duro (fila 1 "no").

Mantener el playbook es deuda: cada ejecución futura es un drift potencial y una alert innecesaria. Borrarlo sin plan es un riesgo (algún consumer no documentado podría romperse). Este ADR define el camino intermedio: deprecación controlada en 6 semanas.

## Decisión

### 1. Criterios por los que se marca deprecado

1. **Dominio cambió**: la app es un deploy K8s; el contrato (ADR 010) prohíbe Ansible para este dominio.
2. **Herramienta nueva encaja mejor**: Argo CD + ApplicationSet reconcilia continuamente; el playbook es un one-shot.
3. **Drift observado**: 4 ejecuciones en 60 días, todas revertidas por Argo CD. El playbook actúa en contra del sistema correcto.
4. **Uso bajo + riesgo elevado**: nadie sabe cuándo correrlo, pero toca producción. Costo de mantenerlo > valor que aporta.
5. **Dependencia estable del reemplazo**: Argo CD 12 meses sin incidentes mayores — el reemplazo es production-ready.

### 2. Reemplazo recomendado y migration path

- **Reemplazo**: `ApplicationSet` existente en `platform-gitops/apps/checkout/`, generado por template `checkout/{{env}}/`.
- **Migration path**: **no requiere migración de código** — el reemplazo ya está en producción desde hace 12 meses, es authoritative y los PRs al servicio ya pasan por él.
- **Lo único que migra es la "memoria operacional"**: documentar en el runbook del team `checkout` que para forzar una sincronización fuera de ciclo se usa `argocd app sync checkout-prod` (con permiso del Argo CD RBAC apropiado), no `ansible-playbook deploy-checkout-to-eks.yml`.

### 3. Owners y stakeholders

| Rol | Persona / team | Responsabilidad |
|-----|---------------|-----------------|
| DRI (Decider Responsible Individual) | @alice (platform-sre) | Dueña del ADR y de la ejecución del plan. |
| Owner del playbook | @bob (team checkout tech lead) | Confirma que su team no depende del playbook. |
| SRE on-call lead | @carol | Confirma que no se usa en runbooks de incidentes. |
| Security | @dave | Confirma que no hay un audit requirement contra el playbook. |
| Audiencia | #platform-announcements + #team-checkout | Reciben los anuncios. |

### 4. Fases y fechas

```text
Semana 0  (lunes)  ANUNCIO
                   - PR al repo marca el playbook con header # DEPRECATED
                     y fecha de removal (semana 6).
                   - Mensaje en #platform-announcements y #team-checkout.
                   - Entry en el CHANGELOG del repo.
                   - Comentario en el job template de AWX con el link al ADR.

Semana 2  (lunes)  FREEZE
                   - CODEOWNERS bloquea cambios al playbook salvo bugfix critico.
                   - Recordatorio en Slack.

Semana 4  (lunes)  CANARY
                   - Deshabilitar el job template en AWX (no borrar).
                   - Monitorear 2 semanas: alerts, tickets, menciones en Slack.
                   - Si aparece un consumer no documentado, se re-evalua.

Semana 6  (jueves) CORTE
                   - Mover playbook a archived/deploy-checkout-to-eks.yml.
                   - Borrar el job template de AWX (export previo guardado en
                     repo-backups/awx-exports/ por rollback).
                   - Cerrar el ticket PLAT-1234.

Semana 7  (lunes)  POST-MORTEM corto
                   - Que aprendimos (15 min meeting).
                   - Update del contrato de plataforma si procede.
                   - Agregar a plantilla reutilizable de deprecaciones.
```

### 5. Canary de corte

- Deshabilitar el **job template en AWX** (no borrar aún) corta el 100% del acceso vía UI/API controlado. Si alguien intenta correr → error claro con link al ADR.
- Ventana de 2 semanas de observación.
- Métricas a monitorizar:
  - Alerts en `#platform-oncall` relacionadas a `checkout` (debería caer a 0 relacionadas con el playbook).
  - Tickets abiertos mencionando `deploy-checkout-to-eks`.
  - Preguntas en Slack sobre el playbook.
- Si en 2 semanas no hay señal de uso, se procede al corte definitivo.

### 6. Plan de rollback

Si en la semana 6 o inmediatamente después del corte se detecta un impacto imprevisto:

1. **Re-habilitar el job template** en AWX desde el export guardado (`awx-cli import repo-backups/awx-exports/jt-deploy-checkout-to-eks.yml`).
2. **Restaurar el playbook** desde `archived/` a su ubicación original (es un `git mv` reverso).
3. **Añadir approval obligatorio** al job template (manual, con tech lead del team) para evitar uso "por costumbre".
4. **Replanificar** el corte 2 semanas más tarde con el consumer identificado migrado.
5. **Post-mortem más largo** (1 h) para entender por qué el canary no detectó el consumer.

El rollback debe poder ejecutarse en ≤ 30 min por un SRE on-call.

### 7. Comunicación

- **Canal principal**: `#platform-announcements` (anuncio semana 0, recordatorio semana 2, aviso de canary semana 4, confirmación de corte semana 6).
- **Canal secundario**: `#team-checkout` (los stakeholders directos).
- **Email a tech leads de todos los teams** en semana 0 y semana 4 (por si algún team olvidado usa el playbook).
- **Mensaje en el ticket de change management** (si la org exige ServiceNow / Jira change para prod).
- **Template de mensaje**:

  ```
  [DEPRECATION] playbooks/deploy-checkout-to-eks.yml
  Fecha de corte: <YYYY-MM-DD>
  Reemplazo: Argo CD ApplicationSet (platform-gitops/apps/checkout/)
  Contexto: ADR 011 (link).
  Si tu team usa este playbook, responde en este thread antes del <YYYY-MM-DD - 2w>.
  Owner: @alice (platform-sre).
  ```

## Consecuencias

### Positivas

- Eliminación de 4 alerts/mes falsas y de drift repetido en EKS prod.
- Un ejemplo concreto que refuerza el contrato (ADR 010) — podemos citarlo en futuros debates.
- La plantilla de este ADR es reutilizable para las próximas 3–5 deprecaciones previstas.
- El team `checkout` reduce su carga mental (una herramienta menos que recordar).

### Negativas

- Durante 6 semanas, el team `checkout` tiene que recordar "no usar el playbook" — pequeña fricción cognitiva.
- Si un SRE on-call reflexivamente lanza el playbook en un incidente futuro (y falla), tendrá que leer el ADR en el peor momento. Mitigación: el error que mostramos cuando el job template está deshabilitado lleva el link al ADR y al runbook del reemplazo.
- Overhead de ejecución del plan (~ 4 h de trabajo distribuidas en 6 semanas).

## Alternativas descartadas

### Alt A — "Dejarlo por si acaso"

- **Por qué no**: el drift observado prueba que "por si acaso" acaba siendo "por error". El costo de mantener el playbook (reviews, alerts, confusión) excede su valor como seguro — hay un seguro mejor (rollback de Argo CD).

### Alt B — "Borrarlo sin anuncio"

- **Por qué no**: viola el contrato (ADR 010 §7 — proceso de excepciones) y es malo culturalmente: equipos aprenden que la plataforma mueve el suelo bajo sus pies. 30 días de preaviso es el mínimo humano.

### Alt C — "Reescribirlo como workflow en AWX con approval y mantenerlo"

- **Por qué no**: añade overhead de mantener un flujo paralelo a Argo CD. Dos sources of truth es peor que una. El objetivo es que exista **un solo deployer** por aplicación.

---

## Lecciones para la plantilla reutilizable

- Las fases **anuncio / freeze / canary / corte / post-mortem** son generales — reutilizarlas por default.
- El canary vía "disable job template" (no borrar) es más seguro que borrar el playbook directamente.
- El export previo del job template en `repo-backups/awx-exports/` es la pieza clave del rollback barato.
- Comunicación por **dos canales mínimo** (announcement + team-específico) + email a tech leads en semana 0 y semana 4.
- Métricas de canary: alerts + tickets + menciones en Slack — definir siempre antes de empezar.
