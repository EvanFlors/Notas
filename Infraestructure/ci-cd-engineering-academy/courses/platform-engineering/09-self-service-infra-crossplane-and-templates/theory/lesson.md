# plat-09 — Lección: self-service infra con Crossplane + templates

> 12 secciones. 85 % conceptual, 15 % mecánica. Prerrequisito: `plat-06`, curso **terraform** ≥ Nivel 2, `k8s-14`.

---

## 1. Problema: el ticket queue es la antítesis de la plataforma

El síntoma clásico en organizaciones pre-plataforma es:

> *"Hola plataforma, necesito un bucket S3 para la nueva feature. ¿Pueden crearlo?"*

y una hora, un día o una semana después, un ingeniero de plataforma lo crea manualmente o abre un PR en el repo Terraform central. El developer **no sabe cuándo** llegará, **no puede ver el estado** del recurso, y **no puede iterar** sin volver a abrir ticket.

Este modelo tiene tres daños acumulativos:

1. **Cognitive load intrínseca** del developer sube: el recurso cloud es ahora parte de su mapa mental porque tiene que seguirlo, pedir cambios, chasear.
2. **El platform team se vuelve cuello de botella**. El número de tickets escala con el número de developers; el equipo plataforma no.
3. **La plataforma se percibe como un peaje**, no un acelerador. Los developers aprenden a **evitarla** (ejemplo: alguien se saca sus propias credenciales AWS para evitar pedir el bucket).

El objetivo del self-service es *invertir* los tres: el developer **pide** el recurso declarativamente, el plataforma team no interviene en el camino caliente, y la plataforma gana percepción de **producto**.

> **Idea clave:** self-service no significa "cada developer tiene permisos de AWS/GCP/Azure directos". Significa que el **contrato** para pedir recursos está **versionado, revisable y auditado** por el platform team; el **cómo** materializa el recurso lo esconde la plataforma.

---

## 2. Dos familias de soluciones: K8s-native vs TF-native

Para implementar self-service hay **dos familias** maduras hoy:

### 2.1 K8s-native (Crossplane, ACK, Config Connector)

El developer crea un **Custom Resource** (CR) en Kubernetes. Un operador en el cluster lo observa y materializa el recurso cloud correspondiente llamando a la API del provider (AWS/GCP/Azure/…).

- **Crossplane**: multi-cloud, abstracciones composicionales (XRD + Composition), ecosistema CNCF.
- **AWS Controllers for Kubernetes (ACK)**: oficial AWS, 1:1 con APIs AWS, sin composición.
- **Config Connector**: oficial GCP, 1:1 con APIs GCP, sin composición.

Ventajas: **todo el plano K8s se hereda** (RBAC, GitOps vía Argo CD, políticas vía Kyverno/OPA, auditoría vía K8s audit log, observabilidad vía los mismos exportadores).

### 2.2 TF-native (Terraform via PRs: Atlantis, GHA, Env0, Spacelift, Terraform Cloud)

El developer **abre un PR** a un repo Terraform con un bloque nuevo. Un robot (Atlantis / GHA / Terraform Cloud) ejecuta `terraform plan` como comentario del PR, un reviewer aprueba, el `apply` ocurre al merge.

- **Atlantis**: open source, GitOps puro, auto-hostable, muy maduro.
- **GHA + Terraform**: la aproximación mínima; sirve si el equipo es pequeño.
- **Terraform Cloud / Env0 / Spacelift**: SaaS con workspaces, policies (Sentinel/OPA), workflows avanzados.

Ventajas: **familiaridad universal** de Terraform; el **plan explícito** del PR es un control natural; el **estado** vive en TF state (S3/Postgres), accesible con herramientas conocidas; drift detection está resuelto desde hace años.

### 2.3 Criterio de elección

| Dimensión | Crossplane | TF-via-PR |
|-----------|------------|-----------|
| Stack dominante | K8s-first, muchos equipos ya hablan CRs | TF-first, Terraform ya es el lenguaje común |
| Multi-cloud real | Sí (composición multi-provider) | Sí (módulos TF por provider) |
| Curva de aprendizaje | Alta (XRD, Composition, functions) | Baja (TF estándar) |
| Debugging de "no se creó" | Opaco: hay que leer status de 3 CRs y logs del provider | Transparente: `terraform plan`/`apply` logs |
| GitOps idiomático | Nativo (Argo CD aplica CRs) | Externo (Atlantis/CI aplica) |
| Policy enforcement | Kyverno/OPA sobre claims (K8s-native) | Sentinel / OPA / policy-as-code en TF |
| Overhead operacional | Control plane permanente, upgrade de providers | Runners CI o SaaS |
| Rollback | Delete CR; semántica no siempre limpia | `terraform destroy` o revert PR |

**Regla gruesa:** si tu organización ya corre sobre K8s con GitOps maduro y quiere **muchas plataformas** (DB, bucket, cola, DNS, certificados), **Crossplane** amortiza; si tu organización tiene **Terraform como lingua franca** y las plataformas a exponer son **pocas y estables**, **TF-via-PR** entrega valor más rápido. La actividad 02 te hace defender la decisión para 3 contextos.

---

## 3. Las piezas de Crossplane

```
┌─────────────────────────────────────────────────────────────────┐
│ Developer (namespace: team-foo)                                 │
│   crea un Claim:                                                │
│     apiVersion: platform.io/v1alpha1                            │
│     kind: NamespaceProductClaim                                 │
│     metadata: { name: team-foo-prod }                           │
│     spec: { tier: small, env: prod }                            │
└────────────────────────────┬────────────────────────────────────┘
                             │ (binding)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ Cluster-scoped Composite                                        │
│   apiVersion: platform.io/v1alpha1                              │
│   kind: XNamespaceProduct                                       │
│   spec: { tier, env, claimRef: ... }                            │
└────────────────────────────┬────────────────────────────────────┘
                             │ (reconcile by Composition)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ Managed resources materializados                                │
│   kubernetes.crossplane.io/Object → Namespace                   │
│   kubernetes.crossplane.io/Object → ResourceQuota               │
│   kubernetes.crossplane.io/Object → NetworkPolicy (default deny)│
│   (en un ejemplo con AWS: Object → VPC, SG, RDSInstance, …)     │
└─────────────────────────────────────────────────────────────────┘
```

- **Provider**: binario que sabe hablar con una API externa (AWS, GCP, Azure, Kubernetes, GitHub, Vault…). Instalado como un `Provider` CR; se descarga como OCI image (xpkg).
- **ManagedResource (MR)**: un CR 1:1 con un recurso del provider. Ejemplos: `s3.aws.upbound.io/Bucket`, `rds.aws.upbound.io/Instance`, `kubernetes.crossplane.io/Object`. **El platform team los conoce; el developer no debería crearlos directamente.**
- **CompositeResourceDefinition (XRD)**: el **contrato** que el platform team **ofrece** al developer. Define el nombre del composite (`XNamespaceProduct`), el nombre del claim namespaced (`NamespaceProductClaim`), y el schema de `spec`/`status` (OpenAPI v3).
- **Composition**: la **receta** que materializa un composite. Toma el `spec` del composite y produce una lista de MRs con `patches` que inyectan los valores.
- **Composite Resource (XR)**: la instancia cluster-scoped. Normalmente **no la crea el developer**; la crea el claim.
- **Claim**: la instancia **namespaced** que el developer sí crea. Es un *alias* del XR en su namespace. Cuando se crea el claim, Crossplane crea un XR cluster-scoped y hace el *binding*.

### 3.1 Por qué claim vs composite están separados

- **Composites son cluster-scoped**: muchos recursos cloud lo son (una VPC no pertenece a un namespace K8s).
- **Claims son namespaced**: el RBAC del developer es por namespace. Un developer de `team-foo` puede crear claims en `team-foo`; no en `team-bar`.
- **El platform team controla el schema del XRD** (el "qué puedo pedir"); el **cómo** se materializa vive en la Composition, no visible al developer.

Esta separación es **el truco** que hace sostenible el modelo: el developer no necesita RBAC sobre VPC o RDS; necesita RBAC sobre `NamespaceProductClaim` en su namespace.

---

## 4. El patrón "producto de plataforma"

Un buen XRD cumple **cuatro propiedades**:

1. **Pocos inputs**: 3–5 campos; cualquier cosa más es ya una pista de que el platform team quiere delegar decisiones que debería tomar la plataforma.
2. **Defaults opinados**: si no pasas `region`, se asume la región default del equipo; si no pasas `tier`, se asume `small`.
3. **Guardrails en el schema**: `enum` para `tier`, `pattern` para `name`, `required` sólo lo imprescindible.
4. **Output útil**: el `status` publica lo que el developer necesita (connection string, bucket URL, namespace creado) usando el patrón **Crossplane connection secrets** (si aplica) o `writeConnectionSecretsToRef`.

Ejemplo de contrato bien dimensionado para "una Postgres managed":

```yaml
spec:
  parameters:
    tier: small      # enum: small | medium | large (traduce a instance class)
    env:  prod       # enum: dev | staging | prod   (traduce a backup policy)
    name: billing-db # pattern: ^[a-z][a-z0-9-]{2,30}$
```

Lo que el platform team esconde detrás:

- VPC + SG + subnet group correctos para la región default.
- `AWS::RDS::DBInstance` con `instance_class`, `backup_retention`, `multi_az` según `tier` y `env`.
- Secret K8s con el password generado y la connection string.
- Labels `cost-center`, `team`, `env` para FinOps.

Un XRD **mal dimensionado** (anti-patrón): 20 inputs, incluyendo `backup_retention_days`, `instance_class`, `maintenance_window`. Si el developer tiene que elegir todo eso, no hay producto de plataforma: hay un wrapper fino sobre Terraform.

---

## 5. Composition: dónde esconder la complejidad

La Composition traduce 1 composite → N managed resources. Los patches inyectan valores del composite en los MRs:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xnamespaceproducts.k8s-native
spec:
  compositeTypeRef:
    apiVersion: platform.io/v1alpha1
    kind: XNamespaceProduct
  resources:
    - name: namespace
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: v1
              kind: Namespace
              metadata:
                name: "" # patched
                labels:
                  managed-by: crossplane
      patches:
        - fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.metadata.name
    - name: quota
      base: # ...ResourceQuota manifest...
      patches:
        - fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.metadata.namespace
        - fromFieldPath: spec.parameters.tier
          toFieldPath: spec.forProvider.manifest.spec.hard["requests.cpu"]
          transforms:
            - type: map
              map: { small: "2", medium: "8", large: "32" }
```

Patterns útiles de patches:

- `type: map` para traducir `tier` → valor concreto.
- `type: string` con `fmt` para componer nombres (`"%s-quota"` del name).
- `type: math` para derivar un valor numérico.
- `combine` para componer un string desde varios campos.

**Alternativa moderna**: en lugar de patches YAML, usar **Composition Functions** (Go/Python) para lógica no trivial. Para este módulo nos quedamos con patches, que cubren el 80 % de los casos.

---

## 6. Claims desde Backstage: scaffolder → PR → Argo CD → Crossplane

El flujo end-to-end "developer self-service" cuando se combina con Backstage:

```
developer en Backstage
   │  llena 3 inputs del template (name, tier, env)
   ▼
Backstage Scaffolder
   │  renderiza templates/claim.yaml.njk con los inputs
   │  publish:github → PR al repo gitops/claims/
   ▼
PR revisado (opcional) y merged
   │
   ▼
Argo CD (observa gitops/)
   │  aplica el YAML del claim al cluster
   ▼
Crossplane
   │  observa el claim → crea XR → Composition materializa MRs
   ▼
Recursos físicos listos
   │
   ▼
Backstage muestra el estado:
   - Catalog entry del recurso
   - Plugin Argo CD con sync status
   - Status.conditions del claim visibles vía plugin K8s
```

El template de Backstage mínimo tiene:

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: namespace-product
spec:
  parameters:
    - title: Namespace product
      required: [name, tier, env]
      properties:
        name:  { type: string, pattern: "^[a-z][a-z0-9-]{2,30}$" }
        tier:  { type: string, enum: [small, medium, large] }
        env:   { type: string, enum: [dev, staging, prod] }
  steps:
    - id: fetch
      action: fetch:template
      input:
        url: ./skeleton
        values: { name: ${{ parameters.name }}, tier: ${{ parameters.tier }}, env: ${{ parameters.env }} }
    - id: publish
      action: publish:github:pull-request
      input:
        repoUrl: github.com?owner=org&repo=gitops
        branchName: claim-${{ parameters.name }}
        title: "feat(claim): ${{ parameters.name }}"
        description: "Claim NamespaceProduct for team"
```

El `./skeleton/claim.yaml.njk` es:

```yaml
apiVersion: platform.io/v1alpha1
kind: NamespaceProductClaim
metadata:
  name: ${{ values.name }}
  namespace: ${{ values.name }}-team
spec:
  parameters:
    name: ${{ values.name }}
    tier: ${{ values.tier }}
    env:  ${{ values.env }}
```

Clave: Backstage **no habla con Crossplane directamente**. Habla con **git**. Argo CD habla con el cluster. Crossplane habla con el provider. Cada pieza hace **una cosa**.

---

## 7. Guardrails: políticas sobre claims (Kyverno / OPA Gatekeeper)

Un claim que no respeta las reglas de la plataforma **no debe materializarse**. Dos formas canónicas:

### 7.1 Admission policies (Kyverno / Gatekeeper)

Políticas que ejecutan en el admission webhook del API server, rechazando el claim antes de que llegue a Crossplane. Ejemplos reales:

- `claims.platform.io` sólo pueden crearse en namespaces con label `platform.io/tenant=true`.
- `spec.parameters.region` debe estar en `[eu-west-1, us-east-1]`.
- `metadata.labels.cost-center` es obligatorio.
- Un namespace no puede tener más de 2 claims activos del mismo tipo.

### 7.2 Validation en el schema del XRD

El OpenAPI schema del XRD ya puede imponer gran parte de los guardrails estructurales (`enum`, `pattern`, `required`). Es el **primer filtro**, barato y declarativo. Las reglas que requieren contexto cross-recurso van a admission policies.

**Patrón recomendado:** schema del XRD para la forma del input; Kyverno para las políticas de uso (quién puede, dónde, cuánto, con qué labels).

---

## 8. Observabilidad y debugging del claim

El talón de Aquiles de Crossplane es que **cuando algo no se crea, el debugging es poco obvio**. Cadena de inspección mínima:

```bash
# 1) ¿El claim está Bound?
kubectl get <claim-kind> <name> -n <ns>
# status.conditions debe tener type=Ready, status=True

# 2) ¿Existe el XR?
kubectl get <xr-kind>
# el claim apunta al XR por nombre; si falta, Composition no corrió

# 3) ¿Qué MRs produjo la Composition?
kubectl describe <xr-kind> <xr-name>
# resourceRefs lista los MRs; cada uno tiene su status.conditions

# 4) ¿Qué dicen los MRs?
kubectl get object -o wide
# o el kind concreto si es un provider cloud
# status.conditions.lastTransitionTime y type=Synced / Ready

# 5) ¿Qué dice el provider?
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-kubernetes
```

**Las dos condiciones clave de todo MR son `Synced` y `Ready`.** `Synced=True` significa "Crossplane logró llamar al provider"; `Ready=True` significa "el recurso físico está listo". `Synced=False` es casi siempre un problema de credenciales, políticas, o ProviderConfig; `Synced=True, Ready=False` es casi siempre tiempo (recurso aún provisionando) o problema del cloud.

---

## 9. FinOps mínimo: labels obligatorios

Un self-service sin disciplina de labels es un **generador de facturas sin dueño**. El patrón mínimo:

```yaml
metadata:
  labels:
    cost-center: "platform-120"
    team:        "billing"
    env:         "prod"
    product:     "namespace-product"
```

Enforce vía:

- El schema del XRD *requiere* los labels como parte del claim.
- La Composition los propaga a **todos** los MRs (patches).
- Una policy Kyverno rechaza claims sin estos labels.
- El provider cloud (si es AWS) propaga labels → tags del recurso real.
- El billing/showback agrupa por tag.

Sin este bucle completo, el self-service se vuelve un acelerador de deuda financiera. Es **tan importante como el guardrail de región**.

---

## 10. Catálogo de productos de plataforma: por dónde empezar

El error común es intentar publicar 15 productos el día uno. La vía sostenible:

1. **Elige UN producto de alta demanda, baja variabilidad, dolor compartido.** Candidatos típicos: *namespace* en el cluster compartido, *bucket* de staging, *base de datos Postgres pequeña*.
2. **Publícalo con 3 inputs.** Si necesitas 10, no es un producto, es un wrapper.
3. **Mide adopción**: cuántos claims a la semana, cuántos equipos distintos, cuántos tickets evitó.
4. **Itera**: siguiente producto una vez que el primero esté en producción con 5+ equipos usándolo.
5. **Deprecar es diseño**: desde el día 1, versiona el XRD (`v1alpha1 → v1beta1 → v1`) y publica cómo serán los upgrades.

El catálogo típico de una plataforma madura (de más usado a menos):

- Namespace + quotas + network policy.
- Bucket (S3/GCS) para staging / backups.
- Base de datos Postgres pequeña o mediana.
- Cola / topic (SQS, SNS, Pub/Sub).
- DNS record + certificado (ACM/Let's Encrypt via cert-manager).
- Repo nuevo + CI base (que suele venir de un template Backstage, no de Crossplane).

Notar que **repo + CI** sigue siendo Backstage puro (scaffolder); **recursos cloud** son Crossplane. Son complementarios, no competidores.

---

## 11. Ventajas y limitaciones honestas de Crossplane

**Ventajas:**

- Mismo plano de control que el resto del cluster: RBAC, GitOps, políticas, auditoría, métricas, logs.
- Composition reutilizable: un XRD cambia; todos los claims heredan el cambio en el siguiente reconcile.
- Multi-cloud real sin cambiar la UX del developer.
- Ecosistema CNCF con tracción creciente (Upbound, Crossplane v2 incluye claims mejorados, functions, etc.).

**Limitaciones y riesgos a asumir:**

- **Curva de aprendizaje real**. XRDs + Compositions + patches + functions es *otro* paradigma; subirse cuesta semanas.
- **Debugging opaco** cuando algo no reconcilia (ver §8).
- **Estado opaco** comparado con Terraform state: no hay `crossplane plan`; cada aplicación es por reconcile, y el drift se corrige silenciosamente (lo cual es a veces lo que quieres, a veces no).
- **Upgrades de providers** son operaciones de riesgo: breaking changes en MRs pueden requerir migraciones.
- **Compatibilidad con APIs cloud** nuevas no siempre es inmediata; a veces hay que esperar al provider.
- **Ownership de los MRs**: si borras el XR, por defecto se borran los MRs. **Esto puede destruir infra en producción si no está documentado**. `deletionPolicy: Orphan` + convenciones son obligatorias.

**Cuándo *no* adoptar Crossplane:**

- Equipo de plataforma de 1–2 personas sin experiencia K8s profunda.
- Stack ya productivo con Terraform + Atlantis estable y pocos productos de plataforma por exponer.
- Lenguaje franco de la organización es TF; introducir CRs es carga cognitiva pura.
- Entornos sin Kubernetes de control plane dedicado.

---

## 12. Qué sigue (y qué llevarse)

Al terminar este módulo deberías poder:

- Diseñar un XRD con 3–5 inputs y una Composition que materialice 3–5 MRs.
- Instalar Crossplane en un cluster kind y aplicar el XRD + Composition + Claim.
- Explicar por qué el claim vive en un namespace del developer y el composite no.
- Decidir, dado un contexto, entre Crossplane y Terraform-via-PR, defendiendo la elección con criterios técnicos (no slogans).
- Diseñar el catálogo mínimo de productos de plataforma self-service.

Lo que **sigue**:

- `plat-10` — scorecards: cómo medir "este servicio tiene owner, tiene SLO, tiene runbook".
- `plat-11` — métricas DORA + SPACE + platform-as-product.
- `plat-12` — gobernanza a escala: multi-tenancy, deprecations, SLOs de la propia plataforma.

Una síntesis final:

> **Crossplane convierte "provisionar un recurso cloud" en "crear un Custom Resource". Esto hereda al control plane de Kubernetes el RBAC, el GitOps, las políticas, la observabilidad y la auditoría. El precio es una curva de aprendizaje real y un debugging menos obvio. Para una organización K8s-first con varios productos de plataforma por exponer, amortiza; para una organización TF-first con pocos productos y un platform team pequeño, Terraform-via-PR entrega más valor por hora.**
