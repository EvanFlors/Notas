# Referencia — gl-05-01

Solución de referencia. **No es la única posible**: usa esto para contrastar criterios, no para copiar literalmente.

## 1. Decisión de diseño

El pipeline duplicado tiene 4 jobs. Mi análisis:

| Job | Veredicto |
|-----|-----------|
| `lint` | Al componente (idéntico entre proyectos salvo versión de Node). |
| `unit` | Al componente, con `coverage` como input boolean. |
| `build` | Al componente (idéntico, incluso el artifact). |
| `deploy-staging` | **Fuera** del componente: cada proyecto despliega distinto; el componente no debe acoplarse a infra de deploy. |

Inputs extraídos:

| Input | Tipo | Default | Por qué |
|-------|------|---------|---------|
| `node_version` | string | `'20'` | Varía (18/20/22); con `options:` para limitarlo a majors soportados. |
| `coverage` | boolean | `false` | 3 proyectos lo quieren, 4 no. Boolean limpio. |
| `stage` | string | `'test'` | Un proyecto usa `'quality'`. |
| `runner_tag` | string | `'saas-linux-small-amd64'` | Un proyecto usa `medium`. `options:` para los 2 válidos. |

## 2. Archivos finales

Ver:

- `component/README.md`
- `component/templates/node-test/template.yml`
- `consumer/.gitlab-ci.yml`

## 3. Chequeos de autoevaluación

- [ ] El consumer tiene menos de 25 líneas (sin contar comentarios).
- [ ] El componente **no** incluye `deploy-staging` (no es su responsabilidad).
- [ ] Los inputs tienen `description:` útil (no `"TODO"`).
- [ ] Al menos un input usa `options:` o `regex:`.
- [ ] El consumer pasa al menos un input **distinto del default** (prueba el contrato).
- [ ] El `README.md` del componente tiene `## Uso` e `## Inputs`.

## 4. Antipatrones comunes

- **Meter `deploy-staging` al componente**: acoplas el componente a credenciales/hooks que no controla.
- **Inputs sin `description:`**: el Catalog UI muestra el campo vacío; nadie entiende qué pasarle.
- **Usar `$CI_COMMIT_BRANCH` dentro del componente** sin advertirlo en el README: dependencia implícita.
- **`node_version: integer`** cuando `'22'` también se usa en tag de imagen (`node:22-alpine`): tratarlo como string es más limpio.
- **Un único input `config:` que es un objeto grande**: pierdes el valor del contrato tipado.

## 5. Siguiente paso

→ `../../02-adr-components-vs-includes/` para justificar por escrito cuándo elegir componente, cuándo `include:project:` y cuándo `extends:`.
