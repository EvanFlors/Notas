# Ejemplo 02 — CVSS vs EPSS vs KEV, tres hallazgos

> Lectura y análisis. Objetivo: entrenar la **intuición de triage**: por qué CVSS alto no siempre gana y por qué EPSS/KEV cambian la foto.

## 1. Las tres medidas (recap)

| Medida | Qué mide                                 | Rango     | Fuente       |
|--------|------------------------------------------|-----------|--------------|
| CVSS   | severidad teórica (vector + impacto)     | 0.0–10.0  | FIRST / NVD  |
| EPSS   | probabilidad de explotación en 30 días   | 0.0–1.0   | FIRST (diario) |
| KEV    | sí/no: explotada en el mundo real        | boolean   | CISA         |

Scores de ejemplo abajo son **ilustrativos** (no datos vivos). El objetivo es el método, no el número.

## 2. Hallazgo A — "El CVSS alto que puede esperar"

```
CVE: CVE-2024-AAAA (ejemplo didáctico)
Librería: libparse-xml 1.2.3 (dependencia transitiva de reporting-sdk)
CVSS: 9.1 (CRITICAL)   — XXE sin autenticación
EPSS: 0.012            — baja probabilidad de explotación
KEV:  no
Exposición: la función XXE vulnerable solo se llama en una CLI interna
           de export de reportes. Nunca expuesta externamente.
```

**Lectura.** CVSS grita **CRITICAL** → el default de muchas políticas sería **fallar el build**. Pero EPSS 0.012 → casi nadie la explota; KEV = no → no hay evidencia de uso en ataques; **exposición: ninguna externa**.

**Decisión razonable.**

- No es P0 ni P1.
- Programar fix para el próximo ciclo (P3, 30–60 días).
- Si Trivy la marca y bloquea PRs no relacionados, **excepción documentada con expiración** (ver `examples/03-exception-policy-sample/`).
- Compensating control: la CLI corre solo con input de empleados del equipo de reporting.

## 3. Hallazgo B — "El CVSS medio que es P0"

```
CVE: CVE-2024-BBBB (ejemplo didáctico)
Librería: web-fx 3.4.0 (framework HTTP, en el camino caliente del gateway)
CVSS: 6.5 (MEDIUM)     — bypass de header de autenticación bajo condiciones específicas
EPSS: 0.92             — probabilidad muy alta
KEV:  SÍ               — CISA la añadió hace 10 días
Exposición: gateway público, auth basada exactamente en el header afectado.
```

**Lectura.** CVSS **MEDIUM** → política ingenua "fallar en HIGH+" la deja pasar. Pero EPSS 0.92 → activamente explotada; KEV presente → ya tiraron sistemas con ella; **exposición: nuestro API público usa justo ese header**.

**Decisión obligatoria.**

- **P0 inmediato**: parche o workaround en < 24 h.
- Si no hay versión parcheada, **compensating control urgente**: regla WAF que detecte el header malformado, o header replacement.
- Communications: notificar al Security Officer. Posiblemente anunciar como incidente.

Este es el ejemplo prototípico de por qué **CVSS solo** es insuficiente.

## 4. Hallazgo C — "El CVSS crítico fantasma"

```
CVE: CVE-2024-CCCC (ejemplo didáctico)
Librería: parse-xml-java 4.5.0 (SOLO Java)
CVSS: 10.0 (CRITICAL)  — RCE
EPSS: 0.65             — alta
KEV:  SÍ
Exposición: tu stack es Python 3.12 + FastAPI. No usan Java en producción.
            El CVE aparece porque Trivy encontró un .jar dentro de la imagen
            (dependencia transitiva de un plugin de Confluent del dev-tools).
```

**Lectura.** CVSS 10 + KEV + EPSS alto → en papel es la peor pesadilla. En la realidad: **el componente no está en el camino de ejecución** de tu servicio. El `.jar` está presente pero nunca se carga.

**Decisión.**

- Verificar que el componente de verdad **no se ejecuta** (no listed en entrypoint, no loaded in classpath).
- Si confirmado: **suppression con razón concreta** ("not loaded; dev-tools only"), expiración 90 días.
- Fix definitivo: **sacarlo de la imagen** (multi-stage, no copiarlo al runtime). Esa es la buena solución.
- Entretanto, no bloquear PRs no relacionados.

## 5. Tabla síntesis de los 3 casos

| Caso | CVSS | EPSS | KEV | Exposición  | Prioridad |
|------|------|------|-----|-------------|-----------|
| A    | 9.1  | 0.012| no  | interna     | P3 (30–60 d) |
| B    | 6.5  | 0.92 | SÍ  | externa     | **P0 (<24 h)** |
| C    | 10.0 | 0.65 | SÍ  | no-ejecutada| suppression + remove |

Mensaje: la **urgencia** no es `max(CVSS)`. Es `f(CVSS, EPSS, KEV, exposición)`.

## 6. Fórmula heurística (plantilla)

```
if cve in KEV and exposure_external:
    priority = P0   # 24–72 h
elif cvss >= 9.0 and epss > 0.5:
    priority = P1   # 7 d
elif cvss >= 7.0 or (cve in KEV):
    priority = P2   # 30 d
elif cvss >= 4.0 and epss < 0.01 and not in KEV:
    priority = P3   # 60–90 d
else:
    priority = P4   # informational
```

Variantes: añadir "está en el path caliente" (gateway, auth) para subir una prioridad; añadir "en dev-only image layer" para bajarla.

## 7. Qué llevar a la actividad

- **CVSS solo no basta.** Toda política de severidad en la actividad `02-severity-policy-draft` **debe citar** EPSS y KEV, no solo bandas CVSS.
- La **exposición del componente** modula la urgencia tanto como el score.
- "Suppressions" caben para FP y para "no ejecutable"; "exceptions" caben para riesgo real + compensating control + expiración.
