# Actividad 02 — Escribir el step `standardBuild()` opinado

## 1. Identificación

- **ID:** `jk-04-02-write-standard-build-step`
- **Tecnología:** `jenkins`
- **Módulo:** `jk-04-scripted-pipeline-and-shared-libraries`
- **Dificultad:** intermediate
- **Duración estimada:** 75–85 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

El equipo de Platform ya tiene decidido *qué* debe hacer el pipeline estándar de la organización (checkout → lint → test → build → push → notify) y los defaults que le aplican. Lo que falta es **diseñar la API pública** del step `standardBuild(args)` que lo encapsule: qué parámetros son obligatorios, cuáles opcionales con default sensato, qué errores lanzar ante uso incorrecto, y cómo documentar el contrato público para que 15 equipos consumidores no te pregunten lo mismo.

No vas a instalar nada. No hay Jenkins corriendo. El entregable es la **library** (`vars/`, `src/`, `resources/`) + un `Jenkinsfile` de prueba + un `README-INTENT.md` que define el contrato público.

## 3. Objetivos

Al terminar deberías poder:

- Diseñar la API de un step global siguiendo convenciones Groovy (`Map args`, defaults, validación temprana).
- Delegar lógica a una clase bajo `src/` para dejar `vars/` como orquestador puro.
- Usar `libraryResource(...)` para leer plantillas desde `resources/`.
- Documentar un contrato público: parámetros, defaults, errores, estrategia de versionado.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en especial §4–§6).
- Haber recorrido los tres `examples/`.
- Herramientas: `bash` y un editor de texto. Opcionalmente `groovy` para probar sintaxis a mano.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/jk-04-standard-build
cd /tmp/jk-04-standard-build
```

Puedes usar otro directorio; pásaselo al validador.

### 5.2 Layout obligatorio

```
/tmp/jk-04-standard-build/
├── vars/
│   └── standardBuild.groovy
├── src/
│   └── org/
│       └── acme/
│           └── ci/
│               └── StandardBuild.groovy
├── resources/
│   └── org/
│       └── acme/
│           └── ci/
│               └── notify-template.md
├── Jenkinsfile
└── README-INTENT.md
```

### 5.3 `vars/standardBuild.groovy`

El step global. Requisitos mínimos (el validador los exige):

- Debe declarar `def call(Map args = [:])` (o firma equivalente con `Map`).
- Debe **validar** al menos el parámetro obligatorio `image` lanzando un error claro si falta (`assert`, `IllegalArgumentException`, `error '...'`).
- Debe `import org.acme.ci.StandardBuild` y delegar en esa clase.
- Debe orquestar al menos las stages `Checkout`, `Build` y `Notify` (nombres exactos).

### 5.4 `src/org/acme/ci/StandardBuild.groovy`

La clase que modela el build. Requisitos:

- Debe declarar `package org.acme.ci`.
- Debe declarar `class StandardBuild`.
- Debe `implements Serializable`.
- Debe exponer al menos: `String image`, `String registry`, `List<String> deploy`.
- Debe tener un constructor que acepte un `Map args` y aplique **defaults sensatos** (`registry = 'ghcr.io/acme'`, `deploy = ['dev']`).

### 5.5 `resources/org/acme/ci/notify-template.md`

Una plantilla de notificación (Markdown o texto plano) con **al menos un placeholder** tipo `${status}`, `${image}` o `${buildUrl}`. El validador comprueba que exista y que contenga al menos un placeholder `${...}`.

### 5.6 `Jenkinsfile`

Un Jenkinsfile de prueba (puedes imaginar que vive en un repo consumidor):

- Debe cargar la library con `@Library('acme-ci@v0.1.0') _` (pin a tag).
- Debe invocar `standardBuild(image: '...', ...)` con **al menos dos parámetros**.
- Debe quedar en 25 líneas no vacías o menos.

### 5.7 `README-INTENT.md`

Documento con el **contrato público** del step. Secciones obligatorias (el validador las busca):

- `## API` — tabla de parámetros con columnas: nombre, tipo, obligatorio, default, descripción.
- `## Defaults` — justificar cada default elegido.
- `## Errores` — qué lanza el step y bajo qué condiciones.
- `## Versionado` — política de bumps semver y cómo deprecar un parámetro.

Además, el documento debe mencionar explícitamente:

- `Serializable` (requisito CPS).
- `libraryResource` (cómo se lee la plantilla).
- `semver` (política de versionado).

> **No llames al archivo `ANALYSIS.md`** — usa `README-INTENT.md`.

## 6. Resultado esperado

- El árbol existe con los nombres exactos.
- `vars/standardBuild.groovy` valida argumentos y delega en `StandardBuild`.
- `src/.../StandardBuild.groovy` tiene package, class, Serializable, y defaults.
- `resources/.../notify-template.md` tiene al menos un placeholder.
- `Jenkinsfile` carga con pin a tag.
- `README-INTENT.md` tiene las 4 secciones y las menciones mínimas.
- El validador pasa en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Correctitud sintáctica**: Groovy legible.
- **Mantenibilidad**: `vars/` ligero, lógica en `src/`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/jk-04-standard-build
```

El validador comprueba layout, firmas, validaciones y documentación. **No** ejecuta Groovy.

## 9. Preguntas de reflexión

1. ¿Por qué validar `image` con `assert` dentro del `call(...)` y no dejar que falle el `docker build`?
2. ¿Qué pasa si un consumidor pasa `deploy: 'prod'` (string) en lugar de `deploy: ['prod']` (lista)? ¿Cómo lo manejas?
3. Si decides renombrar `image → artifact`, ¿qué estrategia usas para no romper 15 consumidores de golpe?
4. ¿Por qué la plantilla de notificación va en `resources/` y no hardcodeada en `StandardBuild.groovy`?
5. Si un auditor pregunta "muéstrame todos los repos que usan `standardBuild` v0.1.0", ¿cómo se lo demuestras?

## 10. Extensiones

- Añade un parámetro `requireApproval: Boolean` que meta un stage `input` con `timeout` antes de deploy a `prod`.
- Añade un segundo step `notifySlack(...)` en `vars/` que use la misma plantilla de `resources/`.
- Escribe un `CHANGELOG.md` describiendo `v0.1.0` y qué cambiaría en `v0.2.0` (hipotético).

## 11. Limpieza

```bash
rm -rf /tmp/jk-04-standard-build
```
