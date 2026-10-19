# REFERENCE — jk-08-02-migration-adr-and-dual-run

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte. Acompañan los archivos `Jenkinsfile` y `dual-run.yml` adyacentes.

---

# ADR 002 — Migración de Jenkins a GitHub Actions

## Estado

Propuesto (Fase 3). Objetivo: ser Aceptado tras revisión de Platform + Security + Compliance y ejecutado en 7 fases (Fase 0 → Fase 5 + archivado) a lo largo de ~9 meses.

## Contexto

- Operamos un Jenkins LTS con **120 pipelines** (80 declarative, 40 freestyle) y 4 años de historia.
- Todos los repos están en **GitHub Enterprise** corporativo.
- Compliance acaba de añadir el requisito "retirar credentials AWS de larga duración": **OIDC federation obligatoria** antes de fin de año.
- El equipo platform ya opera workflows GHA para otros proyectos; curva baja.
- Los 40 pipelines freestyle sin dueño son el dolor principal: `#1` fuente de incidentes operativos.
- SLA actual del Jenkins es 99.5% (ver ADR-OPERATE-AT-SCALE); seguimos operando mientras migramos.

Decisión alta: **migrar a GitHub Actions**, en paralelo (dual-run) con el Jenkins existente, por fases, con criterios de corte explícitos y un ADR vivo. El Jenkins se apaga únicamente cuando se cumplen los criterios de corte.

## Decisión

### 1. Target: GitHub Actions

Elegimos GHA (y no GitLab CI ni Argo Workflows) porque:

- Repos ya en GitHub → latencia cero de webhook, SSO integrado.
- OIDC a AWS probado por otros equipos de la casa.
- Reusable workflows como reemplazo directo de nuestras Shared Libraries.
- Marketplace de actions cubre el 90% de pasos de plugins Jenkins actuales (ECR login, Terraform, Trivy, cosign).

### 2. Inventario y clasificación

De los 120 pipelines estimamos (ajustar en Fase 0):

| Clase | % estimado | Nº | Notas |
|-------|------------|----|-------|
| **retirar** | 30% | ~36 | Freestyle sin runs 90d, duplicados, repos archivados. |
| **consolidar** | 10% | ~12 | Variantes paramétricas (p. ej. `app-release-{a,b,c,d}`). |
| **migrar** | 60% | ~72 | Pipelines activos con dueño; entran en el plan por fases. |

Las 4 variantes `app-release-*` se consolidan en 1 pipeline parametrizado **antes** de migrar — es más barato refactor en Jenkins y luego mover que arrastrar la duplicación a GHA.

### 3. Dual-run framework

```
                       Push a Git
                           │
         ┌─────────────────┴─────────────────┐
         │                                   │
         ▼                                   ▼
   Webhook Jenkins                    GitHub Actions
   (Jenkinsfile)                      (.github/workflows/dual-run.yml)
         │                                   │
         ▼                                   ▼
   artefacto A                         artefacto B
         │                                   │
         └───────────► compare-runs.sh ◄─────┘
                              │
                              ▼
                     Dashboard de divergencia:
                     - estado
                     - hash artefacto
                     - delta duración
                     - logs error-key
```

Reglas:

- Dual-run por pipeline: **mínimo 2 semanas no críticos, 4–8 semanas críticos**.
- 20 runs consecutivos con **mismo estado y mismo hash** → candidato a declarar ganador.
- Owner del pipeline firma por escrito "no quiero volver" antes del corte.
- Rollback: reactivar webhook Jenkins, desactivar workflow GHA (no borrar). Documentar causa en el ADR.

### 4. OIDC federation (adiós a `withCredentials`)

Reemplazo sistemático:

- Cada repo con pipeline migrado estrena un rol AWS `gha-<repo>-<env>` con trust policy:
  ```json
  {
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::<acct>:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike":  { "token.actions.githubusercontent.com:sub": "repo:acme/<repo>:ref:refs/heads/main" }
    }
  }
  ```
- Los credentials Jenkins (`aws-*`) **se desactivan** una semana después de declarar ganador el pipeline correspondiente.
- Compliance recibe informe mensual con `credentials eliminados` vs `credentials pendientes`.

### 5. Reemplazo de Shared Libraries

- La library `std-build@v3` (steps: `standardBuild()`, `publishToS3()`, `notifySlack()`) se re-expresa como **reusable workflow** en el repo `acme/.github`:
  - `.github/workflows/std-build.yml` ← `standardBuild()`
  - `.github/workflows/publish-to-s3.yml` ← `publishToS3()`
  - `.github/workflows/notify-slack.yml` ← `notifySlack()`
- Los pipelines migrados los invocan con `uses: acme/.github/.github/workflows/std-build.yml@v1`.
- Pinning por SHA + tag `v1`, igual que Jenkins pinnea `@3` de la library.
- La library Jenkins queda **congelada** (sin más PRs) desde Fase 3; cualquier cambio nuevo ocurre en los reusable workflows.

### 6. Plan por fases (9 meses)

| Fase | Semanas | Qué |
|------|---------|-----|
| **0 Preparación** | 1–2 | Inventario; dashboards dual-run; formación GHA; OIDC provider en AWS. |
| **1 Canarios** | 3–6 | `orders-api-ci` y `docs-site` en dual-run. Validar framework. |
| **2 Volumen bajo** | 7–14 | 40% de pipelines simples. |
| **3 Shared Libs + volumen alto** | 15–24 | Reusable workflows publicados. 40% pipelines complejos no críticos. |
| **4 Críticos** | 25–32 | `payments-nightly` y resto críticos. Dual-run 4–8 semanas por pipeline. |
| **5 Corte y archivado** | 33–36 | Último dual-run verde; archivado histórico; apagado procedimentado. |

### 7. Criterios de corte (apagado del Jenkins)

Todos deben cumplirse:

1. 100% pipelines `migrar` han pasado dual-run y están en GHA.
2. 0 pipelines `retirar` activos (borrados o archivados).
3. 4 semanas sin builds en Jenkins para los pipelines migrados.
4. Logs y artefactos relevantes **archivados** a S3 Glacier Deep Archive con retención 7 años (compliance firma).
5. Shared library Jenkins marcada read-only; reusable workflows publicados y referenciados.
6. Webhooks externos reconfigurados fuera de Jenkins.
7. Credentials de larga duración revocados en AWS (los no-OIDC desactivados).

### 8. Procedimiento de apagado

1. Backup final Velero del `JENKINS_HOME` → S3 object-locked 7 años.
2. Deshabilitar nuevos builds (`Prepare for Shutdown` + bloqueo de webhooks a nivel de ingress).
3. Esperar a que la queue drene.
4. Snapshot EBS → Glacier.
5. Apagar controller.
6. 30 días en standby (DNS redirige a página "Jenkins migrado → GHA"; infra apagable con `terraform apply` revertible).
7. `terraform destroy` del stack Jenkins.
8. ADR actualizado a `Aceptado — ejecutado`.

### 9. Criterios de rollback

Rollback por pipeline (durante dual-run):

- Workflow GHA falla sistemáticamente en algún caso que Jenkins resuelve.
- Hash de artefacto diverge sin explicación tras 1 semana de debug.
- Equipo del pipeline no firma el "no quiero volver".

Rollback global (freno de la migración):

- Más del 20% de pipelines en Fase 2 vuelven a Jenkins. Señal de que el framework de dual-run o el target está roto. Pausa de 2 semanas, postmortem y replan.

## Consecuencias

### Positivas

- Elimina 40 pipelines freestyle sin dueño en 9 meses.
- Reemplaza credentials AWS de larga duración por OIDC (compliance resuelto).
- UI/UX moderna, logs mejores, auditoría integrada en GitHub.
- Shared Libs → reusable workflows versionados: mejor DX, testing nativo.
- Reduce la superficie Jenkins a cero al final → menos CVEs que gestionar.

### Negativas

- 9 meses de operación duplicada (Jenkins vivo + GHA creciente).
- Costo adicional GHA (minutes privados) estimado durante la ventana: ~800 USD/mes extra, decreciente.
- Riesgo de rollback en Fase 4 (críticos). Mitigación: dual-run largo + go/no-go por pipeline con approval del CTO.
- Curva de aprendizaje para 10 ingenieros con poco GHA. Mitigación: pairing + "office hours" semanales de platform.

## Alternativas descartadas

### Alternativa A: no migrar (seguir operando Jenkins)

- Pros: ningún esfuerzo.
- Contras: no resuelve compliance (OIDC obligatorio); mantiene 40 freestyle insostenibles; sigue acumulando CVEs de plugins.
- **Por qué no**: no cumple el deadline de compliance ni elimina el dolor operativo.

### Alternativa B: migrar a GitLab CI

- Pros: estándar maduro, OIDC también.
- Contras: implica migrar también los repos → coste combinado de migración × 2.
- **Por qué no**: GitHub Enterprise ya está pagado; migrar repos es un proyecto aparte.

### Alternativa C: migrar a Argo Workflows

- Pros: K8s-native, encaja con nuestro EKS.
- Contras: UI y DX inferiores para equipos no-K8s; mayor curva; ecosistema de reusables más limitado.
- **Por qué no**: pensado como target de pipelines K8s-centric (data, ML), no para CI tradicional.

### Alternativa D: "big bang" — migrar todo en 2 meses sin dual-run

- Pros: menos operación duplicada.
- Contras: garantía estadística de romper algún pipeline crítico un lunes por la mañana.
- **Por qué no**: inaceptable para `payments-nightly` y similares. Dual-run no es opcional en producción.

---

## Pipelines canary

- **`orders-api-ci`** — pipeline simple y **crítico**: build + test + publish a S3/ECR. Prueba el camino OIDC y la equivalencia funcional en producción desde el día uno.
- **`docs-site`** — pipeline simple y **no crítico**: absorbe los primeros bugs del framework de dual-run sin afectar negocio.

Ver `Jenkinsfile` y `dual-run.yml` adyacentes para la equivalencia 1:1.
