# Ejemplo 03 — OIDC federation GitHub Actions → AWS

## Concepto que demuestra

Un workflow de GitHub Actions que **asume un rol en AWS** sin usar ningún secreto de larga vida, usando el token OIDC que GitHub emite por cada run.

## Contexto

Patrón clásico (malo): guardas `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` como secrets del repo. Vida de años. Si se filtran: compromiso duradero.

Patrón OIDC (bueno): el workflow pide a GitHub un **JWT firmado** con claims identificando el run (repo, branch, environment, workflow). STS lo canjea por credenciales temporales (típicamente ≤ 1 h). Ver `theory/lesson.md` sección 2.5 para el flujo completo.

Lo que necesitas del lado AWS:
1. Un **OIDC Provider** `token.actions.githubusercontent.com` registrado en IAM (una vez por cuenta).
2. Un **IAM Role** con `AssumeRolePolicyDocument` que **pinnea el `sub`** al repo/branch/environment correctos.

Lo que necesitas del lado GitHub:
1. `permissions: { id-token: write }` en el workflow (sin esto, no se emite OIDC token).
2. La acción `aws-actions/configure-aws-credentials@v4` con `role-to-assume`.

## Archivos

- `trust-policy.json` — a usar al crear el rol IAM. **`AWS-ACCOUNT-ID` es dummy; sustitúyelo.**
- `deploy.yml` — a copiar en `.github/workflows/deploy.yml` del repo.

## Flujo ASCII

```
+-------------------+        1) JWT (iss, sub, aud, exp)         +-----------------+
| GitHub Actions    | --------------------------------------->   | AWS STS         |
| run (workflow)    |        AssumeRoleWithWebIdentity           | (trust policy)  |
|                   | <---------------------------------------   |                 |
|                   |        2) Temp credentials (<= 1h)         +-----------------+
+-------------------+
          |
          |   3) aws s3 cp ...
          v
     +---------+
     |  AWS    |
     | APIs    |
     +---------+
```

## Pinning del `sub` — opciones

| Pin value | Cuándo usar |
|-----------|-------------|
| `repo:OWNER/REPO:ref:refs/heads/main` | push a `main` |
| `repo:OWNER/REPO:ref:refs/tags/v*` | push de tags (release) |
| `repo:OWNER/REPO:pull_request` | PRs — ojo con PRs de forks |
| `repo:OWNER/REPO:environment:production` | **recomendado para prod** — combina con approval del environment |

**Nunca** uses `repo:OWNER/*` sin más condiciones.

## Ejecución local (lectura)

Este ejemplo no se "ejecuta" en tu máquina. Para probarlo end-to-end necesitas:

1. Una cuenta AWS (sandbox / personal).
2. Registrar el OIDC provider:
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list <ver docs AWS; GitHub auto-manages hoy, pero sigue requiriéndose>
   ```
3. Crear el rol con `trust-policy.json`:
   ```bash
   aws iam create-role --role-name github-deploy \
     --assume-role-policy-document file://trust-policy.json
   aws iam attach-role-policy --role-name github-deploy \
     --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
   ```
4. Copiar `deploy.yml` a `.github/workflows/` de tu repo, ajustar el ARN, y pushear.

Costo IAM: **USD 0**. Lo que puedas gastar depende de qué hagas con el rol una vez asumido.

## Verificación

En la UI del run, el step `aws sts get-caller-identity` debe imprimir un ARN tipo:

```
arn:aws:sts::123456789012:assumed-role/github-deploy/GitHubActions
```

Si falla con `An error occurred (AccessDenied) when calling the AssumeRoleWithWebIdentity operation`, revisa:
- Pin de `sub` en el trust policy coincide con la ref/environment real.
- `aud` del condition == `sts.amazonaws.com`.
- `permissions: id-token: write` en el workflow.
- El OIDC provider existe en IAM (`aws iam list-open-id-connect-providers`).

## Interpretación

- El token OIDC NO es un secret. Es efímero (≤ 15 min) y GitHub lo emite por cada job.
- La credencial AWS devuelta por STS sí lo es (temporal, ≤ 1 h) y vive solo en memoria del runner.
- No queda nada persistido. Si el runner se compromete *durante* el run, hay una ventana. Si se compromete después, no hay nada que robar.

## Equivalentes para otros clouds

- **GCP**: Workload Identity Federation + `google-github-actions/auth@v2`.
- **Azure**: Entra ID federated credentials + `azure/login@v2`.
- **HashiCorp Vault**: `hashicorp/vault-action` con `method: jwt`.

El patrón arquitectónico es idéntico; cambia la terminología.

## Errores frecuentes

- Falta `permissions: id-token: write` → `Unable to get Actions OIDC token`.
- Pin con `StringEquals` en `sub` pero el valor incluye wildcard → usar `StringLike`.
- Olvidar el `aud: sts.amazonaws.com` → request rechazado.
- Thumbprint del OIDC provider: históricamente requería mantenerlo; GitHub cambió el certificado, muchos integradores se rompieron. Hoy AWS lo autogestiona cuando creas el provider sin thumbprint explícito (consulta docs al día).

## Referencia

- GitHub Docs — <https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services>
- AWS Docs — <https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html>
