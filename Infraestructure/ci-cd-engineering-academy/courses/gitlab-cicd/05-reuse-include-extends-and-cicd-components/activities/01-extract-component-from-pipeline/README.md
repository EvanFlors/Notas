# Actividad 01 — Extraer un CI/CD Component de un pipeline duplicado

## 1. Identificación

- **ID:** `gl-05-01-extract-component-from-pipeline`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-05-reuse-include-extends-and-cicd-components`
- **Dificultad:** intermediate
- **Duración estimada:** 80–100 min
- **Tipo:** guided-lab (independiente de la actividad 02)

## 2. Contexto

El equipo de plataforma te pasa un `.gitlab-ci.yml` real que corre en 7 proyectos distintos del grupo. Es el mismo pipeline, copiado y pegado 7 veces, con pequeñas diferencias (versión de Node, si corre coverage, qué stage). Alguien dejó de sincronizar hace 3 meses y ahora los 7 están ligeramente divergentes.

Tu encargo: **extraer el bloque común a un CI/CD Component** con contrato tipado, publicarlo en una ruta "como si fuera un repo del Catalog", y escribir un pipeline consumidor que lo invoque pasando los inputs correctos.

**Importante**: no necesitas un GitLab real. El validador comprueba que la **estructura** del componente y del consumidor sea válida (archivos presentes, YAML parseable, `spec:inputs:` correcto, `include: component:` con sintaxis correcta).

## 3. Objetivos

Al terminar deberías poder, sin consultar la lección:

- Reconocer la duplicación recurrente en un pipeline y decidir qué extraer.
- Crear un componente con la estructura obligatoria (`templates/<name>/template.yml`).
- Definir `spec:inputs:` con `type`, `default`, `description` y al menos un input con `options:` o `regex:`.
- Escribir un consumidor que use `include: - component:` con `inputs:`.
- Documentar el componente en un `README.md` legible por otro equipo.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo.
- Haber recorrido los tres `examples/` del módulo (en especial `03-cicd-component-publish-and-consume/`).
- Herramientas: `bash`, `python3` con `PyYAML`. Un editor de texto.

**Costos**: ninguno. Todo local.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gl-05-01
cd /tmp/gl-05-01
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Lee el pipeline duplicado

Está en `starter/duplicated-pipeline.gitlab-ci.yml`. Es el pipeline que corre hoy en los 7 proyectos. Léelo y responde en tu cabeza:

- ¿Qué partes son **idénticas** entre proyectos?
- ¿Qué partes **varían** (son candidatas a input)?
- ¿Qué partes son **específicas del proyecto** y deben quedarse fuera del componente?

### 5.3 Crea el componente

Estructura **exacta** (el validador la busca):

```
/tmp/gl-05-01/
├── component/
│   ├── README.md
│   └── templates/
│       └── node-test/
│           └── template.yml
└── consumer/
    └── .gitlab-ci.yml
```

Requisitos del `component/templates/node-test/template.yml`:

- **Dos documentos YAML** separados por `---`.
- Primer documento: `spec:` con `inputs:` que incluya al menos:
  - `node_version` (string, con `default:` y `description:`).
  - `coverage` (boolean, con `default: false`).
  - `stage` (string, con `default: 'test'`).
  - Al menos **uno** con `options:` **o** `regex:` (restricción de valores).
  - Todos los inputs deben tener `description:` no vacío.
- Segundo documento: al menos **un job** cuyo `script:`, `image:` o `stage:` use `$[[ inputs.X ]]`.

Requisitos del `component/README.md`:

- Debe mencionar el nombre del componente (`node-test`).
- Debe tener una sección `## Uso` (o `## Usage`) con un ejemplo de `include: - component:`.
- Debe tener una sección `## Inputs` que liste los inputs.

Requisitos del `consumer/.gitlab-ci.yml`:

- Debe tener `stages:` definidos.
- Debe tener un `include:` con una entrada `component:` cuyo identificador siga el formato `<host>/<path>/<name>@<version>` (puedes usar un host ficticio como `gitlab.example.com`).
- La entrada `component:` **debe** venir con un bloque `inputs:` con al menos **dos** valores (uno de ellos distinto del default del componente).
- Debe tener al menos un job propio adicional (p. ej. `build`) que no venga del componente.

### 5.4 Documenta tu decisión (opcional, no evaluado por el validador)

Un `component/CHANGELOG.md` con tu primera versión `v1.0.0` es buena práctica aunque el validador no lo exija.

### 5.5 Entregables

```
/tmp/gl-05-01/
├── component/
│   ├── README.md
│   └── templates/node-test/template.yml
└── consumer/
    └── .gitlab-ci.yml
```

### 5.6 Ejecuta el validador

```bash
bash tests/validate.sh /tmp/gl-05-01
```

Debe terminar con `OK: componente y consumer pasan validacion estructural.` y exit code 0.

## 6. Criterios de aceptación

- `component/templates/node-test/template.yml` es YAML válido con **dos documentos**.
- El primer documento contiene `spec.inputs` con los 3 inputs mínimos y al menos uno restringido.
- El segundo documento define al menos un job que usa `$[[ inputs.X ]]`.
- `component/README.md` tiene las secciones requeridas.
- `consumer/.gitlab-ci.yml` incluye el componente con sintaxis correcta y `inputs:` no vacío.
- `bash tests/validate.sh` retorna 0.

## 7. Autoevaluación

Compara tu solución con `solution/REFERENCE.md` y los archivos de `solution/`:

- ¿Elegiste inputs **del tamaño correcto**? (Si tienes 15 inputs, probablemente el componente intenta hacer demasiado.)
- ¿Tu `README.md` deja claro qué hace el componente **sin leer el YAML**?
- ¿Tu consumer pasa inputs que **no son el default** (lo cual demuestra que el contrato funciona)?

## 8. Qué sigue

→ `../02-adr-components-vs-includes/` — defiende por escrito cuándo escoger componente, cuándo `include:project:` y cuándo `extends:` basta.
