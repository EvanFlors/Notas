# Actividad 02 — Plantilla de Production Readiness Review que cite al scorecard

## 1. Identificación

- **ID:** `plat-10-02-production-readiness-review-template`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-10-scorecards-and-service-maturity`
- **Dificultad:** advanced
- **Duración estimada:** 45–75 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

El scorecard mide, continuamente y en automático, los chequeos **que se pueden automatizar** (owner, SLO, imagen firmada, CVEs, etc.). La **PRR** es una conversación formal que ocurre antes de poner un servicio en producción y cubre lo que **no se automatiza**: dependencias externas, modos de fallo, plan de capacidad, DR, ownership on-call, rollback.

El antipatrón canónico es una PRR de 40 páginas que **duplica** lo que el scorecard ya mide. El resultado: nadie la lee, se rellena por copia-y-pega y pierde su propósito.

Esta actividad entrena diseñar la PRR como complemento, no sustituto, del scorecard.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Redactar un `PRR-TEMPLATE.md` reusable con **al menos 6 secciones cualitativas** (no automatizables).
- Incluir una sección 1 explícita que **cita el score actual** del scorecard en vez de repetir sus chequeos.
- Definir el **flujo de archivo** (dónde vive, cuándo se revisa).
- Articular en `NOTES.md` por qué PRR y scorecard **no se solapan**.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §7).
- Haber recorrido el ejemplo `examples/03-adoption-dashboard/`.
- Herramientas: `bash` + editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-10-prr
cd /tmp/plat-10-prr
```

Puedes usar otro directorio, pero entonces debes pasárselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `PRR-TEMPLATE.md`

El archivo debe ser una **plantilla**: ningún equipo lo ejecuta tal cual; se copia por servicio y se rellena. Secciones **requeridas**:

#### Sección 1 — Resumen y estado en el scorecard

- Nombre del servicio, owner, dominio, tier.
- Enlace al scorecard del servicio en Backstage / herramienta equivalente.
- Nivel actual (bronze/silver/gold) y gap al siguiente nivel.
- **Explícito**: *"esta PRR no repite los chequeos del scorecard; los cita."*

#### Sección 2 — Dependencias

- Dependencias **upstream** (de quién depende este servicio para funcionar).
- Dependencias **downstream** (quién depende de este servicio).
- Dependencias externas de terceros (SaaS, APIs vendor).
- Para cada dependencia, qué pasa si cae y durante cuánto tiempo es tolerable.

#### Sección 3 — Modos de fallo

- Los 3–5 modos de fallo más probables (no exhaustivo).
- Para cada uno, cómo se detecta (métrica, log, alerta) y cuál es el blast radius.

#### Sección 4 — Capacidad y escalado

- Carga esperada en producción (RPS, QPS, usuarios concurrentes…).
- Headroom actual y punto de dolor conocido.
- Estrategia de escalado (HPA, manual, pre-scaling eventos).

#### Sección 5 — Rollback y DR

- Cómo hacer rollback de un deploy fallido (herramienta, tiempo esperado).
- RPO/RTO objetivo si el servicio es stateful.
- Último ejercicio de DR (fecha, resultado).

#### Sección 6 — Ownership on-call

- Rotación (nombre, herramienta, SLA de respuesta).
- Documentación de escalation (quién es el siguiente nivel).
- Última vez que el on-call fue despertado por este servicio.

#### Sección 7 — Archivo y revisión

- Dónde se guarda esta PRR (ruta en el repo del servicio o enlace a Confluence/Notion).
- Cada cuánto se revisa (sugerencia: semestral o tras incidente mayor).
- Explícito: *"esta PRR no bloquea el deploy; el bloqueo técnico vive en el scorecard."*

> Puedes añadir más secciones (seguridad, compliance, costes). El mínimo son esas 7.

### 5.3 Escribe `NOTES.md`

Un archivo `NOTES.md` corto con tres secciones:

#### Sección A — Qué mide la PRR que el scorecard no puede

Lista 4–6 cosas concretas. Ejemplos: *"blast radius de que la DB caiga"*, *"opinión de la mantenedora sobre qué hace el servicio en picos de Black Friday"*.

#### Sección B — Qué mide el scorecard que la PRR no debería repetir

Lista 4–6 chequeos del scorecard que **no** aparecen literalmente en tu PRR. Ejemplo: *"has-owner"* (lo cita; no lo repite).

#### Sección C — Flujo propuesto

Un diagrama ASCII o lista enumerada que muestre: *nuevo servicio → scaffolded → scorecard calcula nivel → se escribe PRR → se archiva → se revisa cada 6 meses → se re-revisa si baja de silver*.

### 5.4 Entregable

```
/tmp/plat-10-prr/
├── PRR-TEMPLATE.md
└── NOTES.md
```

## 6. Resultado esperado

- `PRR-TEMPLATE.md` existe con **al menos 7 secciones numeradas**.
- Cita explícitamente el scorecard al menos 2 veces.
- Enumera al menos 6 áreas cualitativas no automatizables (dependencias, modos de fallo, capacidad, DR, ownership on-call, rollback).
- `NOTES.md` tiene las tres secciones (A, B, C).
- `bash tests/validate.sh /tmp/plat-10-prr` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: ninguna sección duplica un chequeo del scorecard.
- **Reproducibilidad**: cualquier equipo puede copiar la plantilla y rellenarla para su servicio sin más contexto.
- **Mantenibilidad**: Markdown válido; secciones numeradas y titulares explícitos.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-10-prr
```

El validador comprueba **estructura**, no semántica. Compara tu PRR con `solution/TEMPLATE.md` después para autoevaluarte.

## 9. Preguntas de reflexión

1. Si tu organización ya tiene una plantilla PRR de 40 páginas, ¿cómo la **recortas** sin perder lo esencial?
2. ¿Qué pasa si el scorecard dice "gold" pero el equipo nunca escribió la PRR? ¿Debería bloquear producción?
3. ¿Qué sección de la PRR vuelves a leer **primero** después de un incidente mayor?
4. ¿Por qué la PRR se **archiva** (vs se descarta) tras completarse?
5. ¿En qué se diferencia la PRR del *design doc* del servicio?

## 10. Extensiones

- Añade una sección 8 opcional de **presupuesto y FinOps**.
- Añade una sección 9 opcional de **compliance** (SOC2, GDPR) si tu capstone la requiere.
- Escribe una **versión abreviada** (1 página) para servicios tier-3 y argumenta en `NOTES.md` por qué tier-3 merece una PRR distinta.

## 11. Limpieza

```bash
rm -rf /tmp/plat-10-prr
```
