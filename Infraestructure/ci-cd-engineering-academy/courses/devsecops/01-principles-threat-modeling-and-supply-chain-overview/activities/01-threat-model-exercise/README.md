# Actividad 01 — Threat model STRIDE de un servicio URL shortener

## 1. Identificación

- **ID:** `sec-01-01-threat-model-exercise`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-01-principles-threat-modeling-and-supply-chain-overview`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 02)

## 2. Contexto

Tu equipo acaba de recibir el encargo de montar un **URL shortener** interno (tipo bitly). El brief:

- `POST /shorten` recibe `{ "url": "https://..." }` y devuelve `{ "short": "https://sho.rt/abc123" }`.
- `GET /{code}` redirige al URL original (HTTP 302).
- Usuarios autenticados vía JWT (los no autenticados pueden crear links con rate limit más agresivo).
- Métricas por link (clicks) visibles en un dashboard web para el creador.
- Deploy: FastAPI + Postgres + Redis (rate limit) en Kubernetes detrás de un Ingress público.
- CI/CD con GitHub Actions → GHCR → ArgoCD.

Antes de escribir una línea de código productivo, tu lead te pide un **threat model de una página** con DFD, trust boundaries y tabla STRIDE priorizada.

Esta actividad es **puramente conceptual**. No hay código, ni cluster, ni API real. El validador verifica **estructura**, no semántica.

## 3. Objetivos

Al terminar deberías poder:

- Dibujar un DFD mínimo útil con los 4 símbolos (entidad externa, proceso, almacén, flujo).
- Marcar **trust boundaries** y justificar por qué son boundaries.
- Enumerar amenazas STRIDE para el servicio **cubriendo las 6 letras**.
- Priorizar cada amenaza por `likelihood × impact` (al menos H/M/L para cada eje).
- Proponer **una** mitigación concreta por amenaza (algo que un ticket pueda recoger).
- Dejar explícitas tus **assumptions** y lo que queda **fuera de scope**.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §4, §5, §10).
- Haber revisado los tres `examples/` del módulo (muy útil `01-stride-of-fastapi-service`).
- Herramientas: `bash` + editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/sec-01-threat-model
cd /tmp/sec-01-threat-model
```

Puedes usar otro directorio, pero entonces pásalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `THREAT_MODEL.md`

Debe contener (como mínimo) estas secciones y marcadores que el validador buscará:

#### Sección 1 — Scope

- Qué cubre (p. ej. `POST /shorten`, `GET /{code}`, dashboard).
- Qué queda **fuera de scope** y por qué.

#### Sección 2 — DFD (ASCII)

- Al menos: 1 entidad externa, 1 proceso, 1 almacén, 1 flujo.
- Dibújalo en un bloque de código.

#### Sección 3 — Trust boundaries

Al menos **2 trust boundaries**, cada uno con una línea de justificación. Formato libre pero debe aparecer la palabra **trust boundary** (o "límite de confianza").

#### Sección 4 — Tabla STRIDE

Una tabla Markdown con una columna por amenaza. **Al menos 6 filas** (puedes tener más), cubriendo las **6 letras** de STRIDE (S, T, R, I, D, E). Formato sugerido:

```
| ID  | Letra | Amenaza concreta | Likelihood | Impact | Mitigación |
|-----|-------|------------------|------------|--------|------------|
| T01 | S     | ...              | H/M/L      | H/M/L  | ...        |
```

Reglas:

- Cada letra S, T, R, I, D, E debe aparecer al menos **una vez** en la columna *Letra*.
- Likelihood y Impact deben ser `H`, `M` o `L` (o palabras equivalentes).
- La mitigación debe ser una **acción**, no una categoría. "Rate limit por IP y por token" sí, "mejorar seguridad" no.

#### Sección 5 — Assumptions

Lista numerada o bullet. Al menos **3** assumptions explícitas (p. ej. *"asumimos que el Ingress termina TLS"*, *"asumimos que el JWT secret está en un secret manager"*).

### 5.3 Entregable

Un único archivo:

```
/tmp/sec-01-threat-model/THREAT_MODEL.md
```

con las 5 secciones.

## 6. Resultado esperado

- `THREAT_MODEL.md` existe.
- Tiene las 5 secciones (Scope, DFD, Trust boundaries, STRIDE, Assumptions).
- Tabla STRIDE con las 6 letras cubiertas.
- Al menos 2 trust boundaries nombrados.
- Al menos 3 assumptions.
- `bash tests/validate.sh /tmp/sec-01-threat-model` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada mitigación es un ticket accionable, no un lema.
- **Reproducibilidad**: alguien que lea tu DFD puede re-dibujarlo igual.
- **Mantenibilidad**: Markdown válido; fecha visible al principio.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-01-threat-model
```

El validador comprueba **estructura**, no semántica. Compara con `solution/REFERENCE.md` para autoevaluarte conceptualmente.

## 9. Preguntas de reflexión

1. ¿Qué amenaza propia del **URL shortener** no habrías pensado si no hubieras aplicado STRIDE letra a letra? (Pista: la `R` casi siempre).
2. ¿Qué pasaría si el link redirigiera a un phishing site? ¿Es una amenaza de **tu** servicio o del cliente? ¿Dónde la clasificas?
3. Si tu lead te dice "no priorices, haz todo igual", ¿cómo argumentas que la priorización es parte del threat model, no un extra?
4. ¿Qué assumptions son más peligrosas: las explícitas o las tácitas? ¿Por qué el ejercicio insiste en hacerlas explícitas?

## 10. Extensiones

- Añade una **sexta sección** con "open questions" (cosas que no sabes resolver aquí).
- Dibuja un segundo DFD "futuro" cuando se añada un **custom domain por usuario** y marca cómo cambian los boundaries.
- Convierte 2 de tus mitigaciones de la tabla en pseudo-tickets (título + criterios de aceptación).

## 11. Limpieza

```bash
rm -rf /tmp/sec-01-threat-model
```

No hay procesos ni contenedores que detener.
