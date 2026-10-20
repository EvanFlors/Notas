# Starter — ans-10-02-deprecation-plan

Esta actividad es **independiente**: no hay código ejecutable. El entregable es un ADR Markdown.

## Pasos

1. Lee `../README.md` y la sección §10 de `../../theory/lesson.md`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/ans-10-deprecation
   cd /tmp/ans-10-deprecation
   ```
3. Crea `ADR-DEPRECATION-PLAN.md` con las 6 secciones ADR y el contenido mínimo exigido por el validador.
4. Valida:
   ```bash
   bash <ruta-repo>/courses/ansible/10-platform-patterns-when-ansible-when-not/activities/02-deprecation-plan/tests/validate.sh /tmp/ans-10-deprecation
   ```
5. Compara con `../solution/REFERENCE.md`.

## Plantilla sugerida

```markdown
# ADR 011 — Deprecación de playbooks/deploy-checkout-to-eks.yml

## Estado
Propuesto

## Contexto
<historia del playbook: 18 meses, se escribió cuando Argo CD no estaba estable;
hoy Argo CD estable, drift observado 4 veces en 60 dias; owner nominal: team checkout>

## Decisión

### 1. Criterios por los que se marca deprecado
- Dominio cambió: la app corre en EKS y hay ApplicationSet propiedad del team checkout.
- Drift observado: 4 ejecuciones en 60 días, todas revertidas por Argo CD.
- Uso bajo + riesgo elevado: nadie sabe cuándo correrlo pero toca prod.
- Contrato de plataforma (ADR-ANSIBLE-CONTRACT): fila 1 "no" — apps K8s → Helm + Argo CD.

### 2. Reemplazo recomendado y migration path
- Reemplazo: Argo CD ApplicationSet existente en platform-gitops/apps/checkout/.
- Migration path: no requiere migración de código — el reemplazo ya está en producción desde hace 12 meses y es authoritative.

### 3. Owners y stakeholders
- DRI: platform-sre (DRI del contrato), @alice.
- Team afectado: checkout (3 ingenieros), @bob (tech lead).
- SRE on-call: notificar al rotation.
- Comunicación: canal Slack #platform-announcements + #team-checkout.

### 4. Fases y fechas
```text
Semana 0:  Anuncio    → PR marca playbook DEPRECATED, mensaje en Slack
Semana 2:  Freeze     → no se aceptan PRs al playbook (CODEOWNERS bloquea)
Semana 4:  Canary     → disable job template en AWX para team checkout
Semana 6:  Corte      → mover playbook a archived/, borrar job template
Semana 7:  Post-mortem corto + update del contrato si procede
```

### 5. Canary de corte
<deshabilitar el job template en AWX para team checkout; monitorear 2 semanas>

### 6. Plan de rollback
<si el corte produce impacto: restaurar job template desde export AWX;
re-ejecutar playbook desde archived/ con approval manual; sunset en 2 semanas>

### 7. Comunicación
<canal, cadencia, template de mensaje>

## Consecuencias
### Positivas
- ...
### Negativas
- ...

## Alternativas descartadas
### Alt A: dejar el playbook "por si acaso"
- Por qué no: ...
### Alt B: borrar sin anunciar
- Por qué no: ...
```
