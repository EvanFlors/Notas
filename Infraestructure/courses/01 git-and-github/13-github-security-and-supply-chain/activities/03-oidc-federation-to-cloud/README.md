# Actividad 03 — OIDC federation GitHub Actions → AWS (dual-mode)

## 1. Identificación

- **ID:** `gh-13-03-oidc-federation-to-cloud`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-13-github-security-and-supply-chain`
- **Dificultad:** advanced
- **Duración estimada:** 50–75 min
- **Tipo:** guided-lab (dual-mode: live AWS o validación local)

## 2. Contexto

El objetivo del módulo es **eliminar las credenciales de larga vida** del CI. Esta actividad construye el patrón OIDC completo:
- Un workflow GHA que **asume un rol AWS** sin ningún secret.
- Un trust policy IAM que **pinnea el `sub`** al repo + environment correcto.

En MODE=live lo despliegas en una cuenta AWS real (costo IAM = USD 0). En MODE=local el validator inspecta la **corrección** de ambos artefactos (YAML + JSON) sin ejecutar nada.

## 3. Objetivos

- Diseñar un `trust-policy.json` correcto: `Principal.Federated` apuntando al OIDC provider de GitHub, `Condition` con `aud: sts.amazonaws.com` y pin de `sub` por **repo + environment**.
- Diseñar un `deploy.yml` que:
  - Dispara en `push` a `main` o `workflow_dispatch`.
  - Declara `permissions: id-token: write` + `contents: read` (como mínimo).
  - Usa el environment `production`.
  - Usa `aws-actions/configure-aws-credentials` con `role-to-assume`.
  - **No** usa ningún `AKIA...` ni `secrets.AWS_*_KEY`.
- Documentar en `docs/oidc.md` el flujo y qué garantiza.

## 4. Prerrequisitos

- Para MODE=local (default): solo bash + python3 (para JSON) + grep.
- Para MODE=live: cuenta AWS con permiso IAM, `aws` CLI, repo GitHub real.

**Costos**: USD 0 para operaciones IAM/STS. Si el rol asumido se usa para operaciones facturables (S3, EC2…), eso lo asumes tú.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/oidc-fed
```

Esto crea `/tmp/oidc-fed/project/` con la estructura inicial (vacía de contenido relevante) y una guía en `README.md`.

### 5.2 Tareas

Trabaja en `/tmp/oidc-fed/project/`:

1. **Crear `trust-policy.json`** en la raíz, válido JSON, con la estructura:
   - `Version`: `"2012-10-17"`.
   - Un `Statement` con:
     - `Effect: "Allow"`.
     - `Action: "sts:AssumeRoleWithWebIdentity"`.
     - `Principal.Federated` apuntando a `arn:aws:iam::<AWS-ACCOUNT-ID>:oidc-provider/token.actions.githubusercontent.com`. **Usa `AWS-ACCOUNT-ID` o `000000000000` como placeholder.**
     - `Condition.StringEquals` con `token.actions.githubusercontent.com:aud: "sts.amazonaws.com"`.
     - `Condition.StringLike` con `token.actions.githubusercontent.com:sub: "repo:MyOrg/MyRepo:environment:production"` (puedes usar el patrón exacto, sin wildcard al dominio).

2. **Crear `.github/workflows/deploy.yml`**:
   - `on: push` a `main` (+ opcional `workflow_dispatch`).
   - **`permissions:` top-level restrictivo** (`{}` o solo `contents: read`).
   - Un job `deploy` que:
     - Usa `environment: production`.
     - Declara `permissions: { id-token: write, contents: read }`.
     - Primer step: `actions/checkout`.
     - Segundo step: `aws-actions/configure-aws-credentials@...` con `role-to-assume: arn:aws:iam::<AWS-ACCOUNT-ID>:role/github-deploy` y `aws-region`.
     - Tercer step: ejecuta `aws sts get-caller-identity` (prueba de concepto).
   - **No** debe contener strings tipo `AKIA`, ni `${{ secrets.AWS_ACCESS_KEY_ID }}`, ni `${{ secrets.AWS_SECRET_ACCESS_KEY }}`.

3. **Crear `docs/oidc.md`** explicando (mínimo 3 párrafos):
   - El flujo `AssumeRoleWithWebIdentity`.
   - Por qué el pin del `sub` es crítico y qué pasa sin él.
   - Qué se requiere en la cuenta AWS (OIDC provider en IAM).

### 5.3 Validar

```bash
# MODE=local (default)
bash tests/validate.sh /tmp/oidc-fed

# MODE=live (requiere aws CLI auth; el validator también lee workflow y policy)
MODE=live bash tests/validate.sh /tmp/oidc-fed
```

### 5.4 Pistas

- Pista 1: El JSON del trust policy debe parsear con `python3 -c "import json,sys;json.load(open(sys.argv[1]))"`.
- Pista 2: En el workflow, `permissions: id-token: write` **debe** estar en el job (o top-level) o AWS no recibirá el token.
- Pista 3: Pinnear `sub` con `StringLike` + exact value es idéntico a `StringEquals`; usa cualquiera. `StringLike` solo tiene sentido con wildcards.
- Pista 4: Para "environment" en el sub: `repo:<org>/<repo>:environment:<env-name>`.

## 6. Resultado esperado

- `trust-policy.json` parsea JSON, tiene los 5 campos correctos.
- `.github/workflows/deploy.yml` parsea YAML, tiene `id-token: write`, usa `configure-aws-credentials`, cero menciones a `AKIA`/`AWS_ACCESS_KEY_ID` como secret.
- `docs/oidc.md` existe y menciona el flujo + pin del sub + OIDC provider.
- `tests/validate.sh` → `RESULT: ALL CHECKS PASS`.

## 7. Criterios de aceptación

- [ ] JSON válido y con todos los campos requeridos.
- [ ] Workflow YAML válido con `id-token: write`.
- [ ] Workflow sin secrets AWS de larga vida.
- [ ] Pin del `sub` **no es wildcard** (`repo:MyOrg/*` sería FAIL).
- [ ] Documento `docs/oidc.md` mínimo presente.

## 8. Validación

```bash
bash tests/validate.sh /tmp/oidc-fed
```

El validator:

1. Carga `trust-policy.json` con `python3 -m json.tool` (parse válido).
2. Verifica, usando `python3`, que:
   - `Version == "2012-10-17"`.
   - Hay al menos un `Statement` con `Effect=Allow`, `Action=sts:AssumeRoleWithWebIdentity`, `Principal.Federated` termina en `/token.actions.githubusercontent.com`.
   - `Condition.StringEquals` incluye `token.actions.githubusercontent.com:aud=sts.amazonaws.com`.
   - Existe un pin del `sub` (StringEquals o StringLike) que empieza por `repo:` y **no** usa `*` justo después del nombre del repo.
3. Verifica el YAML con `python3 -c "import yaml;…"` (parse válido).
4. Verifica que en algún `permissions:` del workflow aparece `id-token: write`.
5. Verifica que el workflow usa `aws-actions/configure-aws-credentials` (cualquier versión).
6. Verifica que el workflow **NO contiene** `AKIA`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` como env/secret largos.
7. Verifica que `docs/oidc.md` existe y menciona `AssumeRoleWithWebIdentity`, `sub`, y `OIDC provider` (los 3).

En MODE=live añade: `aws sts get-caller-identity` debe funcionar (si no, documentarlo).

## 9. Preguntas de reflexión

1. ¿Qué pasa exactamente si en el trust policy pones `token.actions.githubusercontent.com:sub: "repo:MyOrg/*"`?
2. ¿Por qué `permissions: id-token: write` **no es un riesgo** por sí mismo?
3. ¿Qué cambia operacionalmente si el pin del sub es por `ref:refs/heads/main` vs por `environment:production`? ¿Cuál es más fuerte?
4. Un atacante consigue abrir un PR en tu repo. ¿Puede asumir el rol? ¿Qué patrón de sub lo evitaría? ¿Qué otros controles?
5. Compara OIDC a AWS vs OIDC a GCP: ¿qué cambia en el trust (Workload Identity Pool)?

## 10. Extensiones

- **E1** — Añade un segundo rol `deploy-staging` con pin del sub distinto (`environment:staging`), y un segundo job en el workflow.
- **E2** — Añade un step que verifica el token OIDC crudo con `curl` al endpoint `GITHUB_ID_TOKEN_REQUEST_URL`. Comenta por qué esto es útil para debug.
- **E3** — Investiga PyPI "trusted publishers" (OIDC a PyPI). Diseña el equivalente conceptual.

## 11. Limpieza

```bash
rm -rf /tmp/oidc-fed
```

En MODE=live, borra el rol IAM:

```bash
aws iam detach-role-policy --role-name github-deploy --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
aws iam delete-role --role-name github-deploy
# Opcional: borrar el OIDC provider si no lo compartes
```
