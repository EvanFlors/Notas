# tf-14-02 — ADR del contrato de plataforma IaC

## 1. Identificación

- **ID:** `tf-14-02-platform-contract-adr`
- **Tecnología:** terraform
- **Módulo:** `14-platform-patterns-drift-and-refactoring-at-scale`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** architecture

## 2. Contexto

Eres la nueva *Staff Platform Engineer* en **Acme Payments**, una fintech de 180 ingenieros con ~60 microservicios en AWS, usando Terraform en todos lados pero sin estándares. Hay:

- 3 copias distintas de "módulo VPC" entre equipos.
- Drift detectado en ~20 stacks que nadie reconcilia.
- Un incidente reciente: alguien bumpeó el provider AWS a mano en prod y rompió otros 4 stacks.
- Developers quejándose de que "crear un microservicio toma 3 semanas de ticket".

El VP de Platform te pide un **ADR del contrato de plataforma IaC**: un documento corto (3–6 páginas) que fije las decisiones clave y las defienda frente a trade-offs reales (autonomía dev vs control de seguridad, velocidad vs auditabilidad).

Este no es un documento aspiracional; es un contrato que tendrás que defender ante Security, Finance y los Tech Leads de producto en una revisión próxima.

## 3. Objetivos

- Producir un ADR estructurado (`adr.md`) con las secciones exigidas.
- Fijar al menos **5 decisiones concretas** (una por área: registry, SemVer, golden paths, drift, gobernanza).
- Para cada decisión, listar **trade-offs explícitos** entre autonomía dev y control.
- Definir **SLOs/métricas** medibles del éxito de la plataforma.
- Defender el contrato en 10 min (preguntas al final).

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` completo.
- Haber reproducido los 3 ejemplos del módulo.
- Nociones básicas de ADR (Architecture Decision Record): ver sección "Formato".
- **Costos**: ninguno (ejercicio de escritura).

## 5. Instrucciones

### 5.1 Punto de partida

```bash
bash starter/bootstrap.sh
cd /tmp/tf14-act02
ls
# adr-template.md  context.md
```

- `context.md` describe la situación de Acme Payments (expandida).
- `adr-template.md` es el esqueleto que vas a rellenar en un archivo `adr.md`.

Copia el template y edita:

```bash
cp adr-template.md adr.md
$EDITOR adr.md
```

### 5.2 Formato del ADR

El ADR debe contener, en este orden exacto, los siguientes encabezados Markdown (nivel `##`). El validador los busca literalmente:

1. `## Status`
2. `## Context`
3. `## Decisions`
4. `## Trade-offs`
5. `## SLOs and metrics`
6. `## Consequences`
7. `## Alternatives considered`

Dentro de `## Decisions` incluye **al menos 5 subdecisiones** (encabezados `### Decision N:` con N=1..5). Sugeridas:

1. Dónde vive el registry (Git tags self-hosted / HCP / Artifactory) y por qué.
2. Política de SemVer y qué cuenta como breaking.
3. Qué expone el módulo "golden" microservicio-EKS: variables obligatorias vs opcionales vs internas.
4. Respuesta operativa al drift: reconcile / adopt / revert, con criterios por tipo de recurso.
5. Gobernanza del `apply` en prod: quién aprueba, por cuánto tiempo, cómo se audita.

Dentro de `## SLOs and metrics` incluye al menos **3 métricas numéricas** (ej: `p95 time-to-prod para un nuevo microservicio: < 2 días`, `% stacks sin drift abierto: > 95%`, `MTTR de drift crítico: < 24 h`).

### 5.3 Defensa del contrato

Al final del ADR agrega una sección `## Defense Q&A` con **3 preguntas** anticipadas que te hará el revisor adversarial, cada una respondida en 2–4 líneas. Ejemplos:

- "¿Por qué los equipos no pueden usar el provider AWS directamente?"
- "¿Qué pasa si Security exige un control que el módulo golden no soporta todavía?"
- "¿Por qué el ADR no obliga a HCP Terraform?"

### 5.4 Validar

```bash
bash /ruta/al/repo/courses/terraform/14-platform-patterns-drift-and-refactoring-at-scale/activities/02-platform-contract-adr/tests/validate.sh
# o:
bash tests/validate.sh /tmp/tf14-act02/adr.md
```

El validador comprueba **estructura, no contenido**: existencia de todas las secciones, número mínimo de decisiones, presencia de métricas numéricas, longitud mínima.

## 6. Resultado esperado

- `/tmp/tf14-act02/adr.md` existe.
- Contiene las 7 secciones requeridas en el orden exacto.
- Contiene ≥ 5 subdecisiones.
- Contiene ≥ 3 métricas con número y unidad.
- Contiene una sección `## Defense Q&A` con ≥ 3 preguntas.
- Longitud total ≥ 50 líneas no-vacías (señal mínima de densidad, no un stub).

## 7. Criterios de aceptación

| Criterio | Cómo se mide |
|----------|--------------|
| Estructura | `tests/validate.sh` (automatizado) |
| Densidad | ≥ 50 líneas con contenido |
| Trade-offs explícitos | Sección `## Trade-offs` lista al menos autonomía vs control, velocidad vs auditabilidad |
| Defendibilidad | 3 Q&A anticipadas, respondidas |

## 8. Validación

Automatizada vía `tests/validate.sh`. Opcional: revisión por un peer que juegue el rol de "adversarial reviewer".

## 9. Preguntas de reflexión

1. ¿Qué decisión del ADR tendrías más miedo de defender ante el equipo de Security? ¿Y ante los Tech Leads de producto?
2. Si fueras más estricto (p. ej. "todo stack prod debe pasar por el módulo golden"), ¿qué equipos lo evitarían y cómo? ¿Qué señales buscarías?
3. ¿Qué métrica del ADR cambiarías primero si la plataforma fallara en adopción?

## 10. Extensiones

1. Añade una sección `## Migration plan` con el plan a 90 días para llevar los 60 microservicios existentes al golden path.
2. Diseña un **dashboard** (describe las 5 métricas y de dónde salen) para monitorizar la salud del contrato.
3. Escribe un segundo ADR complementario: "Política de upgrade de major del provider AWS en 60 stacks".

## 11. Limpieza

```bash
rm -rf /tmp/tf14-act02
```
