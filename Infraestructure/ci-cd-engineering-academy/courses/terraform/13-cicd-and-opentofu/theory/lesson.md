# tf-13 · Teoría — CI/CD de Terraform y OpenTofu

> 12 secciones. Nivel producción. Asume `tf-11`, `tf-12`, `gha-11`.

---

## 1. El problema: por qué CI/CD de Terraform es diferente

Un pipeline de aplicación tradicional compila, testea y publica un artefacto. Un pipeline de Terraform **cambia la realidad**: crea VPCs, borra buckets, muta IAM. El `apply` tiene **efectos laterales no retractables**: borrar una base de datos de producción no se deshace con un revert de Git. Eso impone restricciones distintas:

- El cambio debe ser **revisable** antes de ocurrir — el `plan` existe para eso.
- El `apply` debe ejecutar **el mismo cambio** que se revisó — ni más, ni menos.
- El acceso a cloud debe ser **mínimo, efímero y auditable** — nada de credenciales ambientales permanentes.
- Debe existir un **mecanismo humano de aprobación** para el blast radius alto (prod).

Todo el patrón de este módulo deriva de esos cuatro requisitos.

---

## 2. Pipeline canónico: PR → plan, merge → apply

```
┌─────────────────────────┐     ┌─────────────────────────┐
│  Pull Request abierto   │     │  Merge a main           │
│  o actualizado          │     │                         │
└──────────┬──────────────┘     └──────────┬──────────────┘
           │                               │
           ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│  job: plan              │     │  job: apply             │
│  - checkout             │     │  - checkout             │
│  - setup-terraform/     │     │  - setup-terraform/     │
│    opentofu             │     │    opentofu             │
│  - fmt -check           │     │  - download artifact    │
│  - init                 │     │    (plan.tfplan)        │
│  - validate             │     │  - OIDC assume role     │
│  - OIDC assume role     │     │    (prod)               │
│    (read-only)          │     │  - apply plan.tfplan    │
│  - plan -out=plan.tfplan│     │                         │
│  - upload artifact      │     │  gated by:              │
│  - comment plan on PR   │     │  environment: production│
└─────────────────────────┘     └─────────────────────────┘
```

En PR se corre todo lo barato y de solo lectura. En merge se corre lo caro y mutante, con *required reviewers* del environment como gate humano.

Separación clave: el **job de plan asume un rol read-only**, el **job de apply asume un rol con permisos de mutación**. Son dos roles IAM con dos trust policies distintas.

---

## 3. OIDC a cloud: cero credenciales estáticas

Ya se cubrió el mecanismo en `gha-11`. Aquí la aplicación concreta:

```yaml
permissions: {}            # top-level restrictivo

jobs:
  plan:
    permissions:
      id-token: write      # pedir el JWT a GitHub
      contents: read       # checkout del repo
      pull-requests: write # pegar el plan como comentario
    steps:
      - uses: actions/checkout@...
      - uses: hashicorp/setup-terraform@... # o opentofu/setup-opentofu
        with:
          terraform_version: 1.9.5
      - uses: aws-actions/configure-aws-credentials@...
        with:
          role-to-assume: arn:aws:iam::000000000000:role/terraform-plan-ro
          aws-region: eu-west-1
      - run: terraform plan -out=plan.tfplan
```

Dos roles IAM, dos `sub` distintos en la trust:

- `terraform-plan-ro` → `sub = repo:MyOrg/MyRepo:pull_request` (o `:ref:refs/heads/*`).
- `terraform-apply-prod` → `sub = repo:MyOrg/MyRepo:environment:production`.

Sin este desacople, el `plan` del PR tendría los mismos permisos de mutación que el `apply`. Cualquier contributor con PR podría forzar efectos vía código HCL creativo (por ejemplo con un `local-exec` provisioner).

---

## 4. Plan como artefacto: el problema TOCTOU

**TOCTOU** (*Time-Of-Check vs Time-Of-Use*) es una clase de bug en seguridad: entre que verificas una condición y actúas sobre ella, la condición cambió.

En Terraform aparece así:

1. PR genera un `plan` que dice: "voy a crear 1 recurso, modificar 2".
2. Revisor aprueba y mergea.
3. Pipeline de apply corre y, si **recalcula el plan** antes de aplicar, puede ver un estado distinto (p. ej. alguien tocó la consola) y aplicar un **plan diferente al revisado**.

La solución canónica:

```bash
# Job de PR
terraform plan -out=plan.tfplan
# subir plan.tfplan como artefacto

# Job de apply (post-merge)
# descargar plan.tfplan del artefacto
terraform apply plan.tfplan   # <-- sin -auto-approve, sin recalcular
```

`terraform apply <planfile>` aplica *exactamente* ese plan. Si el estado real divergió desde el plan, el apply **falla** (no inventa un plan nuevo), lo que es el comportamiento deseado: alguien debe mirar qué pasó.

Caveats:

- El `.tfplan` **puede contener valores sensibles** (incluidos secretos computados). Se trata como artefacto confidencial, con retención corta y restricción a la organización.
- La versión de Terraform que lo generó y la que lo aplica deben coincidir. De ahí la importancia del lockfile y la versión fija en el setup.
- El state puede haber cambiado entre plan y apply por otro apply concurrente — por eso también el locking del backend (`tf-11`) es necesario, no suficiente.

---

## 5. Coherencia de versión: `required_version` + lockfile + setup-action

Tres barreras complementarias:

```hcl
# versions.tf
terraform {
  required_version = "~> 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}
```

- `required_version` → cualquier binario fuera del rango falla al correr.
- `.terraform.lock.hcl` → fija el **hash exacto** de cada provider. Se commitea. `terraform init -upgrade` lo actualiza y queda en un diff revisable.
- `setup-terraform` / `setup-opentofu` → fija la versión del binario que el runner descarga. Debe coincidir con lo que corren los developers locales.

Sin las tres, el pipeline puede comportarse distinto al local, generar `.tfplan` que el `apply` no sabe leer, o cambiar el formato del state entre runs.

---

## 6. Comentar el plan en el PR

El objetivo es que el revisor **no tenga que abrir el log del workflow** para ver qué va a cambiar. El plan va al hilo del PR como comentario *sticky* (uno por PR, actualizado en cada push).

Patrón mínimo (sin acciones de terceros):

```yaml
- name: Save plan text
  run: terraform show -no-color plan.tfplan > plan.txt

- name: Post plan as PR comment
  uses: marocchino/sticky-pull-request-comment@...
  with:
    header: terraform-plan
    message: |
      ```terraform
      ${{ steps.plan.outputs.stdout }}
      ```
```

Alternativas: `hashicorp/setup-terraform` con `terraform_wrapper: true` captura `stdout`/`stderr` y los expone como outputs; `dflook/terraform-github-actions` publica el plan y además lo guarda como artefacto. La acción concreta importa menos que la propiedad "el revisor ve el plan sin salir del PR".

Guardrails recomendados:

- Si el plan excede ~65 KB (límite de GitHub por comentario), truncar y linkar al run.
- Separar `fmt -check` y `validate` en checks propios, de modo que el PR falle rápido por sintaxis sin esperar al `plan`.
- Marcar el workflow como `required status check` en branch protection.

---

## 7. Environment gating: approval como circuit breaker

El job de `apply` **vive en un `environment:` de GitHub** con *required reviewers* y, opcionalmente, *wait timer* y *deployment branch policy*:

```yaml
jobs:
  apply:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://console.aws.amazon.com/...
    permissions:
      id-token: write
      contents: read
    steps:
      - ...
```

Qué garantiza:

- El job queda **pendiente** hasta que un reviewer aprueba desde la UI de GitHub.
- La trust policy IAM está pinneada a `sub = repo:MyOrg/MyRepo:environment:production`. Si alguien intenta correr el apply fuera del environment, GitHub emite un `sub` distinto y AWS rechaza el assume. Doble barrera.
- La aprobación es *per deployment*: aprobar un apply no autoriza futuros apply.

Branch protection coherente: `main` requiere PR + 1 review + status check de plan verde. Reduce la ventana a: cambio aprobado en código + cambio aprobado en apply.

---

## 8. Drift detection scheduled

Drift = diferencia entre el estado real del cloud y el state de Terraform, causada por cambios fuera del pipeline (consola, otra herramienta, provisioners, autoscaling que modifica tags).

El pipeline normal no detecta drift porque el `plan` del PR corre contra el código del PR; solo captura la diferencia *código → cloud*. Para capturar *cloud → state* existe un job separado:

```yaml
on:
  schedule:
    - cron: "0 6 * * *"   # 06:00 UTC diario
  workflow_dispatch: {}

jobs:
  drift:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
      issues: write
    steps:
      - uses: actions/checkout@...
        with:
          ref: main
      - uses: hashicorp/setup-terraform@...
      - uses: aws-actions/configure-aws-credentials@...
        with:
          role-to-assume: arn:aws:iam::000000000000:role/terraform-plan-ro
      - run: terraform init
      - id: drift
        run: |
          set +e
          terraform plan -refresh-only -detailed-exitcode -no-color -out=drift.tfplan
          echo "exitcode=$?" >> "$GITHUB_OUTPUT"
      - if: steps.drift.outputs.exitcode == '2'
        uses: actions/github-script@...
        with:
          script: |
            github.rest.issues.create({ ... title: "Drift detected on prod" ... })
```

Clave: `-detailed-exitcode` devuelve:

- `0` = sin cambios.
- `1` = error.
- `2` = cambios detectados.

El job **no aplica nada**; abre un issue (o pinga un canal). La decisión de reconciliar es humana (ver `tf-14`).

---

## 9. Runners: hosted vs self-hosted

GitHub-hosted runners son efímeros por job y no comparten estado entre runs. Un self-hosted runner mal gobernado es un vector de robo de credenciales:

- Si inyectas creds AWS en el entorno del runner, cualquier workflow que corra en él las ve, incluidos workflows de otros repos del pool.
- `pull_request_target` + checkout del fork + runner self-hosted = ejecución de código arbitrario con las creds del runner.
- Dejar cache de `.terraform/` sucio entre runs filtra plans y potencialmente state.

Reglas prácticas:

1. **Preferir GitHub-hosted runners** salvo requisitos duros (networking a redes privadas, hardware específico).
2. Si self-hosted es necesario: runners **ephemeral**, uno por job, en VMs desechables. Grupos de runners separados por sensibilidad (prod aislado de PRs públicos).
3. **OIDC siempre, en todos los casos.** No hay creds estáticas que robar aunque alguien gane acceso al runner.

---

## 10. OpenTofu: por qué existe

Línea temporal corta:

- **Pre-2023**: Terraform es Mozilla Public License 2.0 (open source estándar).
- **Agosto 2023**: HashiCorp cambia la licencia a **BUSL** (Business Source License). BUSL es *source-available*, no OSI-approved; restringe uso competitivo durante 4 años antes de revertir a licencia más permisiva.
- **Septiembre 2023**: fork comunitario inicial (OpenTF Manifesto, firmado por Gruntwork, env0, Spacelift, Scalr, etc.).
- **Enero 2024**: la **Linux Foundation** adopta el proyecto como **OpenTofu**, bajo **Apache 2.0**.
- **2024–2025**: convergencia funcional con TF; OpenTofu añade features propias (state encryption nativa, provider-defined functions, `removed` block más completo) y mantiene compatibilidad del lockfile y del state con TF 1.5.x.

Qué es OpenTofu operativamente:

- Binario `tofu` (en lugar de `terraform`).
- Lee los mismos `.tf` que TF.
- Lee y escribe el mismo formato de state.
- Usa su propio Registry (`search.opentofu.org`) pero puede resolver providers del Registry de HashiCorp con configuración explícita.

---

## 11. Compatibilidad y divergencias Terraform ↔ OpenTofu

**Compatibilidad fuerte (al momento de esta lección):**

- **State file**: ambos leen y escriben el mismo formato. Se puede alternar `terraform` y `tofu` sobre el mismo state. Caveat: si `tofu` escribe state usando una feature propia (p. ej. state encryption nativa), `terraform` ya no puede leerlo.
- **HCL**: mismo lenguaje, misma versión. Código escrito para TF 1.5 corre en `tofu` sin cambios.
- **Providers**: los mismos binarios de providers. Ambos consumen plugins vía gRPC con el mismo protocolo. El Registry de OpenTofu reespeja casi todos los providers oficiales.
- **Lockfile**: formato idéntico. Un `.terraform.lock.hcl` generado por `terraform init` se consume por `tofu init` y viceversa.

**Divergencias actuales relevantes:**

- **State encryption nativa**: OpenTofu lo soporta en el lenguaje (`terraform { encryption { ... } }`). TF requiere encriptación a nivel de backend (KMS en S3, etc.) o herramientas externas.
- **`removed` block**: ambos lo soportan; la semántica en OpenTofu permite `removed` sin `moved` previo con menos ceremonia.
- **Provider-defined functions**: OpenTofu permite que un provider exponga funciones usables en HCL (`provider::aws::arn_parse(...)`). TF las ganó más tarde.
- **Early evaluation de variables**: OpenTofu permite usar `var.*` en configuración de backend y en `required_version`. TF no.
- **Testing**: `terraform test` (TF) y `tofu test` (OpenTofu) convergieron en sintaxis pero divergen en features de mocking.

**No divergencia que importe para una migración trivial de 2025:** si tu stack no usa las features propias de OpenTofu arriba listadas, el cambio es *reemplazar binario* más *actualizar la acción de setup en CI*.

---

## 12. Criterio de migración: cuándo pasar a OpenTofu

Un ADR Terraform vs OpenTofu debería ponderar al menos cinco ejes:

| Eje | Pregunta clave |
|---|---|
| **Licencia** | ¿Mi organización puede/quiere usar software BUSL? ¿Hay cláusulas competitivas que me afecten (soy vendor que ofrece IaC gestionado)? |
| **Features propias** | ¿Necesito state encryption nativa, provider-defined functions, early evaluation? |
| **Soporte comercial** | ¿Compro HCP Terraform / Terraform Enterprise? ¿O prefiero un vendor neutral (Scalr, Spacelift, env0) que soporta ambos? |
| **Riesgo de proveedor** | ¿Qué peso doy al riesgo de otro cambio de licencia unilateral? |
| **Costo de migración** | ¿Cuánto HCL tengo, cuánta política interna asume `terraform` como binario, cuántos pipelines debo tocar? |

Reglas de dedo defendibles (no absolutas):

- **Equipos pequeños, stacks < 50 módulos, sin HCP Terraform**: migrar a OpenTofu es casi gratis y elimina el riesgo de licencia.
- **Organizaciones ya en HCP Terraform / Enterprise**: quedarse en TF, el beneficio de OpenTofu no justifica perder la plataforma.
- **Vendors que ofrecen IaC gestionado como producto**: OpenTofu, obligatorio por BUSL.
- **Entornos regulados con requisito de state encryption en reposo**: OpenTofu simplifica el control, aunque backend-level encryption en TF también cumple.

Plan de migración mínimo si decides moverte:

1. Pinnear versión actual de Terraform (`required_version = "~> 1.5.0"`), congelar.
2. En un branch, cambiar `terraform` → `tofu` en pipelines, probar `tofu init` + `tofu plan`. Lockfile y state deben ser compatibles.
3. Correr el pipeline completo en un ambiente no-prod. Diff del plan debe ser *vacío* (prueba de equivalencia).
4. Promoción progresiva por ambiente: dev → stg → prod.
5. Removal: borrar el binario `terraform` de los runners.
6. Documentar en ADR el nuevo estado y las features de OpenTofu que ahora puedes usar.

El ADR es el entregable principal del `tf-13` — no basta con "lo migré"; hace falta registrar *por qué*.
