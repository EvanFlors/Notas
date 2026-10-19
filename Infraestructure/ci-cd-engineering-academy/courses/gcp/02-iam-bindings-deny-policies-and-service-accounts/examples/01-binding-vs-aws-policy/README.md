# Ejemplo 01 — Binding GCP vs IAM Policy AWS

> Lectura y análisis. Sin ejecución. Objetivo: fijar en memoria **dónde vive el permiso** en cada nube para el mismo caso.

## 1. El escenario

Un equipo de data analysts necesita **leer** objetos del bucket de datos de producción `acme-prod-data`. No debe poder escribir ni borrar. Son 8 personas, con rotación: entran 2, salen 1 cada semestre.

## 2. Formulación en AWS

En AWS creas un IAM Group (o Role, o lista de users) y le **adjuntas** una policy JSON. La policy viaja con el principal:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::acme-prod-data",
        "arn:aws:s3:::acme-prod-data/*"
      ]
    }
  ]
}
```

Montaje:

```
IAM Group: DataReaders
  ├── Attached policy: DataReadersPolicy (JSON de arriba)
  └── Members: alice, bob, carol, ... (8 IAM users o SSO assignments)
```

Para auditar "¿quién puede leer `acme-prod-data`?":

```
aws iam list-attached-group-policies --group-name DataReaders
aws iam get-group --group-name DataReaders   # lista miembros
```

Partes incómodas:

- La policy menciona el **recurso en su cuerpo** (`arn:aws:s3:::acme-prod-data`). Si el bucket se renombra, hay que editar la policy.
- El scope del allow (los dos ARNs) **no está en el bucket** — está en la policy.

## 3. Formulación en GCP

En GCP, modificas la **allow policy del bucket**. El permiso vive **en el recurso**:

```yaml
# gcloud storage buckets get-iam-policy gs://acme-prod-data --format=yaml
bindings:
  - role: roles/storage.objectViewer
    members:
      - group:data-analysts@acme.io
etag: BwX8pQ...
version: 3
```

Montaje:

```
Resource: gs://acme-prod-data
  └── Allow policy
        └── binding (role=roles/storage.objectViewer,
                     members=[group:data-analysts@acme.io])

Google Group: data-analysts@acme.io
  └── Members: alice@acme.io, bob@acme.io, ... (8)
```

Para auditar "¿quién puede leer `acme-prod-data`?":

```
gcloud storage buckets get-iam-policy gs://acme-prod-data
```

Y luego, para cada binding, resuelves el grupo:

```
gcloud identity groups memberships list --group-email=data-analysts@acme.io
```

## 4. Diferencias materiales

| Aspecto | AWS | GCP |
|---------|-----|-----|
| Dónde vive el permiso | Adjunto al principal (user/group/role) | En el recurso (allow policy) |
| Granularidad del rol | Policy JSON a medida con actions | Role predefinido referenciado por nombre |
| Rotación de personas | Añadir/quitar del IAM Group | Añadir/quitar del Google Group — **sin tocar GCP** |
| Auditoría "¿quién puede X recurso?" | Reverse-lookup desde principals | Lectura directa del recurso |
| Auditoría "¿qué puede X persona?" | Leer policies adjuntas al principal | Recorrer la jerarquía Resource Manager hacia abajo |
| Renombrar el recurso | Editar la policy (ARN en el cuerpo) | Normalmente no aplica (el binding está EN el recurso) |

## 5. Qué cambia si quieres añadir "escribir en un prefijo"

**AWS**: añades un segundo `Statement` a la misma policy:

```json
{
  "Effect": "Allow",
  "Action": "s3:PutObject",
  "Resource": "arn:aws:s3:::acme-prod-data/analytics-uploads/*"
}
```

**GCP**: añades un segundo binding al bucket, con **condition** sobre el prefijo:

```yaml
bindings:
  - role: roles/storage.objectViewer
    members:
      - group:data-analysts@acme.io
  - role: roles/storage.objectCreator
    members:
      - group:data-analysts@acme.io
    condition:
      title: only-analytics-uploads-prefix
      expression: |
        resource.name.startsWith(
          "projects/_/buckets/acme-prod-data/objects/analytics-uploads/"
        )
```

Observaciones:

1. GCP necesita la **condition** porque los roles predefinidos no granulan por prefijo. En AWS, el prefijo es parte del `Resource`.
2. CEL es más expresivo que condiciones IAM AWS en algunos casos, menos en otros.
3. Si quieres algo que ni predefined ni condition cubren, en GCP recurres a un **custom role** con `includedPermissions` específicos.

## 6. Lectura clave

- El **cambio de locus** (principal → recurso) implica que las herramientas, los dashboards y los procesos de auditoría se construyen distinto. No es "una policy equivale a un binding"; es una organización mental distinta.
- **Grupos** son el mecanismo compartido: en AWS son IAM Groups o Identity Center groups; en GCP son Google Groups del dominio corporativo. En ambos: **nunca** `user:alice@...` directamente en producción.
- Los **roles predefinidos** de GCP son más tacaños a veces (p. ej., `objectViewer` incluye `storage.objects.get` y `.list` — AWS te deja listar o no por acción distinta). Trade-off: menos verbosidad, menos granularidad por defecto.

## 7. Preguntas de autocomprobación

1. En AWS, si borras el IAM Group `DataReaders`, ¿qué pasa con los permisos de sus miembros al bucket? ¿Y en GCP si borras el Google Group `data-analysts@acme.io`?
2. Un auditor pide "lista todos los principals con acceso a `acme-prod-data`". ¿Qué comando ejecutas en cada nube?
3. Añades 2 personas al equipo. En AWS son IAM users nuevos; en GCP son usuarios ya existentes del dominio. ¿En qué nube hay que tocar la policy / el binding del bucket? ¿Por qué?
4. En GCP, un binding con `members: ["user:alice@acme.io"]` ¿se recomienda o no? Justifica desde la perspectiva de rotación de personal.
5. Si quisieras conceder lectura al bucket **solo** entre lunes y viernes, ¿cómo lo modelarías en AWS? ¿Y en GCP?
