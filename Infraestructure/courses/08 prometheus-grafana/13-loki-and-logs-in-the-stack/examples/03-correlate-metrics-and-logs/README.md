# Ejemplo 03 — Correlacionar métricas y logs en Grafana

Muestra cómo un panel de **Prometheus** (p99 de latencia) salta a **Loki** (líneas de ERROR del mismo pod y ventana) con un **data link**.

## La idea

Grafana permite definir un *data link* por panel: cuando el usuario hace click en un punto de la serie, abre una URL con variables sustituidas. Si la URL es un deeplink a **Explore** apuntando a Loki, consigues el "ver los logs de esto" en un click.

## Archivos

- `dashboard.json` — dashboard con un panel de Prometheus (`http_requests_total`) y un data link que abre Explore de Loki con:
  ```
  {app="$app", instance="$instance"} |= "ERROR"
  ```
  en la ventana temporal del click.
- `grafana-provisioning/` — provisioning YAML que carga el dashboard y los data sources.

## Convención de labels

Para que el data link funcione, Prometheus y Loki **deben compartir** los labels `app` e `instance`. Esto es cuestión de:

- Scrape config de Prometheus con los mismos relabel que Alloy aplica en los logs.
- O (recomendado) tomar ambos labels de la misma fuente de verdad (annotations del pod, labels del contenedor Docker, atributos de recurso OTel).

## Correrlo

Este ejemplo asume que ya tienes Prometheus **y** Loki en Grafana (p. ej. combinando el stack de `obs-02` con el ejemplo 01 de este módulo). Importa `dashboard.json` manualmente o via provisioning y verifica el data link.
