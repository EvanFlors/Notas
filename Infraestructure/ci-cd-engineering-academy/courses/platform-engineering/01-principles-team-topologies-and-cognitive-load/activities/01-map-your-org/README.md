# Actividad 01 — Mapear tu organización en Team Topologies

## 1. Identificación

- **ID:** `plat-01-01-map-your-org`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-01-principles-team-topologies-and-cognitive-load`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 02)

## 2. Contexto

Antes de construir un IDP, antes de elegir Backstage o Port, antes de dibujar un golden path, hay una pregunta que casi nadie contesta por escrito: **¿cómo está realmente estructurada tu organización de ingeniería y qué arquitectura produce esa estructura por Conway's Law?**

Esta actividad entrena ese músculo. Vas a mapear una organización — la tuya si quieres, o una ficticia bien definida — a Team Topologies, clasificar sus interacciones, y decidir si tiene (o necesita) un platform team con sentido.

El entregable es un análisis técnico en Markdown. **No hay** cluster, ni `kubectl`, ni código. Es puramente conceptual.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Clasificar cada equipo en uno de los **4 tipos** Team Topologies (stream-aligned, platform, enabling, complicated-subsystem) y defender el tipado.
- Clasificar cada interacción en uno de los **3 modos** (X-as-a-Service, collaboration, facilitating).
- Explicar por qué el DEFAULT entre un platform team y los stream-aligned es **X-as-a-Service**.
- Decidir, para la organización mapeada, si **tiene** o **necesita** un platform team formal, o si está en una fase donde todavía no vale la pena.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §3, §4, §5, §10).
- Haber recorrido los 3 `examples/` del módulo.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-01-map
cd /tmp/plat-01-map
```

Puedes usar otro directorio, pero entonces debes pasárselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Elige la organización

Tienes dos opciones. Elige una, no mezcles:

- **Opción A — tu organización real** (si puedes compartir estructura sin romper NDA). Más valioso para ti, menos "reutilizable" en el curso.
- **Opción B — una organización ficticia bien definida**. Puedes tomar prestado el caso **NimbusCo** del `examples/01-team-topologies-case-study/` **ampliado**: imagina que han crecido a **10 equipos** y añádele 4 equipos que te inventes (ej.: "Mobile", "Data Platform", "Security Enablement", "Billing"). O inventa otra org desde cero.

Mínimo: **5 equipos** mapeados.

### 5.3 Escribe `ORG_MAP.md` con cuatro secciones

#### Sección A — Tabla de equipos y tipos

```
## Equipos

| Equipo        | Tipo Team Topologies                         | Justificación (1–2 líneas) |
|---------------|----------------------------------------------|----------------------------|
| <nombre>      | stream-aligned | platform | enabling | complicated-subsystem | <por qué> |
| ...           | ...                                          | ...                        |
```

Al menos **5 filas**. Los 4 tipos no tienen que estar todos representados — si la organización no tiene (todavía) un enabling team o un complicated-subsystem, **dilo explícitamente**.

#### Sección B — Tabla de interacciones

```
## Interacciones

| Equipo A      | Equipo B      | Modo                                   | ¿Es el default correcto? |
|---------------|---------------|----------------------------------------|---------------------------|
| Platform      | Checkout      | X-as-a-Service | collaboration | facilitating | si / no — justifica |
| ...           | ...           | ...                                    | ...                       |
```

Al menos **4 filas**. Debe haber al menos una interacción marcada como **X-as-a-Service** (si tu organización tiene platform team).

#### Sección C — Diagrama ASCII

Dibuja (ASCII) el organigrama con flechas que indiquen el modo de interacción.

Marca:
- Los **tipos** de equipo (puedes abreviar: `[S]` stream, `[P]` platform, `[E]` enabling, `[C]` complicated-subsystem).
- El **modo** de cada interacción (`XaaS`, `collab`, `facilit`).

Ejemplo (plantilla; **no la copies literal, adáptala**):

```
   ┌─────────────┐
   │ Observ. [E] │
   └──┬───────┬──┘
      │ facilit (temporal, rotatorio)
      ▼       ▼
   ┌──────┐ ┌──────┐
   │ A [S]│ │ B [S]│
   └──┬───┘ └──┬───┘
      │ XaaS   │ XaaS
      ▼        ▼
   ┌────────────────┐
   │ Platform [P]   │
   └────────────────┘
```

#### Sección D — Decisión sobre platform team

Responde explícitamente, con 3–6 bullets:

- ¿La organización **tiene** hoy un platform team formal?
- Si lo tiene, ¿está sano (X-as-a-Service, product mindset) o es un antipattern (ticketing, ivory tower, dumping ground)?
- Si **no** lo tiene, ¿lo **necesita** ya? Criterios: nº de stream-aligned, estabilidad del producto, buy-in de leadership, existencia de un "cliente alfa".
- Si no está lista, **qué alternativa recomiendas** (equipo a tiempo parcial, IDP SaaS, 1–2 golden paths sin equipo formal).

### 5.4 Entregable

Un archivo:

```
/tmp/plat-01-map/ORG_MAP.md
```

con las cuatro secciones A, B, C y D.

## 6. Resultado esperado

- `ORG_MAP.md` existe y es coherente.
- Tabla de equipos con **al menos 5 filas** y justificación por equipo.
- Tabla de interacciones con **al menos 4 filas**.
- Diagrama ASCII con los tipos marcados y al menos un modo de interacción nombrado.
- Sección D con decisión explícita sobre el platform team.
- `bash tests/validate.sh /tmp/plat-01-map` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada tipado defendido con criterio técnico (misión del equipo, autonomía, cliente, etc.), no por el "nombre" del equipo.
- **Reproducibilidad**: alguien que lea tu documento puede dibujar el mismo organigrama.
- **Mantenibilidad**: Markdown válido, tablas legibles.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-01-map
```

El validador comprueba **estructura**, no semántica. Compara tu análisis con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Hay en tu organización algún equipo que **se llama** "platform" o "DevOps" pero que, por su interacción (tickets, collaboration continua), **es** otra cosa? ¿Qué cosa?
2. Si aplicaras un **reverse Conway maneuver** sobre la organización mapeada, ¿qué equipo tocarías primero y por qué?
3. ¿Hay algún equipo que podría ser **complicated-subsystem** pero está clasificado como stream-aligned (o viceversa)? ¿Cómo lo decidiste?
4. ¿Hay interacciones que, según el diagrama, parecen **collaboration** pero deberían estar siendo **X-as-a-Service** si la plataforma estuviera madura?
5. Si tu organización todavía no está lista para un platform team formal, ¿cuál es el **evento disparador** (nº de equipos, dolor compartido, decisión de leadership) que la haría estar lista?

## 10. Extensiones

- Añade una **sexta columna** a la tabla de equipos con *Cognitive load percibida* (baja/media/alta) basada en tu intuición.
- Dibuja un **segundo diagrama** proyectando dónde deberían estar los equipos en 12 meses (post reverse Conway).
- Para el equipo con cognitive load más alta, lista **3 capabilities concretas** que la plataforma debería ofrecer para bajarla.

## 11. Limpieza

Como es puramente conceptual:

```bash
rm -rf /tmp/plat-01-map
```

No hay procesos ni contenedores que detener.
