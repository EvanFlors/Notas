# Actividad 02 — ADR del estándar mínimo de documentación

## 1. Identificación

- **ID:** `plat-07-02-docs-minimum-standard-adr`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-07-techdocs-docs-as-code`
- **Dificultad:** advanced
- **Duración estimada:** 40–60 min
- **Tipo:** independent (sin dependencia de la 01)

## 2. Contexto

Montar TechDocs es la parte fácil. Lo difícil es que **cada servicio** mantenga docs mínimas sin que la plataforma se convierta en policía. Esta actividad entrena el ejercicio de redactar el **ADR del equipo plataforma** que institucionaliza el estándar: *qué* se exige, *desde cuándo*, *cómo* se mide y *qué pasa* si un equipo no cumple.

No hay código. Entregable: un documento `STANDARD.md` con un ADR razonado.

## 3. Objetivos

- Enumerar al menos 5 artefactos obligatorios con su ruta canónica.
- Decidir in-situ vs centralized con justificación de escala.
- Definir política de ownership (CODEOWNERS) y de enforcement (soft fail en PR, warning en catálogo, o bloqueo).
- Articular cómo se mide la adopción sin que se vuelva *gaming* (Goodhart's Law).
- Nombrar al menos 2 antipatterns a evitar.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (secciones 8 y 10 son centrales).
- Haber recorrido los 3 `examples/`.
- Haber completado `plat-04`, `plat-05`.
- Herramientas: `bash` + editor Markdown.

**Costos:** 0.

## 5. Instrucciones

### 5.1 Preparar directorio

```bash
mkdir -p /tmp/plat-07-standard
cd /tmp/plat-07-standard
```

Puedes usar otra ruta: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `STANDARD.md` con estas secciones

```
# ADR — Documentation Minimum Standard for Services

## Status
accepted · YYYY-MM-DD · owner: team-platform

## Context
Por qué hace falta un estándar. Qué pasa hoy. Qué duele.

## Decision

### Artefactos obligatorios
Lista de ≥ 5 artefactos (una tabla preferiblemente):

| Artefacto | Ruta | Obligatorio desde | Rol |
|-----------|------|-------------------|-----|
| README/index | docs/index.md | …  | … |
| ADRs | docs/adr/NNNN-*.md | … | … |
| Runbook | docs/runbook/*.md | … | … |
| API reference | docs/api/*.md | … | … |
| Contactos | docs/contact.md | … | … |
| SLOs | docs/slo.md | … | … |

### Modo TechDocs
in-situ vs centralized. Decide uno y justifica (escala, latencia, coste, superficie).

### Ownership
Política CODEOWNERS: regla para `docs/`. Review obligatorio por equipo dueño.

### Enforcement
Qué pasa si un servicio no cumple:
- soft fail en PR (warning)
- warning en el catálogo Backstage
- bloqueo del deploy (solo "gold tier")

### Métricas de adopción
Qué se mide, cómo, por qué no se gamifica.

## Consequences
Positivas y negativas, honestas.

## Alternatives considered
Al menos 2 descartadas con 1 línea cada una.

## Antipatterns a evitar
Al menos 2 con 1 línea cada uno.
```

### 5.3 Entregable

```
/tmp/plat-07-standard/STANDARD.md
```

### 5.4 Validación

```bash
bash <ruta-repo>/courses/platform-engineering/07-techdocs-docs-as-code/activities/02-docs-minimum-standard-adr/tests/validate.sh /tmp/plat-07-standard
```

El validador comprueba **estructura** (secciones, tabla, keywords clave), no la calidad del razonamiento. La semántica la revisas tú con `solution/REFERENCE.md`.

## 6. Resultado esperado

- `STANDARD.md` existe con las secciones listadas.
- La tabla tiene ≥ 5 artefactos.
- El documento menciona TechDocs, `backstage.io/techdocs-ref`, CODEOWNERS, in-situ o centralized.
- Enuncia ≥ 2 antipatterns.
- Validador en verde.

## 7. Criterios de aceptación

- **Funcionalidad:** validador estructural pasa.
- **Calidad:** cada decisión está justificada en 1–3 líneas; no "porque sí".
- **Reproducibilidad:** otra persona lee el ADR y puede implementar el estándar en su propia org sin dudas razonables.
- **Mantenibilidad:** incluye fecha, status y owner (campos propios de un ADR).

## 8. Preguntas de reflexión

1. ¿Por qué conviene que el `openapi.yaml` esté commiteado y no autogenerado solo en build?
2. Si tu scorecard mide "¿tiene docs/index.md?", ¿cómo evitas que los equipos generen un stub vacío para pasar el check?
3. ¿En qué momento tiene sentido pasar de "soft fail" a "bloqueo" para un artefacto doc?
4. ¿Qué ventaja da declarar el estándar como ADR (vs una página wiki o una entrada en el `README` del repo plataforma)?
5. Un equipo pequeño (3 personas, servicio no crítico) te pide exención "temporal" del estándar. ¿Cómo respondes?

## 9. Extensiones

- Añade un segundo ADR encadenado (0002) que define los **niveles** del scorecard (bronze/silver/gold) con los artefactos obligatorios por nivel.
- Diseña la **plantilla Markdown** que un equipo copiará al adoptar el estándar (lo que llamarías `docs-starter-template`).
- Esboza el fact/check que mediría cada artefacto (adelanto de `plat-10`).

## 10. Limpieza

```bash
rm -rf /tmp/plat-07-standard
```
