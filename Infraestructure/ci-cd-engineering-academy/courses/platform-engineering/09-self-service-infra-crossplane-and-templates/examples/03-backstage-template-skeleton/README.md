# Ejemplo 03 — Backstage template que genera un claim

## Objetivo

Mostrar, **sin ejecutar Backstage**, el esqueleto de un `template.yaml` del Scaffolder y el skeleton nunjucks que genera un `NamespaceProductClaim.yaml` listo para abrirse como PR en el repo GitOps.

Este ejemplo es **lectura y análisis**, no ejecución: no requiere Backstage ni cluster. El objetivo es que puedas copiar el patrón a tu propio Backstage del módulo `plat-06`.

## Archivos

- `template.yaml` — manifiesto del Scaffolder (`scaffolder.backstage.io/v1beta3`) con 3 parámetros y 2 pasos (`fetch:template` + `publish:github:pull-request`).
- `skeleton/claim.yaml` — plantilla nunjucks que recibe las variables (`${{ values.name }}`, etc.) y produce el YAML del claim.
- `skeleton/catalog-info.yaml` — plantilla del catalog entry que acompañaría al claim (opcional pero recomendable).

## Qué hace el template al ejecutarse en Backstage

```
Developer en Backstage
   │  llena los 3 inputs (name, tier, env)
   ▼
step fetch:template
   │  renderiza skeleton/*.njk con los valores
   ▼
step publish:github:pull-request
   │  crea rama claim-<name> y abre PR al repo gitops
   ▼
PR → merge → Argo CD → Crossplane → recursos materializados
```

## Puntos clave de diseño

1. **El template no habla con Crossplane directamente.** Habla con **git**. Esto es importante: separa la UX (Backstage) del plano de control (Crossplane) con el canal más auditable del mundo (PRs).
2. **El JSON Schema del paso 1 duplica las validaciones del XRD** (`pattern`, `enum`). Dos capas de validación: UX (Backstage) y backend (XRD).
3. **El PR es revisable antes del merge.** Si la organización quiere auto-merge para claims triviales, se añade una automation; para claims caros, un reviewer humano hace sentido.
4. **El `catalog-info.yaml` opcional** registra el recurso en el catálogo de Backstage para que aparezca en vistas, scorecards (`plat-10`) y relaciones.

## Lectura cruzada

- `theory/lesson.md` §6 — flujo end-to-end detallado.
- Módulo `plat-06-templates-and-scaffolder` — anatomía completa del Scaffolder y nunjucks.
- `examples/02-xrd-namespace-product/claim.yaml` — el claim resultante que este template produce.
