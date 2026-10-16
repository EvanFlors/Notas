# Ejemplo 01 — Caso de estudio: NimbusCo mapeada en Team Topologies

> Lectura y análisis. Sin ejecución. Objetivo: ver un **caso completo** de 6 equipos clasificados según Team Topologies, con sus interacciones justificadas.

## 1. Contexto de NimbusCo

**NimbusCo** es una empresa ficticia (scale-up de ~250 personas, ~30 ingenieros) con un marketplace B2C de productos de nicho. Dos años después de product-market-fit, decide formalizar su estructura de ingeniería. Hoy tiene estos 6 equipos:

```
┌──────────────┬───────────────────────────────────────────────────────┐
│ Equipo       │ Misión declarada                                      │
├──────────────┼───────────────────────────────────────────────────────┤
│ Checkout     │ Proceso de compra end-to-end (carrito → pago → OK)    │
│ Catalog      │ Catálogo de productos, búsqueda, SEO                  │
│ Pricing      │ Motor de precios dinámicos y promociones              │
│ Risk Engine  │ Scoring antifraude en tiempo real (motor en Rust)     │
│ Delivery     │ CI/CD, cluster K8s, IDP (Backstage), golden paths     │
│ Observ. Enab.│ Adopción de OTel + SLOs en todos los stream           │
└──────────────┴───────────────────────────────────────────────────────┘
```

## 2. Mapeo a Team Topologies

| Equipo | Tipo | Justificación |
|--------|------|---------------|
| **Checkout** | **Stream-aligned** | Entrega valor directo al cliente final sobre el flujo "comprar". Autonomía end-to-end desde idea a prod. |
| **Catalog** | **Stream-aligned** | Entrega valor directo sobre el flujo "descubrir producto". Mismo criterio. |
| **Pricing** | **Stream-aligned** | Entrega valor sobre el flujo "qué precio ve el usuario". Intrinsic alta pero sigue siendo *stream*. |
| **Risk Engine** | **Complicated-subsystem** | Motor Rust con expertise escasa (fraude en tiempo real); sirve a Checkout y Pricing vía API contratada. No es un stream (no habla con cliente final); no es platform (sirve a 2 streams muy específicos, no "al resto"). |
| **Delivery** | **Platform** | Opera CI/CD, cluster, IDP, golden paths — **reduce cognitive load extraneous** de los 3 streams. Default de interacción: X-as-a-Service. |
| **Observ. Enab.** | **Enabling** | Acompaña temporalmente a cada stream (6–8 semanas) a adoptar OTel y definir SLOs. Mandato explícito de rotación. **No** mantiene infra de observabilidad (eso lo hace Delivery). |

Observa dos trampas clásicas que NimbusCo evitó:

- **No** llamaron a Risk Engine "platform team" (aunque es técnicamente profundo). Si lo hubieran hecho, su backlog se mezclaría con tooling genérico y perdería foco en el motor.
- **No** fusionaron Delivery + Observability Enablement en "DevOps/SRE central". Esa fusión suele crear un *dumping ground*: la misma gente mantiene cluster, operadores, templates, Backstage, y además acompaña a equipos — se vuelven cuello de botella.

## 3. Interacciones: diagrama

```
                       ┌───────────────────────┐
                       │   Observ. Enabling    │  (temporal, rotatorio)
                       └───┬────────┬──────────┘
                           │ facilitating
         ┌─────────────────┼────────┼─────────────────┐
         ▼                 ▼        ▼                 ▼
   ┌──────────┐      ┌──────────┐  ┌──────────┐   ┌──────────┐
   │ Checkout │      │ Catalog  │  │ Pricing  │   │   (más   │
   │ (stream) │      │ (stream) │  │ (stream) │   │ streams) │
   └──┬────┬──┘      └────┬─────┘  └─┬─────┬──┘   └──────────┘
      │    │              │          │     │
      │    │ X-as-a-Serv. │          │     │
      │    ▼              │          │     ▼
      │  ┌─────────────────────────────────────┐
      │  │ Delivery Platform (X-as-a-Service)  │
      │  │ CI/CD · K8s · Backstage · golden    │
      │  │ paths · observability data plane    │
      │  └─────────────────────────────────────┘
      │                              │
      │  X-as-a-Service              │ X-as-a-Service
      ▼                              ▼
   ┌──────────────────────────────────┐
   │ Risk Engine (complicated-subsys) │
   │ Rust engine, scoring vía API     │
   └──────────────────────────────────┘
```

Puntos a observar en el diagrama:

- **Delivery** se consume **vía X-as-a-Service** por los 3 streams. Nadie "abre un ticket a Delivery para desplegar". Si alguien lo hace, es un bug del sistema.
- **Risk Engine** se consume **vía X-as-a-Service por Checkout y Pricing**. Catalog no la toca. El contrato es un API gRPC con SLO documentado.
- **Observability Enabling** actúa en modo **facilitating**, con mandato de salida. Después de 6 semanas con Checkout, le toca Catalog; después, Pricing. **No** mantiene el OTel Collector — eso lo hace Delivery.

## 4. Lo que falta (deliberadamente)

NimbusCo **no tiene**:

- **"DevOps engineer" por stream.** Deliberado: la plataforma absorbe esa complejidad vía golden paths y self-service.
- **Un equipo "Data Platform".** Aún no hay volumen; cuando aparezca, se evaluará si crear otro platform team o si es un complicated-subsystem (depende del uso).
- **Un equipo "Security Enabling".** Idem; por ahora, security review se absorbe como ritual compartido. Candidato futuro a enabling team.

## 5. Qué pasaría si rompemos la topología

Dos ejemplos adversariales útiles:

### 5.1 "Delivery deja de ser X-as-a-Service y requiere ticket para cada deploy"

Consecuencia inmediata: lead-time de deploy pasa de minutos a días. Los streams desarrollan **shadow IT** (sus propios scripts, su propio cluster lateral). La plataforma se vuelve irrelevante en 6 meses.

### 5.2 "Observability Enabling se queda permanentemente embebido en Checkout"

Consecuencia: Checkout nunca aprende a operar sus propios SLOs. Observability Enabling pierde capacidad para rotar a Catalog y Pricing. Se vuelve, de facto, un sub-equipo de Checkout. En 12 meses, nadie recuerda por qué era "enabling".

## 6. Preguntas de autocomprobación

1. ¿Por qué Risk Engine **no** es un platform team aunque opere un sistema complejo?
2. Si NimbusCo quisiera adoptar un **data warehouse** nuevo (Snowflake), ¿qué tipo de equipo lo operaría y por qué?
3. Si Delivery recibe demasiados tickets de "necesito un namespace nuevo", ¿cuál es la respuesta Team Topologies (no la respuesta técnica)?
4. ¿Qué le dirías al CEO si propone "crear un equipo transversal de DevOps que ayude a todos los streams"?

Las respuestas se trabajan en la actividad `01-map-your-org`.
