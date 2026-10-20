# Actividad 02 — Migrar un workload de AAD Pod Identity v1 a Workload Identity

## 1. Identificación

- **ID:** `az-07-02-wi-vs-pod-identity-v1`
- **Tecnología:** `azure`
- **Módulo:** `az-07-aks-and-workload-identity`
- **Dificultad:** advanced
- **Duración estimada:** 75–100 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Tu organización lleva 2 años usando **AAD Pod Identity v1** en producción (NMI DaemonSet + MIC + CRDs `AzureIdentity[Binding]`). Funciona, pero:

- Microsoft **anunció deprecación** del proyecto y empuja a Workload Identity.
- Habéis sufrido race conditions ocasionales: pods de arranque rápido veces no veían la MI asignada por MIC a tiempo.
- Debuggearlo requiere entender la intercepción de IMDS que hace NMI (iptables en el host).
- Un equipo quiere **reusar la misma MI en 2 clusters** para una app común y Pod Identity v1 no lo hace trivial.

Tu trabajo: diseñar la migración, escribir los manifiestos antes/después y argumentar la decisión.

### Nota de coste

**0 USD.** Esta actividad es puramente de diseño y escritura. No se levanta ningún cluster. Si tienes Pod Identity v1 en un cluster real y quieres practicar la migración allí, el coste del cluster corre por tu cuenta.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Nombrar al menos **4 diferencias técnicas** entre Pod Identity v1 y Workload Identity (setup, trust, token, reuso, SDK).
- Escribir el **ServiceAccount + CRDs `AzureIdentity[Binding]` + política mínima** para Pod Identity v1 **y** el **ServiceAccount anotado + federated identity credential + política mínima** para Workload Identity, para el mismo workload (p. ej. lee blobs de un Storage account).
- Diseñar un **plan de migración por fases**: dual-run, cutover por workload, rollback.
- Decidir Workload Identity vs Pod Identity v1 para 3 escenarios distintos.
- Explicar por qué Workload Identity **no** reemplaza patrones externos a AKS (Container Apps managed identity, VM system-assigned MI).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §6, §7, §8).
- Haber recorrido `../../examples/02-workload-identity-to-storage/`.
- Herramientas: `bash` y un editor Markdown/YAML. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/az-07-02/{manifests,docs}
cd /tmp/az-07-02
```

### 5.2 Workload base

El workload es trivial: un `Deployment` que necesita leer y escribir blobs en el container `data` de un storage account. **Siempre** usa estos placeholders ficticios:

- Subscription ID: `00000000-0000-0000-0000-000000000000`.
- Tenant ID: `11111111-1111-1111-1111-111111111111`.
- Client ID de la MI `mi-az07-app`: `33333333-3333-3333-3333-333333333333`.
- OIDC issuer URL del cluster: `https://westeurope.oic.prod-aks.azure.com/11111111-1111-1111-1111-111111111111/aaaabbbb-cccc-dddd-eeee-ffff00001111/`.
- Resource group: `rg-az07-demo`. Storage account: `staz07demodata`. Container: `data`.
- Namespace K8s: `apps`. ServiceAccount K8s: `app`.

**No** uses IDs reales de tu tenant o subscription en los manifiestos.

### 5.3 Escribir `manifests/sa-pod-identity-v1.yaml` (ANTES)

Debe incluir:

1. Un bloque de comentario con la **política Azure mínima** del rol: `Storage Blob Data Reader` (y `Storage Blob Data Contributor` para escritura si aplica) sobre el storage account.
2. Un bloque YAML con los CRDs **`AzureIdentity`** y **`AzureIdentityBinding`** (grupo `aadpodidentity.k8s.io/v1`). `AzureIdentity` apunta por `clientId` y `resourceID` a la MI `mi-az07-app`. `AzureIdentityBinding` une el label `aadpodidbinding: app-pi` a la `AzureIdentity`.
3. Un `ServiceAccount` (nombre `app`, namespace `apps`), **sin anotación** Workload Identity (porque todavía no se usa).
4. Un `Deployment` cuyo pod template tiene el label `aadpodidbinding: app-pi`, el `serviceAccountName: app` y un contenedor que haga `az storage blob list ...`.

Añade un comentario explicando que los pods `nmi` (NMI DaemonSet) y `mic` (Managed Identity Controller) deben existir en el cluster.

### 5.4 Escribir `manifests/sa-wi.yaml` (DESPUÉS)

Debe incluir:

1. Un bloque de comentario con la **misma política Azure mínima** (no cambia: la MI es la misma).
2. Un bloque de comentario con la **Federated Identity Credential** (`issuer`, `subject`, `audience`) sobre la misma MI `mi-az07-app`. El `subject` **debe** ser `system:serviceaccount:apps:app`. El `audience` **debe** ser `api://AzureADTokenExchange`.
3. Un bloque de comentario con el **snippet Terraform** equivalente (`azurerm_federated_identity_credential`).
4. Un `ServiceAccount` con la **anotación** `azure.workload.identity/client-id: "33333333-3333-3333-3333-333333333333"`.
5. Un `Deployment` cuyo pod template tiene el label `azure.workload.identity/use: "true"` y `serviceAccountName: app`. **Sin** label `aadpodidbinding`.
6. Añade un comentario explicando que el webhook `azure-workload-identity` debe estar instalado (lo instala el flag `workload_identity_enabled = true` del cluster).

### 5.5 Escribir `docs/MIGRATION.md`

Secciones obligatorias:

```
## Comparación Pod Identity v1 vs Workload Identity

| Dimensión | Pod Identity v1 | Workload Identity |
|-----------|-----------------|-------------------|
| Mecanismo de token | ... | ... |
| Setup por cluster | ... | ... |
| Trust configuration | ... | ... |
| Reuso de MI cross-cluster | ... | ... |
| Compatibilidad fuera de AKS | ... | ... |
| SDK Azure mínimo | ... | ... |
| Deprecación | ... | ... |
| (al menos 3 filas más que estas) |

## Plan de migración por fases

### Fase 1 — Dual-run (preparación)
- ...

### Fase 2 — Cutover (por workload)
- ...

### Fase 3 — Rollback (si algo sale mal)
- ...

### Fase 4 — Cleanup (NMI/MIC + CRDs)
- ...

## Matriz de decisión por escenario

### Escenario A — Greenfield, cluster AKS nuevo
Decisión: ...
Justificación: ...

### Escenario B — Legacy, 20 workloads con Pod Identity v1
Decisión: ...
Justificación: ...

### Escenario C — Workload cross-platform (corre también en Container Apps)
Decisión: ...
Justificación: ...

## Límite claro: lo que Workload Identity NO resuelve
- ...
```

### 5.6 Checklist conceptual (dentro de `MIGRATION.md` o aparte)

Añade al final una lista numerada con **7 preguntas** que harías a un equipo antes de autorizarles la migración (p. ej. *"¿tu SDK soporta Workload Identity? ¿Qué versión?"*, *"¿esta la federated identity credential con el `subject` exacto `system:serviceaccount:<ns>:<sa>`?"*).

### 5.7 Entregables

En `/tmp/az-07-02`:

```
manifests/sa-pod-identity-v1.yaml
manifests/sa-wi.yaml
docs/MIGRATION.md
```

## 6. Resultado esperado

- Los 3 archivos existen.
- `MIGRATION.md` tiene las 4 secciones (comparación, plan, matriz, límite) + 7 preguntas numeradas.
- Los manifiestos tienen `ServiceAccount` + `Deployment` cada uno.
- `sa-pod-identity-v1.yaml` menciona `AzureIdentity`, `AzureIdentityBinding`, `aadpodidbinding`.
- `sa-wi.yaml` menciona `azure.workload.identity/client-id`, `azure.workload.identity/use`, el `subject` federado `system:serviceaccount:apps:app`, el `audience` `api://AzureADTokenExchange` y **no** tiene `aadpodidbinding` activo.
- `bash tests/validate.sh /tmp/az-07-02` pasa.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: la comparación tiene al menos **7 filas** reales (no "N/A").
- **Reproducibilidad**: un peer puede ejecutar el plan de migración leyéndolo.
- **Mantenibilidad**: YAML válido, Markdown bien formado, cero IDs reales (usa los placeholders).

## 8. Validación

```bash
bash tests/validate.sh /tmp/az-07-02
```

El validador comprueba estructura y presencia de los markers clave. Compara `MIGRATION.md` con `solution/REFERENCE.md` para autoevaluarte semánticamente.

## 9. Preguntas de reflexión

1. ¿Por qué Workload Identity simplifica el *trust* pero no la *política Azure* del rol/MI?
2. ¿Qué pasa durante Fase 1 (dual-run) si un pod reinicia y el SDK elige la cadena de credenciales equivocada?
3. En el Escenario C, ¿qué patrón alternativo (sin Pod Identity v1, sin Workload Identity) usarías para un workload que corre también en **Container Apps**?
4. Si tu SDK Azure es muy viejo y **no** soporta `WorkloadIdentityCredential`, ¿cuál es tu única salida sin re-instrumentar la app?
5. ¿Por qué el `audience` de la federated identity credential es `api://AzureADTokenExchange` y no una URL arbitraria?

## 10. Extensiones

- Añade una **sección de observabilidad**: qué eventos de Entra ID (`SignInLogs` + `AADServicePrincipalSignInLogs`) verás con Pod Identity v1 vs Workload Identity y cómo detectar una llamada fallida.
- Añade un **Terraform snippet** que cree la UA-MI, la federated identity credential y el role assignment en un solo módulo reusable.
- Añade un **4.º escenario** propio (p. ej. workload que corre en AKS *y* en una VM fuera del cluster).

## 11. Limpieza

```bash
rm -rf /tmp/az-07-02
```

No hay recursos Azure que limpiar porque **no se creó nada en Azure**.
