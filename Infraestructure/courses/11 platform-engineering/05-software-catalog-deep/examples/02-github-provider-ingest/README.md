# Ejemplo 02 — `GithubEntityProvider`: ingesta a escala

> Lectura y análisis. Sin ejecución. Objetivo: entender cómo Backstage pasa de "registrar un Location por repo" (no escala) a "descubrir todos los `catalog-info.yaml` de una org" (sí escala).

## 1. El problema: la ingesta manual no escala

En `app-config.yaml`, lo más simple es declarar `catalog.locations`:

```yaml
catalog:
  locations:
    - type: url
      target: https://github.com/acme/checkout-api/blob/main/catalog-info.yaml
    - type: url
      target: https://github.com/acme/payments-worker/blob/main/catalog-info.yaml
    - type: url
      target: https://github.com/acme/notifications-api/blob/main/catalog-info.yaml
```

Esto funciona para 5 repos. Con 50, el `app-config.yaml` se vuelve un `/etc/hosts` moderno. Con 300, es ingobernable. Peor: cada nuevo servicio **requiere un PR al repo central** — fricción exactamente opuesta a lo que la plataforma debería ofrecer.

## 2. La solución: provider con descubrimiento

El `GithubEntityProvider` **recorre** una org (vía la API de GitHub) y auto-descubre todo `catalog-info.yaml` que exista en los repos indicados.

```yaml
# app-config.yaml
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}

catalog:
  providers:
    github:
      production:
        organization: 'acme'
        catalogPath: '/catalog-info.yaml'
        filters:
          branch: 'main'
          repository: '.*'
        schedule:
          frequency: { minutes: 30 }
          timeout: { minutes: 3 }
```

Qué hace cada campo:

| Campo | Qué hace |
|-------|----------|
| `organization` | la org de GitHub a recorrer |
| `catalogPath` | la ruta del archivo dentro de cada repo |
| `filters.branch` | solo mira esa rama (habitualmente `main`) |
| `filters.repository` | regex para incluir/excluir repos (p. ej. `^(prod-)`) |
| `schedule.frequency` | con qué frecuencia hace el descubrimiento |
| `schedule.timeout` | cuánto espera por respuesta antes de abortar un ciclo |

> **Clave operativa:** la frecuencia de 30 minutos es un buen default. Más bajo (p. ej. 5 min) castiga la API de GitHub (rate limits) sin ganancia real. Más alto (p. ej. 6 h) hace que un `catalog-info.yaml` nuevo tarde horas en aparecer, lo que confunde al equipo que lo creó.

## 3. Qué pasa en cada ciclo de descubrimiento

```
┌────────────────────────────────────────────────────────────────┐
│ Cada 30 min, GithubEntityProvider:                             │
│                                                                │
│  1. Pide a la API de GitHub la lista de repos de acme          │
│     filtrados por regex 'repository: .*'                       │
│                                                                │
│  2. Para cada repo, intenta leer /catalog-info.yaml en main    │
│                                                                │
│  3. Si existe:                                                 │
│       - lo parsea                                              │
│       - lo pasa al pipeline de processors                      │
│       - processors validan schema + resuelven relaciones       │
│       - entidad(es) se upsert en la DB del catalogo            │
│                                                                │
│  4. Si NO existe o está vacio: el repo queda invisible.        │
│                                                                │
│  5. Entidades que estaban antes pero ya no aparecen:           │
│     se marcan 'orphan' y, tras N ciclos, se borran.            │
└────────────────────────────────────────────────────────────────┘
```

Dos efectos importantes:

- **Idempotencia**: ejecutar el ciclo N veces produce el mismo estado. Entidades no se duplican por nombre.
- **Garbage collection**: si un repo se borra o se renombra sin registrar el nuevo nombre, Backstage termina expulsando sus entidades. Esto es útil para no acumular fantasmas, pero puede sorprender si un provider se desconfigura.

## 4. Filtrado por topic (patrón recomendado)

En orgs grandes conviene **no** descubrir todo. El filtro por **topic** de GitHub es el patrón más limpio:

```yaml
catalog:
  providers:
    github:
      production:
        organization: 'acme'
        catalogPath: '/catalog-info.yaml'
        filters:
          branch: 'main'
          topic:
            include:
              - backstage
```

Así, solo los repos marcados con el topic `backstage` entran al catálogo. El topic se añade manualmente (o via el template del Scaffolder) cuando el equipo quiere que su servicio sea descubierto. Es **opt-in** sin PR al repo central.

## 5. Flujo end-to-end (ASCII)

```
   ┌─────────────────────────┐        ┌───────────────────────────┐
   │   Equipo "payments"     │        │  Equipo "notifications"   │
   │                         │        │                           │
   │   repo: checkout-api    │        │  repo: notifications-api  │
   │   topic: backstage      │        │  topic: backstage         │
   │   /catalog-info.yaml    │        │  /catalog-info.yaml       │
   └──────────┬──────────────┘        └──────────┬────────────────┘
              │                                   │
              │     (sin PR al platform repo)     │
              └──────────────┬────────────────────┘
                             │
                             ▼
         ┌───────────────────────────────────────┐
         │   GithubEntityProvider (every 30m)    │
         │   lista repos con topic=backstage,    │
         │   lee /catalog-info.yaml de cada uno  │
         └──────────────────┬────────────────────┘
                            │
                            ▼
         ┌───────────────────────────────────────┐
         │   Processors del Catalog              │
         │   validan schema + relaciones         │
         └──────────────────┬────────────────────┘
                            │
                            ▼
         ┌───────────────────────────────────────┐
         │   DB del catalog (Postgres)           │
         │   entidades disponibles via UI y API  │
         └───────────────────────────────────────┘
```

## 6. Cuándo NO usar el provider y preferir Location manual

Hay 2 casos donde el `Location` manual sigue ganando:

- **Entidades compartidas** que no viven en un repo (p. ej. todos los `Group` o el catálogo de `Domain` centralizados). Mantener un repo `backstage-catalog/` con esos YAMLs y registrarlo como `Location` es más claro que esparcirlos.
- **Entidades third-party** (SaaS que no son repos: Snowflake, Looker, Datadog). Modelarlos como `Resource` en un `catalog-info.yaml` del repo central.

Para servicios propios que viven en un repo, **siempre** provider con descubrimiento.

## 7. Rate limits y errores comunes del provider

- **403 "API rate limit exceeded"**: el token tiene scope insuficiente o el provider corre con frecuencia agresiva. Fix: subir frequency a 30 min o más; usar GitHub App en vez de PAT (rate limit mayor).
- **"Catalog info not found" para un repo nuevo**: ¿commit a la rama correcta? ¿path exacto? El valor por defecto `/catalog-info.yaml` requiere el archivo en la raíz. Si vive en `.backstage/catalog-info.yaml`, hay que configurar `catalogPath` acorde.
- **Entidades aparecen y desaparecen**: el YAML del repo se valida y falla a veces. Diagnóstico: pre-commit hook obligatorio para rechazar YAMLs rotos antes del push.

## 8. Preguntas de autocomprobación

1. ¿Por qué filtrar por **topic** es mejor patrón que filtrar por nombre de repo?
2. Si bajas `frequency` a 2 minutos, ¿qué dos cosas se rompen?
3. ¿Qué pasa si dos repos distintos definen un Component con el mismo `metadata.name`?
4. ¿Dónde declararías los `Group` de la organización: en un repo central via `Location`, o esparcidos en cada repo? Argumenta.
5. En el flujo de la §5, ¿quién es responsable de que un `catalog-info.yaml` sea válido antes de llegar al provider?

Las respuestas se trabajan en las actividades, especialmente en `02-pre-commit-validate-catalog-info/`.
