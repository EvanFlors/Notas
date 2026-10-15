# Ejemplo 02 — Restricción por branch policy

Dos sabores de `deployment_branch_policy` (son excluyentes):

- **A — `protected_branches: true`** → se alinea con la branch protection del repo. Lo que esté protegido puede desplegar.
- **B — `custom_branch_policies: true`** → defines patrones propios (glob). Más expresivo, requiere mantener los patrones.

## Qué contiene

- `files/environment-prod-protected.yaml` — modo A.
- `files/environment-prod-custom.yaml` — modo B con dos patrones.
- `files/README-rejection.md` — qué ve el usuario cuando el deploy es rechazado por la policy.

## Comparación rápida

| Dimensión | `protected_branches` | `custom_branch_policies` |
|-----------|----------------------|---------------------------|
| Fuente de verdad | Branch protection del repo | Patrones explícitos del env |
| Soporta glob | No (atado a reglas de protección) | Sí (`refs/heads/release/*`, `refs/tags/v*`) |
| Qué pasa si cambias branch protection | El env lo "siente" automáticamente | Sin efecto; sigue aplicando los patrones del env |
| Riesgo típico | Olvidar proteger la rama → cualquier branch despliega | Patrón mal escrito que incluye demasiado |

## Pruébalo rápido

```bash
python3 -c "
import yaml
for p in ['environment-prod-protected.yaml','environment-prod-custom.yaml']:
    d = yaml.safe_load(open(f'$(dirname "$0")/files/{p}'))
    bp = d['deployment_branch_policy']
    # Son excluyentes: exactamente uno de los dos flags debe ser true.
    assert bp['protected_branches'] != bp['custom_branch_policies'], p
    print(p, 'OK')
"
```

## Qué pasa cuando el deploy es rechazado

Cuando intentas desplegar desde una ref que **no** matchea la policy:

```
This branch is not allowed to deploy to <env> due to deployment protection rules.
```

El deployment record queda con `state: rejected`. Nunca llega a crear runner. El error aparece en la UI del run y en la pestaña *Environments*. No consume minutos.

Error típico: alguien configura `custom_branch_policies: true` pero olvida añadir *ningún patrón*. Resultado: **cero** refs pueden desplegar — todo deploy falla. La fix es `POST .../deployment-branch-policies -f name='refs/heads/main'`.
