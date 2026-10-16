# argo-09 — Secretos con GitOps

## Identificación

- **ID:** `argo-09-secrets-with-gitops`
- **Curso:** `argocd-gitops`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:**
  - `argo-03-application-anatomy-sources-destinations-sync`
  - `k8s-05-config-secrets-env-volumes-basics`
  - Deseable: nociones de un *secret manager* en la nube (AWS Secrets Manager, GCP Secret Manager, HashiCorp Vault).

## Objetivo

Gestionar secretos en un flujo GitOps **sin violar sus principios** (nada en claro en Git) y con criterio para **elegir** entre las cinco estrategias vigentes: SOPS+KSOPS, Sealed Secrets, External Secrets Operator (ESO), Secrets Store CSI Driver y Vault Agent Injector. Al terminar deberías poder justificar la elección para tres organizaciones distintas, implementar el patrón recomendado (ESO) de punta a punta, y diseñar la **rotación** y la **auditoría** correspondientes.

## Alcance

Este módulo cubre:

- Por qué los secretos **en claro en Git nunca** son aceptables, incluso en repos privados.
- Las cinco estrategias canónicas, sus modelos de confianza y sus *blast radius* respectivos.
- **SOPS + KSOPS**: cifrado con `age` localmente (sin nube) e integración con Argo CD vía plugin.
- **Sealed Secrets**: controller con par de claves asimétrico y por qué la rotación es cara.
- **External Secrets Operator (ESO)**: `ExternalSecret`, `SecretStore`, `ClusterSecretStore`; patrón recomendado. Se corre contra un *fake provider* local (sin cuenta cloud).
- **Secrets Store CSI Driver**: montaje directo desde el secret manager sin intermediar un `Secret` de K8s.
- **Vault Agent Injector**: patrón sidecar/init.
- **Rotación**: pull periódico (ESO), push manual (Sealed Secrets), reemplazo de clave maestra (SOPS).
- **Auditoría**: qué queda en Git, qué queda en el secret manager, qué queda en etcd.
- **Migración** entre estrategias.

Lo que **no** cubre:

- Admission policies que *obliguen* a `secretKeyRef` o prohíban `env` para secretos → `k8s-12`.
- Encryption-at-rest de etcd (`EncryptionConfiguration`) → `k8s-05`.
- Firma de imágenes / cadena DevSecOps → `k8s-16`.

## Materiales

- **`theory/lesson.md`** — 12 secciones.
- **`examples/`**:
  - `01-eso-aws-secrets-manager/` — ESO contra un *fake provider* local (equivalente a AWS Secrets Manager en lo conceptual, sin credenciales reales).
  - `02-sealed-secrets-walkthrough/` — instalación del controller en kind y ciclo seal → commit → sync.
  - `03-sops-ksops-argocd-plugin/` — SOPS con `age` y plugin KSOPS para Argo CD.
- **`activities/`**:
  - `01-capstone-secrets-via-eso/` (guided-lab) — poner los secretos del capstone bajo ESO y validar que el `Secret` nativo se crea y rota.
  - `02-tradeoffs-adr/` (independent) — ADR eligiendo la estrategia para tres organizaciones distintas.
- **`resources/links.md`** — documentación oficial y lecturas.

## Temas y subtemas

1. **El problema**: por qué un secreto en claro en Git nunca es aceptable.
2. **Modelos de confianza** y *blast radius* comparados.
3. **SOPS + KSOPS** (encriptación con KMS, `age` o PGP).
4. **Sealed Secrets** (controller con clave pública).
5. **External Secrets Operator (ESO)** — patrón recomendado.
6. **Secrets Store CSI Driver**.
7. **Vault Agent Injector**.
8. **Rotación** por estrategia.
9. **Auditoría** y qué queda dónde.
10. **Migración** entre estrategias.
11. **Anti-patrones** frecuentes.
12. **Decisión**: árbol para elegir.

## Conceptos internos (fundamentos)

- **ESO desacopla** "qué secreto necesita la app" (manifiesto en Git) de "dónde vive el valor" (secret manager). El `Secret` nativo se materializa en runtime; en Git no hay valores.
- **Sealed Secrets** acopla el ciclo de vida de los secretos al **par de claves del controller**: perder la clave privada o quererla rotar implica re-sellar *todo*.
- **SOPS** mueve el problema de blast radius: ahora *Argo CD* (o el plugin) necesita permisos al KMS/age key; si Argo CD se compromete, los secretos también.
- **CSI Driver** evita que el valor pase por un `Secret` nativo (etcd no lo ve), a cambio de acoplar el pod al driver y a la API del secret manager.
- **Vault Agent Injector** usa un sidecar/init container y plantillas; muy potente pero introduce un componente adicional y runtime cost.

## Competencias

- **Conceptual**: enunciar por qué cada estrategia *mantiene* el principio GitOps y dónde está exactamente el valor secreto en cada caso.
- **Operativa**: instalar y usar ESO (fake provider), Sealed Secrets y SOPS+KSOPS en un kind local; rotar un valor y observar el efecto en el `Secret` resultante.
- **Arquitectónica**: redactar un ADR que elija y defienda la estrategia para una organización dada; identificar criterios decisivos (cloud nativa, air-gapped, multi-cluster, compliance).

## Ejemplos

Enlaces a `examples/`.

- [`examples/01-eso-aws-secrets-manager/`](examples/01-eso-aws-secrets-manager/README.md)
- [`examples/02-sealed-secrets-walkthrough/`](examples/02-sealed-secrets-walkthrough/README.md)
- [`examples/03-sops-ksops-argocd-plugin/`](examples/03-sops-ksops-argocd-plugin/README.md)

## Actividades

- [`activities/01-capstone-secrets-via-eso/`](activities/01-capstone-secrets-via-eso/README.md) — guided-lab.
- [`activities/02-tradeoffs-adr/`](activities/02-tradeoffs-adr/README.md) — independent (ADR).

## Entregables

- Capstone con secretos vía ESO (patrón recomendado) funcionando en kind.
- ADR comparando las cinco opciones y eligiendo para tres organizaciones.
- Walkthrough reproducible de Sealed Secrets y SOPS+KSOPS como alternativas.

## Criterios de evaluación

- **Conceptual**: explicar dónde queda el valor del secreto en cada estrategia y qué entidad debe estar comprometida para fugarlo.
- **Operativa**: demostrar `ExternalSecret` → `Secret` nativo creado por el operator; demostrar un ciclo `kubeseal` → commit → sync; descifrar un secret SOPS localmente con `age`.
- **Arquitectónica**: ADR con criterios ponderados, no sólo "la recomendada".

## Recursos

Ver [`resources/links.md`](resources/links.md).
