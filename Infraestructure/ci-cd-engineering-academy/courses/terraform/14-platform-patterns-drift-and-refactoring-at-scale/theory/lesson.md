# Lección: Platform patterns, drift management y refactoring a escala

> **ID:** `tf-14-platform-patterns-drift-and-refactoring-at-scale` · **Nivel:** producción · **Duración:** 6 h
> **Prerrequisitos:** `tf-09`, `tf-11`, `tf-12`, `tf-13`.

---

## 1. Introducción intuitiva

Hasta aquí, Terraform fue una herramienta: la usabas tú (o tu equipo) para describir infra. En producción, en una organización con 10, 50 o 500 ingenieros, Terraform deja de ser una herramienta y se vuelve una **plataforma**. Hay una pregunta operativa que cambia todo: *¿quién puede desplegar qué, cómo, con qué controles, y qué pasa cuando alguien hace cambios por fuera?*

Imagina tres escenarios reales:

1. Una developer backend tiene que lanzar un microservicio nuevo. ¿Escribe 400 líneas de HCL para VPC, subnets, IAM roles, cluster, task definition, service, ALB, DNS, dashboards, alertas, logs? ¿O usa un módulo `platform/microservice-eks` que ya trae lo correcto y solo pide 10 variables (`service_name`, `image`, `cpu`, `memory`, `desired_count`, …)?
2. El equipo de seguridad descubre que alguien habilitó un endpoint público en un bucket "para un test". ¿Cómo se enteran? ¿Lo revierten? ¿O lo "adoptan" porque hay una razón real?
3. Hay 80 stacks que usan `module.vpc` v1.3.0. Hay un bug de seguridad que exige v1.4.0. ¿Cómo se migran los 80 sin romper nada?

Las tres son el tema de este módulo. Y las tres se resuelven igual: con **contratos explícitos** entre la plataforma IaC y los equipos de producto, y con mecánicas de Terraform que convierten operaciones de riesgo (adoptar, renombrar, sacar del state, bumpear majors) en **cambios revisables en PR**.

Si `tf-01…tf-13` fueron sobre operar Terraform, este módulo es sobre **operar una organización que usa Terraform**.

---

## 2. Fundamentos

### 2.1 Qué es un "golden path"

Un **golden path** (también "paved road") es la ruta recomendada, soportada y auditada para hacer algo común en la org. No prohíbe salirse — hace que no quieras salirte. Un developer que usa el golden path obtiene: módulos probados, políticas aprobadas, pipeline CI/CD listo, dashboards por defecto, soporte del equipo de plataforma. Un developer que se sale consigue: autonomía total, y la responsabilidad total.

En Terraform, el golden path se materializa como un **módulo opinionado** publicado en un **registry interno** y versionado con **SemVer**. El contrato del módulo es:

- **Inputs**: lo que el equipo de producto decide (nombre del servicio, imagen, réplicas, DNS).
- **Internals opinionados**: lo que la plataforma decide por ti (naming convention, tags obligatorios, encryption, logging, políticas IAM mínimas, networking).
- **Outputs**: lo que la plataforma te promete devolver (URL del servicio, ARN, nombre del log group).

### 2.2 Qué es un module registry

Un **registry** es un sistema que:

1. Almacena versiones inmutables de un módulo (`v1.0.0`, `v1.0.1`, `v2.0.0`).
2. Permite a consumidores declarar la versión que quieren (`version = "~> 1.0"`).
3. Garantiza que `v1.0.0` siempre devuelve el mismo bundle de archivos (inmutabilidad).

Terraform soporta varios transportes como `source`:

- **Terraform Registry** público (`terraform-aws-modules/vpc/aws`): internet, útil para open source.
- **Registry privado HCP** / Artifactory / GitLab (hablan el *Terraform Registry Protocol*): recomendado en empresa.
- **Git tag/branch/ref** (`git::https://host/org/repo.git?ref=v1.0.0`): universal, funciona siempre, requiere disciplina de tagging.
- **Local path** (`./modules/vpc`): no es un registry; es ad-hoc.

El patrón "self-hosted vía Git tags" es el **mínimo viable**: cada módulo vive en su propio repo Git, se tagea con SemVer, y los consumidores lo referencian por tag. Es lo que haremos en el ejemplo 01.

### 2.3 SemVer para módulos de infra

Las reglas (ligeramente adaptadas de SemVer para software):

- **MAJOR** (v1 → v2): breaking change para el consumer. Ejemplos: borrar o renombrar una variable sin alias, cambiar un default de forma que afecta el plan de stacks existentes, cambiar el tipo de un recurso de forma que requiere destroy+create.
- **MINOR** (v1.0 → v1.1): feature backward-compatible. Ejemplos: nueva variable con default sensato, nuevo output, nuevo recurso opcional.
- **PATCH** (v1.0.0 → v1.0.1): bugfix sin cambio de contrato. Ejemplos: corregir una expresión que generaba un plan ruidoso, actualizar una política IAM a una versión más restrictiva pero compatible.

Regla operacional: **nunca mover un tag ya publicado**. Si publicaste `v1.0.0` y hay un bug, publica `v1.0.1`. Mover un tag rompe la inmutabilidad que el consumer dio por sentada.

### 2.4 Drift: qué es y por qué ocurre

**Drift** es la divergencia entre lo que declara el HCL + state y lo que realmente existe en la nube. Fuentes típicas:

1. **Cambios manuales por consola** (lo clásico): alguien tocó algo "temporalmente".
2. **Sistemas externos legítimos**: un operador de K8s crea un ingress que luego aparece como "no gestionado"; un controller de autoscaling cambia `desired_count`; un SCP de AWS inyecta tags.
3. **Procesos automatizados fuera de IaC**: scripts de ops, lambdas que crean recursos, Terraform Cloud de otro equipo.

Terraform *detecta* drift en el próximo `plan` (porque hace *refresh* y compara con el state). El problema no es técnico, es de **respuesta**: ¿qué haces con el drift detectado?

### 2.5 Las tres respuestas al drift

1. **Reconcile (aceptar lo real):** el cambio hecho fuera es correcto y queremos adoptarlo en HCL. Pasos: `terraform apply -refresh-only` para actualizar el state → editar el HCL para reflejar el nuevo estado → `plan` limpio.
2. **Adopt (traer a HCL un recurso nuevo):** apareció un recurso que no está en el state (p. ej. alguien lo creó por consola, o había infra legada). Pasos: `import {}` block → `plan -generate-config-out=generated.tf` → revisar/limpiar el HCL generado → commit.
3. **Revert (re-aplicar lo declarado):** el cambio hecho fuera es incorrecto. Pasos: `terraform apply` normal, que destruirá/reparará el drift.

La elección entre las tres **no es técnica**; es organizacional. Técnicamente las tres son fáciles. Políticamente, "reverter" significa pisar el cambio de alguien, lo que requiere criterios acordados.

---

## 3. Contexto histórico

- **2014–2017:** Terraform temprano. Refactoring era doloroso: renombrar un recurso implicaba `terraform state mv` manual (imperativo, sin review). Importar un recurso existente era `terraform import <addr> <id>` uno por uno, sin HCL generado — tenías que escribirlo a mano por copia-pega del `state show`.
- **2017–2020:** Explosión del Registry público. Módulos como `terraform-aws-modules/vpc/aws` definen las "mejores prácticas" de hecho. Empiezan los primeros registries privados en empresas (self-hosted, con convenciones de Git tags).
- **2021 (Terraform 1.0):** compromiso de estabilidad. Posible pensar a largo plazo en contratos de plataforma.
- **2022 (Terraform 1.1):** `moved` blocks. Primer refactor **declarativo** del state: renombres y movimientos entre módulos pasan por HCL + review en PR, no por comando imperativo.
- **2023 (Terraform 1.5):** `import` blocks + `-generate-config-out`. Importar deja de ser `terraform import` imperativo; se declara en HCL y Terraform genera el config inicial. Cambio enorme para adoptar infra legada a escala.
- **2024 (Terraform 1.7):** `removed` blocks. Simétrico a `moved`: sacar un recurso del state sin destruirlo (handoff a otro stack, por ejemplo) pasa por HCL en vez de `terraform state rm`.
- **2024+:** divergencia parcial con OpenTofu, que avanzó más agresivo en `removed` (soporta sacar y destruir en un solo bloque) y en encryption de state.

El patrón histórico es claro: **todas las operaciones de riesgo del state se están moviendo a HCL declarativo revisable**. La era de `terraform state <subcomando>` imperativo está terminando.

---

## 4. Funcionamiento interno

### 4.1 Cómo resuelve Terraform `source = "git::...?ref=v1.0.0"`

Durante `terraform init`:

1. Terraform parsea `source` y detecta el prefijo `git::`.
2. Clona el repo (shallow) en `.terraform/modules/<module_key>/`.
3. Hace `git checkout <ref>`. Si `ref` es un tag SemVer, el checkout es determinista.
4. Lee el `terraform-sources.json` de `.terraform/modules/modules.json` para registrar la resolución.

Resultado: el módulo queda **copiado localmente**. Terraform no vuelve a tocarlo hasta el siguiente `init -upgrade` o si borras `.terraform/`. Esto es importante: **no hay resolución dinámica en apply**. Lo que estaba en `v1.0.0` en el `init` es lo que se aplica, aunque alguien mueva el tag después.

Para que funcione sin red usamos un **bare git repo local** (`/tmp/registry/foo.git`) y `source = "git::file:///tmp/registry/foo.git?ref=v1.0.0"`. El protocolo `git::file://` es idéntico a `git::https://` desde el punto de vista de Terraform.

### 4.2 Qué hace `import {}` + `-generate-config-out` por dentro

Dado un bloque:

```hcl
import {
  to = local_file.hello
  id = "/tmp/legacy/hello.txt"
}
```

Durante `terraform plan -generate-config-out=generated.tf`:

1. Terraform lee todos los bloques `import {}`.
2. Para cada uno, llama al provider con el `id` para que **lea el recurso real** (equivalente a un `data` lookup pero sobre el schema del `resource`).
3. Genera un `resource {}` en `generated.tf` con todos los atributos *settable* del schema, poblados con los valores reales leídos.
4. Produce un plan donde esos recursos aparecen como `+/import` (serán añadidos al state, no creados en la nube).

Durante `terraform apply`:

1. Terraform ejecuta la operación de import (añade la entrada al state).
2. **No crea ni modifica el recurso real** — solo lo registra.

El HCL generado suele incluir atributos `(known after apply)` o valores default que no te interesan; se **limpia manualmente** antes del siguiente `plan` para que el plan sea `No changes`. Esto es parte del flujo esperado, no un bug.

### 4.3 Qué hace `moved {}` por dentro

```hcl
moved {
  from = local_file.old_name
  to   = local_file.new_name
}
```

Durante `plan`:

1. Terraform ve que `local_file.new_name` no existe en el state pero sí en HCL (sería un `create`).
2. Ve que `local_file.old_name` existe en state pero no en HCL (sería un `destroy`).
3. El bloque `moved` le dice: "no son dos operaciones; es una re-rotulación". Terraform marca el plan como "moved" (no-op real en la nube, solo rename en el state).

Ventajas sobre `terraform state mv`:
- Vive en el código (auditable en Git).
- Pasa por PR review.
- Es idempotente: puedes dejarlo en el código permanentemente; en runs futuros donde la rename ya se aplicó, el bloque no hace nada.
- Funciona para **consumers de un módulo** que renombra internamente: si publicas `module/foo` v2 que renombra un recurso, incluir `moved {}` dentro del módulo hace que el upgrade en consumers sea no-op.

### 4.4 Qué hace `removed {}` por dentro

```hcl
removed {
  from = local_file.obsolete
  lifecycle {
    destroy = false
  }
}
```

- `destroy = false`: saca el recurso del state **sin destruirlo** en la nube. Útil para "handoff": pasa a ser gestionado por otro stack.
- `destroy = true` (default en versiones recientes): equivalente a borrarlo del HCL (destroy normal), pero más explícito.

Vive en el código y es idempotente. Reemplaza a `terraform state rm` para la mayoría de los casos.

---

## 5. Rol en producción / CI/CD

En una org madura, este módulo define varias piezas que viven en CI/CD:

- **Pipeline del módulo golden**: cada PR hace `fmt`/`validate`/`test` + `tflint`/`checkov`; merge a `main` publica un tag SemVer (manual o con release-please). El registry queda alimentado automáticamente.
- **Pipeline de los stacks consumers**: PR hace `plan` y lo comenta; merge hace `apply` (con approval en prod); un job scheduled corre `plan -refresh-only` cada 6 h para **detectar drift** y abrir un issue si lo hay.
- **Dashboard de drift**: por stack, última corrida de drift, drift abierto, tiempo medio para reconciliar. Es un indicador operacional de primer orden.
- **Gobernanza de apply en prod**: un reviewer con rol `platform-approver` tiene que aprobar el `environment: prod` en GitHub Actions antes del `apply`. El quién-aprueba se audita.

El contrato de plataforma IaC es, en últimas, la **unión** de estas piezas automatizadas y las reglas de reviewers.

---

## 6. Problemas que resuelve

| Problema | Mecanismo del módulo |
|----------|----------------------|
| "Cada equipo copia-pega su VPC con variaciones aleatorias" | Golden module + registry interno |
| "Hay drift en 30 stacks y nadie se entera" | Drift detection scheduled + dashboard |
| "No podemos migrar del provider v4 a v5 porque son 80 stacks" | Golden module encapsula upgrades; `moved` + `removed` para refactors internos; bump de versión major del módulo documentado |
| "Hay infra en producción que nunca entró a Terraform" | `import {}` bloques masivos + `-generate-config-out` |
| "El equipo de seguridad audita cambios en PR a mano" | Policy-as-code (Rego) sobre el plan JSON, biblioteca compartida |
| "Developers piden al equipo de plataforma por Slack para desplegar" | Golden path + scaffolds (`cookiecutter`) de un stack completo |

---

## 7. Problemas que NO resuelve

- **No sustituye al criterio humano** para elegir qué va al módulo golden y qué queda libre. Un módulo que fuerza todas las decisiones termina siendo evitado.
- **No elimina drift**: solo lo *detecta* y da herramientas de respuesta. Si la organización no cierra permisos de consola, el drift sigue.
- **No resuelve conflictos de ownership**: si dos equipos pelean por quién posee la VPC compartida, ningún registry lo arregla. Lo arregla un charter de ownership.
- **No garantiza buenos módulos**: un golden module puede ser técnicamente perfecto y aun así ser ignorado por falta de documentación, soporte o UX.

---

## 8. Buenas prácticas

1. **Un módulo = un repo = un lifecycle**. No metas 10 módulos en un monorepo si no tienen el mismo cadencia de release.
2. **SemVer estricto**. Documenta en el CHANGELOG qué fue breaking.
3. **Pinnear por `~> MAJOR.MINOR`** en consumers de dev, y `= MAJOR.MINOR.PATCH` en consumers de prod. Dev prueba el bump; prod lo adopta cuando se declara estable.
4. **README obligatorio** con: ejemplo mínimo, tabla de inputs/outputs, versiones soportadas de provider y TF, ejemplos de upgrade entre majors.
5. **Tests nativos** (`*.tftest.hcl`) + policy checks (checkov/Rego) en el CI del módulo. Un módulo golden sin tests no es golden.
6. **Drift detection scheduled** y accionable: nada peor que un dashboard de drift que nadie mira.
7. **ADR por decisión de plataforma**: por qué se eligió el módulo X, por qué se expone solo tal variable, por qué prod requiere N aprobadores. Si no está escrito, no existe.
8. **`moved` blocks dentro del módulo** cada vez que renombras algo. Los consumers así hacen el upgrade sin intervención.

---

## 9. Errores comunes

- **Mover un tag ya publicado** ("corrijo `v1.0.0` en lugar de publicar `v1.0.1`"): rompe la inmutabilidad; algunos consumers tendrán el bundle viejo en `.terraform/modules/` y otros el nuevo.
- **Pin a `main` o rama**: anti-patrón; el consumer no sabe qué está desplegando.
- **Módulo "mega"** que expone 80 variables para "ser flexible": no es un golden path, es un wrapper trivial sobre los providers. Error opuesto: módulo que solo expone 2 variables cuando los equipos realmente necesitan 7.
- **`ignore_changes` como solución al drift**: útil para campos realmente externos (p. ej. tags inyectados por SCPs); desastroso como manera de "silenciar" drift sistemático. Esconde el problema de fondo.
- **`terraform state mv` / `terraform state rm` en producción** sin trazabilidad en Git: usa `moved {}` / `removed {}`.
- **Import masivo sin un plan por lotes**: importar 300 recursos de golpe hace que si algo falla, el rollback sea caótico. Importa por bounded context.
- **Golden module sin owner declarado**: nadie responde a los PRs, nadie publica nuevas versiones, la plataforma se oxida.

---

## 10. Alternativas / comparativas

| Mecanismo | Cuándo usarlo | Cuándo no |
|-----------|---------------|-----------|
| Git tags como registry | Mínimo viable, sin infra extra, universal | Si necesitas gating de permisos finos por módulo, o búsqueda/discovery |
| Registry nativo HCP / Artifactory / GitLab | Org grande, muchos módulos, necesitas discovery y versioning gating | Overkill para < 10 módulos |
| `cookiecutter` / scaffolds de scripts | Golden path a nivel de **estructura de repo** (no solo módulo) | Si el valor está solo en el módulo, no en el scaffold |
| Backstage templates | Portal interno con muchos tipos de plantillas, no solo Terraform | Si no tienes Backstage ya desplegado |
| `import {}` block | Terraform ≥ 1.5, adopción con PR review | Terraform < 1.5, o one-shot urgente (ahí `terraform import` CLI) |
| `moved {}` | Refactor con historial auditable | Movimientos cross-state (eso es `removed` + `import` en el otro lado) |
| `removed {}` destroy=false | Handoff entre stacks sin downtime | Si el recurso ya no se quiere, usa destroy normal |
| OPA/Rego biblioteca compartida | Varias orgs reutilizando reglas, policy-as-code portable | Si Sentinel ya está adoptado y pagado |
| Sentinel (HashiCorp) | Si estás en HCP Terraform y quieres integración nativa | Comercial, acoplado a HCP |

---

## 11. Preguntas de evaluación

Al final del módulo deberías poder responder, **sin consultar docs**:

1. ¿Qué distingue un `import {}` block de un `terraform import` CLI? ¿Por qué el block es preferible en una org con PRs obligatorios?
2. ¿En qué se diferencia `moved {}` de `terraform state mv`? Nombra dos ventajas prácticas del primero.
3. ¿Qué hace `removed { lifecycle { destroy = false } }` y cuándo lo usarías?
4. Explica por qué **mover un tag Git ya publicado** rompe la garantía de inmutabilidad que necesita un registry.
5. Dado un drift detectado por scheduled job (alguien agregó una política IAM a un rol gestionado por Terraform), ¿cuál de las tres respuestas (reconcile / adopt / revert) eliges, y cómo lo defiendes?
6. ¿Por qué un golden module debe ser "opinionado pero mínimo"? Da un ejemplo concreto de qué debería fijar y qué debería dejar libre un módulo "microservice-eks".
7. Diseña el bump de un módulo del provider AWS v4 → v5 en 80 stacks. ¿Qué publicas, qué comunicas, qué automatizas?
8. Un auditor pregunta: "¿quién puede aplicar cambios en prod?" ¿Qué le muestras? (pista: pensá en el GitHub Environment + branch protection + CODEOWNERS + registro de aprobaciones).

---

## 12. Resumen y siguiente paso

**Resumen**: operar Terraform a escala no es un problema de Terraform; es un problema organizacional que Terraform ayuda a resolver si se usa como plataforma. Las piezas son: **module registry interno + SemVer**, **golden paths** opinionados pero mínimos, **drift detection continuo** con respuesta operativa clara (reconcile/adopt/revert), **import blocks** + `moved` + `removed` para refactorings sin recrear recursos, y un **contrato de plataforma** escrito que gobierna la autonomía dev vs el control de seguridad.

**Siguiente**: aplica el contrato en el capstone del programa. La infra del proyecto final debe consumir al menos un golden module propio, publicado en un registry (aunque sea Git tags), y venir con un ADR del contrato de plataforma que defiendas en revisión.
