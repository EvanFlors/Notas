# Example 02 — "Primer golden path": canvas plantilla

> Ejemplo de **lectura y análisis**. Plantilla que se usa en la actividad `01-define-first-golden-path`.

Un *canvas* es un documento corto (1–2 páginas) que captura lo esencial de un golden path candidato. Lo usa el platform team para decidir si vale la pena construirlo.

## Secciones mínimas

```
# Golden Path Canvas — <nombre>

## 1. Caso de uso
Qué tarea cubre el path, en una frase. Verbo + sustantivo + contexto.
Ejemplo: "Crear un microservicio Python stateless con endpoints HTTP para el dominio de pagos."

## 2. Usuarios objetivo
Quiénes lo usan. Rol, equipo, volumen estimado por trimestre.

## 3. Alcance
Qué incluye el path, lista:
  - Scaffolding de repo
  - CI (lint + test + build + image + sign + push)
  - Chart Helm (o manifest Kustomize)
  - Deploy GitOps (Argo CD / Flux)
  - Observabilidad (logs estructurados + métricas Prometheus + OTel traces)
  - Documentación TechDocs base
  - Registro en catálogo
Qué NO incluye (fuera de scope explícito).

## 4. Criterios de elección (los 4 del lesson)
  - Volumen: ...
  - Variabilidad baja: ...
  - Dolor compartido: ...
  - Impacto medible: ...
  - Bajo riesgo de regresión: ...

## 5. Métricas de éxito
Qué medir, antes y después:
  - time-to-first-commit (objetivo: < 10 min)
  - time-to-production (objetivo: < 1 día)
  - tasa de errores de scaffolding (< 5 %)
  - adopción (% servicios nuevos vía path, objetivo trimestral)
  - platform NPS específico de este path

## 6. Long tail
Qué casos NO entran y qué se les ofrece:
  - "Microservicio Go": opción B soportada (otro path).
  - "Librería interna": fuera de scope (otro path).
  - "Servicio C++ legacy": no soportado, buen vecino.

## 7. Owner y ciclo de vida
  - Owner (persona + equipo).
  - Versionado (SemVer).
  - Política de deprecations.
  - Changelog público (dónde).

## 8. Riesgos y antipatterns a evitar
Listar al menos 3 (ver §10 del lesson).
```

## Qué hace a un canvas "defendible"

- **Específico**: "microservicio Python stateless", no "microservicios en general".
- **Falsable**: criterios y métricas con números objetivo. "Rápido" no es métrica.
- **Honesto con el long tail**: nombra los casos excluidos. No decir "cubre todo".
- **Con dueño identificado**: una persona (no un equipo abstracto).
- **Con una métrica que puede empeorar**: si todas tus métricas solo pueden mejorar, estás eligiendo métricas gamificables.

## Qué lo hace indefendible (señales de alarma)

- "Golden path **universal**" que cubre backend, frontend, data y ML.
- Volumen esperado "ninguno" o "no sabemos todavía".
- Métricas puramente de output (líneas de código generadas, repos creados).
- Owner = "el equipo de plataforma" (sin persona concreta).
- Sin cláusula de deprecation.
