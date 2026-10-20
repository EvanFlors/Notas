# ADR A — Umbrella chart para la suite SaaS self-hosted

## Status
Accepted

## Context
Vendemos una suite que algunos clientes grandes despliegan on-prem. La suite incluye nuestra app web, un worker, una API, Postgres, Redis y un ingress controller. El cliente la instala con un comando y la actualiza trimestralmente dentro de una ventana planificada. El ownership operacional es **nuestro** (soporte + ingeniería del producto); el cliente solo opera la infraestructura base del cluster. Hay una única nota de release por versión y los componentes se validan juntos antes de publicar.

## Decision
Usamos un **umbrella chart** (`suite-platform`) que declara los subcharts de la app web, worker, API, Postgres, Redis e ingress controller con versiones pinneadas en `Chart.yaml` y `Chart.lock` commiteado. Publicamos el umbrella firmado en OCI (GHCR). El cliente lo instala y actualiza como una sola release.

## Consequences
Positivas:
- **UX de instalación trivial**: un `helm upgrade --install` cubre toda la suite; crítico para clientes on-prem que no quieren orquestar múltiples pipelines.
- **Validación conjunta**: QA prueba la combinación exacta de versiones; evita incompatibilidades sutiles entre app y DB.
- **Lifecycle alineado**: queremos *forzar* que todo se mueva junto; el acoplamiento es intencional porque somos los dueños del producto completo.

Negativas / riesgos aceptados:
- **Blast radius**: un fallo de upgrade afecta toda la release. Lo mitigamos con `--atomic` + rollback automático y pre-release en un entorno espejo del cliente.
- **Ownership monolítico**: no hay separación entre "la DB del cliente" y "la app"; para el cliente es una caja negra. Esto es *deseable* en este modelo de distribución.

## Alternatives considered
- **Charts separados** con un *script wrapper* que los instale por orden: añade complejidad al cliente, rompe la promesa "un comando", y nos obliga a mantener nosotros la orquestación fuera del gestor de paquetes.
- **Operador propio**: sería más elegante a largo plazo, pero el coste de desarrollo y mantenimiento no se justifica para una cadencia trimestral y clientes con operadores Kubernetes limitados.
