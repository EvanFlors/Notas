# Actividad 01 — ADR del contrato de seguridad de la plataforma

## 1. Identificación

- **ID:** `sec-14-01-platform-security-contract-adr`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-14-platform-patterns-gates-dx-inventory-and-vuln-mgmt-lifecycle`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** architecture (ADR), independiente de la actividad 02.

## 2. Contexto

Eres platform-security eng de una organización con ~40 servicios en producción. Cada equipo tiene su `.github/workflows/` y ha ido añadiendo scanners *ad hoc*: unos corren Trivy, otros no; unos firman imágenes, otros no; nadie sabe quién corre `openssl 3.0.11`.

El liderazgo pide un **contrato explícito**: qué bloquea el merge, cuál es la política de severidad, cómo se gestionan las excepciones. El entregable esperado es un **ADR** (Architecture Decision Record) que capture la decisión y permita defenderla ante presión de velocidad vs seguridad vs costo.

**No** se levanta infraestructura. **No** se escribe código. **Sí** se redacta un documento razonado.

## 3. Objetivos

Al terminar deberías poder, sin consultar la lección:

- Clasificar al menos 5 gates como *blocking*, *warn* o *nightly*.
- Definir una política de severidad con umbrales explícitos que combine CVSS + EPSS + KEV.
- Formalizar una exception policy con approver, TTL y revisor.
- Enumerar al menos 3 compromisos de DX.
- Enumerar al menos 3 consecuencias (incluyendo las negativas).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (secciones 2, 3, 4, 8).
- Haber recorrido los 3 `examples/` del módulo.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/sec-14-contract
cd /tmp/sec-14-contract
```

Puedes usar otro directorio; pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribir `ADR-security-contract.md`

El documento debe tener **al menos** estas secciones (los títulos pueden variar, pero las palabras clave son las que el validador busca):

#### Sección 1 — Contexto

Describe la situación: fragmentación de gates, falta de inventario, exception creep.

#### Sección 2 — Decisión

Enumera la decisión principal en 1–3 párrafos: **adoptar un contrato de gates con 3 categorías, política de severidad SLO-driven y exception policy formal**.

#### Sección 3 — Gates (tabla)

Clasifica **al menos 5 gates** entre `blocking`, `warn` y `nightly`. Mínimo 1 de cada categoría. Formato libre pero debe ser una tabla Markdown.

#### Sección 4 — Política de severidad

Umbrales explícitos combinando **CVSS**, **EPSS** y **KEV**. Debe mencionar los tres acrónimos.

#### Sección 5 — Exception policy

Debe nombrar: `approver`, `TTL` (o `expires_at` o `expiración`), `revisor` (o `reviewer`), y mencionar que las excepciones viven en el repo (no en `.trivyignore` ad hoc).

#### Sección 6 — Developer experience

Al menos **3 compromisos**: por ejemplo, feedback <10 min, mensajes accionables, un solo panel SARIF, supresión self-service, Backstage security tab.

#### Sección 7 — Consecuencias

Al menos **3 consecuencias**, incluyendo al menos una **negativa** o *trade-off* explícito.

### 5.3 Validar la estructura

```bash
bash <ruta-repo>/courses/devsecops/14-platform-patterns-gates-dx-inventory-and-vuln-mgmt-lifecycle/activities/01-platform-security-contract-adr/tests/validate.sh /tmp/sec-14-contract
```

### 5.4 Autoevaluar comparando con `solution/REFERENCE.md`.

> El validador comprueba **estructura y vocabulario mínimo**, no corrección conceptual. Compara contra la referencia.

## 6. Criterios de evaluación

- La decisión está escrita en términos de **outcome** (SLO, MTTR, blast radius), no de herramientas.
- Los gates distinguen `blocking` / `warn` / `nightly` con criterios.
- La política usa CVSS + EPSS + KEV, no sólo CVSS.
- La exception policy expira (hay TTL).
- Hay al menos un *trade-off* reconocido (p.ej. "en los primeros 90 días el p95 subirá a 12 min").
