# Recursos — Capstone etapa 10 (GitOps multi-ambiente + Argo Rollouts)

## Argo CD — ApplicationSet

- **ApplicationSet — Introducción** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/>
- **Generador `list`** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-List/>
- **Generador `git-directory`** (alternativa) — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/>
- **Template fields y Go templating** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/GoTemplate/>

## Argo Rollouts

- **Argo Rollouts — Docs oficiales** — <https://argo-rollouts.readthedocs.io/en/stable/>
- **Canary strategy** — <https://argo-rollouts.readthedocs.io/en/stable/features/canary/>
- **AnalysisTemplate y AnalysisRun** — <https://argo-rollouts.readthedocs.io/en/stable/features/analysis/>
- **Prometheus provider** — <https://argo-rollouts.readthedocs.io/en/stable/analysis/prometheus/>
- **Plugin `kubectl argo rollouts`** — <https://argo-rollouts.readthedocs.io/en/stable/installation/#kubectl-plugin-installation>

## Image Updater / promoción

- **Argo CD Image Updater — Docs** — <https://argocd-image-updater.readthedocs.io/en/stable/>
- **Write-back a Git** — <https://argocd-image-updater.readthedocs.io/en/stable/basics/update-methods/#write-back-methods>
- **Estrategias de update (semver, digest, latest)** — <https://argocd-image-updater.readthedocs.io/en/stable/basics/update-strategies/>
- **Renovate (alternativa a Image Updater)** — <https://docs.renovatebot.com/>
- **Renovate — Kubernetes manager** — <https://docs.renovatebot.com/modules/manager/kubernetes/>

## Patrones y guías

- **Codefresh — "Progressive delivery with Argo Rollouts"** — <https://codefresh.io/learn/argo-rollouts/>
- **Weaveworks — "GitOps principles"** — <https://www.weave.works/technologies/gitops/>
- **OpenGitOps — Principles 1.0** — <https://opengitops.dev/>
- **Argo CD Best Practices** — <https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/>

## Observabilidad para analysis (puente a etapa 11)

- **Prometheus — Query basics** — <https://prometheus.io/docs/prometheus/latest/querying/basics/>
- **SRE Workbook — "Alerting on SLOs"** — <https://sre.google/workbook/alerting-on-slos/>

## Anti-patrones

- **"Don't use `latest` tag with Image Updater"** — ver `allow-tags: regexp:^[0-9]+\.[0-9]+\.[0-9]+$` como mitigación.
- **"Un solo canary step al 100 %"** — equivale a un Deployment normal; perder los pasos derrota el propósito.
- **"AnalysisTemplate sin `failureLimit`"** — un spike transitorio aborta releases legítimos.
