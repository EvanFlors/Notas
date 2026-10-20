# Actividad 01 — Portar workflow GHA del capstone y documentar la migración

## 1. Identificación

- **ID:** `gl-10-01-migrate-capstone-pipeline`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-10-migration-and-platform-patterns`
- **Dificultad:** advanced
- **Duración estimada:** 100–140 min
- **Tipo:** architecture (independent — no depende de la actividad 02)

## 2. Contexto

Tu organización decidió migrar de GitHub Actions a GitLab (SaaS, plan Premium). El primer repo piloto es la API `my-org/api-checkout`: Node 20, lint + tests (matrix Node 18/20) + build de imagen Docker + push al registry en ECR usando OIDC a AWS. Hoy corre con el workflow de GHA que ves abajo. Tu encargo:

- **Portar** el workflow a `.gitlab-ci.yml` **sin perder** ningún gate (lint, test, build, push).
- **Documentar** la decisión en `MIGRATION-ADR.md`: mapping GHA↔GitLab, decisiones no triviales, plan de dual-run, cambios necesarios en la trust policy AWS y qué bloques promover al **CI/CD Component** del catálogo interno.

**Importante**: no hay cuenta GitLab ni AWS reales. El entregable son **dos archivos**: `MIGRATION-ADR.md` y `.gitlab-ci.yml`. El validador comprueba estructura, no ejecución.

### Workflow GHA de partida (referencia)

```yaml
# .github/workflows/ci.yml
name: ci
on:
  push: { branches: [main] }
  pull_request: {}
permissions:
  id-token: write
  contents: read
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci
      - run: npm run lint
  test:
    runs-on: ubuntu-latest
    needs: lint
    strategy:
      matrix: { node: [18, 20] }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: ${{ matrix.node }}, cache: npm }
      - run: npm ci
      - run: npm test -- --coverage
  build-and-push:
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/gha-build
          aws-region: eu-west-1
      - run: |
          docker build -t $ECR/api:${{ github.sha }} .
          docker push $ECR/api:${{ github.sha }}
```

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Portar un workflow GHA mediano a `.gitlab-ci.yml` defendiendo cada divergencia.
- Explicar por qué el `aud:` y los claims del ID Token difieren de GHA.
- Diseñar un plan de dual-run con criterios de corte explícitos.
- Decidir qué bloque promueves a Componente del catálogo y por qué.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (en particular §2 mapping, §3 inventario, §4 OIDC, §5 dual-run).
- Haber recorrido los tres `examples/` del módulo (sobre todo `01-port-gha-workflow-to-gitlab`).
- Haber completado `gl-05` y `gl-06`.
- Herramientas: `bash`, editor Markdown. Opcional: `yq` para validar YAML a mano.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gl-10-migration
cd /tmp/gl-10-migration
```

Puedes usar otro directorio; pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `.gitlab-ci.yml`

Debe reproducir funcionalmente el workflow GHA. Contenido mínimo que el validador exige:

- Claves top-level **`stages:`** y **`workflow:`**.
- Al menos **3 jobs** cubriendo lint, test y build.
- Un job con **`parallel: matrix:`** para la matriz Node 18/20.
- Un job con **`needs:`** (para construir el DAG).
- Un job con **`id_tokens:`** cuyo bloque tiene `aud:`.
- Al menos una **`rules:`** que filtre por `$CI_COMMIT_BRANCH == "main"`.
- Un **`image:`** declarado (en `default:` o por job).
- Comentario o referencia a **OIDC** y a **AWS**.

### 5.3 Escribe `MIGRATION-ADR.md`

Formato ADR estándar (secciones obligatorias que busca el validador):

```
# ADR 010 — Migración my-org/api-checkout de GHA a GitLab

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(Por qué migramos. Qué constraints.)

## Decisión
(El port + el plan.)

## Consecuencias
(Qué ganamos, qué perdemos.)

## Alternativas descartadas
(Al menos 2.)
```

Contenido mínimo obligatorio:

- **Tabla o lista de mapping GHA↔GitLab** (al menos: `on` → `workflow`, `strategy.matrix` → `parallel: matrix`, OIDC action → `id_tokens`, `${{ github.sha }}` → `$CI_COMMIT_SHA`).
- Mención explícita de **CI/CD Component** o **catálogo interno** (qué promueves y por qué).
- Mención explícita de **dual-run** con criterios de corte.
- Mención explícita de **ID Token** (u OIDC) y de los **claims** nuevos (`project_path`, `ref_type`, `ref`).
- Mención de **AWS** y del nuevo ARN/role que la trust policy acepta.
- **Diagrama o bloque de código** (fence) con la trust policy nueva o con el DAG del pipeline portado.
- Al menos **2 alternativas descartadas** (`#` sub-headings o items `1.`/`2.` numerados).

### 5.4 Entregables

```
/tmp/gl-10-migration/MIGRATION-ADR.md
/tmp/gl-10-migration/.gitlab-ci.yml
```

## 6. Resultado esperado

- Ambos archivos existen y son coherentes.
- El `.gitlab-ci.yml` sería válido estructuralmente para `gitlab-ci-lint` (no lo ejecutamos).
- El ADR documenta decisiones defendibles ante un equipo de 5 personas.
- El validador pasa en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada decisión de divergencia GHA↔GitLab está justificada.
- **Reproducibilidad**: alguien del equipo puede tomar `.gitlab-ci.yml` y copiarlo a un repo real con mínimos ajustes.
- **Mantenibilidad**: Markdown válido, YAML bien indentado, fences cerradas.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-10-migration
```

El validador comprueba **estructura**, no comportamiento en gitlab.com. Compara tu entrega con `solution/REFERENCE.md` después para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué `workflow:` top-level en lugar de un `rules:` repetido en cada job?
2. ¿Qué pierdes al no tener `actions/setup-node` y configurar `image:` en su lugar?
3. ¿Cuántas statements debe tener la trust policy AWS durante el dual-run?
4. ¿Cuál es el *gotcha* al pinnear por `sub` literal en vez de por `project_path` + `ref`?
5. ¿Qué métrica mirarás para decidir el **corte** del dual-run?

## 10. Extensiones

- Añade un job `cosign-sign` que firme la imagen con el ID Token (keyless) y documenta en el ADR el nuevo issuer.
- Promueve el bloque `assume-role-with-web-identity` a Componente `aws-oidc@1.0.0` y muestra el `include:` desde `.gitlab-ci.yml`.
- Añade un panel al dashboard esperado (ejemplo `03-ci-metrics-dashboard`) para medir la *duration* comparativa GHA↔GitLab durante el dual-run.

## 11. Limpieza

```bash
rm -rf /tmp/gl-10-migration
```

No hay procesos ni infraestructura que detener.
