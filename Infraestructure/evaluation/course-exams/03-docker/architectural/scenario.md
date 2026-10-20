# Ejercicio arquitectónico — Supply chain + base image para plataforma Python multi-arch

Peso: **25%** del examen. Tiempo sugerido: **25–40 min**.

## Contexto

Lideras la plataforma de contenedores de **Acme Payments**. El equipo opera **10 microservicios Python** (FastAPI + algunos workers con `numpy`/`pandas`) desplegados en Kubernetes.

**Restricciones no negociables:**

1. **Producción es air-gapped.** Los nodos de prod no pueden salir a Internet; sólo ven un registry interno (Harbor) replicado desde un mirror.
2. **Fleet mixta:** control plane y nodos en `linux/amd64` on-prem; nuevos nodos edge en `linux/arm64` (Graviton y Ampere).
3. **Compliance** exige **atestación SLSA ≥ nivel 2** y **SBOM CycloneDX** por imagen, verificables en el admission controller del cluster.
4. **Objetivo de tamaño:** p95 de pull en nodo frío **< 10 s**. Promedio actual con `python:3.12`: 38 s.
5. **Objetivo de CVE:** cero HIGH/CRITICAL explotables en imagen productiva al momento del release; política de rebuild semanal para refrescar la base.
6. **Developer experience:** los equipos no deben necesitar escribir `cosign` ni `syft` en sus Dockerfiles — la plataforma lo provee.
7. **Rollback de 1 clic a cualquier release de los últimos 90 días.**
8. **Costo:** no se puede introducir una suscripción nueva de > USD 5k/año sin ADR adicional.

**Variables bajo tu control:**

- Base image(s) estándar que la plataforma ofrece.
- Estrategia de tagging y pinning (tags mutables, digests, mirrors).
- Flujo CI → registry (SBOM, scan, firma, attestation, promoción).
- Flujo de verificación en el cluster (admission controller, policies).
- Estrategia multi-arch (QEMU vs native runners, cuándo).

## Entregable

Un **ADR** en `architectural/ADR-001-base-image-and-supply-chain.md` con la estructura siguiente (usar formato ADR MADR o similar):

1. **Contexto y restricciones** (reformuladas con tus palabras — demuestra que las entendiste, no copies).
2. **Opciones consideradas** para cada decisión. Mínimo:
   - Base image: `python:3.12-slim` vs `alpine` vs `distroless` vs `chainguard` vs base interna propia.
   - Pinning: tag semver vs tag + digest vs digest puro.
   - Firma: cosign keyless (OIDC) vs cosign keyed vs notation.
   - Multi-arch: `buildx` con QEMU vs matriz de runners nativos vs builder remoto en cluster.
   - Verificación en admisión: Kyverno vs sigstore policy-controller vs OPA/Gatekeeper.
3. **Decisión** por cada punto, con **trade-offs explícitos**.
4. **Diagrama** (ASCII o mermaid) del flujo build → registry → cluster, mostrando dónde se produce SBOM, dónde se firma, dónde se verifica, y cómo se maneja el air-gap.
5. **Plan de reproducibilidad y rollback** (cómo se recupera `v1.4.2` 60 días después).
6. **Riesgos aceptados** y **anti-objetivos** (qué explícitamente **no** vas a hacer y por qué).
7. **Métricas de éxito** cómo medirás que la decisión funciona en 90 días.

Longitud recomendada: 2–4 páginas. Prefiere densidad a volumen.

## Rúbrica

| Criterio | 0 Insuficiente | 1 Básico | 2 Competente | 3 Experto |
|----------|----------------|----------|--------------|-----------|
| **Comprensión del contexto** (10%) | Ignora restricciones (p. ej. propone pull desde Docker Hub en prod) | Reconoce restricciones pero no las usa como criterio | Cada decisión referencia la restricción que la motiva | + identifica restricción implícita que el enunciado no explicita (p. ej. licensing de base, SLA del registry) |
| **Elección de base image** (15%) | Sin justificación o elige una que rompe la app | Elige razonablemente pero omite trade-offs | Compara ≥ 3 opciones con tamaño/CVE/soporte/compat Python | + propone base interna derivada de upstream con pin + política de refresh |
| **Pinning y rollback** (15%) | Usa `:latest` o sólo semver | Semver + digest pero sin plan de rollback | Digest + mirror + plan reproducible | + mecanismo verificable de "¿sigo pudiendo rebuildear v1.4.2?" |
| **Supply chain (SBOM + firma + attestation)** (20%) | Falta alguno de los tres | Los tres presentes pero sin integración | Flujo completo con verificación en admisión | + explica rotación de claves, revocación, qué pasa si Sigstore está caído |
| **Multi-arch** (10%) | No lo aborda o depende sólo de QEMU para builds pesados | QEMU para todo | Runners nativos para arch mayoritaria + QEMU para edge | + estrategia híbrida por tipo de workload (compute vs IO) con métricas |
| **Air-gap** (10%) | Propone acceso directo a registries públicos | Reconoce el problema sin solución operativa | Mirror con sincronización + política de staleness | + propagación de attestations/firmas por el mirror; verificación offline |
| **Trade-offs y anti-objetivos** (10%) | Presenta la solución como "la correcta" | Menciona 1-2 trade-offs | Trade-offs explícitos por decisión + 2-3 anti-objetivos | + identifica qué decisión reconsideraría si una restricción cambia |
| **Developer experience** (5%) | Carga a los equipos con `cosign`/`syft` manual | Scripts compartidos | Template/base Dockerfile + CI shared workflow | + mide fricción con un KPI (p. ej. "tiempo de nuevo servicio en producción < 1 día") |
| **Diagrama** (5%) | Ausente o ilegible | Presente pero no refleja decisiones | Refleja flujo + puntos de verificación | + anota en el diagrama dónde está cada control de las restricciones |

Puntuación arquitectónica: `pct_arq = sum(peso_i * nivel_i) / (3 * sum(peso_i)) * 100`. Mínimo exigido: 50%.

## Red flags (invalidación por decisión)

- Propone **desactivar verificación** en admisión "para empezar".
- Propone usar **Docker Hub** directamente desde los nodos de prod.
- Confunde **tag inmutable** con digest (p. ej. "pinnearemos a `v1.2.3` y Harbor garantiza inmutabilidad" sin verificar que esté configurado así).
- No menciona rotación/revocación de claves.
- Propone **almacenar la clave privada** de cosign en el cluster o en el registry.
- Decide **firmar en el runner del developer** (clave en laptop) en vez de en CI con identidad federada.

## Preguntas de seguimiento (live only)

1. "Harbor cae por 2 h en medio del release. ¿Qué pasa con los deployments en curso y los nuevos?"
2. "Un desarrollador quiere `pip install --index-url https://pypi.org`. ¿Cómo lo bloqueas y qué le ofreces en su lugar?"
3. "Mañana Sigstore anuncia breaking change en formato de attestation. ¿Cómo lo absorbes sin romper el admission controller?"
4. "Tu base image interna hereda de `python:3.12-slim`. Upstream saca un parche crítico. ¿Cuánto tardan tus 10 servicios en estar re-releaseados y por qué?"
5. "Un equipo necesita `tensorflow` y la base distroless no basta. ¿Haces excepción, forkeas la base o les das una variante paralela? Defiende el impacto en gobierno."

## Guía de corrección (instructor-only)

**Respuestas "experto" tipo:**

- Base: **Chainguard** `python` o una base interna derivada de `distroless` con `FROM ...@sha256:...`, actualizada semanalmente por un job que abre PR automático. Reconoce que Chainguard introduce **costo** (verificar que entra en el límite) o requiere "wolfi" como alternativa libre.
- Pinning: `v1.2.3` + digest en el `kustomization.yaml`/Helm `values.yaml`; registry Harbor con **retention policy** y **immutable tags** activadas; mirror con `oras cp` o `crane cp` + `cosign copy` para preservar firmas.
- Firma: **cosign keyless** (OIDC federado del provider CI) en pipeline; verificación en cluster con **sigstore policy-controller** o **Kyverno** (si ya está en uso). Reconocer que keyless air-gapped requiere **Rekor espejado** o aceptar que el cluster verifica con política basada en el issuer/subject del certificado pre-provisioned.
- Multi-arch: matriz de runners nativos (amd64 + arm64) en CI; QEMU **sólo** para tests, no para artefacto final de workloads con `numpy`.
- Air-gap: Harbor como *source of truth*; sync job verificado (cosign verify al pullear al mirror); nodes sólo tienen credencial a Harbor; `imagePullPolicy: IfNotPresent` + preload en nodos edge.
- DX: shared GitHub Actions workflow (`acme/docker-publish@v1`) que recibe `app_path` y produce imagen + SBOM + firma + PR a GitOps repo.

**Red flags observadas en candidatos reales a vigilar:**

- "Firmar es opcional en dev, obligatorio en prod" → pierde la propiedad de que **lo que corre en prod se buildeó en CI**.
- "Usamos `latest-slim` porque siempre tiene parches" → ignora reproducibilidad.
- Dibuja un diagrama con cosign **después** del deploy ("verificamos en el pod") → verificación debe ser en **admission**, no runtime.

**Puntuación:** aplicar rúbrica criterio por criterio. Si aparece una red flag de la lista, el criterio asociado baja a 0 y el ejercicio no puede superar 60% total.
