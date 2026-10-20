# ADR 010 — Pipeline GitHub Actions → GCP sin service account keys (WIF)

## Estado

Propuesto (Fase 3). Objetivo: aceptado y materializado con Terraform en Fase 4 antes del audit anual.

## Contexto

El pipeline actual publica imágenes a Artifact Registry autenticándose con una **service account key JSON** almacenada en `secrets.GCP_SA_KEY`. Esa key:

- Fue creada hace 14 meses y nunca se ha rotado.
- Tiene `roles/editor` sobre el project (riesgo de blast radius alto).
- Aparece semanalmente como finding en Security Command Center (SCC) categoría *Service Account Key Age > 90 days*.
- No deja rastro útil en Audit Logs: la auditoría solo ve que "la SA actuó", no desde dónde.

Queremos eliminarla antes del audit anual, sin que el pipeline deje de funcionar. GitHub Actions soporta **OIDC**, GCP soporta **Workload Identity Federation (WIF)**: la combinación elimina la key sin añadir piezas.

Constraints:

- Única región: `europe-west1` (compliance).
- Único repo que publica a `prod-images`: `acme/checkout` (los demás repos usan otros repos de Artifact Registry).
- Pipeline debe seguir corriendo en `push` a `main`.

## Decisión

### 1. Introducir Workload Identity Federation

Un único **Workload Identity Pool** `github-pool` agrupará todos los providers OIDC externos (hoy solo GitHub; en el futuro podría añadirse GitLab). Un **provider** OIDC `github-oidc` dentro del pool apunta a `https://token.actions.githubusercontent.com`.

### 2. Pin del provider al repo correcto vía `attribute_condition`

El provider lleva:

```hcl
attribute_condition = "assertion.repository == \"acme/checkout\""
```

Esto rechaza **en el intercambio del token** cualquier JWT de GitHub Actions que no venga del repo `acme/checkout`. Un fork del repo en otro owner es rechazado antes de que entre en juego el binding de la SA.

### 3. Service account dedicada con mínimo privilegio

Se crea `gha-publisher@my-project-123.iam.gserviceaccount.com` con **solo** `roles/artifactregistry.writer` **solo** sobre el repo `prod-images` de Artifact Registry. Nada de `roles/editor`, nada a nivel de project.

### 4. Binding con `principalSet://` filtrado por `attribute.repository`

```
principalSet://iam.googleapis.com/projects/.../workloadIdentityPools/github-pool/attribute.repository/acme/checkout
```

Esto es **defensa en profundidad**: si por error se relajara el `attribute_condition`, el binding sigue filtrando.

### 5. Workflow GHA sin secretos de GCP

```yaml
permissions:
  id-token: write
  contents: read
```

y `google-github-actions/auth@v2` con `workload_identity_provider` + `service_account`. **No hay** `secrets.GCP_SA_KEY` en el workflow — el secret se elimina del repo tras el cutover.

### 6. Modelo de cutover

1. Crear WIF + SA nuevas (coexisten con la key vieja).
2. Nuevo workflow en una rama; probar end-to-end.
3. En main, reemplazar el workflow viejo.
4. Esperar 7 días sin incidencias.
5. Borrar la key JSON (`gcloud iam service-accounts keys delete`) y el secret `GCP_SA_KEY`.
6. Borrar la SA vieja si ya no se usa.

## Consecuencias

### Positivas

- **Cero service account keys estáticas**. El finding de SCC desaparece.
- Audit trail completo: cada acción incluye `repository`, `ref`, `actor` de GitHub.
- Tokens efímeros (≤1 h). Un leak accidental es casi inútil.
- Rotación eliminada como preocupación operacional.

### Negativas

- Configuración inicial más compleja que "pegar una key en Secrets". Mitigación: Terraform versionado.
- Debug de errores OIDC requiere leer Cloud Audit Logs del pool/provider — curva de aprendizaje nueva para el equipo.
- Dependencia operativa de GitHub como IdP: si GitHub Actions OIDC está caído, el pipeline no puede autenticarse. Mitigación: documentar procedimiento manual de emergencia con BreakGlass en consola.

## Alternativas descartadas

### Alternativa A: rotar la key y seguir con JSON key

Rotar cada 30 d vía `gcloud iam service-accounts keys create` automatizado. **Descartada**: no elimina el riesgo, solo lo reduce. SCC seguirá señalando. El audit sigue pidiendo "¿por qué existe una key?".

### Alternativa B: pool por repo

Crear `pool-checkout`, `pool-billing`, etc. **Descartada**: multiplica recursos sin aportar aislamiento adicional (el binding ya aísla por repo). Más pools = más superficie que gobernar.

### Alternativa C: provider sin `attribute_condition`, confiar solo en el binding

**Descartada**: viola defensa en profundidad. Un error en el binding (p. ej. usar `attribute.repository/acme/*` por error) abriría la impersonación a todos los repos de la org. El `attribute_condition` cierra esa puerta primero.

### Alternativa D: usar GitHub-managed OIDC "legacy" sin WIF (Workload Identity sin federation)

**Descartada**: no existe de forma equivalente para repos externos. Workload Identity "sin federation" solo aplica a workloads dentro de GCP (p. ej. Pods en GKE).
