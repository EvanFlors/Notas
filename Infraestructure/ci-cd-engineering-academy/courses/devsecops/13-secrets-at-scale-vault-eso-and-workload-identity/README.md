# sec-13 — Secretos a escala: Vault, ESO y Workload Identity

## Identificación

- **ID:** `sec-13-secrets-at-scale-vault-eso-and-workload-identity`
- **Curso:** `devsecops`
- **Nivel:** producción
- **Duración estimada:** 6 h
- **Prerrequisitos:** `sec-02` (overview de secretos), curso **argocd-gitops** ≥ `argo-09`, curso **aws** o **gcp** (secret managers y Workload Identity). Haber usado `kubectl`, `helm` y `docker` con fluidez. Conocer la diferencia entre un `Secret` y un `ConfigMap` de K8s.

## Objetivo

Operar **secretos a escala** con **rotación**, **auditoría** y **mínimo privilegio**. Al terminar deberías poder diseñar la arquitectura de secretos de una organización mediana (10–50 servicios, 2–3 clouds) y defender, pieza por pieza, por qué cada secreto es **efímero**, **auditado** y **nunca estático** dentro de un repositorio Git.

## Alcance

Este módulo cubre:

- **HashiCorp Vault** en modo *dev* local: `kv` v2, `database` (dynamic creds), `transit` (encryption-as-a-service), `pki` (visión), auth methods (K8s, approle, OIDC, cloud IAM) y por qué el **token root** solo existe en dev.
- **External Secrets Operator (ESO)** como *puente* K8s ↔ Vault / AWS Secrets Manager / GCP Secret Manager / Azure Key Vault: `ClusterSecretStore`, `SecretStore`, `ExternalSecret`, `refreshInterval`, `creationPolicy`.
- **Secrets Store CSI Driver** como alternativa (mount directo), con ventajas y limitaciones frente a ESO.
- **Dynamic secrets** de Vault: credenciales de DB generadas *on-demand* con TTL cortos. Rotación = TTL vencido.
- **Workload Identity** (IRSA en EKS, Pod Identity en EKS, Workload Identity en GKE, Azure Workload Identity en AKS) para que el Pod *sea* un principal cloud sin credenciales estáticas. **Walkthrough-only** en este módulo (requiere cuenta cloud).
- **Rotation policy** y **break-glass procedures**: cómo rotar sin downtime, cómo abrir un secreto en una emergencia dejando rastro auditado.
- Auditoría: quién accedió a qué secreto, cuándo. Logs de Vault, políticas Sentinel (visión), compliance mínima.
- **Migración** desde el antipatrón "secrets como ConfigMaps base64" o "`.env` en el repo".

Lo que **no** cubre (fuera de alcance):

- SSO corporativo contra Vault con OIDC real → requiere IdP. Se menciona a nivel de arquitectura.
- Vault en modo HA con Raft/Consul y auto-unseal cloud → fuera del horizonte de 6 h.
- SOPS / sealed-secrets / age — se mencionan en `sec-02`; aquí se tratan como alternativas inferiores a Vault+ESO para la escala objetivo.
- Secret scanning (encontrar fugas) — es `sec-04`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`resources/links.md`** — referencias oficiales (Vault, ESO, cloud WI).
- **`examples/`** — 3 ejemplos ejecutables (lectura + comandos a correr; sin tests automáticos):
  - `01-vault-dev-mode-and-k8s-auth/` — levantar Vault dev en Docker, enlazar un `kind` con el método `kubernetes` de auth.
  - `02-eso-pulling-from-vault/` — ESO instalado por Helm, `ClusterSecretStore` apuntando al Vault dev, `ExternalSecret` que materializa un `Secret` K8s.
  - `03-dynamic-db-creds-with-vault/` — PostgreSQL en Docker, Vault emite credenciales efímeras con TTL de 2 min y las rota al expirar.
- **`activities/`** — 2 actividades (`01` depende del ejemplo 2; `02` es **independiente**):
  - `01-capstone-secrets-end-to-end/` — montar Vault + ESO en `kind` y hacer que un Pod obtenga un secreto *dinámico* sin ningún valor estático en Git. Validador real (requiere `vault`/`kind`/`kubectl`/`helm`).
  - `02-rotation-and-break-glass-adr/` — ADR escrito: modelo de rotación para 5 tipos de secretos distintos y procedimiento de break-glass. Independiente, sin infra.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Definir "dynamic secret" sin confundirlo con "secret rotado". Enumerar los 4 auth methods principales de Vault y cuándo usar cada uno. Explicar por qué el `token root` de dev **no existe** en producción. |
| Operativa | Levantar Vault dev + kind + ESO y materializar un `Secret` K8s desde Vault en < 15 min. Reproducir dynamic creds de PostgreSQL. |
| Arquitectónica | Diseñar el modelo de rotación de 5 tipos distintos de secretos (DB password, API key externa, cert TLS, OAuth client secret, SSH host key) con TTLs, trigger, blast radius y break-glass. |
| Seguridad | Argumentar por qué un *secret* en un `ConfigMap` base64 **no es un secret**. Explicar qué información mínima debe aparecer en un log de auditoría de accesos a Vault. |

## Criterios de evaluación

- Explica, con palabras propias, por qué "dynamic secret + TTL corto" **sustituye** la operación de rotación clásica.
- Distingue **ESO** de **Secrets Store CSI Driver** y nombra un escenario donde cada uno gana.
- Diseña un ADR de rotación + break-glass defendible frente a un auditor.
- Monta el capstone (Vault → ESO → Pod) sin ningún secreto estático comprometido en Git.
- Pasa los dos validadores estructurales en verde.

## Entregables

- Capstone con **secretos dinámicos** vía Vault + ESO + (walkthrough) workload identity, sin ningún secret estático en Git (actividad `01`).
- ADR razonado de **rotation + break-glass** para 5 tipos de secretos (actividad `02`).

## Advertencia de seguridad

Todos los `token`s, `password`s y `key`s de este módulo son **dev-only**. Vault corre con `-dev -dev-root-token-id=root`; ese `root` **no es un secreto**, se publica a propósito en los `README.md` para que el estudiante entienda el flujo. **Nunca** uses esta configuración fuera de tu laptop. Un Vault en modo dev conserva los datos **en memoria**: al apagar el contenedor se pierden. Esa es exactamente la propiedad que queremos para un laboratorio.

## Siguiente módulo

→ `sec-14-platform-patterns-gates-dx-inventory-and-vuln-mgmt-lifecycle` — operar DevSecOps como plataforma; secretos entran como una de las piezas del contrato.
