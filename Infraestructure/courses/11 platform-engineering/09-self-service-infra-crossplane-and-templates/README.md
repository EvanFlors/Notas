# plat-09 — Self-service infra: Crossplane + templates

## Identificación

- **ID:** `plat-09-self-service-infra-crossplane-and-templates`
- **Curso:** `platform-engineering`
- **Nivel:** avanzado
- **Duración estimada:** 6 h
- **Prerrequisitos:** `plat-06-templates-and-scaffolder`, curso **terraform** ≥ Nivel 2, curso **kubernetes** ≥ `k8s-14`.

## Objetivo

Habilitar que un developer provisione infraestructura (bases de datos, buckets, namespaces, colas) **sin abrir tickets**, mediante *claims* declarativos, con guardrails fuertes del platform team. Al terminar deberías poder diseñar un **CompositeResourceDefinition (XRD)** + **Composition** de Crossplane, exponerlo vía template de Backstage y decidir con criterio entre **Crossplane** y **Terraform-via-PR** para una organización dada.

## Alcance

Este módulo cubre:

- **Crossplane** como *control plane* multiplataforma: providers, managed resources, composite resources, XRDs, compositions, claims.
- Por qué "crear un CR" y "provisionar un recurso cloud" se vuelven **la misma operación** (RBAC, GitOps, observabilidad, políticas, todo heredado del plano Kubernetes).
- Diferencia entre **composite resource (cluster-scoped)** y **claim (namespaced)**: quién lo pide (developer) vs quién lo materializa (plataforma).
- El patrón **"producto de plataforma"**: un XRD expone un contrato pequeño (3–5 inputs); la Composition esconde la complejidad detrás.
- **Templates de Backstage que generan claims**: el scaffolder abre un PR al repo GitOps con el `XNamespaceClaim.yaml`; Argo CD lo sincroniza; Crossplane lo materializa.
- **Alternativa Terraform-via-PR** (Atlantis / GHA): mismo objetivo, infra tooling distinto, trade-offs claros.
- **Políticas** sobre los claims (Kyverno / OPA Gatekeeper) para enforce de región, tier, labels obligatorios, cuotas.
- **FinOps mínimo**: labels obligatorios para que showback funcione.

Lo que **no** cubre:

- Instalación productiva de Argo CD, Kyverno end-to-end (se cubre en los cursos `gitops` y `devsecops`).
- Diseño de providers propios de Crossplane (`xpkg`, `crossplane-runtime`); se nombra, no se construye.
- Multi-tenancy avanzado y deprecations de contratos XRD → `plat-12`.

## Decisión arquitectónica del módulo

Para que las actividades **corran sin costo y sin credenciales**, usamos el **provider `kubernetes`** de Crossplane (`crossplane-contrib/provider-kubernetes`). Este provider convierte "cualquier recurso Kubernetes nativo" en un `Object` managed resource. Es la elección canónica para enseñar XRD + Composition sin tocar AWS/GCP/Azure.

El patrón se traslada 1:1 a providers cloud: cambias el `provider-kubernetes` por `provider-aws`, los `Object{kind: Namespace}` por `Object{kind: RDSInstance}` dentro de la Composition, y el claim del developer **no cambia**.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-crossplane-install-in-kind/` — instala Crossplane + provider-kubernetes en un cluster kind efímero (reproducible, con cleanup).
  - `02-xrd-namespace-product/` — XRD `XNamespaceProduct` + Composition que materializa `Namespace` + `ResourceQuota` + `NetworkPolicy` default-deny.
  - `03-backstage-template-skeleton/` — esqueleto `template.yaml` + skeleton nunjucks que genera el claim para el repo GitOps (lectura; no se ejecuta Backstage).
- **`activities/`**:
  - `01-self-service-namespace-claim/` — guided-lab: desplegar Crossplane en kind, aplicar un XRD + Composition, crear un Claim, validar que todo materializa.
  - `02-adr-crossplane-vs-tf-pr/` — independiente: ADR razonado comparando Crossplane vs Terraform-via-PR para 3 contextos distintos.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar en 90 s qué es un XRD, una Composition y un Claim, y por qué el claim es *namespaced* y el composite *cluster-scoped*. |
| Operativa | Instalar Crossplane en kind, aplicar un XRD + Composition propios, pedir un claim desde un namespace de developer, inspeccionar el composite + los managed resources materializados. |
| Arquitectónica | Decidir, dado un contexto (tamaño del platform team, stack dominante, deuda TF existente, presupuesto, aversion al K8s-native), si la organización gana más con Crossplane o con Terraform-via-PR. Diseñar el **catálogo mínimo** de productos de plataforma self-service. |

## Criterios de evaluación

- Explica con palabras propias por qué un claim de developer **no** otorga permisos sobre el recurso cloud subyacente (sólo lo pide).
- Dado un XRD + Composition, puede trazar el ciclo claim → composite → managed resources → recursos físicos.
- Nombra 3 guardrails típicos (política de región, política de tier/tamaño, política de labels obligatorios).
- Articula los trade-offs honestos de Crossplane (curva de aprendizaje, debugging via statuses de CRs, estado opaco) vs TF-via-PR (familiaridad, plan explícito, drift conocido pero manual).
- Entrega las dos actividades con sus validadores en verde.

## Entregables

- Un cluster kind con Crossplane y un claim `XNamespaceProductClaim` materializado (sale de la actividad 01).
- Un **ADR** eligiendo Crossplane vs Terraform-via-PR para el capstone, defendible (sale de la actividad 02).

## Siguiente módulo

→ `plat-10-scorecards-and-service-maturity` — medir y evolucionar la madurez de servicios.
