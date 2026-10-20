# Ejemplo 02 — Ejercicio guiado de cognitive load

> Lectura y análisis. Objetivo: medir la cognitive load **extraneous** de un equipo stream-aligned ficticio y mostrar qué piezas de una plataforma la bajarían.

## 1. El equipo bajo observación

**Equipo "Checkout"** de NimbusCo. Son 5 ingenieros. Misión: mantener el flujo de compra end-to-end. Lenguaje principal: Python/FastAPI. Base de datos: PostgreSQL. Infra: EKS multi-tenant operado por Delivery.

A primera vista parece un equipo bien dimensionado. Hacemos **cognitive load auditing** entrevistándolos durante 1 hora.

## 2. La pregunta clave

> *"¿Cuántas tecnologías y herramientas necesitas entender **bien** para hacer tu trabajo normal — no para un hackathon, sino para resolver un bug normal o lanzar una feature pequeña?"*

Respuestas combinadas del equipo:

```
┌──────────────────────────────────────────┬─────────────────────────┐
│ Tecnología / herramienta                 │ Clasificación           │
├──────────────────────────────────────────┼─────────────────────────┤
│ Python + FastAPI                         │ INTRINSIC               │
│ PostgreSQL + modelo de dominio           │ INTRINSIC               │
│ Regla de negocio de carrito y pago       │ INTRINSIC               │
│                                          │                         │
│ Docker + Dockerfile multistage           │ EXTRANEOUS (plat. puede)│
│ Helm chart custom del servicio           │ EXTRANEOUS              │
│ YAML de Argo CD (Application + Project)  │ EXTRANEOUS              │
│ Pipeline CI (3 archivos: build, test,    │ EXTRANEOUS              │
│   deploy; cada uno con sintaxis distinta)│                         │
│ Secrets Manager (3 formatos distintos:   │ EXTRANEOUS              │
│   SealedSecrets, ExternalSecrets, env)   │                         │
│ Configuración de observabilidad          │ EXTRANEOUS              │
│   (Prometheus + Grafana + OTel + Loki,   │                         │
│    cada uno con su YAML)                 │                         │
│ Políticas de red (NetworkPolicy)         │ EXTRANEOUS              │
│ Approval workflow para prod (3 docs      │ EXTRANEOUS              │
│   wiki, 2 roles de aprobador)            │                         │
│ Backstage catalog-info.yaml              │ EXTRANEOUS (menor)      │
│                                          │                         │
│ Patrón hexagonal interno del servicio    │ GERMANE                 │
│ Tests de contratos entre Checkout/Risk   │ GERMANE                 │
└──────────────────────────────────────────┴─────────────────────────┘
```

## 3. Diagnóstico

- **Intrinsic:** 3 ítems. No se puede bajar sin cambiar de dominio o producto. **No se toca.**
- **Extraneous:** 10 ítems. Alto. Cada ingeniero gasta ~40 % del sprint operando piezas que **no son el dominio**.
- **Germane:** 2 ítems. Sano, pero compite por tiempo con lo extraneous.

Dicho de otra forma: el equipo tiene capacidad para dominar quizá **5–6 áreas simultáneamente**. Ahora mismo mantiene **13**. **Está sobrecargado estructuralmente.**

Síntoma secundario: el *time to first commit* de un nuevo joiner en Checkout es de **12 días**. En equipos sanos del mismo tamaño en NimbusCo, es de **3 días**.

## 4. Qué debería hacer la plataforma

Lista priorizada de **productos** que Delivery Platform debería ofrecer para absorber extraneous de Checkout (y de los demás streams):

| Pieza extraneous | Capability platform (X-as-a-Service) |
|------------------|---------------------------------------|
| Docker + Dockerfile multistage | **Golden path template** con Dockerfile base + CI que construye y escanea sin tocar YAML. |
| Helm chart custom | **Helm chart compartido** parametrizado; el servicio solo declara `values.yaml` mínimo. |
| Argo CD YAML | **Autogeneración** de Application + Project desde el Backstage template. |
| Pipeline CI con 3 archivos | **Pipeline reutilizable** (workflow template) importado con 10 líneas. |
| 3 formatos de secretos | **Un solo patrón canonical** (ExternalSecrets) con doc y validación. |
| Observabilidad fragmentada | **OTel SDK por default** en el template + dashboards base auto-generados; Loki/Prom/Grafana invisibles. |
| NetworkPolicy manual | **Policies por tier** (public/private/data) aplicadas por default; el equipo solo elige el tier. |
| Approval workflow en 3 docs | **Approval flow en el IDP**, con reglas por entorno; sin wiki. |

Resultado proyectado: la lista de "tecnologías que necesitas entender bien" baja de ~13 a ~6. El sprint recupera ~30 % de capacidad. El nuevo joiner llega a su primer commit en 4–5 días en lugar de 12.

## 5. Qué NO debería hacer la plataforma

- **No** forzar collaboration con Delivery para cada nueva feature. Si una capability no está en el self-service, se **productiza** o se **documenta su ausencia**, no se "ayuda a mano".
- **No** absorber la **germane** del equipo (patrón hexagonal, tests de contrato). Esa es inversión del equipo en su propio dominio; la plataforma no la sustituye ni la impone.
- **No** reducir intrinsic. Si el dominio es complejo (pricing, risk), la respuesta no es "simplifiquemos el pricing"; es "ayudemos al equipo a enfocarse en el pricing bajando todo lo demás".

## 6. Métricas para verificar que el movimiento funcionó

A los 3–6 meses de ofrecer esos productos:

- **Encuesta repetida**: la lista de "tecnologías que necesitas entender bien" debería bajar en Checkout. Si no baja, el producto no sirve o no se adoptó.
- **Lead-time de nuevo servicio**: debería bajar de días a minutos.
- **Tickets manuales a Delivery sobre YAML/infra**: tendencia a la baja.
- **Platform NPS en Checkout**: tendencia al alza.
- **DORA: deployment frequency de Checkout**: debería subir.

Si estos 5 no mueven en 6 meses, **la plataforma está midiendo lo equivocado** o **construyendo lo equivocado**.

## 7. Preguntas de autocomprobación

1. ¿Por qué la plataforma **no** debería intentar reducir la *germane* del equipo?
2. Si el equipo Pricing tiene **intrinsic altísima** (modelo matemático complejo), ¿qué debería priorizar la plataforma — hacerles la vida más fácil con infra o invertir en herramientas de dominio?
3. Un ingeniero del equipo propone "contratar a un DevOps engineer dedicado para Checkout". ¿Por qué eso **no** resuelve el problema de cognitive load estructuralmente?
4. ¿Qué pasaría si la plataforma ofrece un **helm chart compartido** pero sigue permitiendo que los equipos escriban el suyo? ¿Es sano o es antipattern?

Las respuestas se trabajan en la actividad `01-map-your-org`.
