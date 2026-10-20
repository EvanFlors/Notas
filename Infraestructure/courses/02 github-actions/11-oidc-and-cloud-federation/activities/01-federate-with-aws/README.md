# Actividad 01 — Federar GitHub Actions con AWS vía OIDC (dual-mode)

## 1. Identificación

- **ID:** `gha-11-01-federate-with-aws`
- **Tecnología:** `github-actions`
- **Módulo:** `11-oidc-and-cloud-federation`
- **Dificultad:** advanced
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab (dual-mode: `MODE=local` por defecto, `MODE=live` opcional)

## 2. Contexto

Construyes el patrón OIDC completo contra AWS: trust policy JSON + workflow YAML + documento que explica el flujo. En `MODE=local` (default) el validator inspecta los dos artefactos sin tocar la cloud; en `MODE=live` adicionalmente verifica que las creds AWS del host funcionan (y, si tienes repo real, puedes probarlo end-to-end tú).

Esta actividad **profundiza** sobre `gh-13-03-oidc-federation-to-cloud` del curso Git. Aquí tienes además:

- Un rol diferenciado para prod vs CI.
- La ambición de que el pin del `sub` incluya `environment:` (recomendado por este módulo).
- Un check extra: nada de `permissions: write-all` top-level.

## 3. Objetivos

- Diseñar `trust-policy.json` con pin seguro del `sub` por `environment:production`.
- Diseñar `.github/workflows/deploy.yml` que:
  - Dispara en `push` a `main` o `workflow_dispatch`.
  - Declara `permissions: {}` top-level y `id-token: write` + `contents: read` en el job.
  - Usa `environment: production`.
  - Usa `aws-actions/configure-aws-credentials` con `role-to-assume`.
  - **No** contiene `AKIA...`, `${{ secrets.AWS_ACCESS_KEY_ID }}`, ni `${{ secrets.AWS_SECRET_ACCESS_KEY }}`.
  - **No** usa `permissions: write-all` ni `permissions: id-token: write` top-level.
- Documentar en `docs/oidc.md` el flujo, el porqué del pin, y qué se necesita en AWS.

## 4. Prerrequisitos

- `MODE=local` (default): `bash`, `python3` (3.8+), `python3-yaml` (ya suele estar).
- `MODE=live` (opcional): cuenta AWS con permiso IAM, `aws` CLI configurada.

**Costos**: USD 0 para operaciones IAM/STS. El rol asumido podría operar recursos facturables si lo decides tú — no te pedimos nada así.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/gha-oidc
```

Esto crea `/tmp/gha-oidc/project/` con la estructura inicial y un README guía.

### 5.2 Tareas

Trabaja en `/tmp/gha-oidc/project/`:

1. **Crear `trust-policy.json`** en la raíz con la estructura:
   - `Version`: `"2012-10-17"`.
   - Un `Statement` con `Effect: "Allow"`, `Action: "sts:AssumeRoleWithWebIdentity"`.
   - `Principal.Federated` apuntando a `arn:aws:iam::<AWS-ACCOUNT-ID>:oidc-provider/token.actions.githubusercontent.com` (usa `AWS-ACCOUNT-ID` o `000000000000` como placeholder).
   - `Condition.StringEquals`:
     - `token.actions.githubusercontent.com:aud` = `"sts.amazonaws.com"`.
     - `token.actions.githubusercontent.com:sub` = `"repo:MyOrg/MyRepo:environment:production"` (puedes cambiar `MyOrg/MyRepo`).

2. **Crear `.github/workflows/deploy.yml`**:
   - `on`: `push` a `main` + `workflow_dispatch`.
   - **`permissions: {}` top-level** (restrictivo).
   - Job `deploy`:
     - `environment: production`.
     - `permissions: { id-token: write, contents: read }`.
     - Steps: `actions/checkout`, `aws-actions/configure-aws-credentials` (con `role-to-assume`), `aws sts get-caller-identity`.
   - **Sin** `AKIA...`, sin `secrets.AWS_ACCESS_KEY_ID`, sin `secrets.AWS_SECRET_ACCESS_KEY`, sin `permissions: write-all`.

3. **Crear `docs/oidc.md`** (mínimo 3 párrafos) mencionando `AssumeRoleWithWebIdentity`, el `sub`, el `OIDC provider`, y el `environment`.

### 5.3 Validar

```bash
# Default: MODE=local
bash tests/validate.sh /tmp/gha-oidc

# Opcional: MODE=live (requiere `aws` CLI con creds)
MODE=live bash tests/validate.sh /tmp/gha-oidc
```

### 5.4 Pistas

- El JSON tiene que parsear con `python3 -c "import json; json.load(open('trust-policy.json'))"`.
- El workflow tiene que parsear con `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/deploy.yml'))"`.
- `permissions: {}` top-level se escribe tal cual (dict vacío).
- `role-session-name: GitHubActions-${{ github.run_id }}` ayuda a trazar en CloudTrail.
- Si olvidas `environment:production` en el job, el `sub` del JWT no tendrá `environment:` y la trust que pinnea por env no match.

## 6. Resultado esperado

- `trust-policy.json` parsea JSON y tiene todos los campos requeridos.
- `.github/workflows/deploy.yml` parsea YAML; tiene `id-token: write` en el job (no top-level) y usa `configure-aws-credentials`.
- Cero menciones de `AKIA.*` / `secrets.AWS_ACCESS_KEY_ID` / `secrets.AWS_SECRET_ACCESS_KEY` / `permissions: write-all`.
- `docs/oidc.md` presente con las 4 menciones mínimas.
- `tests/validate.sh` → `RESULT: ALL CHECKS PASS`.

## 7. Criterios de aceptación

- [ ] JSON válido con los 5 campos requeridos.
- [ ] Workflow YAML válido con `id-token: write` *en el job* (no top-level).
- [ ] Workflow sin secrets AWS de larga vida.
- [ ] Pin del `sub` incluye `environment:production` o `environment:<algo>`.
- [ ] `permissions:` top-level es `{}` o solo `contents: read`.
- [ ] `docs/oidc.md` menciona: `AssumeRoleWithWebIdentity`, `sub`, `OIDC provider`, `environment`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gha-oidc
```

El validator:

1. Parsea `trust-policy.json` con `python3 -m json.tool`.
2. Semántica: `Version`, `Statement[*].Effect=Allow`, `Action=sts:AssumeRoleWithWebIdentity`, `Principal.Federated` termina en `/token.actions.githubusercontent.com`, `aud=sts.amazonaws.com`, `sub` empieza con `repo:` sin wildcard peligroso **y** contiene `:environment:`.
3. Parsea el workflow con `python3 -c "import yaml; …"`.
4. Verifica `permissions: id-token: write` en algún job (no top-level); top-level restrictivo (`{}` o `contents: read`).
5. Usa `aws-actions/configure-aws-credentials` con `role-to-assume`.
6. **No** contiene `AKIA`, `secrets.AWS_ACCESS_KEY_ID`, `secrets.AWS_SECRET_ACCESS_KEY`, `permissions: write-all`.
7. `docs/oidc.md` menciona `AssumeRoleWithWebIdentity`, `sub`, `OIDC provider`, `environment`.

En `MODE=live` añade: `aws sts get-caller-identity` del host debe funcionar.

## 9. Preguntas de reflexión

1. ¿Qué pasa si cambias el pin del `sub` a `repo:MyOrg/MyRepo:ref:refs/heads/main`? ¿Deployas igual? ¿Qué pierdes?
2. ¿Por qué el `permissions:` top-level es `{}` y lo subes solo en el job?
3. Imagina que un contributor abre un PR modificando `deploy.yml` para dumpear el OIDC token a los logs. ¿Qué defensas tienes antes de que llegue a asumir prod?
4. ¿Cómo cambiaría la trust policy si quisieras permitir deploy desde `main` **O** desde `environment:production`?
5. ¿Qué cambia operacionalmente si `MaxSessionDuration` del rol es 12h vs 1h?

## 10. Extensiones

- **E1** — Añade un segundo rol `github-deploy-staging` y un segundo job `deploy-staging` con `environment: staging`.
- **E2** — Añade un step que dumpee los claims del JWT (solo en una branch `debug/*`, nunca en main) y verifica que el `sub` real matchea lo que esperabas.
- **E3** — Replica el patrón contra GCP (WIF). ¿Cómo cambia la "trust policy"? (Pista: `attribute_condition` CEL + binding sobre la SA).

## 11. Limpieza

```bash
rm -rf /tmp/gha-oidc
```

En `MODE=live`:

```bash
aws iam detach-role-policy --role-name github-deploy-prod \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
aws iam delete-role --role-name github-deploy-prod
# El OIDC provider lo compartes entre repos: no lo borres si otros proyectos lo usan.
```
