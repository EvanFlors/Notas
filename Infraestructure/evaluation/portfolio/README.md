# Portafolio — qué publica el estudiante

El portafolio es el **repositorio público** que el estudiante presenta a hiring managers. Es la cara externa del programa: si alguien no lee esta academia, debe entender lo que el estudiante hizo **solo con el portafolio**.

Vive en un repo propio del estudiante (ej. `username/cicd-portfolio`), **no** dentro de este repo.

## Principios

1. **Un hiring manager debe poder evaluar en 10 min**. Jerarquía clara, enlaces profundos solo donde se requieren.
2. **Artefacto antes que narrativa**. Un workflow real pesa más que un párrafo diciendo que lo hiciste.
3. **Decisiones explícitas**. Toda elección no trivial va en un ADR. Si no hay ADR, se asume que fue default.
4. **Nada de secretos, nada de nombres de empresa reales**. Si existió un lab contra una org real, anonimizar.
5. **Reproducible donde se pueda**. Comandos pegables, `make`, scripts de setup.

## Estructura top-level del repo

```
cicd-portfolio/
├─ README.md                   # usar TEMPLATE.md como base
├─ ADRs/                       # decisiones arquitectónicas (Nygard format)
│  ├─ 0001-cloud-choice.md
│  ├─ 0002-gitops-tool.md
│  ├─ 0003-progressive-delivery-strategy.md
│  └─ ...
├─ courses/                    # un dir por curso de la academia (17)
│  ├─ git-and-github/
│  ├─ github-actions/
│  └─ ...                      # ver "Artefactos mínimos por curso" abajo
├─ capstone/
│  ├─ architecture/            # diagramas C4 L1/L2, data flow
│  ├─ pipelines/               # workflows, Jenkinsfiles, .gitlab-ci.yml
│  ├─ manifests/               # k8s/helm/argocd ejemplares
│  ├─ dashboards/              # exports JSON de Grafana + screenshots
│  ├─ sboms/                   # 1 SBOM por release significativa
│  ├─ signatures/              # cosign public key + attestations ejemplares
│  ├─ incident-writeups/       # 2+ postmortems (uno real del capstone, uno simulado)
│  ├─ runbooks/                # on-call runbooks ejecutables
│  └─ scorecards/              # Backstage scorecard config + capturas
├─ metrics/
│  ├─ dora.md                  # 4 DORA del capstone con método de medición
│  ├─ space.md                 # resultado de SPACE autoevaluado
│  └─ dashboard.md             # snapshot del dashboard de progreso (sample-output.md)
├─ defense/
│  ├─ slides.pdf               # bloque A de la defensa
│  ├─ demo-script.md           # bloque B
│  └─ rubric-signed.md         # rúbrica firmada por el panel
└─ LICENSE
```

## Artefactos mínimos por curso

Para que un curso **cuente** en el portafolio, debe tener al menos lo siguiente bajo `courses/<nombre>/`. Esto está alineado con `../00-master-rubric.md`.

| Curso | Mínimos |
|-------|---------|
| `git-and-github` | 1 ADR branching + evidencia de PR con commits firmados y verificación en CI |
| `github-actions` | 1 workflow reutilizable + 1 workflow con OIDC a cloud (sin secretos) |
| `gitlab-cicd` | 1 pipeline parent/child + evidencia de review app |
| `jenkins` | 1 Jenkinsfile declarative + 1 shared library consumida |
| `docker` | Dockerfile multi-stage non-root + SBOM + firma cosign verificada |
| `kubernetes` | Manifiestos con probes/limits/securityContext + NetworkPolicy default-deny + transcripción de debug de un `CrashLoopBackOff` |
| `helm` | Chart propio con values schema + `helm diff` en CI |
| `argocd-gitops` | Application + Project con RBAC + 1 Rollout canary con AnalysisTemplate |
| `terraform` | Módulo reutilizable + backend remoto con locking + runbook de state lock |
| `ansible` | Role con tests Molecule corriendo en CI |
| `aws` o `gcp` o `azure` (al menos uno, idealmente dos) | Diagrama de red + evidencia OIDC/WIF/MI sin secretos + runbook de rotación |
| `prometheus-grafana` | SLO doc + reglas de alerta burn-rate multi-window + dashboard JSON |
| `opentelemetry` | App instrumentada + Collector config + traza cross-service exportada |
| `devsecops` | Pipeline con SAST+SCA+secret scan + política de admisión + 1 SBOM publicado |
| `platform-engineering` | Entrada en Backstage + scorecard config + dashboard DORA con método |

Si un curso no tiene estos mínimos, se marca `courses/<nombre>/STATUS.md` con `incomplete:` y qué falta — nunca se oculta.

## ADRs

- Formato: Michael Nygard (Context / Decision / Consequences / Status).
- Mínimo esperado: **8 ADRs** cubriendo cloud, orquestador, GitOps tool, estrategia de secretos, progressive delivery, backend de Terraform, observability stack, policy stack.
- Un ADR puede ser `Status: superseded by ADR-0012` — se **conservan**, no se borran.

## Dashboards

- Grafana: exportar JSON **y** screenshots. El JSON es la fuente, el screenshot evita que un reclutador tenga que levantar Grafana para ver nada.
- Progreso de la academia: pegar el `sample-output.md` del dashboard de progreso en `metrics/dashboard.md`, actualizado al mes antes de aplicar.

## Incident writeups

Formato recomendado (adaptable):

```
# Título
## Resumen (3 líneas)
## Impacto (usuarios, tiempo, costo)
## Timeline (UTC)
## Causa raíz (5 whys, no "humano hizo cosa")
## Qué funcionó
## Qué no funcionó
## Acciones (owner + fecha + cómo verifico que se hizo)
```

Mínimo 2 writeups: uno **real** del capstone (etapa 15) + uno **simulado** (fuga de clave, imagen comprometida, state corrupto…).

## Scorecards

Si el estudiante hizo `platform-engineering` end-to-end, debe mostrar:

- Config YAML del scorecard (Backstage o equivalente).
- Al menos 5 checks (ej.: tiene SBOM, tiene SLO, tiene runbook, tiene owner, imagen firmada).
- Capturas con 3+ servicios evaluados (pueden ser los microservicios ficticios del capstone).

## SBOMs y firmas

- SBOM en formato CycloneDX **o** SPDX, JSON. Un SBOM por release significativa (mínimo 3).
- `cosign.pub` publicada **con** un documento `signatures/README.md` que diga: cómo se generó, dónde vive la privada (nunca en el repo), y comando para verificar: `cosign verify --key cosign.pub ghcr.io/<user>/<image>:<tag>`.

## Métricas

- **DORA**: deployment frequency, lead time for changes, change failure rate, MTTR. Cada una con **cómo se midió** (query o script). Vanity sin método no cuenta.
- **SPACE**: autoevaluación corta, honesta. Preferible una debilidad admitida que un 5/5 universal.

## Qué **NO** poner

- `node_modules/`, binarios, logs crudos, dumps de BD.
- Capturas con tokens visibles aunque estén "caducados".
- Nombres reales de empresas donde trabajaste si no autorizaron.
- Prosa generada que no revisaste tú.
- `README.md` que diga "próximamente" en 2026.

## Checklist de publicación

- [ ] `README.md` renderiza en GitHub sin cosas rotas.
- [ ] `ADRs/` tiene índice y numeración consecutiva.
- [ ] 17/17 cursos tienen al menos el mínimo o un `STATUS.md` honesto.
- [ ] `capstone/dashboards/` abre sin credenciales.
- [ ] `cosign verify` del README funciona contra una imagen pública real.
- [ ] `grep -ri 'AKIA\|AIza\|ghp_\|xox[baprs]-\|-----BEGIN' .` → vacío.
- [ ] Licencia explícita (MIT/Apache-2.0 recomendadas).
- [ ] Última actualización < 30 días.

Ver `TEMPLATE.md` como punto de partida del `README.md` del portafolio.
