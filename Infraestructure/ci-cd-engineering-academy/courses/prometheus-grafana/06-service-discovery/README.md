# obs-06 — Service Discovery

## Identificación
- **ID:** `obs-06-service-discovery`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `obs-05-exporters-and-relabeling`

## Objetivo
Descubrir dinámicamente qué scrapear: pasar de listas estáticas a mecanismos declarativos (file SD, Kubernetes SD, cloud SD) y usar `relabel_configs` para filtrar el universo de *targets potenciales* al conjunto correcto.

## Temas y subtemas
1. `static_configs` — bueno hasta 3 targets, insostenible pasado eso.
2. `file_sd_configs` — JSON/YAML en disco actualizado por tooling externo.
3. **Kubernetes SD** — `role: pod | service | endpoints | node | ingress | endpointslice`, labels `__meta_kubernetes_*`.
4. Cloud SD — **EC2**, **GCE**, **Azure**.
5. SD de cluster — **Consul**, **Nomad**.
6. **HTTP SD** — endpoint que devuelve el array de targets.
7. Interacción con `relabel_configs` — filtrar por `prometheus.io/scrape=true`, reescribir `__address__`, `__metrics_path__`.
8. Diferencia **target potencial** vs **target scrapeado**: SD genera N, relabel decide cuáles sobreviven.
9. Diagnóstico "mi pod no es scrapeado" (orden: ¿lo ve SD? ¿lo deja pasar relabel? ¿el endpoint responde? ¿RBAC?).
10. Patrón **Prometheus Operator**: CRDs (`ServiceMonitor`, `PodMonitor`) *generan* el `prometheus.yml` desde SD — se cubre en `obs-12`.

## Conceptos internos (fundamentos)
- SD y relabel son dos fases ortogonales. SD *produce* una lista de targets con `__meta_*`; relabel *decide* y *transforma* (keep/drop/replace). Sin relabel, un cluster con 1 000 pods genera 1 000 scrapes.
- Labels con doble guión bajo (`__address__`, `__scheme__`, `__metrics_path__`, `__param_*`, `__meta_*`) son privados al pipeline de scrape y desaparecen tras `labelmap`/`replace`.
- La única regla razonable al escalar es: **SD trae todo, relabel filtra por anotación/etiqueta explícita**.

## Competencias
- **Conceptual:** explicar por qué filtrar por annotation es más robusto que mantener una lista; distinguir SD de relabel.
- **Operativa:** configurar Kubernetes SD con `role: pod` y keep por annotation; depurar "mi pod no aparece"; leer `__meta_kubernetes_*`.
- **Arquitectónica:** elegir entre file SD vs K8s SD vs cloud SD según la fuente de verdad del inventario.

## Ejemplos
- `examples/01-static-vs-file-sd/` — misma app, dos mecanismos; se agrega un target *en caliente* editando `targets.json`.
- `examples/02-k8s-sd-pods-with-annotation/` — kind + Prometheus scrapeando pods con `prometheus.io/scrape=true` vía `role: pod`.
- `examples/03-ec2-sd-with-tags/` — snippet comentado (no se despliega AWS) con filtro por tag `monitoring=true`.

## Actividades
- `activities/01-scrape-pods-by-annotation/` (guided-lab) — reproducir el patrón del Operator *a mano*: configuración completa con RBAC + ConfigMap + Deployment en kind.
- `activities/02-debug-missing-targets/` (independent, debug) — un `prometheus.yml` roto que no scrapea nada; el estudiante encuentra y arregla causa raíz (annotation, regex, role, RBAC — una por scenario).

## Entregables
- Un cluster `kind` con Prometheus scrapeando targets descubiertos por anotación.
- `prometheus.yml` corregido en la actividad de debug con comentarios explicando cada causa raíz.

## Criterios de evaluación
- **Conceptual:** justifica por qué anotación > lista estática.
- **Operativa:** `/targets` muestra sólo los pods anotados; `__meta_kubernetes_*` quedan mapeados a labels útiles.
- **Arquitectónica:** describe cuándo *no* usar K8s SD manual y pasar al Operator.

## Recursos
Ver `resources/links.md`.
