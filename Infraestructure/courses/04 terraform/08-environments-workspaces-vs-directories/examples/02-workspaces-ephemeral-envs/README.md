# Example 02 — Workspaces para ambientes efímeros (feature envs)

## Idea

Este es el **uso legítimo** de `terraform workspace`: crear sandboxes de corta vida sobre el mismo backend/credenciales que un ambiente de desarrollo (ver `theory/lesson.md` §8). No es para separar prod.

El stack es un único root module. Lo "ambientizamos" con el workspace activo: el sufijo de los recursos deriva de `terraform.workspace`, así que `feature-a` y `feature-b` producen artefactos distintos sin colisionar.

Simula el ciclo de un PR:

1. Checkout de una rama.
2. `terraform workspace new feature-<rama>`.
3. `apply` → se crea un sandbox independiente.
4. (Pruebas / revisión).
5. `destroy` + `workspace delete` al cerrar el PR.

## Layout

```
02-workspaces-ephemeral-envs/
├── README.md
├── versions.tf
├── variables.tf
└── main.tf
```

Nota: no hay `envs/`. Hay **un solo root module**; los workspaces son la dimensión de aislamiento.

## Cómo correr

```bash
terraform init

# Workspace "default" (no lo usaremos para nada relevante — convención)
terraform workspace list

# Primer feature env
terraform workspace new feature-alice-add-cache
terraform apply -auto-approve
cat out/manifest.json      # name incluye "feature-alice-add-cache"
ls terraform.tfstate.d/    # observa el nuevo directorio

# Segundo feature env en paralelo
terraform workspace new feature-bob-fix-bug
terraform apply -auto-approve
cat out/manifest.json      # name distinto, state distinto

# Lista los dos
terraform workspace list

# Limpieza (análogo a "cerrar el PR")
terraform workspace select feature-alice-add-cache
terraform destroy -auto-approve
terraform workspace select default
terraform workspace delete feature-alice-add-cache

terraform workspace select feature-bob-fix-bug
terraform destroy -auto-approve
terraform workspace select default
terraform workspace delete feature-bob-fix-bug
```

## Qué demostrar

1. `terraform.tfstate.d/<workspace>/terraform.tfstate` es la **única** diferencia física entre workspaces con backend local. El resto es el mismo HCL evaluado contra las mismas credenciales.
2. Los recursos se nombran con `terraform.workspace`, así que dos feature envs no colisionan — **pero no están aislados de verdad**. Comparten backend. Si rotas la credencial, afectas a los dos.
3. Si cambiaras `terraform workspace select default` y corrieras `apply`, crearías *otra* copia bajo `default`. Los workspaces no te protegen de operar en el equivocado — sólo cambian la key del state.

## Limpieza completa

```bash
for ws in $(terraform workspace list | tr -d ' *' | grep -v '^default$' | grep -v '^$'); do
  terraform workspace select "$ws"
  terraform destroy -auto-approve 2>/dev/null || true
done
terraform workspace select default
for ws in $(terraform workspace list | tr -d ' *' | grep -v '^default$' | grep -v '^$'); do
  terraform workspace delete "$ws"
done
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* out
```
