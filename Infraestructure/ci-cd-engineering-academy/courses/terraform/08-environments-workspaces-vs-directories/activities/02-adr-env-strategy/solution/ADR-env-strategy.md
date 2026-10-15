# ADR-001 — Estrategia de ambientes para Terraform (Shoply)

> ADR de referencia. Es *una* respuesta válida, no la única.

## 1. Estado

Propuesto.

## 2. Fecha

2026-10-15.

## 3. Autores

SRE lead, Terraform tech lead.

## 4. Contexto

Shoply opera hoy su IaC con un único root module en el monorepo `shoply/infra`. Los ambientes se seleccionan con `terraform workspace select {default|stg|prod}`. Los tres workspaces comparten:

- El mismo bucket S3 para el state (`shoply-tf-state`, keys `env:/stg/terraform.tfstate` y análogos).
- Las mismas credenciales en el runner de GitHub Actions.
- El mismo código HCL evaluado con ternarios dependientes de `terraform.workspace`.

En septiembre de 2026 un ingeniero ejecutó `terraform destroy` creyendo estar en `stg`; estaba en `prod`. El destrozo fue parcial pero causó 40 min de downtime. Postmortem identificó la causa raíz como *acoplamiento de ambientes al nivel de workspace de CLI*: no existe barrera técnica que impida tocar prod desde la laptop/pipeline de otro ambiente.

## 5. Riesgos del status quo

- **R1 — Blast radius unificado**: cualquier credencial válida puede escribir en los tres ambientes. Una filtración de la credencial del runner expone prod inmediatamente.
- **R2 — Operacional confusa**: `terraform workspace select` no tiene feedback visual persistente. El propio incidente de `destroy` ocurrió por esta razón.
- **R3 — Policies no diferenciables**: no se puede exigir vía código, p. ej., "en prod no se permiten tipos de instancia `t3.*`" sin ramificar el HCL por `terraform.workspace`, perpetuando el acoplamiento.
- **R4 — Promoción no trazable**: los tres ambientes consumen *la misma* versión del HCL en cada commit. No existe forma natural de rollback-only-prod ni de "congelar" prod mientras se experimenta en stg.
- **R5 — Auditoría laboriosa**: "¿qué está en prod?" requiere `workspace select prod && state list`, no una inspección estática del repo.

## 6. Decisión

**Decisión:** migrar a *directorios separados por ambiente con módulos locales compartidos* (`envs/{dev,stg,prod}` + `modules/`), con **un backend S3 distinto por ambiente** y **credenciales OIDC distintas por ambiente** vía GitHub Environments. Workspaces se reservan exclusivamente para feature envs efímeros bajo `envs/dev/`.

Justificación:

- Elimina R1: el runner de PR tendrá credenciales efímeras OIDC emitidas sólo para `shoply-dev` o `shoply-stg`; el runner de `apply` a prod requiere approval en el environment `prod` de GHA. Un `apply` desde el runner equivocado no puede escribir en el backend de prod — IAM lo rechaza.
- Elimina R2: los directorios son explícitos; `pwd` siempre dice en qué ambiente estás.
- Resuelve R3: `envs/prod/providers.tf` puede imponer providers/versiones distintos, y los checks de policy (Checkov, OPA) pueden gatearse por ruta.
- Mitiga R4 parcialmente ahora, y abre la puerta a módulos versionados (siguiente ADR) para resolverlo del todo.
- Resuelve R5: `tree envs/` muestra qué hay en cada ambiente sin ejecutar nada.

## 7. Alternativas consideradas

- **Terragrunt** — potente para reducir boilerplate, pero añade una herramienta más al stack cognitivo y a los runners. Postponemos hasta que la duplicación de boilerplate sea el cuello de botella real (medimos a los 6 meses).
- **Workspaces mejorados con convenciones** (p. ej. prohibir `workspace select` manual en prod) — no resuelve el riesgo técnico. Las convenciones no sobreviven a los incidentes; las barreras IAM sí.
- **Multi-repo (`shoply-infra-dev`, `shoply-infra-stg`, `shoply-infra-prod`)** — máxima separación, pero multiplica el costo de PR cruzadas (hoy 8 ingenieros = sobrecoste alto). Volveremos a evaluarlo si crecemos a > 25 ingenieros.

## 8. Consecuencias

Positivas:

- Blast radius acotado al ambiente de la credencial activa.
- Permisos y aprobaciones diferenciables por ambiente (CODEOWNERS por path, GHA environments).
- `destroy` accidental deja de ser posible cross-env.
- Base para futuro versionado de módulos.

Negativas / costo:

- Duplicación de boilerplate en cada `envs/<X>/` (versions.tf, backend.tf, llamada al módulo).
- Costo de migración (sección 9).
- Mientras no versionemos módulos, un cambio al módulo compartido impacta a los tres ambientes en el próximo `apply` de cada uno — mitigable con PR + revisión + `plan` previo.

## 9. Plan de migración

1. **Bootstrap**: crear tres buckets S3 (`shoply-tf-state-{dev,stg,prod}`) con versioning y SSE-KMS. Crear tres roles IAM distintos (`shoply-tf-apply-{dev,stg,prod}`) con permiso de escritura **sólo** a su bucket y a los recursos de su cuenta.
   - *Validación*: `aws s3 ls` desde cada rol sólo ve su bucket.
   - *Rollback*: borrar buckets y roles; no afecta el stack actual.
2. **Refactor del HCL**: extraer la lógica a `modules/app/`. Crear `envs/{dev,stg,prod}/` con roots que consumen el módulo. Mergear sin apply.
   - *Validación*: `terraform validate` en cada env; CI corre `plan` contra los backends nuevos (vacíos) y muestra "create everything" — como se espera.
   - *Rollback*: revertir el PR; el stack monolítico sigue intacto.
3. **Migración del state por ambiente**: para cada ambiente, uno por uno (empezando por `dev`):
   - Hacer `terraform state pull` del workspace actual en el backend viejo.
   - Hacer `terraform state push` al backend nuevo del ambiente.
   - Ejecutar `terraform plan` en el nuevo root: debe reportar **cero cambios**.
   - *Validación*: `plan` limpio; `apply` idempotente.
   - *Rollback*: `terraform state push` del state original al backend viejo.
4. **Switch del pipeline**: actualizar GitHub Actions para que `envs/dev/` corra con `OIDC → shoply-tf-apply-dev`, análogo para stg/prod; añadir environment `prod` con required reviewers.
   - *Validación*: PR de prueba, approval, apply.
   - *Rollback*: revertir el workflow.
5. **Deprecar el root monolítico**: tras 2 ciclos limpios (~2 semanas) sobre los tres ambientes nuevos, borrar el root viejo del repo y archivar el bucket de state viejo (sin eliminar — mantener 90 días por auditoría).
   - *Validación*: nada que validar activamente; grep de `terraform.workspace` en el repo = 0 referencias (excepto en `envs/dev/` para feature envs).
   - *Rollback*: restaurar desde Git si fuera necesario, pero a esta altura no debería serlo.
