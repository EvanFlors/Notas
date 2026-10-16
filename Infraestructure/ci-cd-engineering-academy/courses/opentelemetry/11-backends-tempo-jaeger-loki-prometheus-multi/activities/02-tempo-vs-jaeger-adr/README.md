# Actividad 02 — ADR Tempo vs Jaeger

## 1. Identificación

- **ID:** `otel-11-02-tempo-vs-jaeger-adr`
- **Tecnología:** `opentelemetry`
- **Módulo:** `11-backends-tempo-jaeger-loki-prometheus-multi`
- **Dificultad:** advanced
- **Duración estimada:** 60–90 min
- **Tipo:** independent

## 2. Contexto

Vas a entrar como SRE en **"Mesa Logistics"**, una empresa de logística urbana. Datos:

- **Escala:** 30 servicios en Kubernetes, ~2 000 RPS pico, ~400 M spans/día.
- **Equipos:** 6 equipos de producto, 1 equipo de platform (3 personas).
- **Stack actual:** Prometheus + Grafana ya en producción. Loki en piloto. NO hay backend de traces aún.
- **Equipo de platform NO quiere SaaS** por política de datos (envíos, PII de clientes).
- **Objetivo:** elegir **Tempo** o **Jaeger** como backend de traces self-hosted, documentar la decisión en un **ADR** y defenderla ante los equipos de producto.
- Grafana ya es la UI canónica — nadie quiere introducir otra.

Tu entregable es un **ADR** real (no una comparativa genérica de internet). El starter trae una plantilla `ADR-0001-tempo-vs-jaeger.md` que debes **rellenar completamente** con criterio técnico. **No consultes `solution/REFERENCE-ADR.md` hasta terminar.**

## 3. Objetivos

- Escribir un ADR siguiendo el formato Michael Nygard (Status / Context / Decision / Consequences).
- Enumerar al menos **5 criterios de decisión** con peso explícito.
- Argumentar la elección referenciando los datos de Mesa Logistics (no en abstracto).
- Listar **consecuencias negativas** honestas de la decisión elegida.
- Definir un **punto de reevaluación** (cuándo revisitar el ADR y con qué métrica).

## 4. Prerrequisitos

- Lectura de la teoría de `otel-11` (secciones 3, 4, 7, 10).
- Haber hecho la actividad 01 (entender el patrón "cambio de backend por YAML") ayuda.
- **Costos:** ninguno. Es un ejercicio de escritura y razonamiento.

## 5. Instrucciones

### 5.1 Preparar el workspace

```bash
bash starter/setup.sh /tmp/otel11-lab02
cd /tmp/otel11-lab02
```

Verás:

- `ADR-0001-tempo-vs-jaeger.md` — plantilla a rellenar.
- `CRITERIA.md` — lista de dimensiones típicas (coste, UX, operabilidad, correlación…).
- `MESA-LOGISTICS-FACTS.md` — los datos de la empresa, para que no inventes.

### 5.2 Escribir el ADR

Rellena `ADR-0001-tempo-vs-jaeger.md` con, al menos:

- **Status:** `Accepted` (o `Proposed`).
- **Context:** describe el escenario de Mesa Logistics en tus propias palabras. 10–15 líneas.
- **Decision:** una sola frase inequívoca. Después, la lista de criterios con peso y evaluación de cada candidato contra cada criterio.
- **Consequences:** `positive`, `negative`, `neutral`. Como mínimo 2 de cada.
- **Review trigger:** condición objetiva (p. ej. "si spans/día > 2 B o si Platform crece > 6 personas").

### 5.3 (Opcional) Crear material de defensa

Añade un `DEFENSE.md` con las 3 preguntas más probables de los equipos de producto y tus respuestas de 3–5 líneas.

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/otel11-lab02
```

El validador NO juzga el contenido técnico — eso lo hace la revisión humana. Verifica que:

- El ADR existe y tiene las secciones mínimas (`## Status`, `## Context`, `## Decision`, `## Consequences`).
- Cada sección tiene contenido no trivial (≥ 100 caracteres).
- La decisión menciona **explícitamente** `Tempo` o `Jaeger`.
- Hay al menos **5** criterios enumerados (bullets o numerados).
- Hay un **review trigger** detectable (sección o línea con la palabra `review` / `reevaluate`).

## 6. Resultado esperado

- `ADR-0001-tempo-vs-jaeger.md` completo, defendible.
- El validador pasa 5/5 checks.
- Puedes defender la decisión frente a estas tres objeciones:
  1. "Jaeger lo usa todo el mundo, ¿por qué cambiar?"
  2. "Si al final migramos a Datadog en 1 año, ¿esto importa?"
  3. "Tempo requiere Grafana — y si Grafana se cae, ¿qué?"

## 7. Criterios de aceptación

- [ ] ADR tiene las 4 secciones mínimas con contenido real.
- [ ] Decisión referencia **explícitamente** uno de los dos candidatos.
- [ ] Al menos 5 criterios ponderados.
- [ ] Al menos 2 consecuencias negativas honestas.
- [ ] Review trigger definido en términos objetivos.
- [ ] Sin claims no respaldados ("más rápido", "mejor UX") sin referencia a la escala de Mesa.

## 8. Validación

```bash
bash tests/validate.sh /tmp/otel11-lab02
```

Reporta OK/FAIL por check. No requiere Docker ni servicios: es análisis estático del Markdown.

## 9. Preguntas de reflexión

1. Si en 6 meses el equipo decide pasar de self-hosted a Grafana Cloud, ¿cuánto de este ADR sigue siendo válido? ¿Qué se replantea?
2. ¿Cómo cambia tu decisión si Platform fuera de **1 persona**, no 3?
3. ¿Y si la empresa duplica tráfico (4 B spans/día)? ¿El ADR tiene un escape path?
4. Un ADR no es una comparativa; es una **decisión**. Si re-escribes esto como `comparativa`, ¿qué pierdes?
5. ¿Qué métrica concreta (del backend o del Collector) sería la señal de que *la decisión fue incorrecta*?

## 10. Extensiones

- **E1** — Añade un **ADR-0002** complementario: "estrategia de muestreo compatible con la elección de ADR-0001" (head vs tail, consistent).
- **E2** — Simula la defensa: pídele a un compañero que te desafíe con las 3 objeciones de la sección 6 y graba (texto) tus respuestas en `DEFENSE.md`.
- **E3** — Diseña el *rollback plan*: cómo volverías atrás si en 90 días la métrica de `review trigger` demuestra que elegiste mal.

## 11. Limpieza

```bash
rm -rf /tmp/otel11-lab02
```
