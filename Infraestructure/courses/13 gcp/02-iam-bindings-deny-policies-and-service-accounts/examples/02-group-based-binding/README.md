# Ejemplo 02 — Bindings por Google Group (no por usuario)

> Lectura y análisis. Sin ejecución. Objetivo: fijar por qué los bindings productivos **nunca** mencionan a `user:` directamente.

## 1. El antipatrón

```yaml
# allow policy del project acme-prod
bindings:
  - role: roles/run.developer
    members:
      - user:alice@acme.io
      - user:bob@acme.io
      - user:carol@acme.io
      - user:dave@acme.io
      - user:erin@acme.io
```

Lee como "cinco personas pueden desplegar en Cloud Run". Problema: cuando Alice se va de la empresa, hay que:

1. Darse cuenta de que Alice tenía ese acceso (hay que auditarlo).
2. Editar la allow policy del project y quitar `user:alice@acme.io`.
3. Hacer lo mismo en los otros 15 projects donde Alice tenía bindings.
4. Repetir cuando entre Frank.

En una org con 30 desarrolladores y 20 projects, esto es trabajo de mantenimiento permanente. En la práctica **no se hace**, y los permisos de ex-empleados sobreviven meses.

## 2. El patrón correcto

```yaml
# allow policy del project acme-prod
bindings:
  - role: roles/run.developer
    members:
      - group:platform-eng@acme.io
```

Una línea. El Google Group `platform-eng@acme.io` se mantiene en el IdP (Google Workspace, o sincronizado desde Okta/Entra vía SCIM). Añadir a Frank = añadir a Frank al grupo. Quitar a Alice = quitarla del grupo. **GCP no se toca.**

Beneficios materiales:

1. **Rotación de personal desacoplada** de la gestión de permisos GCP.
2. **Auditoría trivial**: `gcloud identity groups memberships list --group-email=platform-eng@acme.io` lista a los 5 (o 50). El binding es "estable" en Git.
3. **Policy as code en Terraform** no cambia cuando cambia el equipo — solo cuando cambia la **política**.
4. **Lifecycle del empleado**: cuando HR desprovisiona a Alice en el IdP, pierde acceso a GCP automáticamente.

## 3. Catálogo mínimo de grupos para una org pequeña

| Grupo | Qué contiene | Qué bindings típicos recibe |
|-------|--------------|------------------------------|
| `platform-eng@acme.io` | SREs/Platform (acceso amplio en dev, read en prod) | `roles/editor` en dev projects, `roles/viewer` en prod |
| `developers@acme.io` | Developers de producto | `roles/run.developer` en dev, `roles/run.viewer` en prod |
| `data-analysts@acme.io` | Analistas | `roles/storage.objectViewer` en bucket de analytics, `roles/bigquery.dataViewer` |
| `break-glass-prod@acme.io` | 2–3 personas de emergencia | `roles/owner` en prod — con alerta por cada acceso |
| `security-audit@acme.io` | Equipo de seguridad | `roles/iam.securityReviewer`, `roles/logging.viewer` en toda la org |
| `billing-viewers@acme.io` | Finance | `roles/billing.viewer` en la Billing Account |

Observa: **ningún** `user:...@acme.io`. Si alguien necesita acceso puntual, se añade a un grupo y se audita el cambio de membresía.

## 4. Excepciones legítimas a "siempre group"

1. **Service accounts como members**: `serviceAccount:<sa>@<proj>.iam.gserviceaccount.com` es correcto (no son humanos). La SA **sí** se referencia directamente.
2. **`domain:acme.io`** para buckets internos de documentación (todos los empleados). Peligroso si `allowedPolicyMemberDomains` no está bien.
3. **`principalSet://...`** para WIF — mapea claims OIDC, no humanos directamente.
4. **Owner inicial del project**: el humano que lo crea queda con `roles/owner`. Debería **retirarse** cuanto antes y sustituirse por un binding de grupo.

## 5. Pero… ¿y si Google Groups no está disponible?

- **Externo (Okta, Entra ID)**: usa SCIM push al dominio Google Workspace / Cloud Identity. Los grupos del IdP se materializan como Google Groups automáticamente. Es el patrón empresarial estándar.
- **Sin IdP corporativo**: usa Cloud Identity (gratis en su tier básico) solo para los grupos. Sigue siendo mejor que `user:` directo.
- **No usar Google Workspace de ninguna forma**: posible pero inviable a escala — pierdes el patrón. En ese escenario, considera `principalSet://` con WIF para humanos (poco común, pero legal).

## 6. Validación mental antes de un commit a Terraform

Antes de hacer merge de un cambio de IAM, pregunta:

- ¿Añade este binding un `user:` directo? Si sí, ¿por qué no un group?
- ¿Añade `allUsers` o `allAuthenticatedUsers`? Si sí, ¿está justificado y revisado por seguridad?
- ¿Añade un basic role (`roles/owner`, `roles/editor`, `roles/viewer`)? Si sí, ¿es un dev project? ¿Hay un predefined que encaje?
- ¿Añade un rol en Organization/Folder cuando bastaría en Project o en el recurso concreto? Si sí, ¿por qué?

## 7. Preguntas de autocomprobación

1. Si quitas a Alice del grupo `platform-eng@acme.io`, ¿cuánto tarda en perder los permisos efectivos en los projects donde el grupo tiene bindings? ¿Las sesiones activas (ADC tokens) caducan al instante?
2. Un junior añade a su commit un binding con `user:his-personal@gmail.com` por error. ¿Qué org policy lo bloquea? (Pista: sección 9 de la lección.)
3. Rotación: entra Frank, sale Alice. Lista los pasos exactos con bindings por grupo vs con bindings por usuario — compara el número de operaciones.
4. ¿Puedes anidar un Google Group dentro de otro (`platform-leads@acme.io` ⊂ `platform-eng@acme.io`)? ¿Qué impacto tiene en los bindings?
5. ¿Qué prefijo usarías en `members` para una SA de otro project? ¿Y para un principal de WIF?
