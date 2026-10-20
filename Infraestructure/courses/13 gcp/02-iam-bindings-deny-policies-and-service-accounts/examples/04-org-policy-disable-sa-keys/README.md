# Ejemplo 04 — Org Policy: deshabilitar creación de SA keys

> Lectura y análisis. Sin ejecución. Objetivo: entender por qué `iam.disableServiceAccountKeyCreation` es el **primer** control defensivo que aplicas en una organización GCP.

## 1. El constraint

**Nombre canónico**: `constraints/iam.disableServiceAccountKeyCreation`

**Tipo**: boolean (on/off).

**Qué hace**: cuando está en `enforced=True`, cualquier llamada a `iam.serviceAccounts.keys.create` (API o `gcloud iam service-accounts keys create`) **falla** con `FAILED_PRECONDITION`. No se puede emitir un JSON de SA key en los projects bajo el scope de la policy.

## 2. YAML de la policy

```yaml
# Org policy adjuntada al folder "prod" (y por herencia a todos sus projects)
name: folders/123456789012/policies/iam.disableServiceAccountKeyCreation
spec:
  rules:
    - enforce: true
```

Variante por organización (recomendada en el baseline inicial):

```yaml
name: organizations/987654321098/policies/iam.disableServiceAccountKeyCreation
spec:
  rules:
    - enforce: true
  inheritFromParent: false
```

Variante con excepción puntual para un project heredado (durante una migración):

```yaml
# En el project legacy, aflojamos
name: projects/legacy-etl-prod/policies/iam.disableServiceAccountKeyCreation
spec:
  rules:
    - enforce: false
  inheritFromParent: false   # romper la herencia
```

> Observa: `inheritFromParent: false` **sobrescribe** la policy del padre. Útil para excepciones controladas; peligroso si se abusa. En revisión de código: cada excepción debe tener comentario con fecha de deprecación y ticket.

## 3. Por qué va primero

En una org nueva, antes de darle acceso a nadie, aplicas estas tres cosas en este orden:

1. **`iam.disableServiceAccountKeyCreation=enforced`** — nadie puede emitir keys.
2. **`iam.automaticIamGrantsForDefaultServiceAccounts=False`** — la default SA no viene con `roles/editor`.
3. **`iam.allowedPolicyMemberDomains=["acme.io"]`** — solo principals del dominio corporativo pueden aparecer en bindings.

Las tres juntas **eliminan tres clases de incidente** antes de que ocurran:

- Clase 1: credencial filtrada de SA key sin rotación.
- Clase 2: workload con default SA que puede hacer **todo** en el project.
- Clase 3: binding con `user:someone@gmail.com` por copy-paste.

## 4. Qué **rompe** esta policy (ser honestos)

Honestidad operacional — esta policy sí rompe cosas que estabas haciendo mal:

| Cosa que rompe | Qué debes hacer en su lugar |
|----------------|------------------------------|
| Workload en EC2/on-prem que usaba una SA key JSON | Migrar a WIF (`gcp-10`) o a una SA del propio compute si estás en GCP |
| GitHub Actions con `GOOGLE_APPLICATION_CREDENTIALS` montando una key en secret | WIF desde GitHub Actions (`gcp-10`) |
| Developer local probando con una key descargada | `gcloud auth application-default login` + impersonation |
| Terraform corriendo en Jenkins on-prem con una key | WIF o self-hosted runner en GCP con SA attached |
| App legacy en App Engine std con una key en secret | Attached SA del propio App Engine |

Observa: **ningún caso legítimo** requiere una SA key en 2026. Si tu equipo "necesita" una, es señal de deuda de arquitectura.

## 5. Qué **NO** rompe la policy

- **No** afecta a SAs ya existentes ni a keys ya emitidas. Si existe una key creada antes, sigue funcionando hasta que la revoques explícitamente (`gcloud iam service-accounts keys delete`).
- **No** afecta a impersonation ni a attached SAs ni a Workload Identity Federation.
- **No** afecta a los OAuth tokens de humanos (`gcloud auth login`).

**Consecuencia operacional**: aplicar la policy **no limpia** las keys existentes. Hay un trabajo separado: auditarlas (`gcloud iam service-accounts keys list --iam-account=...` para cada SA) y revocarlas.

## 6. Auditoría de keys existentes antes de activar

Script conceptual (no ejecutar aquí; es ilustrativo):

```bash
# Para cada project, para cada SA, listar keys USER_MANAGED (no SYSTEM_MANAGED)
# Las SYSTEM_MANAGED son keys internas de Google (no se pueden borrar y rotan solas).
for proj in $(gcloud projects list --format='value(projectId)'); do
  for sa in $(gcloud iam service-accounts list --project="$proj" --format='value(email)'); do
    gcloud iam service-accounts keys list \
      --iam-account="$sa" \
      --project="$proj" \
      --managed-by=user \
      --format="table(name,validAfterTime,validBeforeTime)"
  done
done
```

Lo que buscas:

- Keys con `validAfterTime` **antiguo** (meses o años) — candidatas a revocación inmediata.
- Keys sin `validBeforeTime` (sin expiración) — todas, por defecto. Riesgo máximo.

## 7. Diferencia con AWS

AWS no tiene un constraint directo equivalente ("ningún IAM user puede crear access keys para sí mismo"). Lo más cercano es una SCP:

```json
{
  "Effect": "Deny",
  "Action": ["iam:CreateAccessKey"],
  "Resource": "*"
}
```

GCP lo expone como **constraint declarativo**, no como deny policy. Es más semántico ("prohíbo esta **configuración** del recurso SA") y más fácil de auditar en la consola.

## 8. Preguntas de autocomprobación

1. ¿Qué comando falla cuando `iam.disableServiceAccountKeyCreation=enforced`? ¿Con qué mensaje de error?
2. Si un developer dice "necesito una SA key para probar", ¿cuál es la respuesta correcta en términos de patrones GCP?
3. ¿Qué pasa con las keys **ya emitidas** cuando activas esta policy? ¿Por qué este punto importa en una migración?
4. Un project `legacy-etl-prod` **necesita** mantener una key durante 3 meses mientras migra a WIF. ¿Cómo expresas la excepción? ¿Qué controles compensatorios añades?
5. ¿Qué otras org policies pondrías en el mismo baseline inicial y por qué?
