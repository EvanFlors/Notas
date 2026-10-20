# ADR-009 — Estrategia de secretos en GitOps (ejemplo de solución)

- **Status:** accepted
- **Date:** 2026-10-15
- **Deciders:** Platform Team
- **Revisit:** 2027-10-15

## Context

GitOps exige que todo el estado deseado viva en Git, pero los valores secretos no pueden commitearse en claro. Las cinco opciones vigentes son SOPS+KSOPS, Sealed Secrets, ESO, CSI Secrets Store Driver y Vault Agent Injector. Difieren en dónde vive el valor, quién lo materializa, el *blast radius* y la UX de rotación.

## Decision table

| Criterio                | SOPS+KSOPS | Sealed Secrets | ESO | CSI Driver | Vault Injector |
|-------------------------|:----------:|:--------------:|:---:|:----------:|:--------------:|
| Blast radius            |     2      |       3        |  4  |     4      |       4        |
| Rotation UX             |     2      |       1        |  5  |     5      |       5        |
| Operator overhead       |     5      |       4        |  3  |     3      |       2        |
| Cost                    |     5      |       5        |  3  |     3      |       2        |
| Multi-cluster           |     3      |       1        |  5  |     4      |       4        |
| Compliance fit          |     3      |       2        |  4  |     5      |       5        |
| Migration cost          |     3      |       2        |  4  |     3      |       3        |

## Org 1 — Startup fintech en AWS

**Decision:** External Secrets Operator con AWS Secrets Manager y IRSA.
**Why:** La org ya está en AWS; IRSA elimina credenciales largas; ESO materializa `Secret` nativo que SOC2 audita vía CloudTrail del provider; rotación por `refreshInterval` sin PRs; patrón canónico para 50 microservicios.
**Trade-offs:** El `Secret` nativo acaba en etcd — requiere `EncryptionConfiguration` + KMS envelope, que ya trae EKS 1.28+.

## Org 2 — Agencia gubernamental air-gapped

**Decision:** SOPS + KSOPS con claves `age` custodiadas en HSM USB.
**Why:** Sin conectividad cloud, los operators que pulean (ESO/CSI/Vault) carecen de provider accesible. SOPS sólo requiere la clave age en el `repo-server`; el equipo ya conoce PGP, la curva es corta; air-gap elimina riesgos de red; el HSM garantiza custodia física.
**Trade-offs:** Rotación de clave maestra implica re-cifrar todos los archivos; mitigado con script y revisión semestral.

## Org 3 — Empresa industrial con Vault

**Decision:** Vault Agent Injector para los servicios core (dynamic DB creds con lease 1 h); ESO + Vault como provider para el resto.
**Why:** La inversión en Vault ya está hecha; dynamic secrets reducen a cero el riesgo de credenciales persistentes para los servicios críticos; ESO cubre los 100+ servicios restantes sin sidecar overhead; una única fuente de verdad (Vault) simplifica audit.
**Trade-offs:** Dos patrones vivos requieren documentación clara de cuál usar; sidecars encarecen pods core pero el gain operativo lo justifica.

## Consequences (apuesta global del equipo)

Si tuviéramos *una* sola estrategia global, elegiríamos ESO: cubre el 80% de los casos, se integra con cualquier provider, y la curva de aprendizaje es moderada. Pagamos un operator más y dependencia del provider, pero obtenemos rotación continua y audit heredado del provider.

## Rotation plan

- **Secretos de aplicación**: trimestral; automatizado vía provider (ESO lo propaga).
- **Claves maestras SOPS**: anual; drill en Q2 con staging.
- **Credenciales del operator al provider** (IRSA role, Vault AppRole): rotación semi-anual; alertas 30 días antes del vencimiento vía Prometheus + Alertmanager.

## Links

- `theory/lesson.md`
- https://external-secrets.io/
- https://www.vaultproject.io/docs/platform/k8s/injector
- https://github.com/getsops/sops
