# REFERENCE — aws-02-01-write-least-privilege-policy

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## `POLICY.json` (modelo)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListBucketScopedToMonthlyPrefix",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::acme-reports",
      "Condition": {
        "StringLike": {
          "s3:prefix": ["monthly/", "monthly/*"]
        }
      }
    },
    {
      "Sid": "GetMonthlyObjects",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:GetObjectVersion"],
      "Resource": "arn:aws:s3:::acme-reports/monthly/*"
    }
  ]
}
```

## `JUSTIFICATION.md` (modelo)

### Qué concedía la original

La policy `"Action": "*"` + `"Resource": "*"` no era "todo S3": era **todo AWS**. Concretamente, concedía:

- Todas las acciones de S3 (incluyendo `s3:DeleteBucket`, `s3:PutBucketPolicy`).
- Todas las acciones de IAM, incluyendo `iam:DeleteRole` sobre su propio rol y `iam:PutRolePolicy` para auto-escalar privilegios o `iam:CreateUser` + `iam:CreateAccessKey` para abrir una puerta trasera.
- Todas las acciones de EC2, RDS, Lambda, etc. — es decir, poder costar dinero sin tope.
- Todas las acciones de billing/organizations (si el rol estuviera en la cuenta de management).

En resumen, un rol con esa policy es equivalente a `AdministratorAccess` sobre toda la cuenta. Si se compromete, el blast radius es la cuenta entera.

### Decisiones de la nueva policy

- **Dos statements, no uno.** `s3:ListBucket` opera sobre el ARN del **bucket** (`arn:aws:s3:::acme-reports`); `s3:GetObject` opera sobre el ARN del **objeto** (`arn:aws:s3:::acme-reports/monthly/*`). Separarlos deja la intención explícita y permite poner la `Condition` de prefijo justo donde corresponde.
- **`Condition s3:prefix`.** Sin esta condición, `aws s3 ls s3://acme-reports/` listaría todo el bucket. Con la condición, listar cualquier otro prefijo devuelve `AccessDenied`.
- **`s3:GetObjectVersion` incluido.** El bucket tiene versioning activo; la app a veces baja una versión antigua. Si no fuera el caso, lo quitaría.
- **ARNs explícitos**, no wildcards. `arn:aws:s3:::acme-reports` es un ARN concreto; `arn:aws:s3:::acme-reports/monthly/*` restringe los objetos al prefijo. Nada apunta a `*`.

### Lo que deliberadamente dejé fuera

- **`s3:PutObject` / `s3:DeleteObject`**: la app solo lee. Añadirlos abre la puerta a escrituras no planificadas (y a borrados accidentales, que con versioning se recuperan, pero generan ruido).
- **`s3:GetBucketLocation`**: la SDK solo lo necesita si no se le pasa la región explícita. Nuestra app configura `region=us-east-1` al crear el cliente, por lo que es innecesario.
- **`s3:GetObjectAcl`**: en buckets modernos las ACLs están deshabilitadas; no hay ACL que leer. Si el bucket fuera legacy con ACLs activas, lo añadiría acotado al mismo ARN de objeto.
- **`kms:Decrypt`**: por ahora los objetos están cifrados con SSE-S3 (clave gestionada por S3). Si se migraran a SSE-KMS con una CMK customer-managed, haría falta añadir `kms:Decrypt` sobre esa key en la policy del rol **y** permitir al rol en la **key policy** de la KMS.

### Cómo lo validaría contra el motor real

Antes de desplegar, correría:

```bash
aws iam simulate-custom-policy \
  --policy-input-list "file://POLICY.json" \
  --action-names s3:ListBucket s3:GetObject s3:PutObject s3:DeleteObject \
  --resource-arns arn:aws:s3:::acme-reports \
                  arn:aws:s3:::acme-reports/monthly/report.pdf
```

Esperado:

- `s3:ListBucket` sobre `arn:aws:s3:::acme-reports` **con contexto** `s3:prefix=monthly/` → `allowed`.
- `s3:GetObject` sobre `.../monthly/report.pdf` → `allowed`.
- `s3:PutObject`, `s3:DeleteObject` → `implicitDeny`.

(En su defecto, mismo ejercicio en el Policy Simulator de consola.)

## Puntos clave

1. **"Action: *" es "todo AWS", no "todo S3"**: siempre es un error de diseño.
2. **Dos ARNs → dos statements**: bucket y objeto son ARNs distintos.
3. **`s3:prefix` como `Condition`** es lo que convierte `ListBucket` de "contaminante" en "acotado".
4. **Añade lo que la app usa, no lo que podría usar.** La mantenibilidad no está en "cubrir todos los casos", sino en poder volver y añadir cuando aparezca un `AccessDenied` real.
