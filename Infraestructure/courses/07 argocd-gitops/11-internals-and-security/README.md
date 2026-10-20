# argo-11 — Internals y seguridad de Argo CD

## Identificación

- **ID:** `argo-11-internals-and-security`
- **Curso:** `argocd-gitops`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `argo-02-install-and-first-application`, `argo-06-projects-rbac-and-boundaries`, `k8s-16-security-hardening-and-supply-chain`.

## Objetivo

Entender la anatomía interna de Argo CD (componentes, caché, autenticación, RBAC propio, sharding) y **endurecer** una instalación default hasta un estado apto para producción: SSO obligatorio, admin local deshabilitado, HTTPS, Pod Security `restricted` en el namespace `argocd`, y **backup verificado** del estado (CRs) con Velero.

## Alcance

Este módulo cubre:

- **Componentes y comunicación interna**: `argocd-server` (gRPC + REST + Web), `application-controller` (sharded reconciler), `repo-server` (rendering de manifests), `applicationset-controller`, `notifications-controller`, `dex-server` (opcional, OIDC federator), `redis` (caché volátil de manifests renderizados y estado).
- **Modelo de autenticación**: admin local (bootstrapeado via `argocd-initial-admin-secret`), **OIDC/SSO** directo o vía Dex, **SAML** vía Dex, **JWT tokens** por project role para automatización (CI).
- **Argo CD RBAC** (distinto del RBAC de Kubernetes): el ConfigMap `argocd-rbac-cm` define policies en **sintaxis CSV estilo Casbin** (`p, role:<name>, <resource>, <action>, <object>, <effect>`), roles por project, bindings a grupos OIDC vía `g, <group>, role:<name>`.
- **Sharding del `application-controller`**: cómo se distribuyen clusters entre réplicas para escalar; `--replicas` en el StatefulSet; `shard` asignado por hash estable.
- **Fuentes de verdad de la configuración**: `argocd-cm` (global settings: URL, OIDC config, resource customizations), `argocd-rbac-cm` (policy CSV), `argocd-cmd-params-cm` (flags de los componentes, p. ej. `server.insecure`), `argocd-secret` (claves de firma JWT, admin password hash, OIDC client secret), `repo-creds`/`repo` Secrets.
- **Hardening**: SSO obligatorio en prod (desactiva login local), `admin.enabled: "false"` en `argocd-cm`, HTTPS obligatorio (quitar `--insecure`, poner TLS por Ingress), Pod Security Admission `restricted` en el namespace `argocd`, NetworkPolicies, rotación de la clave `server.secretkey`, revocación de JWTs.
- **Backup y restore**: Argo CD es casi *stateless* a nivel de disco — todo su estado es CRs (`Application`, `AppProject`, `ApplicationSet`) + ConfigMaps + Secrets. Un backup del namespace `argocd` con **Velero** (o con `argocd admin export`) basta para reconstruirlo.

Lo que **no** cubre (está en otros módulos):

- Multi-cluster y bootstrap (`argo-08`).
- Secretos de las apps gestionadas (ESO/SOPS/Sealed Secrets — `argo-09`).
- Observabilidad de Argo CD (métricas, dashboards) — `argo-12`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-oidc-with-github/` — `argocd-cm` + `argocd-secret` para OIDC directo contra GitHub (Dex).
  - `02-rbac-csv-walkthrough/` — recorrido anotado del CSV: deny-by-default, roles por project, binding a grupos.
  - `03-velero-backup-argocd-ns/` — instalar Velero (MinIO), `Backup` del ns `argocd`, borrar y `Restore`.
- **`activities/`**:
  - `01-harden-argocd-install/` — guided-lab: tomar una instalación default y aplicar 7 controles de hardening verificados.
  - `02-recover-argocd-from-backup/` — independent: diseñar y ejecutar un *disaster recovery* del Argo CD completo.
- **`resources/links.md`** — docs oficiales, CVEs históricos, Casbin, Velero.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Dibujar los componentes de Argo CD y las flechas gRPC/HTTP/Redis entre ellos. Explicar la diferencia **Argo CD RBAC** vs **K8s RBAC**. Leer un CSV `argocd-rbac-cm` y decir quién puede hacer qué. Explicar por qué Argo CD es *stateless* a nivel de disco. |
| Operativa | Configurar OIDC con un IdP (GitHub/Dex). Deshabilitar admin local. Aplicar PSA `restricted` al namespace `argocd`. Crear un `Backup` de Velero del ns `argocd` y verificar `Restore` en un cluster nuevo. |
| Arquitectónica | Auditar una instalación default y producir un **plan de hardening priorizado** (SSO → TLS → PSA → NetworkPolicy → backup). Justificar la decisión *admin local on/off* por entorno. Diseñar la política de rotación de `server.secretkey` y revocación de JWTs. |

## Criterios de evaluación

- Instalación de Argo CD con los **7 controles de hardening** del activity 01 verificados.
- OIDC funcional contra al menos un IdP (puede ser Dex con mock connector).
- `argocd-rbac-cm` con policy *deny-by-default*, 2 roles por project y binding a grupos.
- Backup Velero del ns `argocd` completado y restaurado en cluster limpio con todas las `Application` reconciliando a `Synced/Healthy`.
- ADR corto (≤ 1 página) con el plan de hardening priorizado para una instalación default dada.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada).
2. Reproduce `examples/01-oidc-with-github/` (si no tienes IdP real, usa Dex con el mock connector descrito).
3. Lee y escribe en papel el CSV de `examples/02-rbac-csv-walkthrough/`.
4. Haz la actividad `activities/01-harden-argocd-install/`.
5. Reproduce `examples/03-velero-backup-argocd-ns/`.
6. Haz la actividad `activities/02-recover-argocd-from-backup/` (independent).
7. Escribe el ADR de hardening priorizado.

## Siguiente

→ `argo-12-platform-patterns-promotion-previews-observability`: ya endurecido Argo CD, lo operamos como plataforma (promoción, PR previews, métricas, notifications).
