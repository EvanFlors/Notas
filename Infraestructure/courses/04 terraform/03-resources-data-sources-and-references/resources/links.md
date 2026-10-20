# Recursos — tf-03

## Documentación oficial de Terraform

- **Resources (overview)** — <https://developer.hashicorp.com/terraform/language/resources>
- **Resource behavior** — <https://developer.hashicorp.com/terraform/language/resources/behavior>
- **Data sources** — <https://developer.hashicorp.com/terraform/language/data-sources>
- **References to resources** — <https://developer.hashicorp.com/terraform/language/expressions/references>
- **Meta-argument `depends_on`** — <https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on>
- **`terraform state list`** — <https://developer.hashicorp.com/terraform/cli/commands/state/list>
- **`terraform state show`** — <https://developer.hashicorp.com/terraform/cli/commands/state/show>
- **`terraform graph`** — <https://developer.hashicorp.com/terraform/cli/commands/graph>

## Providers usados en este módulo

- **`hashicorp/tls`** — <https://registry.terraform.io/providers/hashicorp/tls/latest/docs>
  - `tls_private_key` — <https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key>
  - `tls_self_signed_cert` — <https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert>
- **`kreuzwerker/docker`** — <https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs>
  - `docker_image` — <https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/image>
  - `docker_container` — <https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/container>
- **`integrations/github`** — <https://registry.terraform.io/providers/integrations/github/latest/docs>
  - `github_repository` — <https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository>
  - `github_repository_deploy_key` — <https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_deploy_key>

## Internals del grafo y del plan

- **"Resource Graph" (concepto, docs oficiales)** — <https://developer.hashicorp.com/terraform/internals/graph>
- **"Resource Addressing"** — <https://developer.hashicorp.com/terraform/cli/state/resource-addressing>
- **Graphviz Online** (para pegar DOT y visualizar) — <https://dreampuf.github.io/GraphvizOnline/>
- **Graphviz oficial** (si prefieres `dot` local) — <https://graphviz.org/download/>

## Lecturas complementarias

- **"Attributes as Blocks" (nested blocks, atributos y por qué algunos recursos split)** — <https://developer.hashicorp.com/terraform/language/attr-as-blocks>
- **Terraform Registry (buscar providers)** — <https://registry.terraform.io/>
- **OpenTofu Registry (equivalente comunitario)** — <https://search.opentofu.org/>
