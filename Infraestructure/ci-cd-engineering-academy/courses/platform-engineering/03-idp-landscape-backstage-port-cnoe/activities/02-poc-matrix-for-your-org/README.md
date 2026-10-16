# Actividad 02 — Matriz de evaluación PoC para tu organización

## 1. Identificación

- **ID:** `plat-03-02-poc-matrix-for-your-org`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-03-idp-landscape-backstage-port-cnoe`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Elegir una herramienta IDP sin **evaluar antes** es ingeniería a ciegas. Pero un *Proof of Concept* mal diseñado también falla: compara herramientas por features superficiales, dura 3 meses sin conclusión, o se convierte en un favoritismo encubierto.

Esta actividad entrena el diseño de una **matriz de evaluación PoC** operable en **2–4 semanas**. El entregable es un plan ejecutable para dos finalistas (por defecto **Backstage** vs **Port**, pero puedes elegir otros).

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Definir **al menos 8 criterios de evaluación** agrupados en dimensiones (DX, extensibilidad, costo, operabilidad, lock-in).
- Asignar **pesos ponderados** justificados por el contexto organizacional (no "porque sí").
- Definir **métricas o señales medibles** por criterio (no "subjetivo").
- Diseñar **escenarios de uso concretos** que ambas herramientas deban superar (no "demo del vendor").
- Establecer un **cronograma 2–4 semanas** con responsables y entregables.
- Producir un **go/no-go framework** que decida objetivamente al cierre del PoC.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §8 y §9).
- Haber recorrido los tres `examples/` del módulo (sobre todo `03-port-vs-backstage/`).
- Haber completado `plat-01` y `plat-02`.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno. Esta actividad **diseña** el PoC; no lo ejecuta.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-03-poc
cd /tmp/plat-03-poc
```

Puedes usar otro directorio, pero entonces debes pasárselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `POC-MATRIX.md` con cinco secciones

#### Sección A — Contexto organizacional

Describe en 5–8 bullets:

- Tamaño de la organización (devs totales, equipos, servicios estimados).
- Tamaño y perfil del platform team (FTE, skills, bandwidth real).
- Stack técnico predominante.
- Compliance (self-hosted obligatorio? SaaS permitido?).
- Presupuesto disponible (capex vs opex aproximado).
- Horizonte de la decisión (12/18/24 meses).

#### Sección B — Finalistas elegidos y por qué

Nombra **2 finalistas** (p. ej. Backstage y Port) y justifica por qué quedaron fuera los otros 4 del paisaje (`Backstage`, `Port`, `OpsLevel`, `Cortex`, `Humanitec`, `CNOE`). **Al menos 4 descartes razonados.**

#### Sección C — Matriz de criterios ponderados

Define **al menos 8 criterios** con **peso** (suma = 100) y **métrica medible**. Formato:

```
| # | Criterio                        | Dimensión       | Peso | Métrica / señal medible                |
|---|---------------------------------|-----------------|------|----------------------------------------|
| 1 | Time-to-first-template          | DX              |  15  | horas desde setup hasta template útil  |
| 2 | Extensibilidad de plugins       | Extensibilidad  |  10  | ¿Permite plugin K8s custom? Si/No      |
| 3 | ...                             | ...             | ...  | ...                                    |
```

Dimensiones sugeridas: **DX**, **Extensibilidad**, **Operabilidad**, **Costo**, **Lock-in**, **Compliance**, **Adopción interna**.

Los pesos deben sumar **100** y estar justificados en el texto por el contexto organizacional (sección A).

#### Sección D — Escenarios de uso que ambas deben superar

Define **al menos 3 escenarios** concretos que ambas herramientas deben ejecutar durante el PoC. Formato:

```
### Escenario 1 — Onboarding de un servicio nuevo
- Pasos: scaffold → repo creado → CI green → aparece en catalog → docs renderizadas.
- Medimos: tiempo total, pasos manuales requeridos, UX del developer.
- Criterio de éxito: < 30 min, 0 pasos manuales fuera del portal.
```

Escenarios candidatos: onboarding, deprecación de servicio, scorecard de madurez, provisioning self-service, búsqueda cross-dominio, upgrade del portal.

#### Sección E — Plan 2–4 semanas y go/no-go

- **Cronograma** con responsables y entregables semanales (día 1, semana 1, semana 2, semana 3, semana 4).
- **Participantes**: platform team (operadores), engineering leads (observadores), 3–5 developers "piloto".
- **Decision framework**: cómo se calcula el ganador (suma ponderada), umbral de empate, qué pasa si ambos empatan (plan B explícito).
- **Riesgos del PoC**: 2–3 riesgos (p. ej. "el vendor da soporte VIP durante PoC y luego cae a soporte estándar"); cómo se controlan.

### 5.3 Entregable

Un archivo:

```
/tmp/plat-03-poc/POC-MATRIX.md
```

con las cinco secciones A, B, C, D y E.

## 6. Resultado esperado

- `POC-MATRIX.md` existe y es coherente.
- La matriz de criterios tiene **al menos 8 filas** con pesos ponderados sumando 100.
- Hay **al menos 3 escenarios** de uso con criterios de éxito medibles.
- El plan tiene **cronograma 2–4 semanas** con responsables.
- `bash tests/validate.sh /tmp/plat-03-poc` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada criterio tiene una métrica medible (no "mejor UX"); cada escenario tiene criterio de éxito objetivo.
- **Reproducibilidad**: otro equipo plataforma podría ejecutar el PoC siguiendo el plan.
- **Mantenibilidad**: Markdown válido, tabla legible.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-03-poc
```

El validador comprueba **estructura**, no semántica. Compara tu matriz con `solution/REFERENCE.md` después de haberla hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué los pesos deben sumar **exactamente 100** y por qué deben justificarse? ¿Qué pasa si se eligen "al tacto"?
2. ¿Cuál es la diferencia entre "métrica medible" y "señal subjetiva"? Da un ejemplo de cada una para el criterio "DX".
3. Si durante el PoC los developers piloto expresan preferencia emocional por una herramienta, ¿cómo lo integras sin que domine la matriz?
4. ¿Qué pasa si al final del PoC **ambas herramientas superan el umbral** por una diferencia < 5 puntos? ¿Cuál es tu tie-breaker?
5. ¿Qué riesgos tiene **no hacer PoC** y "elegir con la lección aprendida en este módulo"? ¿Cuándo ese riesgo es aceptable?

## 10. Extensiones

- Añade una **sección F — Costo total estimado del PoC** (horas de ingeniería interna + licencias trial + overhead).
- Diseña un **template de reporte final** del PoC (secciones, longitud, audiencia).
- Añade un **tercer finalista** (CNOE o Humanitec) y recalcula pesos — ¿cambia la decisión?

## 11. Limpieza

Como es puramente conceptual:

```bash
rm -rf /tmp/plat-03-poc
```

No hay procesos ni contenedores que detener.
