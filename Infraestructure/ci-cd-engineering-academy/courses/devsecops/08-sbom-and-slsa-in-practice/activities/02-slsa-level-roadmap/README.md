# Actividad 02 — SLSA level roadmap (gap analysis L0→L2→L3)

## 1. Identificación

- **ID:** `sec-08-02-slsa-level-roadmap`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-08-sbom-and-slsa-in-practice`
- **Dificultad:** advanced
- **Duración estimada:** 40–55 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Una organización típica no empieza en SLSA L3 — llega con un pipeline L0 o L1 (`docker build && docker push`, sin provenance, sin firma). Subir de nivel cuesta **ingeniería** y **cambio cultural**, y hacerlo sin plan es o imposible o doloroso.

Esta actividad entrena el **gap analysis**: dado un pipeline de partida, identificar qué controles concretos faltan para alcanzar L2 y luego L3. El entregable es un documento Markdown de ~2–3 páginas.

**No hay** cluster ni ejecución. Es análisis puro.

## 3. Objetivos

Al terminar deberías poder:

- Diagnosticar el nivel SLSA actual de un pipeline dado.
- Enumerar las **brechas concretas** (no genéricas) para subir a L2 y a L3.
- Priorizar las brechas por **costo/beneficio** (qué se obtiene por hora de ingeniería).
- Nombrar **las métricas** que te dirán si cumples cada nivel.

## 4. Prerrequisitos

- `sec-01`, `sec-05`, `sec-08` lección completa.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno.

## 5. El pipeline hipotético de partida

> **Escenario**: equipo de 6 personas, monorepo con dos servicios Python + un cronjob Go. Deploy en EKS vía Argo CD.

Pipeline actual:

```
dev workstation ──► docker build ──► docker push ghcr.io/acme/svc:latest
                       (en la laptop del dev que hace release)
                                                │
                                                ▼
                                        Argo CD sync
```

Hechos relevantes:

- No hay CI de release; releases "oficiales" los hace el tech lead desde su laptop con `make release`.
- No se escanea CVEs antes del push.
- La imagen se tagea `:latest` + `:v1.2.3` sin pin por digest aguas abajo.
- No hay firma ni SBOM ni provenance.
- Argo CD confía en el tag.
- Hay un `Dockerfile` versionado en Git y un `Makefile` con `release:`.

## 6. Instrucciones

### 6.1 Preparar el directorio

```bash
mkdir -p /tmp/sec-08-roadmap
cd /tmp/sec-08-roadmap
```

### 6.2 Escribe `SLSA-ROADMAP.md` con las siguientes secciones

#### Sección A — Diagnóstico actual

Responde:

1. ¿Qué nivel SLSA tiene **hoy** este pipeline? Justifica.
2. ¿Qué clases de atacante NO están defendidas?

#### Sección B — Camino a L2

Lista **al menos 4** cambios concretos que hay que hacer. Para cada uno:

- **Qué cambia** (1 línea).
- **Cómo** (comando, action, config).
- **Qué garantía gana** (en términos de amenaza eliminada).

#### Sección C — Camino de L2 a L3

Lista **al menos 3** cambios concretos adicionales. Mismo formato.

#### Sección D — Métricas de verificación

Lista **al menos 5** señales medibles que te dirán si realmente estás en L2 / L3. Ejemplos de métricas aceptables:

- % imágenes con attestation `slsaprovenance1` adjunta.
- % deploys que fallaron por `verify-attestation` (deseable: > 0 — hay enforcement real).
- % workflows con `permissions.id-token: write` (NO más de los necesarios).

#### Sección E — Las 5 afirmaciones a defender o refutar

Responde **De acuerdo / En desacuerdo / Depende** y justifica en 1–3 líneas:

1. *"Si firmamos todas las imágenes, estamos en SLSA L3."*
2. *"Un `Makefile release:` versionado ya es L1."*
3. *"Subir de L2 a L3 no requiere cambios en el consumidor (Argo CD / admission)."*
4. *"Self-hosted runners pueden mantener L3 si están aislados."*
5. *"SBOM y SLSA provenance se pueden emitir independientemente — no se requieren mutuamente."*

### 6.3 Entregable

```
/tmp/sec-08-roadmap/SLSA-ROADMAP.md
```

con las cinco secciones (A, B, C, D, E).

## 7. Resultado esperado

- `SLSA-ROADMAP.md` existe.
- Sección A diagnostica el nivel actual y menciona *provenance* o *attestation*.
- Sección B tiene al menos 4 cambios concretos.
- Sección C tiene al menos 3 cambios adicionales.
- Sección D tiene al menos 5 métricas.
- Sección E tiene las 5 afirmaciones respondidas.
- `bash tests/validate.sh /tmp/sec-08-roadmap` pasa.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-08-roadmap
```

El validador verifica **estructura**. Compara el contenido con `solution/REFERENCE.md` para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué pasar de L0 a L1 cuesta casi nada y pasar de L2 a L3 cuesta mucho más? ¿Qué cambia?
2. Si tu organización no verifica attestations en admisión, ¿tiene sentido estar en L3? ¿Qué protege realmente?
3. ¿Qué pasa con las imágenes **base** (`python:3.11-alpine`) — están ellas en L0, L2, L3? ¿Importa?
4. Si pierdes acceso a Rekor (histórico), ¿tus imágenes firmadas siguen siendo verificables? (Pista: *inclusion proofs* offline).

## 10. Extensiones

- Añade una sección **F**: estimación de **esfuerzo** (en días/persona) para cada bloque B y C.
- Añade un diagrama ASCII del pipeline **antes** y **después** de L3.
- Marca qué cambios son **reversibles** vs **punto de no retorno** (ej: migrar a GHA hosted — ¿se puede volver atrás?).

## 11. Limpieza

```bash
rm -rf /tmp/sec-08-roadmap
```
