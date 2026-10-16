# Actividad 02 — Canvas platform-as-product (con métricas defendibles)

## 1. Identificación

- **ID:** `plat-11-02-platform-product-canvas`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-11-metrics-dora-space-and-platform-as-product`
- **Dificultad:** advanced
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

El CTO ha pedido al platform team "una presentación de 1 página" explicando qué es la plataforma, para quién, cómo se mide y cómo se financia. El CFO ha añadido: *"y por favor, nada de celebrar número de deploys; demuéstrenme que esto no es un centro de costo invisible"*.

Esta actividad produce ese documento: un **canvas platform-as-product** en Markdown, deliberadamente corto, con **7 métricas elegidas** y defendidas contra Goodhart's Law. Es puramente conceptual — no hay código ni infraestructura.

## 3. Objetivos

Al terminar deberías poder:

- Redactar un canvas platform-as-product de 7 secciones.
- Elegir **exactamente 7 métricas** que mezclen DORA + SPACE + adoption + NPS.
- Justificar cada métrica con **(a) qué outcome mide y (b) cómo se podría gamificar** (y por qué no te importa).
- Articular un modelo de financiamiento explícito (showback / chargeback / platform fee / central) con razonamiento.
- Nombrar 3 antipatterns de medición específicos del dashboard que estás proponiendo.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §5–§9).
- Haber revisado los `../../examples/02-space-survey-template/` y `../../examples/03-platform-product-roadmap/`.
- No requiere haber hecho la actividad 01, pero ayuda.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: cero.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/plat-11-canvas
cd /tmp/plat-11-canvas
```

Si usas otro directorio, pásalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `CANVAS.md` con 7 secciones

Usa la plantilla de `starter/TEMPLATE.md` como esqueleto (cópiala y rellénala). Las 7 secciones son:

#### Sección 1 — Visión y propuesta de valor (3–5 líneas)

Una frase que responde: ¿para quién es?, ¿qué dolor resuelve?, ¿cómo se mide el éxito? Y, muy importante, **qué NO hace**.

#### Sección 2 — Usuarios y "no-usuarios"

- 2–3 personas: stream-aligned dev, SRE, tech lead.
- 1 "no-usuario" explícito: equipo que puede legítimamente **no** usar la plataforma, y por qué está bien.

#### Sección 3 — Roadmap now / next / later (3 ítems por bloque)

Mínimo 3 bullets en cada bloque. Cada ítem en NOW con criterio de aceptación medible.

#### Sección 4 — Modelo de financiamiento

Decide **showback**, **chargeback**, **platform fee** o **central**. Justifica en 3 líneas, cita el riesgo y qué mitigación aplicas.

#### Sección 5 — Las 7 métricas (tabla)

Exactamente **7 métricas**, en una tabla con columnas: *Métrica | Categoría (DORA/SPACE/Adoption/NPS) | Qué mide | Riesgo-Goodhart | Mitigación*.

Reparto sugerido (puedes variar):

- 3 DORA (DF, LTC, CFR y/o FDRT).
- 1 SPACE (una dimensión que **no** sea Activity).
- 2 Adoption (p. ej. % servicios registrados, time-to-first-deploy).
- 1 Platform NPS.

#### Sección 6 — 3 antipatterns a evitar

Enumera **al menos 3** antipatterns específicos del dashboard propuesto. Debe mencionar explícitamente **Goodhart** o *vanity metric* al menos una vez.

#### Sección 7 — Pregunta inicial del próximo trimestre

Una sola pregunta de research que el platform team quiere responder el próximo trimestre, redactada como hipótesis falsable (*"creemos que X; lo validamos mediante Y"*).

### 5.3 Entregable

```
/tmp/plat-11-canvas/CANVAS.md
```

## 6. Resultado esperado

- `CANVAS.md` existe y tiene las 7 secciones (encabezados visibles).
- Tabla de métricas con exactamente 7 filas (más header + separator = 9 líneas con `|`).
- Al menos 2 nombres de métricas DORA presentes.
- Palabra `SPACE` o alguna de sus 5 dimensiones (satisfaction/performance/activity/communication/efficiency) mencionada.
- Palabra `NPS` mencionada.
- Modelo de financiamiento mencionado (al menos uno de showback/chargeback/platform fee/central).
- Al menos 3 ítems numerados en "antipatterns".
- Mención a Goodhart o vanity metric.
- `bash tests/validate.sh /tmp/plat-11-canvas` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada métrica tiene (a) qué mide y (b) riesgo de gamificación identificado.
- **Honestidad**: la Sección 1 incluye un "qué NO hace" sincero.
- **Defendibilidad**: alguien del CFO puede leer el canvas en 10 min y entender cómo se financia y cómo se mide.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-11-canvas
```

El validador comprueba **estructura**. Para corrección conceptual, compara con `solution/REFERENCE.md`.

## 9. Preguntas de reflexión

1. ¿Por qué el "qué NO hace" es más difícil de escribir que el "qué hace"?
2. Si eliges **chargeback**, ¿qué incentivo perverso podría aparecer? ¿Cómo lo mitigas?
3. ¿Cuál es la métrica más fácil de gamificar en tu lista? ¿Vale la pena mantenerla aún así?
4. ¿Cómo cambia tu canvas si tu plataforma sirve a 3 equipos vs a 300?
5. Si la organización dejara de financiar la plataforma mañana, ¿qué métrica usarías para argumentar que es un error?

## 10. Extensiones

- Añade una octava métrica *leading* no estándar (p. ej. "número de preguntas en office hours") y defiéndela.
- Dibuja un diagrama ASCII del dashboard: 8 widgets, cuáles arriba y cuáles abajo, por qué.
- Esboza en 5 bullets cómo responderías al CFO si dice: *"la plataforma consume el 15 % del budget de ingeniería; ¿qué me devuelve?"*.

## 11. Limpieza

```bash
rm -rf /tmp/plat-11-canvas
```

No hay procesos ni contenedores que detener.
