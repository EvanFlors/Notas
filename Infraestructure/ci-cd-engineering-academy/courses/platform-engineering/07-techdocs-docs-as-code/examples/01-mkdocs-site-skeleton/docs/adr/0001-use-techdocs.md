# ADR 0001 — Use TechDocs for service documentation

- **Status:** accepted
- **Date:** 2026-01-15
- **Owner:** team-platform

## Context

El equipo ha mantenido documentación en Confluence durante años. La doc va 2–3 sprints por detrás del código y el search es malo.

## Decision

Adoptamos **TechDocs** (Backstage) + **MkDocs** con el bundle `techdocs-core`. Las docs viven en `/docs` del repo del servicio y se publican a S3 vía pipeline CI (modo *centralized*).

## Consequences

- Positivas: PR + review para docs; linkable desde Backstage; indexable por search.
- Negativas: cada repo necesita el pipeline (mitigado con template Backstage); dos semanas de migración desde Confluence.

## Alternativas descartadas

- **Seguir en Confluence:** drift crónico.
- **Google Docs:** nada de ownership ni versioning.
