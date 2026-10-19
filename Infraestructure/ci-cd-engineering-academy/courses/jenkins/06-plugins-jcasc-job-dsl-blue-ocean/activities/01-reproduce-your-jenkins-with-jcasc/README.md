# Actividad 01 — Reproducir tu Jenkins desde cero con JCasC

## 1. Identificación

- **ID:** `jk-06-01-reproduce-your-jenkins-with-jcasc`
- **Tecnología:** `jenkins`
- **Módulo:** `jk-06-plugins-jcasc-job-dsl-blue-ocean`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** guided-lab

## 2. Contexto

El equipo de Plataforma recibió el encargo de reproducir el Jenkins corporativo en un nuevo cluster Kubernetes. El Jenkins original es un *snowflake*: nadie recuerda qué plugins tiene instalados, su configuración se cambió por UI durante años y los jobs se definieron a clic. Vas a dejar las bases para reconstruirlo con JCasC desde cero, de forma reproducible y versionada.

**Importante**: no vas a levantar ningún Jenkins real. El entregable son 4 archivos de texto que el validador analiza estructuralmente. La demo con contenedor Docker queda documentada como walkthrough opcional al final — **SKIP** por defecto.

## 3. Objetivos

Al terminar deberías poder:

- Escribir un `jenkins.yaml` sintácticamente correcto cubriendo security realm, authorization, al menos 1 credential, bloque `unclassified`, un `tool`, y un *seed job*.
- Escribir un `plugins.txt` con **todas** las líneas pinneadas (`nombre:version`), incluyendo al menos `configuration-as-code`, `job-dsl` y `workflow-aggregator`.
- Escribir un `seed-jobs.groovy` que use al menos dos de: `folder`, `pipelineJob`, `multibranchPipelineJob`.
- Justificar en `README-INTENT.md` las decisiones, incluyendo el estado real de Blue Ocean.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completa.
- Haber revisado los tres ejemplos de `../../examples/`.
- Herramientas: `bash`, `python3` (parser YAML; viene en macOS/Linux), editor de texto.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/jk-06-01
cd /tmp/jk-06-01
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe los 4 archivos

Nombres **exactos** (el validador los busca):

1. `jenkins.yaml`
2. `plugins.txt`
3. `seed-jobs.groovy`
4. `README-INTENT.md`

#### `jenkins.yaml`

Requisitos estructurales:

- Debe ser **YAML válido** (parseable por `python3 -c "import yaml; yaml.safe_load(...)"`).
- Debe tener **al menos** las claves top-level: `jenkins`, `credentials`, `unclassified`, `tool`, `jobs`.
- Dentro de `jenkins` deben estar: `securityRealm`, `authorizationStrategy`.
- Dentro de `credentials` debe haber al menos una credencial declarada.
- Dentro de `jobs` debe haber al menos un `script` (puede ser inline o `readFileFromWorkspace('seed-jobs.groovy')`).
- **Prohibido** poner secrets en claro. Usa `${VAR_NAME}` para passwords/tokens.

Base de referencia: `../../examples/01-jcasc-minimal-config/jenkins.yaml`.

#### `plugins.txt`

Requisitos:

- Una línea por plugin con formato `nombre:version`.
- Comentarios con `#` permitidos.
- **Toda** línea no-comentario debe tener `:version` (el validador falla si encuentra `plugin:latest` o `plugin` sin `:`).
- Debe incluir obligatoriamente: `configuration-as-code`, `job-dsl`, `workflow-aggregator`.
- Mínimo 6 plugins no-comentario en total.

Base de referencia: `../../examples/03-plugin-pinning-strategy/plugins.txt`.

#### `seed-jobs.groovy`

Requisitos:

- Al menos un `folder(` definido.
- Al menos un `pipelineJob(` **o** `multibranchPipelineJob(` definido.
- Mínimo 2 llamadas DSL en total (p. ej. 1 `folder` + 1 `pipelineJob`, o 2 `pipelineJob`).

Base de referencia: `../../examples/02-seed-job-with-dsl/seed-jobs.groovy`.

#### `README-INTENT.md`

Secciones **obligatorias** (el validador las busca por heading):

- `## jenkins.yaml` — qué configura, por qué cada bloque.
- `## plugins.txt` — rationale y estrategia de pinning.
- `## seed-jobs.groovy` — qué jobs genera y por qué Job DSL vs otras opciones.
- `## Blue Ocean` — por qué está (o no está) en `plugins.txt`, estado del proyecto en 2026.

Además, el documento debe mencionar al menos una vez:

- `JCasC` o `Configuration as Code`.
- `seed job`.
- `pinning` o `version` (contexto de plugins).

### 5.3 Entregables

```
/tmp/jk-06-01/
├── jenkins.yaml
├── plugins.txt
├── seed-jobs.groovy
└── README-INTENT.md
```

## 6. Resultado esperado

- `jenkins.yaml` parsea como YAML y tiene todas las claves top-level requeridas.
- `plugins.txt` todas las líneas con pinning explícito y con los 3 plugins core presentes.
- `seed-jobs.groovy` tiene al menos un `folder` y un `pipelineJob`/`multibranchPipelineJob`.
- `README-INTENT.md` tiene las 4 secciones y menciones mínimas.
- El validador cierra en `OK`.

## 7. Criterios de aceptación

- **Estructura**: validador pasa.
- **Secrets**: ninguno en claro — todo como `${VAR}`.
- **Correctitud conceptual** (autoevaluación): comparar con `solution/`.
- **Mantenibilidad**: comentarios donde ayuden; nombres consistentes.

## 8. Validación

```bash
bash tests/validate.sh /tmp/jk-06-01
```

El validador comprueba:

- Sintaxis YAML de `jenkins.yaml` con `python3`.
- Presencia de claves top-level y sub-claves clave.
- Pinning estricto en `plugins.txt`.
- Patrones DSL en `seed-jobs.groovy`.
- Secciones y menciones en `README-INTENT.md`.

**No** levanta un Jenkins real ni valida que JCasC acepte el YAML en runtime — eso se hace en la demo opcional.

## 9. Demo opcional (walkthrough — SKIP por defecto)

Si quieres ver tu `jenkins.yaml` aplicado a un Jenkins real:

```bash
docker run --rm -p 8080:8080 \
  -v "$PWD/jenkins.yaml:/var/jenkins_home/casc_configs/jenkins.yaml" \
  -v "$PWD/seed-jobs.groovy:/var/jenkins_home/seed-jobs.groovy" \
  -e CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml \
  -e ADMIN_PASSWORD=admin \
  -e GITHUB_TOKEN=dummy \
  jenkins/jenkins:lts
```

Esto **no** es parte del validador. Es un walkthrough para que veas la UI y confirmes que tu YAML carga sin errores de schema en una instalación real.

**Blue Ocean como walkthrough**: si lo incluiste en `plugins.txt`, puedes navegar a `/blue` tras el login. Observa que la UI clásica sigue siendo la por defecto, y que Blue Ocean solo añade una vista alternativa.

## 10. Preguntas de reflexión

1. Si borraras `jenkins.yaml` y rearrancaras el contenedor, ¿qué se perdería y qué no?
2. ¿Por qué `numExecutors: 0` en el controller es casi siempre lo correcto?
3. Si tu equipo pide "actualizar un plugin para probar algo", ¿cuál es el flujo que respeta la disciplina JCasC?
4. ¿Qué pasa si un plugin pinneado desaparece del update center? ¿Cómo lo detectas?
5. ¿En qué caso recomendarías instalar Blue Ocean en 2026 en una instancia nueva?

## 11. Extensiones

- Añade un segundo cloud (p. ej. `docker` o `ec2`) y escribe su bloque en `jenkins.yaml`.
- Divide `seed-jobs.groovy` en dos ficheros por dominio y usa `jobs` con dos `script` entries.
- Añade CI (GHA workflow) que valide `jenkins.yaml` con `python3` y `plugins.txt` con un script simple de pinning.

## 12. Limpieza

```bash
rm -rf /tmp/jk-06-01
```

No hay infraestructura que detener (salvo que hayas ejecutado la demo opcional — en ese caso `Ctrl+C` al `docker run`).
