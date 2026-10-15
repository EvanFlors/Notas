# Ejemplo 01 — Environment `production` con approval

Descripción declarativa YAML (nuestra convención, GitHub no lo expone así de serie) + fragmento del workflow Actions que lo consume + script `apply.sh` que traduce el YAML a llamadas `gh api`.

## Qué contiene

- `files/environment-production.yaml` — descripción declarativa del environment.
- `files/workflow-deploy.yaml` — fragmento de workflow Actions que usa `environment: production`.
- `files/apply.sh` — script dual-mode: `--dry-run` (default) imprime los comandos, `--apply` los ejecuta contra un repo real.

## Dry-run (sin GitHub)

```bash
mkdir -p /tmp/gha09-env-demo
cp -r "$(dirname "$0")/files/." /tmp/gha09-env-demo/
cd /tmp/gha09-env-demo

python3 -c "
import yaml, sys
d = yaml.safe_load(open('environment-production.yaml'))
assert d['name'] == 'production'
assert d['wait_timer'] >= 0
assert isinstance(d['reviewers'], list) and len(d['reviewers']) >= 1
assert 'deployment_branch_policy' in d
print('OK: environment YAML valido.')
"
bash apply.sh --dry-run
```

## Aplicar a repo real

```bash
export GH_OWNER=your-user GH_REPO=your-sandbox-repo
bash apply.sh --apply
```

Requiere `gh auth login` con permisos de admin sobre el repo.

## Qué muestra el ejemplo

- Cómo describir un environment como código (fuera de la UI).
- Cómo el workflow consume el environment vía la clave `environment:`.
- Cómo las branch policies restringen qué refs pueden desplegar.
- Dónde van los secretos (nombres en el YAML; valores con `gh secret set --env production`).

## Limpieza

```bash
# Si lo aplicaste a un repo real:
gh api -X DELETE repos/$GH_OWNER/$GH_REPO/environments/production
rm -rf /tmp/gha09-env-demo
```
