# Actividad 01 — Portar un workflow GHA a Jenkinsfile declarative

## 1. Identificación

- **ID:** `jk-03-01-port-gha-workflow-to-jenkinsfile`
- **Tecnología:** `jenkins`
- **Módulo:** `jk-03-declarative-pipeline-jenkinsfile`
- **Dificultad:** intermediate
- **Duración estimada:** 80–100 min
- **Tipo:** guided-lab

## 2. Contexto

Tu equipo quiere evaluar Jenkins para un repo que hoy corre su CI en GitHub Actions. Antes de decidir, el tech lead pide una prueba de concepto: **portar literalmente el workflow actual** a un `Jenkinsfile` declarative y compararlos lado a lado. No se despliega nada real; es un ejercicio de traducción de semántica.

El workflow origen (ver `starter/.github/workflows/ci.yml`) hace `lint → test → build → push → deploy-staging` con un job de `deploy-prod` que depende de aprobación manual (environment protection rule). En Jenkins, esa semántica se expresa con `pipeline + stages + agent por stage + when + input`.

**Importante**: no hay Jenkins corriendo. El entregable es un **archivo `Jenkinsfile`**. El validador comprueba estructuralmente que contiene los bloques exigidos.

## 3. Objetivos

Al terminar deberías poder:

- Leer un workflow GHA y mapear cada `job` a un `stage` declarativo.
- Escribir un `Jenkinsfile` con los bloques top-level en orden: `agent`, `options`, `environment`, `stages`, `post`.
- Usar `agent none` al nivel de pipeline y declarar `agent { docker { ... } }` o `agent { label '...' }` por `stage`.
- Compartir el checkout entre stages con `stash` / `unstash`.
- Introducir `when { branch '...' }` y `when { expression { ... } }` para separar `deploy-staging` de un futuro `deploy-prod`.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (secciones 1–7).
- Haber recorrido `../../examples/01-declarative-skeleton/` y `../../examples/02-parallel-stages/`.
- Herramientas: `bash`, `grep`. **No** hace falta Jenkins arrancado.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/jk-03-01
cd /tmp/jk-03-01
```

Si prefieres otro directorio, pásalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Lee el workflow origen

El `starter/.github/workflows/ci.yml` incluido es el que tienes que portar:

```yaml
# jobs: lint, test, build-and-push, deploy-staging, deploy-prod
# triggers: push a main + pull_request
# matrix de node-version en test
# secrets: GHCR_TOKEN, KUBECONFIG_STAGING
```

Léelo con atención. **No** tienes que replicar la matrix de node-version — con un solo stage de test en Node 20 es suficiente.

### 5.3 Escribe `Jenkinsfile` en `/tmp/jk-03-01/Jenkinsfile`

Requisitos exigidos por el validador (coinciden con lo que un revisor pediría en PR):

1. Debe empezar con `pipeline {` al nivel más externo.
2. `agent none` al nivel de pipeline (patrón defensivo).
3. `options { }` con al menos `timeout(...)` y `buildDiscarder(...)`.
4. `environment { }` con al menos `APP_NAME` y `REGISTRY`.
5. `stages { }` con, como mínimo, estos stages (nombre exacto en el `stage('...')`):
   - `Checkout`
   - `Lint`
   - `Test`
   - `Build`
   - `Deploy staging`
6. Al menos **un** `stage` con `agent { docker { image '...' } }`.
7. Al menos **un** `stage` con `when { ... }` — típicamente `Deploy staging` filtrando por `branch 'main'`.
8. Al menos **un** `stash` y un `unstash` (para pasar el checkout entre stages con agent distinto).
9. Al menos **un** uso de credenciales — `withCredentials { ... }` **o** `credentials('...')` dentro de `environment`.
10. `post { }` con al menos `always` y `failure`.

El `solution/Jenkinsfile` muestra una implementación de referencia (consultar sólo tras intentarlo).

### 5.4 Entregables

```
/tmp/jk-03-01/
└── Jenkinsfile
```

Un único archivo. El validador no exige nada más.

## 6. Resultado esperado

El validador imprime `OK` para cada chequeo y termina con `0 issue(s)`.

```bash
bash tests/validate.sh /tmp/jk-03-01
```

## 7. Criterios de aceptación

- **Estructural**: validador en verde (`0 issue(s)`).
- **Semántico** (autoevaluación): el `Jenkinsfile` resuelve la misma intención que el workflow GHA. Comparar con `solution/REFERENCE.md`.
- **Mantenibilidad**: nombres de stage legibles, variables en `environment { }` en vez de hardcodeadas, uso correcto de `withCredentials` o `credentials()`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/jk-03-01
```

El validador es estructural: busca con `grep` los bloques y nombres exigidos. **No** ejecuta el pipeline. Si tienes un Jenkins arrancado, puedes validarlo adicionalmente con el `declarative-linter` (ver `theory/lesson.md` §10.1).

## 9. Preguntas de reflexión

1. ¿Qué equivalente tiene en Jenkins el `environment` de GitHub Actions (que gatea deploy-prod)? Pista: `input` + `submitter`.
2. ¿Qué pasaría si en el `Jenkinsfile` pusieras `agent any` en vez de `agent none` + por stage?
3. GHA cachea `node_modules` entre jobs con `actions/cache`. ¿Cómo se resuelve el equivalente en Jenkins sin Shared Libraries?
4. Si el workflow GHA tiene `strategy.matrix.node-version: [18, 20]`, ¿cómo lo expresarías en Declarative? Pista: `matrix { }` dentro de `stages`.
5. ¿Qué información del workflow GHA **no** tiene mapeo directo en Jenkins y necesitaría un plugin extra?

## 10. Extensiones

- Añade un stage `SBOM` en paralelo con `Lint` usando `anchore/syft` como agent Docker.
- Añade `when { beforeAgent true; branch 'main' }` en el stage de build y mide la diferencia de tiempo en una PR típica.
- Convierte el `Jenkinsfile` en una **Multibranch Pipeline** job: el mismo archivo pero con los `when` filtrando por `env.CHANGE_ID` para distinguir PR builds de main builds.

## 11. Limpieza

```bash
rm -rf /tmp/jk-03-01
```

No hay infraestructura que detener.
