# Inventario de credentials — snapshot 2026-09-30

> Export sin valores. Solo id, tipo, scope, descripción.

| id | tipo | scope | descripción | últ. uso detectado en logs |
|----|------|-------|-------------|-----------------------------|
| `gh-pat-legacy` | string | GLOBAL | "github token" | hace 3 días |
| `gh-pat-personal-jose` | string | GLOBAL | "token de Jose - ya no esta" | hace 14 meses |
| `aws-prod-keys` | usernamePassword | GLOBAL | "AWS access keys produccion" | hace 2 semanas |
| `aws-prod-keys` (duplicado) | usernamePassword | SYSTEM | "copia por si acaso" | hace 11 meses |
| `docker-hub` | usernamePassword | GLOBAL | "" | hace 5 días |
| `old-svn-password` | usernamePassword | GLOBAL | "svn repo migrado 2022" | hace 3 años |
| `k8s-prod-sa` | file | GLOBAL | "kubeconfig prod" | hace 2 días |
| `signing-key` | basicSSHUserPrivateKey | GLOBAL | "firma releases" | hace 1 mes |
| `vault-approle-roleid` | string | SYSTEM | "role_id para Vault" | hace 1 hora |
| `vault-approle-secretid` | string | SYSTEM | "secret_id para Vault" | hace 1 hora |

## Notas del SRE

- Hay 2 credentials de AWS prod duplicadas (`aws-prod-keys` × 2). Nadie recuerda cuál usa cada job.
- `gh-pat-personal-jose` es un PAT a nombre de un ex empleado. Jose dejó la empresa hace 14 meses.
- `old-svn-password` apunta a un repo SVN migrado a Git en 2022.
- Todas las credentials están en scope `GLOBAL` o `SYSTEM`. No hay folders — todos los equipos comparten el namespace.
