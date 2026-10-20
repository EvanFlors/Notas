# Actividad 02 — Política de severidad y excepciones

## 1. Identificación

- **ID:** `sec-03-02-severity-policy-draft`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-03-scanning-landscape-sast-dast-sca-iac-container-secret`
- **Dificultad:** beginner
- **Duración estimada:** 40–50 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Tu organización ya acordó qué scanners va a correr (la actividad 01). Ahora toca lo más importante: **qué hacer con los hallazgos**. Sin política, los scanners son generadores de ruido.

La trampa clásica es "fallar el build en Critical+High". Suena razonable y es **insuficiente**: CVSS mide severidad teórica, no urgencia real. El trípode **CVSS + EPSS + KEV** es la única forma madura de ordenar la cola.

**No hay que instalar nada**. El entregable es un documento Markdown — una **política operativa**, no un ensayo.

## 3. Objetivos

Al terminar deberías poder:

- Redactar una política que combine **CVSS, EPSS y KEV** para asignar prioridades **P0/P1/P2/P3**.
- Fijar **SLA de remediación** por prioridad (horas/días/semanas).
- Diferenciar en el documento mismo **suppression** (FP) vs **exception** (riesgo aceptado) con campos obligatorios distintos.
- Especificar el **proceso de aprobación** y **expiración** de excepciones.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (sobre todo §10, §11, §12).
- Haber recorrido los `examples/02-cvss-vs-epss-vs-kev/` y `examples/03-exception-policy-sample/`.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos:** ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/sec-03-policy
cd /tmp/sec-03-policy
```

Puedes usar otro directorio pasándoselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `SEVERITY_POLICY.md` con cuatro secciones

#### Sección A — Taxonomía de prioridades

Define cuatro prioridades **P0, P1, P2, P3** (al menos). Para cada una debe aparecer:

- Nombre y descripción breve.
- **SLA de remediación** (horas/días/semanas).
- Qué comunicación dispara (p. ej. P0 → alerta al Security Officer; P3 → backlog).

Ejemplo de forma (no copies literal):

```
### P0 — remediacion inmediata (24-72 h)
Hallazgo activo con exposicion externa y evidencia de explotacion.
Comunicacion: canal #sec-incident; Security Officer en loop.
```

#### Sección B — Matriz de asignación de prioridad

Tabla que mapea `(CVSS × EPSS × KEV × exposición) → prioridad`. **Al menos 5 filas**. Cada combinación debe ser clasificable sin ambigüedad.

Ejemplo:

```
## Matriz de prioridad

| Condición                                      | Prioridad | SLA     |
|------------------------------------------------|-----------|---------|
| CVE en KEV y exposicion externa                | P0        | 72 h    |
| CVSS >= 9.0 y EPSS > 0.5                       | P1        | 7 dias  |
| CVSS >= 7.0 o CVE en KEV (sin exposicion ext)  | P2        | 30 dias |
| CVSS >= 4.0 y EPSS < 0.01 y no KEV             | P3        | 90 dias |
| CVSS < 4.0                                     | informativo | n/a |
```

#### Sección C — Suppressions vs Exceptions

Dos subsecciones con **tabla de campos obligatorios** para cada tipo. Debe quedar claro que:

- **Suppression** = FP técnico. Campos: razón, scanner, reviewed_until (opcional pero recomendado).
- **Exception** = riesgo aceptado. Campos: justificación, compensating_control, owner, approver (**distintos**), created_at, **expires_at obligatorio**, severity, cve/finding.

Incluye **al menos un ejemplo** de cada (puede ser YAML o Markdown).

#### Sección D — Proceso y métricas

- **Proceso** (flujo): quién introduce, quién aprueba, dónde se registra, qué pasa cuando expira.
- **Métricas** mínimas (al menos 3): nº de exceptions activas por severidad, nº expiradas sin renovar, edad media.
- Regla de **re-review**: cada N días el security lead valida la lista.

### 5.3 Entregable

Un archivo:

```
/tmp/sec-03-policy/SEVERITY_POLICY.md
```

con las cuatro secciones A, B, C y D.

## 6. Resultado esperado

- `SEVERITY_POLICY.md` existe y es coherente.
- La sección A define **al menos 4 prioridades** (P0..P3) con SLA.
- La matriz (sección B) tiene **al menos 5 filas**.
- La sección C diferencia claramente suppression de exception y lista campos obligatorios.
- La sección D incluye proceso + al menos 3 métricas.
- El documento menciona **CVSS**, **EPSS** y **KEV** al menos una vez cada uno.
- `bash tests/validate.sh /tmp/sec-03-policy` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: la matriz es inequívoca (una entrada → una prioridad).
- **Reproducibilidad**: un ingeniero que lea el documento sabe clasificar un hallazgo nuevo en < 1 min.
- **Mantenibilidad**: Markdown válido; tabla legible.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-03-policy
```

El validador comprueba **estructura**, no semántica. Compara tu análisis con `solution/REFERENCE.md` después de haberlo hecho.

## 9. Preguntas de reflexión

1. ¿Por qué una política con **solo CVSS** acaba produciendo "alert fatigue"?
2. ¿Cuánto crees que debe durar como máximo una **exception** antes de forzar re-review? ¿Por qué?
3. Si un hallazgo CVSS 6.5 está en KEV y afecta un servicio interno sin internet, ¿lo clasificas P1, P2 o P3? Defiéndelo.
4. ¿Qué daño hace una exception **sin owner**? ¿Y una **sin expires_at**?
5. Si tu organización no tiene aún Security Officer formal, ¿quién debe aprobar las exceptions P0? ¿Y las P2?

## 10. Extensiones

- Añade una banda de **excepción automática** (hallazgos cuyo CVE está en una lista "known-not-reachable" del equipo, con TTL corto).
- Diseña la **métrica de "deuda de seguridad"**: suma ponderada de exceptions activas × severidad × edad.
- Define el **comportamiento del CI**: qué prioridades fallan el build, cuáles solo lo marcan como warning.

## 11. Limpieza

Como es puramente conceptual:

```bash
rm -rf /tmp/sec-03-policy
```

No hay procesos ni contenedores que detener.
