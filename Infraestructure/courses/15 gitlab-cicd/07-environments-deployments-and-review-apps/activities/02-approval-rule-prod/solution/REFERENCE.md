# REFERENCE — gl-07-02-approval-rule-prod

> Una **referencia** razonada. No es la unica respuesta correcta — es un modelo contra el que compararte.

---

## `protected-environment.yaml`

```yaml
name: production
deployment_tier: production
deploy_access_levels:
  - group: platform-admins
# No habilitamos deploy_access_levels por access_level (p. ej. maintainer)
# porque "maintainer" en este proyecto incluye a mas gente de la que
# queremos que pueda tocar prod. Preferimos el principio de minimo
# privilegio: un grupo explicito.
```

## `approval-rules.yaml`

```yaml
environment: production
approval_rules:
  - group: sre
    required_approvals: 1
  - group: security
    required_approvals: 1
# Dos reglas separadas = ambas se deben satisfacer (AND). Si en el futuro
# queremos "o uno de SRE o uno de Security", seria una sola regla con
# los dos grupos listados y required_approvals: 1 (requiere Ultimate en
# algunas versiones).
```

---

# ADR 002 — Protected environment `production` con approval multi-equipo

## Estado

Aceptado (post-mortem del incidente del 2026-04-11). Pendiente de aplicar via Terraform modulo `gitlab/protected_environments`.

## Contexto

El 2026-04-11 un deployment a `production` sin revision humana aplico una migracion de base de datos destructiva. Resultado: 2h de downtime, SLA incumplido, ~15k EUR en credit refund. El post-mortem identifico dos huecos:

1. **Cualquier maintainer** podia ejecutar un pipeline que apuntara a `production`. No habia restriccion por rol funcional.
2. **No habia gate humano** entre "el pipeline tiene un job marcado como `when: manual`" y "el job arranca". Un maintainer apretar "Play" era suficiente.

El equipo definio en el post-mortem el requisito:

- Deploy a `production` restringido a un grupo explicito (`@platform-admins`, 4 personas).
- Approval de al menos 1 miembro de SRE **y** 1 miembro de Security antes de cada deployment.

Constraints:

- Plan GitLab actual: Ultimate (approval rules estan incluidas).
- Horario: on-call cubre 24/7 en SRE y Security. El gate no bloquea deploys urgentes.
- Compliance: tenemos que poder mostrar al auditor que ningun deployment a prod paso sin aprobacion registrada.

## Decision

Modelar `production` como **protected environment** con:

- **`deploy_access_levels`**: solo el grupo `@platform-admins` (4 personas, lista revisada trimestralmente).
- **`approval_rules`**: dos reglas AND:
  - `group: sre, required_approvals: 1`.
  - `group: security, required_approvals: 1`.

Representacion YAML (ver `protected-environment.yaml` + `approval-rules.yaml` adjuntos):

```yaml
# protected-environment.yaml
name: production
deployment_tier: production
deploy_access_levels:
  - group: platform-admins

# approval-rules.yaml
environment: production
approval_rules:
  - group: sre
    required_approvals: 1
  - group: security
    required_approvals: 1
```

### Diferencia critica: `rules:` vs approval rule

Un `rules: - if: ... when: manual` en el `.gitlab-ci.yml` controla **cuando el job entra al pipeline** y **si arranca automatico o requiere click**. **No** es un gate de aprobacion. Cualquiera con permiso de ejecutar jobs puede apretar "Play".

Un **approval rule** del protected environment vive en Settings (no en `.gitlab-ci.yml`) y actua **despues** de que alguien lanzo el job: el job queda `waiting for approval` hasta recibir el minimo de aprobaciones. Son planos ortogonales y necesarios.

El pipeline queda como:

```yaml
deploy_production:
  stage: deploy
  script: ./deploy.sh --env production --sha "$CI_COMMIT_SHA"
  environment:
    name: production
    url: https://app.example.com
    deployment_tier: production
  rules:
    - if: $CI_COMMIT_TAG =~ /^v[0-9]+\.[0-9]+\.[0-9]+$/
      when: manual
```

El `rules:` filtra a tags SemVer y marca manual. **Encima** de eso, el protected environment aplica `deploy_access_levels` + `approval_rules`.

### Comparacion con GitHub Actions

En GHA, el equivalente es un Environment con `required_reviewers: [sre, security]`. Modelo similar, mas simple (no distingue "deploy access" de "approval"), pero con menos granularidad: en GHA no puedes decir "1 de SRE **y** 1 de Security"; solo "N aprobadores de este set". GitLab aporta la precision de reglas AND por grupo. Esta precision es la que justifico tecnicamente la eleccion de GitLab vs GHA en nuestro ADR corporativo (fuera de scope aqui).

## Consecuencias

Positivas:

- Imposible desplegar a prod sin dos aprobaciones registradas → auditabilidad.
- `platform-admins` acotado a 4 personas → principio de minimo privilegio.
- El widget de approval en el MR da visibilidad: todos ven quien aprobo y cuando.
- Zero reconfiguracion del pipeline en el futuro: cambiar la politica es editar los YAML, no el `.gitlab-ci.yml`.

Negativas:

- Un deploy en horario nocturno puede tardar 5-15 min adicionales esperando a que el oncall de SRE y Security aprueben.
- Si un grupo tiene problemas de disponibilidad (vacaciones + enfermedad simultaneas), el gate bloquea. Mitigacion: cada grupo tiene minimo 3 miembros, rotacion on-call documentada.
- Dependencia de Ultimate: si bajamos a Premium, approval rules dejan de funcionar y hay que replantear.

## Alternativas descartadas

### 1. Solo `deploy_access_levels` sin approval rules

Restringir deploy a `platform-admins` y confiar en que ellos revisen "con cuidado". **Descartado**: el post-mortem demostro que la revision informal falla; necesitamos trazabilidad explicita (quien aprobo, cuando). Un `deploy_access_levels` sin approval es *autenticacion* sin *autorizacion registrada*.

### 2. Approval rule con un solo grupo (`sre, required_approvals: 2`)

Mas simple de administrar, pero perdemos el angulo de seguridad. Un bug de seguridad introducido via deploy no seria capturado por un segundo SRE que no mira el angulo de seguridad. Prefiero la **diversidad de perspectiva** (SRE + Security) a la cantidad (2 SREs).

### 3. Replicar la politica en GitHub Actions con required reviewers

Costaria migracion de plataforma. GHA cubre el caso basico ("N reviewers") pero no la precision AND entre grupos distintos. Descartado por costo migratorio + perdida de granularidad.

### 4. Gate externo (p. ej. ArgoCD con approval webhook)

Mover el gate fuera de GitLab a ArgoCD/Spinnaker. Mas complejo de operar y añade otra pieza al stack. Reservado para cuando (si) migremos CD a Argo. Mientras tanto, GitLab resuelve el caso nativo.

---

## Notas de implementacion

- Aplicar via Terraform `gitlab_project_protected_environment` y `gitlab_deployment_approval_rule` (verificar en Fase 4 que el provider soporta las dos piezas; si no, parchar via API con un `null_resource`).
- Revisar membership de `platform-admins`, `sre` y `security` trimestralmente (recordatorio en el calendario del equipo de Platform).
- Monitorear tiempo medio de aprobacion (metrica `deployment_approval_wait_seconds`). Si > 30 min P95 en horario laboral, revisar el proceso.
- Documentar el **break-glass**: fuera de horario, con incidente activo, un unico aprobador on-call puede desbloquear via un procedimiento documentado (fuera de scope de este ADR; vivira en `RUNBOOK-ONCALL.md`).
