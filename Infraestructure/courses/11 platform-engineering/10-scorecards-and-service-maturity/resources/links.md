# Recursos — plat-10

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso para asegurar vigencia (las APIs y precios cambian).

## Backstage TechInsights (open source)

- Plugin oficial: `https://backstage.io/docs/features/tech-insights/`
- Repositorio: `https://github.com/backstage/backstage/tree/master/plugins/tech-insights`
- Fact retrievers (patrón): `https://backstage.io/docs/features/tech-insights/writing-fact-retrievers`
- Checks (JSON Rules Engine): `https://backstage.io/docs/features/tech-insights/writing-tech-insights-checks`

## Spotify Soundcheck (comercial, sobre Backstage)

- Producto: `https://backstage.spotify.com/plugins/soundcheck/`
- Comparativa vs TechInsights: buscar "Soundcheck vs TechInsights" en el blog de Spotify Open Source.

## Alternativas independientes de Backstage

- **OpsLevel**: `https://www.opslevel.com/` → *Maturity* y *Service Catalog*.
- **Cortex**: `https://www.cortex.io/` → *Scorecards* y *Service Catalog*.
- Comparativa anual (buscar la más reciente): "OpsLevel vs Cortex vs Backstage" en CNCF blog / Thoughtworks Radar.

## Diseño de scorecards (buenas prácticas)

- *"The Scorecard Pattern"* — artículos del blog de **OpsLevel** y **Cortex** (buscar la versión reciente).
- *"Production Readiness Reviews at Google"* — SRE Book, cap. 32 (relevante para la integración scorecard ↔ PRR).
- *"Thinking in Bets"* — Annie Duke (útil para argumentar contra "100 chequeos" vs "los 5 que importan").

## Supply chain (contexto de los chequeos de imagen firmada / CVEs)

- **Cosign / Sigstore**: `https://docs.sigstore.dev/`
- **Trivy** (escáner de imágenes): `https://aquasecurity.github.io/trivy/`
- **SLSA** (Supply-chain Levels for Software Artifacts): `https://slsa.dev/`

## Kubernetes Pod Security Admission (PSA)

- Docs: `https://kubernetes.io/docs/concepts/security/pod-security-admission/`
- Niveles (privileged / baseline / restricted): `https://kubernetes.io/docs/concepts/security/pod-security-standards/`

## Métricas de adopción (vista previa de `plat-11`)

- DORA metrics: `https://dora.dev/`
- SPACE framework: `https://queue.acm.org/detail.cfm?id=3454124`

## Para el módulo previo (contexto)

- `plat-05-catalog` — sin catálogo no hay scorecard.
- `plat-08-plugins` — TechInsights **es** un plugin.

## Checklist de verificación requerida en Fase 4

- Estado del plugin **TechInsights** (API estable vs experimental).
- Comparativa vigente **TechInsights vs Soundcheck vs OpsLevel vs Cortex** (features y precios).
- Estado de **Cosign/Sigstore** (versiones estables).
- Nuevos *fact retrievers* oficiales que hayan aparecido (GitHub, GitLab, PagerDuty, Datadog, Snyk).
