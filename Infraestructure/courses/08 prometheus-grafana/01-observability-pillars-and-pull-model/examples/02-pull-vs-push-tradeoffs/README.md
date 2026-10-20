# Ejemplo 02 — Pull vs push: trade-offs

> **Tipo:** lectura y análisis. No corre nada.
> **Duración:** 15–20 min.

## Objetivo

Ver, lado a lado y con diagramas, cómo cambia la arquitectura y las garantías cuando eliges **pull** (Prometheus) vs **push** (StatsD, OTLP push, InfluxDB push). El objetivo no es "cuál es mejor" en abstracto — es poder justificar cada uno para un caso concreto.

---

## 1. Topología pull

```
                 ┌──────────────────────┐
                 │  Service Discovery   │   (K8s API / Consul / EC2 / file)
                 │  "qué existe"        │
                 └──────────┬───────────┘
                            │ lista de targets
                            ▼
                 ┌──────────────────────┐
                 │     Prometheus       │
                 │     (scraper)        │
                 └───┬──────┬───────┬───┘
                     │      │       │  HTTP GET /metrics  (cada 15 s)
                     ▼      ▼       ▼
                  [app-1][app-2][app-3]
                   /metrics /metrics /metrics
                     ▲      ✗       ▲
                     │  caido        │
                     │               │
                 up=1  up=0 (lo escribe el scraper)  up=1
```

Puntos clave:

- La **dirección de la conexión** va *scraper → target*. El target solo expone HTTP.
- El inventario de targets vive en SD + relabel, **no** en el target.
- Si el target cae, el scraper lo nota en el próximo intento y **produce** `up == 0`. No depende del target "avisar".

---

## 2. Topología push

```
     [app-1]     [app-2]     [app-3]
       │ UDP/HTTP   │ UDP/HTTP  │
       │ emite        │ emite       │ emite
       ▼           ▼           ▼
     ┌──────────────────────────────┐
     │   Colector (StatsD/OTLP)     │
     │   acepta, agrega, reenvia    │
     └──────────────┬───────────────┘
                    │
                    ▼
            [backend TSDB]
```

Puntos clave:

- La **dirección de la conexión** va *target → colector*.
- El colector sabe de ti si decides enviarle (self-registration implícito).
- Si el target cae, **simplemente deja de enviar**. El colector ve silencio. Para distinguir "silencio sano" de "silencio por caída", necesitas que el target emita un *heartbeat* explícito — que también se calla si el proceso muere.

---

## 3. Comparación por dimensión

| Dimensión                     | Pull (Prometheus)                                 | Push (StatsD / OTLP push)                            |
|-------------------------------|---------------------------------------------------|------------------------------------------------------|
| Inventario de targets         | Explícito en SD + config revisable                | Implícito: "los que me enviaron"                     |
| Detección de caída            | Gratis: `up == 0`                                 | Requiere heartbeat explícito (frágil)                |
| Testabilidad                  | `curl /metrics` reproduce lo que ve el scraper    | Hay que capturar el payload en vuelo                 |
| Firewall / NAT                | Scraper debe alcanzar el target                   | Target debe alcanzar el colector                     |
| Batch jobs cortos             | Mal — usar Pushgateway                            | Natural                                              |
| Serverless efímero            | Mal — proceso vive menos que `scrape_interval`    | Natural                                              |
| IoT masivo tras NAT           | Mal — scraper no alcanza                          | Natural                                              |
| Alta cardinalidad en origen   | El scraper se ralentiza                           | El colector se satura                                |
| Granularidad temporal         | Limitada por `scrape_interval` (default 15 s)     | Potencialmente por evento (más caro)                 |
| Opacidad                      | Cero: el formato texto es inspectable             | Depende del protocolo (binario frecuente)            |
| Múltiples consumidores        | Trivial: N Prometheus al mismo target             | Requiere fan-out en el colector                      |
| Auto-registro no deseado      | Imposible por diseño                              | Un cliente mal escrito puede inundar el colector     |

---

## 4. Dos escenarios para fijar criterio

### Escenario A — microservicios en Kubernetes

Topología: 40 microservicios, 300 pods, red interna estable, deploys declarativos.

- **Pull gana con comodidad**. SD de K8s + `ServiceMonitor` del Operator eliminan el `prometheus.yml` manual. `up == 0` detecta pods caídos sin esfuerzo. Un pod puede ser scrapeado por el Prometheus "cluster" y por otro Prometheus "equipo platform" sin coordinar.
- Push sería *posible* pero añade: tener que operar un colector push, construir heartbeats, perder la relación 1:1 inventario-de-K8s ↔ inventario-de-targets.

### Escenario B — cron de reconciliación nocturno

Topología: un `CronJob` corre cada noche a las 03:00, dura ~45 s, procesa pedidos pendientes y publica "procesados: N, fallidos: M".

- **Pull falla por diseño**: el proceso vive menos que una ventana razonable y no está encendido cuando Prometheus intenta scrapear.
- Solución canónica: **Pushgateway**. El job hace `PUT` al Pushgateway al terminar; Prometheus scrapea al Pushgateway como si fuera un target más. Es la **excepción documentada**.
- Alternativa: convertir el cron en un servicio permanente que exponga la métrica como `gauge` de "último N procesado" — a veces es más limpio.

Regla práctica: **si tu proceso no está vivo cuando Prometheus intenta scrapear, pull no aplica**. En todos los demás casos, pull es el default.

---

## 5. Qué resuelve pull que push no resuelve gratis

1. **`up` como alerta de primera clase**.
2. **Service discovery → scrape** sin invertir dependencia (los targets no conocen al scraper, los services no conocen al colector).
3. **Debug sin impacto**: un segundo Prometheus apuntado al mismo target no interfiere.
4. **Rate limiting del scraper** por diseño: si el scraper es lento, los targets no se saturan — hay back-pressure natural.
5. **Testabilidad**: tu suite de tests puede llamar a `/metrics` y hacer *assertions* sobre el texto.

## 6. Qué resuelve push que pull no resuelve gratis

1. **Batch jobs cortos**.
2. **Clientes efímeros o detrás de NAT**.
3. **Eventos de muy alta frecuencia** que no quieres agregar en origen.
4. **Entornos donde el scraper no puede conectar al target por política de red**.

## 7. Conclusión

- Prometheus eligió pull **a sabiendas** de estos trade-offs.
- Pushgateway es la **válvula de escape** para los casos específicos donde pull no aplica — no es "la forma más fácil de hacer todo push".
- Elegir push por default implica reimplementar manualmente service discovery, detección de caídas, auditoría, y testabilidad.
- Para microservicios en K8s en 2026, pull es la elección default y es raro que no sea la correcta.

Siguiente paso del curso: `obs-02-install-local-stack-and-first-scrape` levanta el stack real.
