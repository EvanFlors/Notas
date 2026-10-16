# Actividad 02 — SLSA gap analysis del pipeline del capstone

## 1. Identificación

- **ID:** `sec-01-02-slsa-gap-analysis`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-01-principles-threat-modeling-and-supply-chain-overview`
- **Dificultad:** beginner
- **Duración estimada:** 40–55 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Tu lead de plataforma te pide: *"Dime en qué nivel SLSA está nuestro pipeline hoy, a qué nivel razonable podríamos llegar en un trimestre y qué cambios concretos requiere. Y de paso aclárame SBOM vs provenance, que la gente los mezcla."*

Suponemos el pipeline típico del capstone (si tu capstone real difiere, usa el real):

```yaml
# .github/workflows/release.yml  (estado actual)
on:
  push:
    branches: [main]
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t ghcr.io/org/capstone:latest .
      - run: docker login ghcr.io -u ${{ github.actor }} -p ${{ secrets.GHCR_TOKEN }}
      - run: docker push ghcr.io/org/capstone:latest
```

Características del estado actual:

- Tag `:latest` (mutable).
- No publica digest.
- No publica provenance.
- No publica SBOM.
- Usa `GHCR_TOKEN` (long-lived PAT).
- `actions/checkout@v4` (pinned por **tag**, no por SHA).

Esta actividad es **puramente conceptual**. No se corre pipeline. El validador verifica **estructura** del análisis.

## 3. Objetivos

Al terminar deberías poder:

- **Clasificar** el pipeline actual en L0/L1/L2/L3 con justificación.
- Elegir un **nivel objetivo** realista en 1 trimestre y argumentarlo.
- Enumerar al menos **3 gaps** concretos y accionables.
- Explicar la **diferencia SBOM / provenance** con ejemplo.
- Producir un **roadmap** ordenado por esfuerzo (quick wins primero).
- Nombrar al menos **2 incidentes reales** de supply chain y la lección de cada uno.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §7, §8, §9).
- Haber revisado el ejemplo `03-slsa-levels-walkthrough`.
- Herramientas: `bash` + editor Markdown.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/sec-01-slsa-gap
cd /tmp/sec-01-slsa-gap
```

### 5.2 Escribe `SLSA_GAP.md` con estas secciones

#### Sección 1 — Estado actual

- Clasificar el pipeline en L0/L1/L2/L3.
- Justificar en 2–4 líneas por qué.

#### Sección 2 — Nivel objetivo (en 1 trimestre)

- Nivel elegido (ej.: L2 o L3).
- Por qué ese y no otro (coste, retorno, prerequisites del equipo).

#### Sección 3 — Gaps

Tabla con al menos **3 gaps**:

```
| ID | Gap | Qué cambia | Esfuerzo (H/M/L) |
|----|-----|------------|------------------|
```

Cada gap debe nombrar un **cambio concreto** (p. ej. "añadir `actions/attest-build-provenance@v2` al workflow"), no un lema.

#### Sección 4 — SBOM vs provenance

Debe:

- Definir **SBOM** y **provenance** en 1–2 líneas cada uno.
- Dar un **ejemplo concreto** que responda SBOM y otro que responda provenance.
- Explicar por qué son **ortogonales** (uno no sustituye al otro).

#### Sección 5 — Roadmap

Lista ordenada (quick wins primero). Al menos 4 ítems. Cada ítem con esfuerzo H/M/L y un criterio de "hecho".

#### Sección 6 — Incidentes de referencia

Nombrar al menos **2 de estos 4**: **SolarWinds**, **log4shell**, **xz-utils**, **tj-actions**. Para cada uno, 1–2 líneas con la lección directamente aplicable al pipeline analizado.

### 5.3 Entregable

```
/tmp/sec-01-slsa-gap/SLSA_GAP.md
```

## 6. Resultado esperado

- `SLSA_GAP.md` existe con las 6 secciones.
- Clasificación L0/L1/L2/L3 presente y justificada.
- Tabla de gaps con al menos 3 filas (más header + separator = 5 pipe-lines mínimo).
- Diferencia SBOM / provenance explicada.
- Roadmap con esfuerzo marcado.
- Al menos 2 incidentes nombrados.
- `bash tests/validate.sh /tmp/sec-01-slsa-gap` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada gap nombra un cambio concreto en el workflow, no "mejorar seguridad".
- **Reproducibilidad**: alguien que lea el roadmap puede abrir tickets de inmediato.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-01-slsa-gap
```

Compara con `solution/REFERENCE.md` para autoevaluación conceptual.

## 9. Preguntas de reflexión

1. ¿Por qué pasar de L0 a L1 es sobre todo **disciplina de tags**, mientras que pasar a L2 es sobre todo **cambiar un flag**?
2. ¿Qué pasa si publicas SBOM pero nadie lo verifica en producción? ¿Tiene valor igualmente?
3. Si tu organización no está en GitHub, ¿qué partes de SLSA L3 **pierdes** y cómo las sustituyes?
4. ¿Por qué SolarWinds y tj-actions son el mismo tipo de ataque conceptualmente, aunque uno sea de 2020 y el otro de 2025?

## 10. Extensiones

- Añade una **séptima sección** que proponga la verificación del lado consumidor (`cosign verify-attestation`) con el identity pin exacto que esperas.
- Dibuja el workflow **futuro** (post-roadmap) junto al actual para visualizar el cambio.
- Mapea cada gap a un **control de policy** que lo haga obligatorio (ej. Kyverno/Gatekeeper policy que rechace imágenes sin attestation).

## 11. Limpieza

```bash
rm -rf /tmp/sec-01-slsa-gap
```
