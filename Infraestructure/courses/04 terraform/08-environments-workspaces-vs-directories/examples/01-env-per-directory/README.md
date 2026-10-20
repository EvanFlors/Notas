# Example 01 — Un directorio por ambiente, módulo compartido

## Idea

Tres ambientes (`dev`, `stg`, `prod`) viven en `envs/{dev,stg,prod}/`. Cada uno es un **root module** independiente, con su propio `terraform.tfstate` **local** (en este ejemplo didáctico; en producción sería un backend remoto distinto por ambiente). Los tres consumen el mismo módulo en `modules/app/`.

El módulo `app` genera, de forma determinística:

- Un nombre aleatorio con prefijo del ambiente (`random_pet`).
- Un archivo local (`local_file`) con el "manifiesto" del ambiente — simula el deploy real sin tocar cloud.
- Un token aleatorio con `keepers` ligados al ambiente (ejemplifica cómo evitar regeneraciones espurias).

## Layout

```
01-env-per-directory/
├── README.md
├── modules/
│   └── app/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── envs/
    ├── dev/   { main.tf, versions.tf, terraform.tfvars }
    ├── stg/   { main.tf, versions.tf, terraform.tfvars }
    └── prod/  { main.tf, versions.tf, terraform.tfvars }
```

Nota: **ningún** archivo `.tf` del módulo contiene `if env == "prod"`. Lo que cambia por ambiente son **datos** (`var.replica_count`, `var.instance_class_label`), no código.

## Cómo correr

Desde el directorio del ambiente que te interese. Por ejemplo:

```bash
cd envs/dev
terraform init
terraform apply -auto-approve
ls terraform.tfstate      # el state vive AQUI, no se comparte con stg/prod
cat out/manifest.json
```

Repite en `envs/stg/` y `envs/prod/`. Observa que **cada uno** produce:

- Su propio `terraform.tfstate` en el directorio del ambiente.
- Su propio `out/manifest.json` con un nombre distinto.
- Un plan limpio (`No changes`) si lo vuelves a correr sin cambios.

## Qué demostrar

1. Correr `terraform state list` desde `envs/dev/` **solo** muestra recursos de dev. El state está físicamente aislado por directorio.
2. Correr `terraform destroy` desde `envs/dev/` **no puede** tocar stg ni prod — la credencial efectiva (en este caso el working directory) ni siquiera "ve" los otros ambientes.
3. Cambiar `modules/app/main.tf` impacta a los tres ambientes **la siguiente vez que corras `apply` en cada uno**. (En el patrón con módulos versionados por tag no sería así — cada ambiente pinnearía su versión. Lo veremos en `tf-11`/`tf-14`.)

## Limpieza

```bash
for env in dev stg prod; do
  (cd envs/$env && terraform destroy -auto-approve 2>/dev/null || true)
done
rm -rf envs/*/{.terraform,.terraform.lock.hcl,terraform.tfstate*,out}
```
