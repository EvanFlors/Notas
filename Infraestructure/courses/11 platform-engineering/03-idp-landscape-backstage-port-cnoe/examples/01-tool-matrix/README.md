# Ejemplo 01 — Matriz comparativa de herramientas IDP

> Lectura y análisis. Sin ejecución. Objetivo: tener en la cabeza una **matriz operable** para descartar rápido 4 de las 6 opciones ante un contexto dado.

## 1. Las 6 herramientas, una frase cada una

| Herramienta | Una frase |
|-------------|-----------|
| **Backstage** | Framework OSS Node/TS (CNCF, ex-Spotify) para **construir** tu propio IDP; valor principal en los plugins. |
| **Port**     | SaaS configurable para **tener un portal interno en días** sin operar servidores. |
| **OpsLevel** | SaaS **scorecards-first**, pensado para elevar madurez de servicios más que para onboarding. |
| **Cortex**   | SaaS similar a OpsLevel, catálogo + scorecards + initiatives con énfasis en engineering leadership. |
| **Humanitec**| Platform **orchestrator** basado en Score: developers describen *qué* y la plataforma materializa el *cómo*. |
| **CNOE**     | **Reference stack** CNCF (Backstage + Argo CD + Crossplane + Keycloak + Argo Workflows) pre-ensamblada. |

## 2. Matriz por ejes operativos

> Valores ilustrativos — **verificar** en Fase 4 para pricing y features actuales.

```
                   │ Backstage │   Port    │  OpsLevel │  Cortex   │ Humanitec │   CNOE    │
───────────────────┼───────────┼───────────┼───────────┼───────────┼───────────┼───────────┤
 Modelo            │ OSS       │ SaaS      │ SaaS      │ SaaS      │ SaaS      │ OSS stack │
                   │ framework │ config    │ config    │ config    │ orchestr. │ (CNCF)    │
───────────────────┼───────────┼───────────┼───────────┼───────────┼───────────┼───────────┤
 Portal/Catálogo   │ Core      │ Core      │ Secundario│ Secundario│ Mínimo    │ Backstage │
 Templates         │ Core      │ Actions   │ Básico    │ Básico    │ Score     │ Backstage │
 Scorecards        │ Plugin    │ Nativo    │ Core      │ Core      │ N/A       │ Plugin    │
                   │ (TechIns.)│           │           │           │           │ (TechIns.)│
 Self-service infra│ Via plugin│ Via actn+ │ No nativo │ No nativo │ Core      │ Crossplane│
                   │ + Scaffol │ GitOps    │           │           │ (Score)   │ via Scaff │
 Auth              │ Tú eliges │ Vendor-run│ Vendor-run│ Vendor-run│ Vendor-run│ Keycloak  │
 TechDocs          │ Core      │ Via plugin│ No nativo │ No nativo │ N/A       │ Backstage │
───────────────────┼───────────┼───────────┼───────────┼───────────┼───────────┼───────────┤
 Extensibilidad    │ Alta      │ Media     │ Baja      │ Baja      │ Media     │ Alta      │
 Time-to-value     │ 3–6 meses │ Días      │ Días      │ Días      │ 1–2 meses │ 1–3 meses │
 Equipo mínimo     │ 2–3 TS    │ 0.5 FTE   │ 0.5 FTE   │ 0.5 FTE   │ 1 FTE K8s │ 2–3 CNCF  │
                   │ dedicados │           │           │           │           │ literates │
 Costo             │ Capex ing │ Opex per- │ Opex per- │ Opex per- │ Opex per- │ Capex +   │
                   │ interna   │ dev/mes   │ dev/mes   │ dev/mes   │ dev/mes   │ infra OSS │
 Self-hosted       │ Sí        │ No (SaaS) │ No (SaaS) │ No (SaaS) │ Hybrid    │ Sí        │
 Lock-in           │ Bajo      │ Medio-Alto│ Medio-Alto│ Medio-Alto│ Medio     │ Bajo      │
```

## 3. Reglas de descarte rápido

Si una de estas aplica, elimina las columnas correspondientes **antes** de empezar a comparar features:

- **Platform team < 3 ingenieros, sin TS fuerte** → fuera **Backstage self-hosted** y **CNOE puro**. Mira Port/OpsLevel/Cortex.
- **Compliance exige self-hosted estricto** → fuera **Port/OpsLevel/Cortex**. Mira Backstage, CNOE o Humanitec (hybrid).
- **No hay presupuesto para SaaS per-dev** y hay ingenieros → mira **Backstage** o **CNOE**.
- **Necesitas valor en < 4 semanas** → fuera **Backstage** y **CNOE** si no tienes el equipo. Mira **Port**.
- **El dolor principal es "muchos entornos deriva"** y no "no hay portal" → mira **Humanitec**, no un portal.
- **El dolor principal es "no sabemos qué servicios están en mal estado"** → mira **OpsLevel/Cortex** (scorecards-first), o Backstage con TechInsights.

## 4. Cómo leer la matriz: tres ejemplos

### 4.1 Startup de 40 devs, 2 platform engineers, sin presupuesto SaaS

- Descarta Port/OpsLevel/Cortex por costo.
- Descarta Backstage self-hosted puro: 2 ingenieros no sostienen el day-2.
- **Finalistas: CNOE** (si son CNCF-literate) o **"no construyas IDP todavía"**: documenta golden paths en Markdown y espera.

### 4.2 Empresa mediana, 500 devs, 8 platform engineers, compliance SaaS ok

- Descarta CNOE si no hay cultura CNCF profunda (sumas carga, no la reduces).
- Descarta Humanitec como *portal*; podría convivir como orchestrator.
- **Finalistas: Backstage self-hosted** (si quieren inversión en diferenciación) **o Port** (si quieren ir rápido). PoC a esos dos.

### 4.3 Organización K8s-nativa, 200 devs, 4 platform engineers CNCF-fluent

- Descarta OpsLevel/Cortex: el valor principal (scorecards) lo pueden hacer en Backstage con TechInsights.
- Descarta Port si quieren invertir internamente.
- **Finalistas: CNOE** (opinionado, acelera el day-1) **o Backstage self-hosted** (más libertad).

## 5. Lo que la matriz NO te dice (y hay que preguntar)

- **La cultura del equipo**: ¿aceptan un SaaS externo? ¿quieren diferenciarse por su IDP?
- **El estado del hiring market local**: ¿consigues ingenieros TypeScript+React para Backstage? ¿O te sale más barato pagar Port?
- **La relación con el financiamiento**: ¿capex vs opex pesa igual? ¿Hay freezes de hiring?
- **La deuda técnica previa**: si ya hay un wiki + spreadsheets intentando ser catálogo, cualquier migración es carísima independientemente de la herramienta.

Estos factores se trabajan en la actividad `01-tool-choice-adr/`.

## 6. Preguntas de autocomprobación

1. ¿Cuál es la diferencia **operativa** entre "framework" (Backstage), "SaaS configurable" (Port) y "reference stack" (CNOE)? Responde en términos de **quién** mantiene qué.
2. ¿Por qué CNOE y Backstage self-hosted tienen "lock-in bajo"? ¿Qué significa en la práctica?
3. Si un lead te dice *"Backstage es gratis, elijamos Backstage"*, ¿qué 2 cifras le pides para hacer el TCO real?
4. ¿Qué pregunta responde OpsLevel que Port responde con esfuerzo extra?
5. ¿En qué contexto Humanitec **convive** con Backstage en lugar de competir con él?
