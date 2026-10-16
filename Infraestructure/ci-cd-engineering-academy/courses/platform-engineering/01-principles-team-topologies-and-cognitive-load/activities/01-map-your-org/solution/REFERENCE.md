# REFERENCE — plat-01-01-map-your-org

> Una **referencia** razonada sobre la organización NimbusCo ampliada a 10 equipos. No es la única respuesta correcta — es un modelo contra el que compararte.

Caso: **NimbusCo** 18 meses después del `examples/01-team-topologies-case-study/`. Ha crecido a 10 equipos (~60 ingenieros). Las cursivas en la primera columna marcan equipos nuevos respecto al caso base.

## Sección A — Equipos

| Equipo | Tipo Team Topologies | Justificación |
|--------|----------------------|---------------|
| Checkout | **stream-aligned** | Entrega end-to-end el flujo de compra; autonomía completa. |
| Catalog | **stream-aligned** | Entrega el flujo "descubrir producto". |
| Pricing | **stream-aligned** | Entrega el precio dinámico que ve el usuario. |
| *Billing* | **stream-aligned** | Entrega el flujo "facturar y cobrar"; nuevo stream con dominio propio. |
| *Mobile* | **stream-aligned** | Entrega la app iOS/Android que consume Checkout + Catalog; mismo criterio (otra superficie, otro flujo). |
| Risk Engine | **complicated-subsystem** | Motor Rust con expertise escasa (fraude en tiempo real); sirve 2–3 streams vía API fuertemente contratada. |
| *Data Platform* | **platform** | Opera el data warehouse (Snowflake) + pipelines (dbt) + catálogo de datos como producto. Reduce cognitive load de los streams en todo lo que sea datos analíticos. |
| Delivery Platform | **platform** | CI/CD, cluster K8s, IDP (Backstage), golden paths de servicio. Reduce cognitive load extraneous de los 5 streams. |
| Observ. Enabling | **enabling** | Acompaña temporalmente a cada stream (6–8 semanas) para adoptar OTel + SLOs. Rotación por diseño. |
| *Security Enabling* | **enabling** | Nuevo equipo creado tras un incidente; acompaña a cada stream en threat modeling + supply-chain security durante 4 semanas. Mandato explícito de salida. |

**Nota de tipado**: dos platform teams (Delivery y Data Platform) **no son** antipattern mientras tengan **product boundaries claros** — Delivery no toca el warehouse; Data Platform no toca el cluster de runtime. Cada uno es un producto separado con cliente separado.

**Nota de ausencia deliberada**: no hay "DevOps team". Esa capacidad se absorbe por Delivery Platform (vía golden paths) + Observability Enabling (vía facilitating).

## Sección B — Interacciones

| Equipo A | Equipo B | Modo | ¿Default correcto? |
|----------|----------|------|---------------------|
| Delivery Platform | Checkout, Catalog, Pricing, Billing, Mobile | **X-as-a-Service** | **Sí**. Despliegues, scaffolding, infra básica — self-service vía IDP. |
| Data Platform | Checkout, Pricing, Billing | **X-as-a-Service** | **Sí**. Los streams consumen datasets y pipelines por catálogo + templates. |
| Observ. Enabling | Checkout → Catalog → Pricing → Billing (rotación) | **Facilitating** | **Sí**. Mandato de salida tras 6 semanas. |
| Security Enabling | Todos los streams, uno a la vez | **Facilitating** | **Sí**. Igual que Observability. |
| Delivery Platform | Data Platform | **Collaboration** (acotada) | **Depende**. Tiene sentido mientras definen cómo compartir el cluster para los pipelines de dbt (6 semanas). Si continúa 6 meses, es un bug. |
| Risk Engine | Checkout, Pricing | **X-as-a-Service** | **Sí**. API gRPC con SLO documentado. |
| Checkout | Catalog | **(ninguno directo; eventos)** | **Sí**. Se comunican por eventos vía el bus — platformsied por Delivery. Si hablaran directo síncrono, sería acoplamiento mal resuelto. |

## Sección C — Diagrama

```
   ┌────────────────────┐         ┌────────────────────┐
   │ Observ. Enab. [E]  │         │ Security Enab. [E] │
   └────────┬───────────┘         └────────┬───────────┘
            │ facilit (rotatorio)          │ facilit (rotatorio)
            │                              │
      ┌─────┴──────┬──────┬──────┬─────────┴──────────┐
      ▼            ▼      ▼      ▼                    ▼
   ┌──────┐    ┌──────┐┌──────┐┌───────┐          ┌───────┐
   │Check │    │Cata- ││Pric- ││Billing│          │Mobile │
   │out[S]│    │log[S]││ing[S]││  [S]  │          │  [S]  │
   └─┬──┬─┘    └──┬───┘└──┬───┘└───┬───┘          └───┬───┘
     │  │         │       │        │                   │
     │  │ XaaS    │ XaaS  │ XaaS   │ XaaS              │ XaaS
     │  ▼         ▼       ▼        ▼                   ▼
     │ ┌───────────────────────────────────────────────┐
     │ │  Delivery Platform [P]                        │◄──┐
     │ │  CI/CD · K8s · Backstage · golden paths       │   │ collab
     │ └───────────────────────────────────────────────┘   │ (acotada,
     │                                                     │  6 sem)
     │ XaaS                      XaaS                      │
     ▼                           ▼                         │
   ┌───────────────────┐   ┌──────────────────────────┐    │
   │ Risk Engine [C]   │   │ Data Platform [P]        │────┘
   │ Rust engine, API  │   │ Snowflake + dbt + catalog│
   └───────────────────┘   └──────────────────────────┘
```

Puntos a leer en el diagrama:

- **Dos platforms** con product boundaries claros (Delivery vs Data). Ninguna invade el territorio de la otra.
- **Dos enabling** con mandato de rotación. Nunca "viven" dentro de un stream.
- **El default platform-stream es XaaS**. No hay flechas de "ticket" ni de "collab permanente" entre platform y streams.
- La **única collaboration** es Delivery × Data Platform, por un período acotado y con criterio de salida (cuando queden definidos los contratos de uso del cluster, se vuelve XaaS).
- **Checkout × Catalog** no se tocan directamente — hablan por eventos. Esto evita acoplamiento síncrono y es consistente con Conway's Law (equipos separados → comunicación asíncrona).

## Sección D — Decisión sobre platform team

NimbusCo ampliada **sí tiene** platform team formal; de hecho tiene **dos** (Delivery y Data Platform). Diagnóstico:

- **Hay buy-in de leadership** (presupuesto plurianual, roadmap pactado).
- **Hay cliente alfa claro** desde el inicio (Checkout) + 4 streams más que validan la propuesta de valor.
- **Está dentro del rango sano de dimensión** (~60 ingenieros, 5 streams-aligned): dos platforms es defendible cuando los dominios son muy distintos (runtime vs analítica).
- **El modo default es X-as-a-Service**, no ticketing. (Chequear trimestralmente que no derive).
- **Hay métricas de producto** (adopción voluntaria, platform NPS, lead-time de nuevo microservicio).

**Riesgos a vigilar** (6 meses):

1. Que la collaboration Delivery × Data Platform no se vuelva permanente — es un olor a "no supimos definir el contrato".
2. Que los enabling teams no se vuelvan sub-equipos permanentes de un stream (eterno engagement).
3. Que las dos platforms no empiecen a invadirse (quién opera el cluster para pipelines dbt, por ejemplo) — es la discusión frecuente que **sí** requiere collaboration acotada.

**Si NimbusCo tuviera solo 15 ingenieros y 2 servicios**, la recomendación sería **la opuesta**: no crear platform team formal todavía, adoptar un IDP SaaS (Port o Humanitec), dedicar 20 % del tiempo de un stream-aligned a mantener 1–2 golden paths, y revisar en 6 meses.

## Punto a repetir hasta que suene aburrido

> **Platform team = X-as-a-Service por default. Enabling team = facilitating con rotación. Stream = flujo de valor end-to-end. Complicated-subsystem = expertise escasa tras un API.** Todo lo demás es antipattern o residuo histórico.
