# Actividad 01 — ADR "Jenkins sí / no / migrar" para un escenario dado

## 1. Identificación

- **ID:** `jk-01-01-when-not-jenkins-adr`
- **Tecnología:** `jenkins`
- **Módulo:** `jk-01-why-still-jenkins-and-when-not`
- **Dificultad:** beginner (fundamentos)
- **Duración estimada:** 60–80 min
- **Tipo:** architecture (independiente — sin dependencia de la actividad 02)

## 2. Contexto

Eres la nueva **DevOps lead** de **Nordhaus Insurance**, aseguradora europea de 650 personas (90 ingenieros). Situación actual:

- **Jenkins** on-prem corriendo desde 2017. **1.400 jobs**: mezcla de freestyle (40%), Scripted Pipeline (35%) y Declarative Pipeline (25%).
- **SCM**: GitLab self-managed en el mismo datacenter.
- **Compliance**: GDPR + Solvency II. Logs de pipelines auditables 7 años. Datacenter europeo obligatorio.
- **Dolores observables**:
  - El controller cae ~1 vez al mes bajo carga de release nocturna.
  - 180 plugins instalados, 60 sin tocar en 2 años.
  - El `JENKINS_HOME` tiene backup, pero el último restore drill fue en 2022.
  - 3 CVEs críticos de plugins en los últimos 12 meses, parcheados tarde.
  - Equipo de 2 personas dedicadas a "mantener Jenkins". Rotación: la última se fue hace 3 meses.
- **Expectativa de la CTO**: "en 24 meses esto tiene que estar sano, y preferiría salir de Jenkins si es posible".
- **No negociable**: cualquier CI debe correr **on-prem**, en el datacenter europeo. SaaS externo (github.com, gitlab.com) está vetado por legal.

Tu encargo: **recomendar una decisión** (seguir con Jenkins modernizado, migrar a GitLab CI self-managed, estrategia híbrida, o retirada total), **documentarla en un ADR** que la CTO, el CFO y Security puedan leer, y **defenderla** frente a los dos extremos ("todo sigue en Jenkins porque funciona" y "fuera Jenkins ya").

**Importante**: no hay ejecución de nada. El entregable es **un documento**.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Aplicar el árbol de decisión del `examples/02-brownfield-vs-greenfield-decision/` al escenario.
- Nombrar **3 razones** por las que una empresa como Nordhaus **sigue con Jenkins** legítimamente, y **3 razones** por las que **no es la respuesta a largo plazo**.
- Comparar Jenkins con al menos **GHA, GitLab CI y Argo Workflows** en dimensiones concretas (operación, seguridad, DX, costo).
- Enumerar los pasos del **framework de migración** (inventario → clasificación → target → dual-run → OIDC → retirada) y decidir si aplica ya, en 12 meses o nunca.
- Escribir un ADR legible por un ingeniero que no estuvo en la discusión.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §4 comparación, §6 cuándo sí, §7 cuándo no, §8 framework de migración).
- Haber recorrido los dos `examples/` del módulo.
- Haber completado el curso **github-actions** (para que las comparaciones aterricen).
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno. Todo es papel.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/jk-01-adr
cd /tmp/jk-01-adr
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-JENKINS-DECISION.md`

Formato ADR estándar:

```
# ADR 001 — Decisión sobre Jenkins en Nordhaus Insurance

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(2–4 párrafos: situación actual, dolores, constraints,
expectativa de la CTO.)

## Decisión
(Qué recomiendas, concreta: mantener modernizado,
migrar a X por olas, híbrido, etc. Incluye tabla
comparativa de alternativas y framework de migración
si aplica.)

## Consecuencias
(Qué ganas, qué pierdes. Positivas y negativas.)

## Alternativas descartadas
(Al menos 2 alternativas serias con razón por la que no.)
```

Secciones obligatorias (el validador las busca):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio (el validador lo exige):

- **Diagrama ASCII** en fences de código (puede ser árbol de decisión o arquitectura target).
- Mención explícita de **Jenkins**.
- Al menos **3 alternativas** nombradas de entre: **GitHub Actions / GHA**, **GitLab CI**, **Argo Workflows**, **Tekton**, **CloudBees**.
- Nombra el **framework de migración** con al menos 3 de sus pasos: **inventario**, **clasificación**, **dual-run**, **OIDC** (federation), **retirada**.
- Mención explícita de **on-prem** o **air-gapped** (constraint central del escenario).
- Mención de **compliance** / **GDPR** / **Solvency II** / **auditoría**.
- Mención de los dos tipos de job de Jenkins: **freestyle** y **pipeline** (o `Jenkinsfile`).
- Mención de **CVE** / **vulnerab** / **plugin security** / **script approval** / **sandbox** (riesgo de superficie de ataque).
- Al menos **2 alternativas** descartadas como sub-headings o items numerados `1.` y `2.`.

### 5.3 Entregable

Un archivo:

```
/tmp/jk-01-adr/ADR-JENKINS-DECISION.md
```

con las 6 secciones y el contenido mínimo listado.

## 6. Resultado esperado

- `ADR-JENKINS-DECISION.md` existe y es coherente.
- El validador pasa en verde.
- La CTO, al leerlo, entiende **qué** recomiendas, **por qué**, y **qué pasa si no se hace nada**.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada decisión está justificada (no solo listada); las alternativas descartadas tienen razones concretas, no "no me gusta".
- **Reproducibilidad**: un ingeniero externo podría tomar este ADR y arrancar el plan sin ambigüedades.
- **Mantenibilidad**: Markdown válido, diagramas en code fences.

## 8. Validación

```bash
bash tests/validate.sh /tmp/jk-01-adr
```

El validador comprueba **estructura y presencia de términos clave**, no semántica. Compara tu ADR con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué **no** basta con "modernizar Jenkins" como respuesta única? ¿Qué ganas y qué sigues pagando?
2. Si la CTO cambia de opinión y dice "mantén Jenkins 5 años más", ¿qué parte de tu ADR seguiría válida y qué parte habría que reescribir?
3. ¿Dónde pondrías el **primer** pipeline del dual-run? ¿Un job crítico o uno de bajo riesgo? Defiéndelo.
4. ¿Qué pasa el día que el único ingeniero que entiende las Shared Libraries se va? ¿Tu plan lo mitiga?
5. Si el CFO dice "esto me cuesta demasiado, lo congelamos", ¿qué riesgos aceptas explícitamente?

## 10. Extensiones

- Añade una sección **"Fase 2"** describiendo el estado target a 36 meses.
- Dibuja un **diagrama de olas de migración** con jobs por ola y criterios de salida.
- Añade una tabla **riesgo × probabilidad × mitigación** para los top-5 riesgos del plan.

## 11. Limpieza

```bash
rm -rf /tmp/jk-01-adr
```

No hay procesos ni infraestructura que detener.
