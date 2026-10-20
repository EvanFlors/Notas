# Actividad 02 — ADR: GitLab vs GitHub Actions (primera pasada)

## 1. Identificación

- **ID:** `gl-01-02-adr-gitlab-vs-github-first-pass`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-01-model-and-mapping-to-gha`
- **Dificultad:** beginner
- **Duración estimada:** 65–85 min
- **Tipo:** architecture (independent — sin dependencia de la actividad 01)

## 2. Contexto

Una startup "acme" de **20 personas** (10 ingenieros, 3 data, 2 security, 5 negocio) tiene **todos sus repos en GitHub.com** desde hace 2 años, con 15 repos activos y GHA como CI/CD. Están viendo tracción y planean:

- **Compliance**: SOC 2 Type I en 6 meses, PCI-light en el workload de pagos (`checkout`) en 9 meses.
- **Residencia de datos**: todo en Europa (`eu-*`).
- **Equipos**: 2 áreas claras (`platform`, `checkout`) y una tercera (`analytics`) menos crítica.
- **Secreto**: hoy mezclan `secrets.*` por repo sin convención; ya tuvieron un susto con un token filtrado en logs.
- **Costo**: budget razonable, pero no infinito. Alguien debe hacer el *platform engineering*.

El CTO pregunta:

> "¿Nos quedamos en GitHub Actions, migramos a GitLab, o convivimos un año?"

**Tu encargo**: escribir un **ADR** `ADR-GITLAB-VS-GITHUB.md` que responda esa pregunta con criterio y defienda la decisión por escrito. **No hay cuenta GitLab paga ni proyecto real**. El entregable es un documento.

> **Importante**: no hay una "respuesta correcta" universal. El ADR se juzga por **calidad de razonamiento, cobertura de trade-offs y alternativas descartadas**, no por elegir "GitLab" o "GHA".

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Enumerar los 5–7 ejes de decisión que importan en esta elección (compliance, ecosistema, Self-Managed, jerarquía, costo, migración, SSO).
- Comparar **planes equivalentes** (`GitHub Team + GHAS + GHE` vs `GitLab Ultimate`), no "Free vs Free".
- Defender la decisión en lenguaje de arquitectura (contexto → decisión → consecuencias).
- Nombrar al menos **2 alternativas descartadas** con el motivo concreto.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §4 planes/gating, §10 trade-offs, §11 checklist).
- Haber recorrido los tres `examples/` (sobre todo `02-plan-gating-matrix`).
- Haber completado el primer módulo de **github-actions**.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno. Todo es papel.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gl-01-02
cd /tmp/gl-01-02
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-GITLAB-VS-GITHUB.md`

Formato que debes seguir:

```
# ADR 001 — Plataforma CI/CD: GitLab vs GitHub Actions (primera pasada)

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(2–4 párrafos: org, workloads, compliance, residencia de datos, estado actual.)

## Decisión
(Qué plataforma eliges, en qué plan equivalente, con qué horizonte temporal.
Idealmente con una tabla comparativa de los ejes decisivos.)

## Consecuencias
(Qué ganas, qué pierdes, qué se vuelve más fácil, qué más caro.
Debe cubrir positivas y negativas.)

## Alternativas descartadas
(Al menos 2 alternativas consideradas y por qué no.)
```

Secciones obligatorias (el validador las busca):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio (el validador lo exige):

- Mención explícita de **GitHub Actions** (o `GHA`) y **GitLab**.
- Mención explícita del **plan equivalente real** que comparas: al menos uno de `Ultimate`, `GHAS`, `Premium`, `Team`, `Enterprise`.
- Mención de al menos **3** ejes de decisión del siguiente conjunto: `compliance`, `SOC 2`, `PCI`, `OIDC`, `Self-Managed`, `Subgroup`, `Group`, `Marketplace`, `Catalog`, `migración`, `migration`, `SSO`, `SCIM`, `compliance pipeline`, `required workflow`, `Review Apps`, `environment`.
- **Al menos 2 alternativas descartadas** como subsecciones o listado numerado.
- Mención de **Europa** / `eu-west` / `eu-central` (residencia).
- Al menos **una tabla Markdown** comparando opciones.
- Decisión explícita: `elegimos` / `elegir` / `decisión` / `decision` + plataforma.

### 5.3 Entregable

Un archivo:

```
/tmp/gl-01-02/ADR-GITLAB-VS-GITHUB.md
```

con las 6 secciones y el contenido mínimo listado.

## 6. Resultado esperado

- `ADR-GITLAB-VS-GITHUB.md` existe y es coherente.
- Validador en verde.
- Un ingeniero externo puede leerlo y entender **qué** se eligió y **por qué**.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada eje está justificado contra el contexto (no es un copy-paste genérico).
- **Reproducibilidad**: un equipo con el mismo contexto llegaría a una conclusión parecida leyendo tu ADR.
- **Mantenibilidad**: Markdown válido, tabla bien formada, alternativas separadas.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-01-02
```

El validador comprueba **estructura y presencia de términos**, no semántica. Compara con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. Si la startup **ya tuviera** compliance SOC 2 Type II y 60 personas, ¿cambiaría la decisión? ¿Por qué?
2. ¿Qué pasaría si forzamos la restricción "**no podemos pagar GHAS**"? ¿La ecuación se invierte?
3. ¿Qué parte del ADR es la que más envejecerá en 6 meses? ¿Cómo la escribes para que sea fácil revisarla?
4. ¿Qué métricas pedirías a los 90 días para validar si la decisión fue correcta?
5. Si eliges "convivir un año", ¿cómo evitas que la convivencia se vuelva permanente por inercia?

## 10. Extensiones

- Añade un **anexo** con el **plan de migración por fases** (si eliges migrar) con hitos a 30/60/90 días.
- Añade una **matriz de ejes × plataformas** con pesos (0–3) por eje y suma total.
- Añade un **anexo de costos** con el cálculo del TCO a 12 meses para cada opción.

## 11. Limpieza

```bash
rm -rf /tmp/gl-01-02
```

No hay procesos ni infraestructura que detener.
