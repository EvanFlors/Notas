# Actividad 02 — Inventariar `$JENKINS_HOME`

## 1. Identificacion

- **ID:** `jk-02-02-explore-jenkins-home`
- **Tecnologia:** `jenkins`
- **Modulo:** `jk-02-install-ui-freestyle-vs-pipeline`
- **Dificultad:** beginner
- **Duracion estimada:** 40–45 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Vas a tomar un Jenkins de un equipo heredado y tienes que empezar por lo mas basico: **saber donde vive el estado**. Antes de prometer migraciones o backups, necesitas mapear `$JENKINS_HOME` y entender por que un Freestyle no es trivialmente versionable y un Pipeline from SCM si. En esta actividad **no** modificas nada: solo exploras, documentas y razonas. El entregable es un `INVENTORY.md`.

## 3. Objetivos

Al terminar deberias poder:

- Nombrar y describir los directorios y archivos principales de `$JENKINS_HOME` (`jobs/`, `workspace/`, `plugins/`, `users/`, `secrets/`, `nodes/`, `config.xml`, `credentials.xml`).
- Explicar donde queda guardada la configuracion de un Freestyle y donde queda la de un Pipeline **inline** vs un Pipeline **from SCM**.
- Identificar al menos **tres** rutas de `$JENKINS_HOME` cuyo contenido crece sin limite sin retention o housekeeping.
- Justificar por escrito por que Freestyle **no** es versionable de forma util y que gana Pipeline from SCM.

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` (secciones 1, 7, 8).
- Recorrido los ejemplos `01-jenkins-docker-up`, `02-freestyle-hello-world`, `03-pipeline-hello-world`.
- Herramientas: `bash`, un editor de texto. **Opcional**: `docker` para explorar un `$JENKINS_HOME` real; si no esta disponible, puedes basar el inventario en la documentacion oficial y los ejemplos del modulo (el validador no exige explorar un contenedor real).

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/jk-02-home
cd /tmp/jk-02-home
```

Puedes usar otro directorio, pero pasaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 (Opcional, recomendado) Explorar `$JENKINS_HOME` con Docker

Si tienes el Jenkins local de la actividad 01 u otro Jenkins corriendo:

```bash
# Layout de primer nivel
docker exec jenkins ls -la /var/jenkins_home

# Jobs
docker exec jenkins ls /var/jenkins_home/jobs

# Un job concreto (ajusta el nombre)
docker exec jenkins ls /var/jenkins_home/jobs/first-pipeline-job
docker exec jenkins cat /var/jenkins_home/jobs/first-pipeline-job/config.xml | head -40

# Builds de un job
docker exec jenkins ls /var/jenkins_home/jobs/first-pipeline-job/builds

# Workspace (fuera de jobs/)
docker exec jenkins ls /var/jenkins_home/workspace

# Plugins instalados
docker exec jenkins ls /var/jenkins_home/plugins | head

# Usuarios locales
docker exec jenkins ls /var/jenkins_home/users

# Secretos y credenciales (NO imprimir contenido en claro)
docker exec jenkins ls /var/jenkins_home/secrets
docker exec jenkins ls -la /var/jenkins_home/credentials.xml 2>/dev/null || true
```

Si no tienes Docker, apoyate en lo descrito en `theory/lesson.md` §1, §7, §8 y en la documentacion oficial de Jenkins Handbook ("Managing Jenkins > Backing-up/Restoring Jenkins").

### 5.3 Escribir `INVENTORY.md`

Crea `/tmp/jk-02-home/INVENTORY.md`. Debe tener **estas secciones** (el validador busca los encabezados):

- `## JENKINS_HOME layout` — tabla o lista con al menos estos elementos: `jobs/`, `workspace/`, `plugins/`, `users/`, `secrets/`, `nodes/`, `config.xml`. Para cada uno, una frase describiendo que contiene.
- `## Freestyle` — explica donde queda la configuracion de un Freestyle (ruta exacta `jobs/<name>/config.xml`), que incluye y por que no es versionable de forma util (al menos 3 razones concretas). Debe mencionar literalmente **`config.xml`**.
- `## Pipeline inline vs from SCM` — contrasta donde queda la logica en cada caso. Debe mencionar literalmente **`Jenkinsfile`** y **`Git`** (o `SCM`).
- `## Growth without retention` — enumera al menos **3** rutas o patrones de `$JENKINS_HOME` cuyo contenido crece sin limite sin retention/housekeeping (p. ej. `jobs/<j>/builds/`, logs del controller, `workspace/`, `caches/`). Explica el impacto operativo.
- `## Risks` — mapea al menos 3 riesgos observados (p. ej. perdida del volumen = perdida total; secretos en claro si se usa el modo basico; plugins acumulados = CVEs). Debe mencionar literalmente **`secrets`** o **`credentials`**.

> **No llames al archivo `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa `INVENTORY.md`.

### 5.4 Entregables

```
/tmp/jk-02-home/
└── INVENTORY.md
```

## 6. Resultado esperado

- `INVENTORY.md` presente con las 5 secciones obligatorias.
- Las menciones literales requeridas por el validador presentes (`config.xml`, `Jenkinsfile`, `Git` o `SCM`, `secrets` o `credentials`).
- Validador en verde.

## 7. Criterios de aceptacion

- **Completitud**: cubres los 7 elementos del layout minimo.
- **Correctitud conceptual** (autoevaluacion): compara con `solution/REFERENCE.md`.
- **Razonamiento**: las 3 razones de "Freestyle no versionable" y las 3 rutas de "growth without retention" son concretas, no generales.
- **Mantenibilidad del documento**: lenguaje claro, sin volcar binarios ni secretos reales.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/jk-02-home
```

El validador comprueba:

- `INVENTORY.md` existe.
- Secciones obligatorias presentes.
- Menciones minimas de `config.xml`, `Jenkinsfile`, `Git`/`SCM`, `secrets`/`credentials`.
- Enumeracion de al menos 3 elementos del layout dentro de `## JENKINS_HOME layout`.
- Si Docker esta disponible y hay un contenedor `jenkins` running: comprueba que `/var/jenkins_home` existe en el contenedor (sanity). Si no, marca ese chequeo como `SKIP`.

## 9. Preguntas de reflexion

1. Si tu `$JENKINS_HOME` fuera un repo Git, ¿que archivos deberian estar en `.gitignore`?
2. ¿Que ganas y que pierdes al mover la configuracion global del controller fuera de `config.xml` hacia **JCasC** (ver `jk-06`)?
3. ¿Como implementarias backup y restore de `$JENKINS_HOME` sin parar el servicio? ¿Que te garantiza consistencia?
4. Si un Freestyle legacy tiene 10 "Execute shell" steps encadenados, ¿cual seria tu plan para portarlo a Pipeline sin perder funcionalidad?
5. ¿Por que `secrets/` contiene archivos binarios y no es trivial copiarlos a otro Jenkins incluso con el mismo `credentials.xml`?

## 10. Extensiones

- Escribe un `Makefile` o script `backup.sh` que haga `tar.gz` del `$JENKINS_HOME` excluyendo `workspace/` y `caches/`.
- Documenta las 10 rutas mas pesadas de tu `$JENKINS_HOME` (`du -sh ...`) y propone una politica de retention.
- Lee `jenkins.model.JenkinsLocationConfiguration.xml` y explica que configuracion contiene y por que es relevante para webhooks.

## 11. Limpieza

```bash
rm -rf /tmp/jk-02-home
```

No hay infraestructura que detener (si levantaste Jenkins en la actividad 01, puede quedarse para los proximos modulos).
