# Actividad 01 — Refactorizar un Jenkinsfile monolítico en una Shared Library

## 1. Identificación

- **ID:** `jk-04-01-extract-shared-library`
- **Tecnología:** `jenkins`
- **Módulo:** `jk-04-scripted-pipeline-and-shared-libraries`
- **Dificultad:** intermediate
- **Duración estimada:** 85–95 min
- **Tipo:** mini-project (independent — no depende de la actividad 02)

## 2. Contexto

El equipo de Platform heredó 15 repos cuyos `Jenkinsfile` son copias ligeramente distintas de un mismo pipeline de 180 líneas: checkout, lint, test, build de imagen Docker, push al registry, deploy a Kubernetes. Cada cambio al "pipeline estándar" requiere 15 PRs sincronizados. Tu encargo: **extraer** ese pipeline a una **Shared Library propia** (`acme-ci`) que exponga un step `standardBuild(args)`, y dejar el `Jenkinsfile` del repo consumidor en menos de 20 líneas con un pin por tag.

No vas a instalar nada. No hay Jenkins corriendo. El entregable es un **árbol de archivos** con el layout canónico de una library + un `Jenkinsfile` consumidor + un `README-INTENT.md`.

## 3. Objetivos

Al terminar deberías poder:

- Reconocer qué código pertenece a `vars/` (steps públicos), `src/` (clases Groovy) y `resources/` (archivos estáticos).
- Escribir el skeleton correcto de una Shared Library.
- Pinnear la library a un tag (`v1.0.0`) y defender por qué no se pinnea a `main`.
- Documentar las decisiones del refactor.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en especial §4–§7).
- Haber recorrido los tres `examples/`.
- Herramientas: `bash` y un editor de texto. Opcionalmente `groovy` para probar sintaxis a mano (los validadores **no** ejecutan Groovy).

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/jk-04-shared-library
cd /tmp/jk-04-shared-library
```

Puedes usar otro directorio; pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Crear el layout de la library

Debe quedar **exactamente** así (los nombres de directorio los exige Jenkins):

```
/tmp/jk-04-shared-library/
├── acme-ci/
│   ├── vars/
│   │   └── standardBuild.groovy
│   ├── src/
│   │   └── org/
│   │       └── acme/
│   │           └── ci/
│   │               └── BuildContext.groovy
│   └── resources/
│       └── org/
│           └── acme/
│               └── ci/
│                   └── pipeline-settings.yaml
├── consumer-repo/
│   └── Jenkinsfile
└── README-INTENT.md
```

### 5.3 Escribir `vars/standardBuild.groovy`

Un fichero Groovy con un método `def call(Map args = [:]) { ... }`. Requisitos mínimos (los exige el validador):

- Debe contener la palabra `call` (es la firma del step global).
- Debe `import` o referenciar la clase `org.acme.ci.BuildContext` (no toda la lógica puede vivir aquí).
- Debe orquestar al menos las stages `Checkout`, `Test`, `Build` y `Push`.

### 5.4 Escribir `src/org/acme/ci/BuildContext.groovy`

Una clase Groovy que modele los parámetros del build (`image`, `registry`, `deploy`). Requisitos mínimos:

- Debe declarar `package org.acme.ci`.
- Debe declarar `class BuildContext`.
- Debe `implements Serializable` (requisito del motor CPS — ver teoría §4).

### 5.5 Escribir `resources/org/acme/ci/pipeline-settings.yaml`

Un YAML con los defaults de la organización (registry, timeout, lista de entornos default). El validador comprueba su existencia y que parsee como YAML.

### 5.6 Escribir `consumer-repo/Jenkinsfile`

El Jenkinsfile del consumidor **debe**:

- Cargar la library con `@Library('acme-ci@v1.0.0') _` (pin por **tag**, no por branch ni "sin versión").
- Invocar `standardBuild(...)` con al menos un parámetro.
- No contener más de **25 líneas no vacías** (el objetivo es que sea una fachada ligera).

### 5.7 Escribir `README-INTENT.md`

Documento que explique el refactor. Secciones obligatorias (el validador las busca):

- `## Layout` — qué entró en `vars/`, `src/` y `resources/` y por qué.
- `## Pinning` — por qué `@Library('acme-ci@v1.0.0')` y no `@main`.
- `## Governance` — mencionar al menos: `CODEOWNERS`, PR obligatorio y tag como mecanismo de release.

Además, el documento debe mencionar explícitamente:

- `Serializable` (justificar por qué `BuildContext` lo implementa).
- `JenkinsPipelineUnit` (como mecanismo de testing futuro, aunque este módulo no lo ejecute).

> **No llames al archivo `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa `README-INTENT.md`.

## 6. Resultado esperado

- El árbol de archivos existe con los nombres exactos.
- Los archivos Groovy contienen las palabras clave mínimas (`call`, `package`, `class`, `Serializable`, `import`).
- El `Jenkinsfile` carga la library con pin a tag y es breve.
- El `README-INTENT.md` tiene las secciones obligatorias y las menciones mínimas.
- El validador pasa en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Correctitud sintáctica**: Groovy legible (compilable a ojo; el validador no ejecuta `groovy -c`).
- **Correctitud conceptual** (autoevaluación): comparar con `solution/`.
- **Mantenibilidad**: nombres exactos, un step por fichero en `vars/`, package correcto en `src/`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/jk-04-shared-library
```

El validador comprueba layout, palabras clave y versionado. **No** ejecuta Groovy (no hay JVM garantizada en el entorno). La validación semántica — "¿este pipeline funciona en un Jenkins real?" — se hace manualmente levantando `jenkins/jenkins:lts` del módulo `jk-02` y configurando `acme-ci` como *Global Pipeline Library*.

## 9. Preguntas de reflexión

1. ¿Qué pasaría si `BuildContext` no implementara `Serializable`? ¿En qué fase del build fallaría?
2. Si mañana el equipo de Security quiere añadir SAST obligatorio, ¿cuántos PRs necesitas con el nuevo diseño vs el monolítico?
3. ¿Qué justifica tener `pipeline-settings.yaml` como *resource* en lugar de hardcodeado en `BuildContext`?
4. ¿Por qué no mover **todo** a `src/` y dejar `vars/` vacío?
5. Si un repo consumidor necesita saltarse temporalmente SAST, ¿cómo lo expresas en la API de `standardBuild`? ¿Qué validaciones añades?

## 10. Extensiones

- Añade un step adicional `notifySlack(status, channel)` en `vars/notifySlack.groovy` y una plantilla en `resources/`.
- Añade un `CHANGELOG.md` versionado de la library con el bump `v1.0.0`.
- Escribe un test conceptual (pseudo-código) con `JenkinsPipelineUnit` para `standardBuild` que afirme que `deploy: []` nunca llama a `kubectl apply`.

## 11. Limpieza

```bash
rm -rf /tmp/jk-04-shared-library
```

No hay procesos ni infraestructura que detener.
