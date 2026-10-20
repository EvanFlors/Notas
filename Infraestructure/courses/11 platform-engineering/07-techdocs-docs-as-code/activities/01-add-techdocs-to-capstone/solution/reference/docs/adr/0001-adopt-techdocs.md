# ADR 0001 — Adopt TechDocs for checkout-service

- **Status:** accepted
- **Date:** 2026-02-01
- **Owner:** team-platform

## Context

La doc del servicio vivía en Confluence. En la última retro, 4 de 7 ingenieros dijeron que no la consultaban porque "estaba desactualizada". El runbook tenía 11 meses sin modificar.

## Decision

Adoptamos **TechDocs** con MkDocs + bundle `techdocs-core`. Las docs viven en `/docs` de este repo. Se publican a S3 (modo *centralized*) desde GitHub Actions con OIDC federado hacia el role `techdocs-publisher`.

## Consequences

- Positivas: PR + review para cada cambio de doc; descubribles desde Backstage; linkables desde el EntityPage; mismo oncall que el código.
- Negativas: migración de ~15 páginas Confluence (3 días de trabajo, hecho por el autor del ADR + review del equipo); pipeline nuevo que mantener (mitigado por template).

## Alternativas descartadas

- **Seguir en Confluence:** no resuelve el drift.
- **README monolítico:** no escala; mezcla setup, runbook y arquitectura en una página.
