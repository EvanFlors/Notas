# Actividad 01 — Explorar `gitlab.com` y producir un cheatsheet personal

## 1. Identificación

- **ID:** `gl-01-01-explore-gitlab-com`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-01-model-and-mapping-to-gha`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** guided-lab (independiente — sin dependencia de la actividad 02)

## 2. Contexto

Vienes de GitHub Actions y vas a estar leyendo pantallas de GitLab durante los próximos 9 módulos. Antes de escribir YAML, necesitas poder **ubicar las pantallas** sin pensar y traducir **vocabulario** en tiempo real. Este laboratorio te hace recorrer `gitlab.com` como visitante (o con una cuenta Free opcional) y producir un **cheatsheet** personal `CHEATSHEET.md` que vas a tener abierto en los módulos siguientes.

No se ejecuta ningún pipeline. No se crea ningún Project privado. Solo lectura y anotación.

> **Nota**: si no quieres crear cuenta, puedes recorrer todo lo necesario usando Groups públicos de ejemplo (`gitlab-org`, `gitlab-com`). La actividad está diseñada para funcionar **sin login**.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Decir en qué menú de `gitlab.com` se gestionan Groups, Subgroups, Projects, Group Runners, Group Variables, Protected Branches, Environments y Pipelines.
- Traducir los 10 conceptos principales GHA ↔ GitLab de memoria.
- Reconocer en un pipeline público real cuál es el stage, cuál el job, y qué hace `needs:`.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo.
- Haber recorrido los tres `examples/` del módulo.
- Haber completado el primer módulo de **github-actions** (sabes qué es workflow, job, action, matrix, OIDC).
- Herramientas: navegador y un editor Markdown. Nada más.

**Costos**: ninguno. Todo en navegador contra `gitlab.com` como visitante.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gl-01-01
cd /tmp/gl-01-01
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Recorrido guiado (sin ejecutar nada)

Abre `gitlab.com` en el navegador. Para cada ítem, **anota la ruta UI exacta** (menú → submenú → pestaña) en una nota aparte. Vas a transcribirla al cheatsheet.

1. Localiza un **Group público** y entra. Sugeridos: `gitlab-org`, `gitlab-com`.
2. Dentro del Group: abre **Settings** y ubica, al menos, estas secciones:
   - **General** (nombre, descripción, visibility).
   - **CI/CD** (Group Variables, Runners).
   - **Repository** (Protected Branches, Protected Tags).
3. Entra en un **Subgroup** del Group (si existe) y comprueba que **no** tiene por qué repetir todas las settings — hereda.
4. Entra en un **Project** público (por ejemplo `gitlab-org/gitlab`). Observa:
   - El menú lateral: **Code**, **Build** (pipelines, jobs, artifacts), **Deploy** (environments, releases), **Operate**, **Monitor**, **Analyze**, **Settings**.
   - En **Build → Pipelines**: abre un pipeline reciente y verás **stages** como columnas y **jobs** como tarjetas.
   - En **Deploy → Environments**: lista de entornos; abre uno y mira la URL y el histórico de deployments.
5. En el Project **Settings**:
   - **CI/CD**: Variables, Runners, General pipelines (Pipeline configuration file).
   - **Repository**: Protected branches, Protected tags, Default branch.
   - **Access tokens**.
6. Localiza el **CI/CD Catalog** del Group (si está habilitado para el Group visitado) o visita el catálogo público: `https://gitlab.com/explore/catalog`.

### 5.3 Escribe `CHEATSHEET.md`

Produce `CHEATSHEET.md` con tres secciones obligatorias. El validador comprueba estructura, no semántica.

```markdown
# Cheatsheet personal — GHA ↔ GitLab (gl-01)

## 1. Mapping GHA ↔ GitLab (mínimo 10 filas)

| GitHub Actions | GitLab | Nota |
|----------------|--------|------|
| Workflow | Pipeline | ... |
| Job | Job | ... |
| ... | ... | ... |

(10 filas mínimo — ver lista obligatoria en §5.4)

## 2. Jerarquía y ubicación en gitlab.com

(Explica Instance / Group / Subgroup / Project y menciona Settings)

## 3. Pantallas clave (mínimo 10)

| Qué | Dónde (ruta UI) |
|-----|-----------------|
| Group Variables | Group → Settings → CI/CD → Variables |
| Group Runners | Group → Settings → CI/CD → Runners |
| ... | ... |

(10 filas mínimo — ver lista obligatoria en §5.4)
```

### 5.4 Contenido mínimo (el validador lo exige)

**Sección 1 — Mapping** debe nombrar, en al menos una celda de la tabla, **cada** uno de estos 10 términos:

1. `workflow` o `pipeline`
2. `job`
3. `matrix`
4. `needs`
5. `secrets` o `variables`
6. `OIDC` o `ID Token` o `id_tokens`
7. `pull request` o `PR` o `merge request` o `MR`
8. `org` o `organization` o `Group`
9. `reusable workflow` o `composite` o `component` o `extends`
10. `environment`

**Sección 3 — Pantallas** debe mencionar al menos estas rutas (texto en el documento):

- `Settings` (varias veces OK)
- `CI/CD` (menú o sección Settings → CI/CD)
- `Runners`
- `Variables`
- `Protected Branches` o `Protected branches`
- `Environments`
- `Pipelines`
- `Jobs`
- `Catalog`
- `Repository`

### 5.5 Entregable

Un archivo:

```
/tmp/gl-01-01/CHEATSHEET.md
```

con las 3 secciones y los términos/rutas mínimos.

## 6. Resultado esperado

- `CHEATSHEET.md` existe y es coherente.
- Validador en verde.
- Lo tienes abierto como pestaña permanente para los módulos `gl-02..gl-10`.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada fila añade *una nota breve* que no es solo repetir el término (traducción con sentido).
- **Reproducibilidad**: alguien más leyéndolo encuentra las pantallas sin ambigüedad.
- **Mantenibilidad**: Markdown válido, tablas bien formadas.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-01-01
```

El validador comprueba **estructura y presencia de términos**, no semántica. Compara tu cheatsheet con `solution/REFERENCE.md` para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Qué menú de GitLab **no** tiene equivalente obvio en GitHub? ¿Por qué podría ser útil?
2. ¿Dónde definirías una variable `REGISTRY_URL` para que la vean 5 projects de un mismo área? ¿Y si quisieras que la vean *todos* los projects de la org?
3. ¿Qué diferencia hay, en la UI, entre un **pipeline** y un **job**? ¿Y entre un pipeline y una ejecución de un pipeline?
4. ¿Dónde ubicarías, en GitLab, lo que en GitHub llamas "required workflow"?
5. Si trabajaras en una org con 10 subgrupos: ¿dónde pondrías los runners compartidos? ¿Y los que son solo para producción?

## 10. Extensiones

- Añade al cheatsheet una tabla de **variables predefinidas** útiles (`CI_COMMIT_BRANCH`, `CI_PIPELINE_SOURCE`, `CI_MERGE_REQUEST_IID`, `CI_PROJECT_PATH`...).
- Añade una columna "módulo donde lo veré" (p. ej. OIDC → `gl-03`, Review Apps → `gl-07`).
- Captura (en texto o emoji) los iconos del menú lateral de un Project para memorizar la navegación.

## 11. Limpieza

```bash
rm -rf /tmp/gl-01-01
```

No hay procesos ni infraestructura que detener.
