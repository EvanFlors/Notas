# Ejemplo 01 — Estrategia de tagging y enforcement con SCP

> Lectura y análisis. Sin ejecución. Sin cuenta AWS. El objetivo es ver, de un vistazo, qué tags exigir y cómo se exige con una **SCP**.

## 1. El set mínimo de tags obligatorios

| Tag | Valores admitidos | Razón de ser |
|-----|-------------------|--------------|
| `cost_center` | `cc-NNN` (contabilidad) | FinOps: a quién se le factura internamente. |
| `env` | `dev` \| `stg` \| `prd` | Separar producción de resto en Cost Explorer y en alertas. |
| `service` | `[a-z0-9-]+` | A qué servicio/producto pertenece el recurso. |
| `team` | `[a-z0-9-]+` | Ownership — quién responde ante un incidente o un spike. |
| `data_classification` | `public` \| `internal` \| `confidential` \| `pii` | Seguridad + routing a backup/retención distintas. |

Observa que **no** aparecen tags como `Name` o `createdBy`. Esos son útiles pero no son **gates**. El set anterior sí es *gate*: sin ellos, no se puede crear el recurso.

## 2. SCP de ejemplo (fragmento comentado)

```jsonc
// Objetivo: denegar RunInstances si falta cualquiera de los tags obligatorios.
// Esta SCP se adjunta a la OU "Workloads".
// Account IDs y ARNs son PLACEHOLDERS — no son reales.
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyRunInstancesWithoutMandatoryTags",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "Null": {
          "aws:RequestTag/cost_center": "true",
          "aws:RequestTag/env": "true",
          "aws:RequestTag/service": "true",
          "aws:RequestTag/team": "true",
          "aws:RequestTag/data_classification": "true"
        }
      }
    },
    {
      "Sid": "DenyWrongEnvValue",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringNotEqualsIfExists": {
          "aws:RequestTag/env": ["dev", "stg", "prd"]
        }
      }
    }
  ]
}
```

### Lectura clave

- La condición `Null` evalúa `true` cuando el tag **no viene** en el request. `Deny` + `Null: true` significa "si falta, deniega".
- `StringNotEqualsIfExists` solo aplica si el tag está presente; combinado con el gate `Null`, garantiza presencia **y** validez.
- La SCP se aplica a la **OU `Workloads`** (`dev`, `stg`, `prd`), no al management ni a `log-archive`/`audit` (que crean recursos de plataforma sin estos tags).

## 3. Qué pasa cuando falta un tag

- `terraform apply` → `UnauthorizedOperation` o `AccessDenied` con `encoded authorization failure message`.
- El ingeniero añade el tag → re-aplica → funciona.
- Se enseña **la primera vez**, no cada vez. Es la gran ventaja frente a scripts de recordatorio o policies "sugeridas".

## 4. Activar los tags en Billing (paso que todo el mundo olvida)

Un tag puesto en un recurso **no** aparece en Cost Explorer hasta que se **activa** en:

> *Billing → Cost allocation tags → User-defined cost allocation tags → Activate*

Después de activar, los costes **nuevos** empiezan a desglosarse por ese tag. Los costes **anteriores** no se reescriben.

## 5. Trampas habituales

- **Mayúsculas vs minúsculas**: `Env` y `env` son tags distintos en AWS. Elegir una convención (minúsculas, snake_case) y codificarla en la SCP.
- **Tags en recursos padre vs hijos**: un volumen EBS creado por un RunInstances **no hereda** los tags del instance a menos que uses `TagSpecifications` apropiado. Enforce también en `ec2:CreateVolume` o usa `aws:TagKeys` en la condición.
- **S3 buckets**: `s3:CreateBucket` admite tags; muchos scripts crean el bucket sin tags y luego hacen `PutBucketTagging`. La SCP debe cubrir ambos path.
- **Importar recursos existentes** no dispara `RequestTag`; esos recursos se saltan la SCP. Se compensa con una regla Config que marque no-compliance.

## 6. Preguntas de autocomprobación

1. ¿Por qué `cost_center` no es derivable de `team` directamente?
2. Si quiero añadir un sexto tag `project` solo para la OU `Workloads/dev`, ¿dónde lo hago: SCP, Config rule, documentación de equipo? ¿Por qué?
3. Si una SCP niega `s3:CreateBucket` sin tags, ¿qué pasa con la consola web de AWS que crea bucket sin pedir tags por defecto?
4. ¿Qué tag **nunca** debería ser obligatorio con SCP y por qué?

Las respuestas quedan abiertas; se discuten en la actividad `02-finops-dashboard-and-anomaly/`.
