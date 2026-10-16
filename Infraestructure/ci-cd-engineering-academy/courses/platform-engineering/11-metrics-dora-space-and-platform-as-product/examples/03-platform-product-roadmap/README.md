# Ejemplo 03 — Platform-as-a-Product: roadmap trimestral

Ejemplo real-ish de cómo un platform team publica su roadmap como lo haría un product team: horizonte visible, criterios de aceptación en el *now*, release notes con breaking changes claros.

## Qué hay aquí

- `ROADMAP.md` — formato *now / next / later* para un trimestre (ejemplo: Q4 2026 de una plataforma ficticia "Acme Platform").
- Este README — guía de uso: cadencia, formato, qué debería contener cada bloque.

## Formato

```
# Acme Platform — Roadmap Q4 2026

## NOW (trimestre en curso, comprometido)
  - [epic/feature con criterio de aceptación medible]

## NEXT (candidatos próximo trimestre, no comprometido)
  - [epic con hipótesis de valor]

## LATER (ideas con tracción, sin fecha)
  - [idea con quién lo pidió]

## Release notes últimos 30 días
  - YYYY-MM-DD — [cambio user-visible] [breaking? sí/no] [upgrade path]

## Deprecaciones anunciadas
  - FEATURE — anunciada YYYY-MM-DD, warn desde YYYY-MM-DD, remove YYYY-MM-DD
```

## Reglas de la casa

- **NOW ≠ wishlist.** Si no tiene criterio de aceptación medible y owner, no está en NOW.
- **NEXT no es compromiso**, es hipótesis. Puede moverse a *later* si llega feedback contrario.
- **LATER no es "nunca"**, es "tenemos la señal pero no la capacidad". Cada ítem lleva **quién lo pidió** (equipo o persona), para poder reactivar la conversación cuando haya ancho de banda.
- **Release notes públicos internamente**, no email. Un canal `#platform-changelog` o una página en TechDocs.
- **Deprecations con TTL explícito**: fecha de aviso, fecha warn, fecha de remove. Sin TTL, un deprecation nunca termina de deprecarse.

## Cómo se conecta con las métricas

- Cada ítem en NOW cita el **leading indicator** que debería mover (p. ej. "subir % servicios con scorecard ≥ silver del 42 % al 60 %").
- Al cierre del trimestre, retrospectiva pública: ¿la métrica se movió? ¿no? ¿por qué?
- Si una feature se envió y nadie la adoptó en 90 días, hay que **matarla o rediseñarla**, no defenderla.

## Siguiente

Este ejemplo cierra el bloque de *examples*. Las actividades aplican todo:

- `activities/01-build-dora-dashboard/` — del evento al bucket DORA.
- `activities/02-platform-product-canvas/` — del backlog al canvas platform-as-product.
