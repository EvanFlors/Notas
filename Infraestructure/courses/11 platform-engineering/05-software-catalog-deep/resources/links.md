# Recursos — plat-05

Referencias oficiales y lecturas de apoyo para este módulo. **Verificar en Fase 4** del curso para asegurar vigencia (Backstage mantiene breaking changes frecuentes).

## Oficiales (Backstage)

- **Software Catalog overview**: `https://backstage.io/docs/features/software-catalog/`
- **Descriptor format (todos los kinds)**: `https://backstage.io/docs/features/software-catalog/descriptor-format`
- **Well-known annotations**: `https://backstage.io/docs/features/software-catalog/well-known-annotations`
- **System model**: `https://backstage.io/docs/features/software-catalog/system-model`
- **Life of an entity**: `https://backstage.io/docs/features/software-catalog/life-of-an-entity`
- **External integrations (providers)**: `https://backstage.io/docs/integrations/`
- **GitHub Entity Provider**: `https://backstage.io/docs/integrations/github/discovery`
- **Catalog Graph plugin**: `https://backstage.io/docs/features/software-catalog/catalog-graph`

## Entity kinds (referencia detallada)

- **Component**: `https://backstage.io/docs/features/software-catalog/descriptor-format#kind-component`
- **API**: `https://backstage.io/docs/features/software-catalog/descriptor-format#kind-api`
- **Resource**: `https://backstage.io/docs/features/software-catalog/descriptor-format#kind-resource`
- **System**: `https://backstage.io/docs/features/software-catalog/descriptor-format#kind-system`
- **Domain**: `https://backstage.io/docs/features/software-catalog/descriptor-format#kind-domain`
- **User** y **Group**: `https://backstage.io/docs/features/software-catalog/descriptor-format#kind-user`
- **Location**: `https://backstage.io/docs/features/software-catalog/descriptor-format#kind-location`

## Validadores y herramientas

- **Backstage CLI** (`backstage-cli repo lint`, `catalog:validate` acciones): `https://backstage.io/docs/local-dev/cli-commands`
- **JSON Schemas de las entidades** (en el repo de Backstage): `https://github.com/backstage/backstage/tree/master/packages/catalog-model/src/schema`
- **Catalog API HTTP** (consultas sobre el grafo): `https://backstage.io/docs/features/software-catalog/software-catalog-api`

## Alternativas / contexto

- **Port** (modelo de "blueprints" análogo al catálogo): `https://docs.port.io/`
- **OpsLevel / Cortex** (service catalogs comerciales): `https://www.opslevel.com/`, `https://www.cortex.io/`
- **CNOE catalog bootstrap**: `https://cnoe.io/`

## Lecturas recomendadas

- "The 10 commandments of a healthy Backstage catalog" (buscar en el blog de Spotify / Backstage).
- "From ad-hoc to a software catalog" — charlas en BackstageCon y KubeCon.
- "Why your developer portal needs an entity model" — artículos de Port y OpsLevel comparando enfoques.

## Checklist de verificación requerida en Fase 4

- Estado actual del `apiVersion` para cada kind (algún kind podría haber migrado a `v1beta1` o `v1`).
- Vigencia del `GithubEntityProvider` (API/opciones cambiaron en Backend System 1.0).
- Lista actualizada de **well-known annotations** (nuevas annotations por plugins recientes).
- Compatibilidad del snippet de pre-commit con la versión de `pre-commit` del repo destino.
