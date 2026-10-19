# Actividad 01 — Primer Jenkinsfile declarative sobre Jenkins local

## 1. Identificacion

- **ID:** `jk-02-01-first-pipeline-job`
- **Tecnologia:** `jenkins`
- **Modulo:** `jk-02-install-ui-freestyle-vs-pipeline`
- **Dificultad:** beginner
- **Duracion estimada:** 50–60 min
- **Tipo:** guided-lab

## 2. Contexto

Te acaban de dar acceso de admin a un Jenkins. El equipo quiere migrar sus Freestyle jobs a Pipeline, pero antes de tocar nada en el controller de prod, te piden **demostrarlo en local**: levantar Jenkins con Docker, escribir **un `Jenkinsfile` declarative minimo pero bien estructurado**, y dejar documentado por que ese modelo gana al Freestyle. Cuando tengas el build verde en local, replicaras la logica en el Jenkins de staging.

## 3. Objetivos

Al terminar deberias poder:

- Arrancar Jenkins local con la imagen `jenkins/jenkins:lts` + Docker, persistiendo `JENKINS_HOME` en un volumen.
- Completar el setup wizard y entrar como admin.
- Escribir un `Jenkinsfile` declarative con los bloques minimos: `pipeline`, `agent`, `options` (con `buildDiscarder`), `stages`, `stage`, `steps` (al menos `echo` + `sh`), `post`.
- Ejecutar el pipeline (inline o desde SCM) y conseguir un build **verde**.
- Justificar por escrito por que ese pipeline es un paso adelante respecto a un Freestyle equivalente.

## 4. Prerrequisitos

- Docker Engine instalado y en ejecucion. Si **no** tienes Docker, el validador reporta `SKIP` para los chequeos que lo requieren; aun asi puedes entregar el `Jenkinsfile` y el `README-INTENT.md` y validar lo documental.
- Haber leido `../../theory/lesson.md` (secciones 2, 5, 6) y recorrido los ejemplos `01-jenkins-docker-up`, `02-freestyle-hello-world`, `03-pipeline-hello-world`.
- Herramientas: `docker`, `bash`, `curl`, un editor de texto.

**Costos**: ninguno. Todo corre en local.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/jk-02-pipeline
cd /tmp/jk-02-pipeline
```

Puedes usar otro directorio, pero entonces pasaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Levantar Jenkins con Docker (si tienes Docker)

Si Docker esta disponible, arranca el controller siguiendo `../../examples/01-jenkins-docker-up/`:

```bash
docker volume create jenkins_home
docker run -d --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts

# Esperar
until curl -sfI http://localhost:8080 >/dev/null; do sleep 2; done

# Password inicial
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Completa el wizard (**Install suggested plugins** + crear admin). Deja la URL `http://localhost:8080/` por default.

Si **no** tienes Docker, salta este paso. El validador detectara la ausencia y marcara los chequeos de container como `SKIP`.

### 5.3 Escribir el `Jenkinsfile`

Crea el archivo `/tmp/jk-02-pipeline/Jenkinsfile` con **tu propio contenido** (puedes partir del snippet de `../../examples/03-pipeline-hello-world/`, pero el pipeline debe ser tuyo y debe cumplir todo lo siguiente):

Requisitos **obligatorios** (el validador los busca por grep + estructuralmente):

1. Comienza con `pipeline {` como primer bloque de nivel superior.
2. Declara `agent any` (o `agent { ... }`) al nivel del pipeline.
3. Incluye un bloque `options { ... }` con `buildDiscarder(logRotator(...))` para fijar retention.
4. Incluye un bloque `stages { ... }` con **al menos dos** `stage('<nombre>') { steps { ... } }`.
5. Al menos un `steps` ejecuta un comando shell con `sh 'uname -a'` o similar (debe aparecer el token `sh`).
6. Al menos un `steps` incluye un `echo` con texto no vacio.
7. Incluye un bloque `post { ... }` con al menos un bloque de condicion (`always`, `success` o `failure`) que haga `echo`.
8. Cierra con `}` final balanceado.

> Nota: el validador comprueba **presencia de tokens** y **balance de llaves**. No ejecuta el pipeline. Si tienes Docker, ejecutarlo en Jenkins es parte del lab y se recomienda hacerlo.

### 5.4 Crear el Pipeline job en Jenkins (si tienes Docker)

Con Jenkins ya levantado:

1. Dashboard → **New Item**.
2. Nombre: `first-pipeline-job`.
3. Tipo: **Pipeline** → **OK**.
4. **Pipeline** → **Definition**: `Pipeline script`.
5. Pega el contenido de tu `Jenkinsfile`.
6. **Save** → **Build Now**.
7. Verifica que el build termina en **SUCCESS** (bola azul).

Opcional avanzado: usa `Pipeline script from SCM` apuntando a un repo Git local o remoto donde hayas commiteado el `Jenkinsfile`.

### 5.5 Escribir `README-INTENT.md`

Crea `/tmp/jk-02-pipeline/README-INTENT.md` con las secciones **obligatorias** (el validador busca estos encabezados):

- `## Pipeline anatomy` — explica, bloque por bloque (`pipeline`, `agent`, `options`, `stages`, `steps`, `post`), que hace tu `Jenkinsfile` y por que lo pusiste asi.
- `## Freestyle vs Pipeline` — al menos **3 razones concretas** por las que tu pipeline es mejor que un Freestyle equivalente. Debe mencionar literalmente las palabras **`Jenkinsfile`** y **`Git`** (o `SCM`).
- `## Retention` — explica para que sirve `buildDiscarder` y que pasaria sin el.
- `## Run evidence` — nota breve de la ejecucion: si corriste el pipeline en Jenkins, pega el ultimo tramo del console output (`Finished: SUCCESS` o similar); si no tenias Docker, documenta explicitamente que lo validaste solo estructuralmente.

> **No llames al archivo `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa `README-INTENT.md`.

### 5.6 Entregables

```
/tmp/jk-02-pipeline/
├── Jenkinsfile
└── README-INTENT.md
```

## 6. Resultado esperado

- `Jenkinsfile` presente, con los tokens requeridos y llaves balanceadas.
- `README-INTENT.md` con las 4 secciones obligatorias.
- Si Docker esta disponible: contenedor `jenkins` running en `127.0.0.1:8080` y al menos un build verde del Pipeline job.
- Validador en verde (los chequeos marcados `SKIP` por ausencia de Docker no cuentan como fallo).

## 7. Criterios de aceptacion

- **Funcionalidad**: el `Jenkinsfile` compila y, si tienes Docker, el build termina en SUCCESS.
- **Estructura**: cumple los 8 requisitos del punto 5.3.
- **Correctitud conceptual** (autoevaluacion): compara con `solution/REFERENCE.md`.
- **Mantenibilidad**: nombres de `stage` legibles; sin credenciales ni rutas de tu maquina en el archivo.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/jk-02-pipeline
```

El validador comprueba:

- Presencia y shape del `Jenkinsfile` (`pipeline`, `agent`, `options`, `stages`, al menos 2 `stage`, `sh`, `echo`, `post`, llaves balanceadas, `buildDiscarder`).
- Presencia del `README-INTENT.md` con las 4 secciones.
- Si Docker esta disponible: contenedor `jenkins` corriendo y UI respondiendo en `http://localhost:8080`.
- Si Docker **no** esta disponible: marca los dos chequeos anteriores como `SKIP` y no los cuenta como fallo.

El validador no ejecuta el pipeline ni intenta llamar al `declarative-linter`; esos son pasos opcionales del lab.

## 9. Preguntas de reflexion

1. Si en vez de `agent any` usaras `agent { docker { image 'node:20' } }`, ¿que cambia en el workspace y en reproducibilidad?
2. ¿Que ganas migrando de `Pipeline script` inline a `Pipeline script from SCM`? ¿Que pierdes mientras tanto?
3. Si quitas el `buildDiscarder`, ¿que pasa con `JENKINS_HOME` en 6 meses?
4. ¿Como harias code review de un cambio en este `Jenkinsfile`? ¿Es posible hacerlo si fuera Freestyle?
5. Dado un Jenkins con 400 Freestyle jobs, ¿cual seria tu primer paso para empezar a migrar sin romper nada?

## 10. Extensiones

- Convierte el pipeline inline a **Pipeline script from SCM**: crea un repo Git local, commitea el `Jenkinsfile`, apunta Jenkins al repo.
- Instala el **declarative-linter** y valida el `Jenkinsfile` desde la CLI (`jenkins-cli.jar declarative-linter`).
- Añade un `stage('Lint')` con un `sh` que corra `shellcheck` sobre un script del repo (bajas al mundo real de los pipelines).

## 11. Limpieza

```bash
# Entregable
rm -rf /tmp/jk-02-pipeline

# Jenkins local (opcional)
docker stop jenkins && docker rm jenkins
# Mantener volumen para proximas actividades, o eliminar:
# docker volume rm jenkins_home
```
