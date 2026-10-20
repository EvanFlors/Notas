# Actividad 02 — ADR: umbrella vs charts separados en 3 escenarios

## 1. Identificación

- **ID:** `helm-06-02-split-umbrella-decision`
- **Tecnología:** `helm`
- **Módulo:** `helm-06-dependencies-and-umbrella-charts`
- **Dificultad:** intermediate
- **Duración estimada:** 50–70 min
- **Tipo:** architecture (ADR, sin runtime)

## 2. Contexto

Decidir "umbrella o no" en producción es una decisión arquitectónica cuyo coste de equivocarse se cobra meses después, cuando los equipos ya acoplaron sus pipelines al monolito que creaste. Esta actividad te obliga a defender tres decisiones por escrito, en el formato que se usa en la industria: **ADR** (Architecture Decision Record).

**No hay runtime**. No se instala nada, no se renderiza nada. Entregas un documento Markdown que un revisor senior pueda leer y, sin preguntar, entender por qué decidiste lo que decidiste.

## 3. Objetivos

- Analizar 3 escenarios con información incompleta (como en la realidad).
- Decidir *umbrella* vs *charts separados* para cada uno.
- Redactar un ADR por escenario con secciones estándar.
- Argumentar en términos de **ownership**, **lifecycle** y **blast radius**.

## 4. Prerrequisitos

- Haber hecho la actividad `01-umbrella-for-dev-stack`.
- Haber leído entera `theory/lesson.md` (secciones 9 y 10 son centrales).
- **Costos**: ninguno.

## 5. Instrucciones

### 5.1 Escenarios

Cada ADR trata uno de los tres escenarios siguientes.

#### Escenario A — Suite SaaS self-hosted

Vendes una suite SaaS que algunos clientes grandes despliegan on-prem. La suite tiene: tu aplicación web, un worker, una API, Postgres, Redis y un ingress controller. El cliente la instala con un solo comando y la actualiza una vez al trimestre con una ventana planificada. Tu equipo entrega una nota de release por versión; el cliente no modifica piezas internas.

#### Escenario B — Monorepo de microservicios en una plataforma interna

Tu empresa tiene 40 microservicios en un cluster compartido. Hay un equipo de plataforma que opera ingress-nginx, cert-manager, Prometheus y la base de datos central (Postgres gestionado en RDS). Los equipos de producto despliegan sus propios servicios con cadencia diaria usando Argo CD. Los upgrades de la plataforma los coordina SRE con ventanas separadas.

#### Escenario C — Preview environments en CI

Cada PR levanta un *preview environment* efímero en un cluster compartido: app + Postgres + Redis + MinIO. Vive 24 h y se destruye. Nadie lo opera manualmente: lo crea un workflow de GitHub Actions. El coste de que un `helm upgrade` dañe el entorno es cero (se destruye y se recrea).

### 5.2 Formato ADR

Para **cada** escenario, crea un fichero `adr-<A|B|C>-<slug>.md` en `/tmp/helm06-act02/` con **estas secciones** (los títulos exactos importan, el validador los busca):

```markdown
# ADR <A|B|C> — <título corto>

## Status
Proposed | Accepted | …

## Context
Descripción del escenario y las fuerzas en juego.

## Decision
Umbrella chart | Charts separados. Y por qué.

## Consequences
Positivas, negativas, riesgos aceptados.

## Alternatives considered
Al menos una alternativa descartada y por qué.
```

### 5.3 Reglas de calidad

- Cada ADR entre **200 y 600 palabras** (concisión argumentada, no padding).
- La sección `Decision` debe nombrar explícitamente **umbrella** o **separados**.
- La sección `Consequences` debe mencionar al menos dos de: ownership, lifecycle, blast radius.
- La sección `Alternatives considered` debe listar al menos una alternativa real (no "hacer nada").

### 5.4 Entregar

```bash
mkdir -p /tmp/helm06-act02
# escribe adr-A-*.md, adr-B-*.md, adr-C-*.md allí
bash <ruta-a-la-actividad>/tests/validate.sh /tmp/helm06-act02
```

El validador comprueba estructura (existencia, secciones, palabras clave, longitud). **No** evalúa el contenido semántico: eso es responsabilidad del revisor humano.

## 6. Resultado esperado

- Tres ficheros `adr-A-*.md`, `adr-B-*.md`, `adr-C-*.md` en `/tmp/helm06-act02/`.
- Cada uno con las 5 secciones requeridas.
- Cada uno con una decisión explícita y argumentos operacionales.

## 7. Criterios de aceptación

- **Estructura**: 3 ADRs, cada uno con las 5 secciones.
- **Decisión explícita**: el revisor puede leer solo `Decision` y saber qué se eligió.
- **Argumentación**: `Consequences` y `Context` usan vocabulario de ownership / lifecycle / blast radius.
- **Alternativas**: al menos una alternativa descartada por ADR.
- **Longitud**: 200–600 palabras por ADR.

## 8. Validación

```bash
bash tests/validate.sh /tmp/helm06-act02
```

Checks automatizados (ver `tests/validate.sh`):

1. Existen `adr-A-*.md`, `adr-B-*.md`, `adr-C-*.md`.
2. Cada ADR tiene las 5 secciones.
3. Cada ADR nombra "umbrella" o "separados" en `Decision`.
4. Cada ADR menciona al menos dos de: `ownership`, `lifecycle`, `blast radius`.
5. Longitud en rango [200, 600] palabras.

Revisión semántica (manual): lee los tres ADRs y verifica que la decisión es coherente con el escenario. Una decisión "ambas valen según…" sin postura clara no cumple el criterio.

## 9. Preguntas de reflexión

1. En el Escenario B, un ingeniero propone un **umbrella** que agrupe ingress-nginx + cert-manager + Prometheus + todas las apps. ¿Qué le respondes y con qué argumentos?
2. En el Escenario A, si el cliente quiere actualizar **solo** la app sin tocar Postgres, ¿qué le ofrece tu diseño?
3. En el Escenario C, ¿tiene sentido invertir en `Chart.lock` + versiones pinneadas? ¿Por qué sí o por qué no?
4. ¿Qué información te faltaría en cada escenario para tomar una decisión más robusta?

## 10. Extensiones

- Añade un cuarto ADR para un escenario inventado por ti (p. ej. "nuestra app + un operador de Kafka").
- Convierte los ADRs en un pequeño sitio con MkDocs y revísalos con un compañero.

## 11. Limpieza

```bash
rm -rf /tmp/helm06-act02
```
