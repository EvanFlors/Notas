# tf-08 — Ambientes en Terraform: workspaces vs directorios

> Lección profunda. Doce secciones. Léela antes de los ejemplos y actividades.

---

## 1. Qué es un "ambiente" en IaC

Un **ambiente** (dev, stg, prod, qa, sandbox, feature-env) **no** es una variable de configuración. Es un *contrato operacional* compuesto por:

- Un conjunto de **recursos** reales (una VPC, una base, un cluster) que viven en algún lugar.
- Un **state** que los representa dentro de Terraform.
- Un conjunto de **credenciales** que tienen permiso para leer y escribir ese state y para hablar con la cloud/APIs reales.
- Un conjunto de **políticas** (quién puede aprobar `apply`, qué recursos permite el ambiente, qué tags son obligatorios).
- Un **blast radius**: el daño máximo que puede causar un `apply` erróneo.

Cuando dos ambientes comparten *cualquiera* de estas cinco cosas, dejan de ser ambientes distintos: son **vistas** del mismo ambiente. La pregunta central del módulo es cómo lograr que los cinco contratos sean *físicamente* separables y, al mismo tiempo, el **código** no se duplique.

Hay esencialmente tres patrones para hacerlo con Terraform puro:

1. **Workspaces de CLI** sobre un mismo root module.
2. **Directorios separados por ambiente** con módulos compartidos.
3. **Terragrunt-like**: HCL fino por ambiente que apunta a módulos versionados.

Las secciones 2–5 analizan cada uno. Las secciones 6–12 cubren los temas transversales: anti-patrones, feature envs efímeros, naming, secretos, blast radius, promoción y criterios de elección.

---

## 2. Workspaces de CLI — qué son realmente

Terraform soporta **workspaces** desde la 0.9. La API operacional es sencilla:

```bash
terraform workspace list
terraform workspace new dev
terraform workspace new stg
terraform workspace new prod
terraform workspace select prod
terraform plan
```

Dentro del código HCL hay una expresión `terraform.workspace` que devuelve el nombre del workspace actual:

```hcl
locals {
  bucket_name = "my-app-${terraform.workspace}"
}
```

Hasta aquí todo luce prometedor. El problema aparece al preguntar: **¿qué cambia en el mundo cuando corres `terraform workspace select prod`?**

La respuesta honesta: **sólo cambia la key del state en el backend**.

- Con el **backend local**, Terraform usa `terraform.tfstate.d/<workspace>/terraform.tfstate` en vez de `terraform.tfstate`.
- Con el **backend S3**, usa `env:/<workspace>/<key>` en vez de `<key>`.
- Con **HCP Terraform / Terraform Cloud**, un workspace es un objeto de primera clase con su propio set de variables — este caso es la excepción y lo veremos en `tf-11`.

Nada más. **Las credenciales son las mismas**. El bucket es el mismo. La cuenta cloud es la misma. Los límites IAM son los mismos. Los providers son los mismos. El código `.tf` evaluado es el mismo. Lo único distinto es un string en la ruta del state.

Esto tiene consecuencias serias que la sección 6 enumera. Primero conviene ver los otros dos patrones.

---

## 3. Patrón "directorios separados por ambiente"

El patrón más común y, cuando se aplica bien, el más defensible. La estructura mínima:

```
infra/
├── modules/
│   └── app/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── envs/
    ├── dev/
    │   ├── main.tf           # module "app" { source = "../../modules/app" ...}
    │   ├── backend.tf        # backend "s3" {... bucket=dev, key=dev ...}
    │   └── terraform.tfvars  # valores específicos de dev
    ├── stg/
    │   ├── main.tf
    │   ├── backend.tf        # backend distinto
    │   └── terraform.tfvars
    └── prod/
        ├── main.tf
        ├── backend.tf        # backend distinto + credenciales distintas
        └── terraform.tfvars
```

Propiedades clave:

- Cada `envs/<X>/` es un **root module** independiente. Terraform se corre *desde* ese directorio.
- Cada root tiene su **propio backend** — idealmente, su propio bucket (o al menos su propia key), su propio locking, y requiere **credenciales distintas** para escribir en él.
- Los `envs/<X>/main.tf` son archivos cortos, declarativos: *"instancia este módulo con estos valores"*. Toda la lógica real vive en `modules/`.
- Los módulos están versionados (en el Registry, en Git con tags, o internos). La promoción `dev → stg → prod` se hace **subiendo la versión del módulo** que cada ambiente consume.

Ventajas sobre workspaces:

- El `envs/prod/` puede usar credenciales que un developer o un runner de CI de PR **no tiene**. Un `apply` accidental desde el runner equivocado **no puede** escribir en el backend de prod porque la credencial no tiene acceso.
- Las policies (`checkov`, `OPA/Rego`, Sentinel) pueden exigir reglas distintas por ambiente: `envs/prod/` requiere revisión humana, `envs/dev/` no.
- Los permisos de merge en Git pueden distinguir rutas: cualquier dev puede modificar `envs/dev/`, sólo SREs pueden modificar `envs/prod/` (via CODEOWNERS).

Desventajas:

- Duplicación de boilerplate (`providers.tf`, `backend.tf`, llamadas a módulos). Si no se encapsula bien, los ambientes divergen por descuido.
- Es tentador copiar-pegar entre ambientes en vez de versionar módulos. Si cedes a la tentación, obtienes tres copias del código que ya no es un módulo.

---

## 4. Patrón "Terragrunt-like"

**Terragrunt** (de Gruntwork) es una herramienta que envuelve Terraform para reducir el boilerplate del patrón anterior. La idea es:

- Cada ambiente es un `terragrunt.hcl` extremadamente delgado que declara:
  - Qué módulo versionado consumir (`source = "git::...//modules/app?ref=v1.4.2"`).
  - Qué backend usar (heredado de un `terragrunt.hcl` común).
  - Qué inputs pasar.
- Terragrunt genera, para cada apply, un directorio temporal con el root module ya ensamblado y corre Terraform ahí.

Resultado: tres ambientes = tres archivos de ~20 líneas cada uno; cero duplicación de providers/backend.

El patrón se puede imitar sin Terragrunt a base de disciplina, módulos remotos versionados y generadores propios, pero con costo de ingeniería. En este curso **no** instalamos Terragrunt — basta con reconocer su propuesta y entender que *la estructura mental* es la misma que la del patrón 3: ambientes = HCL fino que consume módulos versionados.

---

## 5. Monorepo vs multi-repo de infra

Dos ejes ortogonales a los tres patrones anteriores.

**Monorepo de infra** — un único repositorio contiene `modules/` y `envs/`. Pros: fácil ver el conjunto, PR cruzadas, herramientas sencillas. Contras: cualquiera que pueda abrir un PR toca potencialmente prod (mitigable con CODEOWNERS y permisos de merge por path).

**Multi-repo** — un repo por módulo, un repo por ambiente, o un repo por "capa" (networking, platform, apps). Pros: permisos finos por repo, releases de módulos independientes de los ambientes que los consumen (esto es lo que *obliga* a versionarlos). Contras: coordinación más costosa, PR cruzadas inexistentes.

En la práctica:

- Equipos pequeños → monorepo, módulos locales en `modules/`, promoción por rama/directorio.
- Equipos medianos → monorepo con módulos versionados en Git tags; `envs/<X>/` referencia `source = "git::...?ref=vX.Y.Z"`.
- Grandes organizaciones → multi-repo: `platform-modules-*` separados de `platform-envs-*`, con un release-train formal de módulos.

Lo que **no** varía: en todos los casos, cada ambiente debe tener *su propio backend* y *sus propias credenciales*. Esa es la invariante que protege prod.

---

## 6. Anti-patrón: workspaces para separar prod del resto

Imagina una organización que decide: *"Usamos workspaces. `terraform workspace select prod` y aplicamos."* ¿Qué está mal?

Riesgos específicos:

1. **Mismo backend, mismas credenciales**. El runner que puede `apply` en `stg` también puede, con un `workspace select` equivocado, `apply` en `prod`. No existe barrera técnica — sólo disciplina.
2. **Blast radius imposible de limitar**. Si una credencial se filtra, pierdes todos los ambientes a la vez.
3. **Policies no diferenciables por ambiente** (al menos no sin ramificar el código, que es el anti-patrón de la sección 7). Checkov o OPA ven el mismo HCL — no pueden exigir, p. ej., "en prod no se permiten tipos de instancia `t3.*`".
4. **Operacional confusa**. `terraform workspace show` es un comando de un solo caracter de diferencia con el que apunta al ambiente equivocado. Los humanos cometen ese error.
5. **`terraform destroy` catastrófico**. Un `destroy` en el workspace equivocado destruye prod sin aviso adicional. Separar directorios obliga a *estar en el directorio equivocado* **y además** tener credenciales — dos barreras en vez de una.
6. **IaC scanning y auditoría más difíciles**. "¿Qué hay en prod?" se contesta ejecutando `terraform workspace select prod && terraform state list`, no leyendo un directorio.
7. **No se puede aplicar `required_providers` ni `required_version` distintos por ambiente** sin ramificar código.

El consenso de la industria —reflejado en guías de HashiCorp, Gruntwork, y la mayoría de equipos que han sufrido un incidente— es: **no uses workspaces para separar prod**. Úsalos para feature envs efímeros (sección 8) donde el blast radius ya es trivial.

---

## 7. Anti-patrón: `if env == "prod"` dentro del módulo

Un módulo con cuerpo como este:

```hcl
resource "aws_instance" "db" {
  instance_type = var.environment == "prod" ? "m5.4xlarge" : "t3.micro"
  monitoring    = var.environment == "prod" ? true : false
  count         = var.environment == "prod" ? 3 : 1
}
```

está roto por diseño por tres razones:

1. **Acopla *qué hace* con *dónde se usa*.** El módulo deja de ser una unidad reutilizable y pasa a ser una colección de ramas condicionales ligadas a nombres de ambiente de esta organización. Otro equipo no puede reusarlo sin inventar sus propios strings.
2. **Rompe la testabilidad**. Un módulo con N ramas ambiente-dependientes tiene N comportamientos distintos. Un test que fija `environment = "test"` no cubre lo que hace en prod.
3. **Hace invisible la configuración**. Para saber qué recibe prod hay que leer el módulo entero buscando ternarios. En el patrón correcto —parámetros explícitos— `envs/prod/main.tf` dice `instance_type = "m5.4xlarge"` y se acabó.

Refactor correcto: convertir cada rama en un *input* del módulo.

```hcl
# modules/db/variables.tf
variable "instance_type" { type = string }
variable "replica_count" { type = number }
variable "monitoring"    { type = bool, default = false }

# envs/prod/main.tf
module "db" {
  source         = "../../modules/db"
  instance_type  = "m5.4xlarge"
  replica_count  = 3
  monitoring     = true
}

# envs/dev/main.tf
module "db" {
  source         = "../../modules/db"
  instance_type  = "t3.micro"
  replica_count  = 1
  monitoring     = false
}
```

Ahora el módulo es puro: dados sus inputs, produce un resultado predecible. Los ambientes son *datos*, no *ramas de código*.

Regla práctica: si tu módulo lee `var.environment` para decidir **qué recursos crear o con qué parámetros**, está mal. `var.environment` sólo debería usarse para **naming/tagging** (p. ej. `name = "${var.name}-${var.environment}"`).

---

## 8. Uso legítimo de workspaces: feature environments efímeros

Workspaces **sí** son útiles —y bien usados, idiomáticos— para esto:

Supón que tienes un stack `envs/dev/` y los developers quieren probar su rama antes de mergear. En vez de darles a cada uno su directorio, les das un workspace:

```bash
cd envs/dev
terraform workspace new feature-alice-add-cache
terraform apply
# ... prueban ...
terraform destroy
terraform workspace delete feature-alice-add-cache
```

Los recursos se nombran con `terraform.workspace`:

```hcl
locals {
  suffix = terraform.workspace == "default" ? "dev" : terraform.workspace
}

resource "random_pet" "name" {
  prefix = "myapp-${local.suffix}"
}
```

Propiedades:

- Mismo backend que `dev` → OK, el blast radius ya era "dev".
- Mismas credenciales que `dev` → OK, el pipeline/dev ya las tenía.
- CI puede crear y destruir workspaces por PR automáticamente (p. ej. `terraform workspace new "pr-$PR_NUMBER"` en el pre-merge, `destroy && workspace delete` al cerrar el PR).
- El state de cada feature queda aislado del `default`/`dev`, así que un `destroy` del feature no toca el resto.

Esto es lo que los workspaces fueron pensados para resolver.

---

## 9. Naming y tags por ambiente

Convención recomendada: `<proyecto>-<ambiente>-<componente>[-<sufijo>]`.

Ejemplos: `shop-prod-api`, `shop-stg-db-primary`, `shop-dev-bucket-assets`.

Reglas:

- El **ambiente** aparece en el nombre del recurso. Si abres la consola de la cloud y ves un recurso suelto, debes poder decir a qué ambiente pertenece sin consultar el state.
- **Tags obligatorios** por módulo: `env`, `project`, `owner`, `managed_by = "terraform"`. El tag `managed_by` es crucial: anuncia a futuros humanos que *no* editen a mano.
- No metas el workspace de CLI en el nombre si estás usando el patrón de directorios — redundante y confuso.
- Los sufijos aleatorios (`random_id`, `random_pet`) son útiles para evitar colisiones de nombres globalmente únicos (buckets S3, DNS). Mantenlos **estables** (`keepers` del random, no se regenera a menos que cambien ciertos inputs).

---

## 10. Secretos y configuración por ambiente

Los secretos **no** deben vivir en el repo, ni como `terraform.tfvars`, ni como `-var`, ni como `TF_VAR_*`. Viven en un sistema de secretos:

- AWS: Secrets Manager / Parameter Store.
- GCP: Secret Manager.
- Azure: Key Vault.
- Multi-cloud / self-hosted: HashiCorp Vault.

Terraform los lee con un `data` source:

```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "shop/${var.env}/db/password"
}
```

Nota importante: ese valor **termina en el state en claro**. Por eso el backend del ambiente debe tener encriptación at-rest y ACLs mínimas. Los permisos para leer el state ≡ permisos para leer todos sus secretos.

La configuración **no-sensible** sí puede vivir en `terraform.tfvars` por ambiente (`envs/prod/terraform.tfvars`, `envs/stg/terraform.tfvars`). Esos archivos sí se versionan.

---

## 11. Blast radius y promoción

**Blast radius** = daño máximo de un `apply` erróneo.

| Patrón | Blast radius de un `apply` erróneo |
|--------|------------------------------------|
| Workspaces para todo | Cualquier ambiente, incluido prod. |
| Directorios por ambiente, mismo backend/credenciales | Cualquier ambiente. (Peor caso: el patrón de directorios *sin* separar credenciales/backend sólo tiene el beneficio cosmético.) |
| Directorios por ambiente + backend por ambiente + credenciales por ambiente | Sólo el ambiente al que apunta la credencial activa. |
| Idem + segunda confirmación humana para prod (OIDC + GitHub environment approval) | Sólo prod, y requiere acción humana explícita. |

**Promoción**: `dev → stg → prod` no es "copiar código entre directorios". Es:

1. Haces el cambio en el **módulo**.
2. Taggeás una nueva versión del módulo (`v1.4.3`).
3. En `envs/dev/main.tf` subes el pin a `v1.4.3`, abres PR, `apply` en dev.
4. Observas; si todo bien, haces lo mismo en `envs/stg/`.
5. Finalmente en `envs/prod/`.

Esto deja un rastro auditable: *qué versión del módulo corre cada ambiente*. Y permite rollback: bajar el pin a `v1.4.2`, `apply`.

En el patrón con módulos locales (`source = "../../modules/app"`) **todos los ambientes consumen el mismo código a la vez**. No hay promoción posible — un cambio al módulo impacta a los tres apenas se mergea. Esto es aceptable al principio y en equipos pequeños; cuando duele, se migra a módulos versionados.

---

## 12. Criterios para elegir el patrón

Árbol de decisión práctico:

1. **¿Un solo ambiente y un solo equipo?** Un único root module, sin workspaces, sin `envs/`. No sobre-diseñes.
2. **¿Dos-tres ambientes, un equipo pequeño, módulos locales son suficientes?** Patrón de directorios con `envs/` y `modules/` en el mismo repo. Backend por ambiente. Credenciales por ambiente. **Esta es la respuesta correcta en >50 % de los casos**.
3. **¿Necesitas feature envs efímeros por PR?** El `envs/dev/` del patrón 2 + workspaces encima de `dev`. No workspaces para prod.
4. **¿Múltiples equipos, varios módulos reusados cross-equipo, promoción formal?** Módulos versionados (Git tags o Registry interno) + `envs/<X>/` que los pinnean. Opcionalmente Terragrunt para reducir boilerplate.
5. **¿Decenas de ambientes similares (p. ej. uno por cliente)?** Patrón 4 obligatorio. Posiblemente generación programática del árbol `envs/<cliente>/`.
6. **¿Usas workspaces para separar prod del resto?** Nunca. Refactoriza antes de que te muerda.

Marcador conceptual: en entrevistas y en ADRs, "separación de ambientes" se evalúa casi siempre contra tres criterios: **blast radius acotable, credenciales separables, promoción trazable**. Si tu patrón cumple los tres, es defendible. Si falla alguno, hay deuda.

---

## Preguntas de evaluación (sin consultar la lección)

1. Explica, en una frase, qué cambia en el mundo real cuando ejecutas `terraform workspace select prod`.
2. Da **tres riesgos específicos** de usar un único workspace para `stg` y `prod` que *no* existan en el patrón de directorios con backends separados.
3. Dado un módulo con `count = var.env == "prod" ? 3 : 1`, propón su refactor y explica qué ganó la refactorización.
4. Describe un caso donde **sí** es apropiado usar workspaces de CLI.
5. En el patrón de directorios con módulos locales (`source = "../../modules/app"`) ¿cómo haces para que un cambio llegue primero a dev, luego a stg, luego a prod? ¿Qué cambiarías si quisieras promoción trazable?
