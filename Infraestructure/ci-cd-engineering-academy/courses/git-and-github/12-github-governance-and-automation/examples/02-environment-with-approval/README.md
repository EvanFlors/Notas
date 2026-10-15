# Ejemplo 02 — Environment `production` con approval

Descripción YAML (nuestra convención; GitHub lo expone vía API, no vía YAML nativo) + fragmentos `gh api` para aplicarlo.

## Qué contiene

- `files/environment-production.yaml` — descripción declarativa del environment.
- `files/workflow-deploy.yaml` — fragmento de workflow Actions que consume `environment: production`.
- `files/apply.sh` — script idempotente que convierte el YAML en llamadas `gh api` (dry-run por default).

## Dry-run (sin GitHub)

```bash
cd /tmp && cp -r "$(dirname "$0")/files" /tmp/env-demo && cd /tmp/env-demo
python3 -c "import yaml; d=yaml.safe_load(open('environment-production.yaml')); \
  assert d['name']=='production'; assert d['wait_timer']>=0; \
  assert isinstance(d['reviewers'], list) and len(d['reviewers'])>=1; \
  assert 'deployment_branch_policy' in d; \
  print('OK: environment YAML válido.')"
bash apply.sh --dry-run
```

## Aplicar a repo real

```bash
export OWNER=your-user REPO=your-sandbox-repo
bash apply.sh --apply
```

Requiere `gh auth login` con permisos de admin sobre el repo, y los IDs de team reales (ver `files/apply.sh`).

## Qué muestra el ejemplo

- Cómo describir un environment como código (fuera de la UI).
- Cómo el workflow consume el environment vía la clave `environment:`.
- Cómo las políticas de deployment branch policy restringen qué refs pueden desplegar.

## Limpieza

```bash
# Si lo aplicaste:
gh api -X DELETE repos/$OWNER/$REPO/environments/production
rm -rf /tmp/env-demo
```
