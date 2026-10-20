# Actividad 02 — Añadir un gate manual al pipeline

## 1. Identificación

- **ID:** `jk-03-02-add-manual-gate`
- **Tecnología:** `jenkins`
- **Módulo:** `jk-03-declarative-pipeline-jenkinsfile`
- **Dificultad:** intermediate
- **Duración estimada:** 50–70 min
- **Tipo:** independent

## 2. Contexto

El pipeline de `jk-03-01` despliega a staging automáticamente, pero el deploy a **prod** sigue siendo manual: alguien ejecuta un script a mano. El objetivo es llevar ese gate manual al propio `Jenkinsfile` usando `input`, con las dos salvaguardas obligatorias:

- **`timeout`** envolviendo el `input` para que un build olvidado no quede colgado consumiendo un executor.
- **`post { aborted { ... } }`** para manejar limpiamente el camino en el que nadie aprueba.

Como extra, el gate debe restringirse a un **grupo** de usuarios con `submitter` (p. ej. `release-managers`), no abrirse a cualquiera.

**Importante**: no hay Jenkins corriendo. El entregable es un **archivo `Jenkinsfile`** con el gate añadido. El validador comprueba la estructura.

## 3. Objetivos

Al terminar deberías poder:

- Insertar un `stage('Approve prod deploy')` con `input` entre `Deploy staging` y `Deploy prod`.
- Envolver el `input` en `timeout(time: X, unit: 'MINUTES')`.
- Restringir el aprobador con `submitter: 'release-managers'`.
- Filtrar el stage con `when { branch 'main' }` para que no aparezca en PRs ni en ramas feature.
- Añadir `post { aborted { ... } }` para notificar o limpiar cuando el gate expira o se cancela.

## 4. Prerrequisitos

- Haber completado `jk-03-01` (o tomar su `solution/Jenkinsfile` como punto de partida).
- Haber leído `../../theory/lesson.md` (§9).
- Herramientas: `bash`, `grep`. **No** hace falta Jenkins arrancado.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/jk-03-02
cp ../01-port-gha-workflow-to-jenkinsfile/solution/Jenkinsfile /tmp/jk-03-02/Jenkinsfile
# (o copia tu propio Jenkinsfile de la actividad 01)
cd /tmp/jk-03-02
```

### 5.2 Añade el gate manual

Edita `/tmp/jk-03-02/Jenkinsfile` para que:

1. Exista un stage **nombrado exactamente** `stage('Approve prod deploy')` entre `Deploy staging` y un nuevo `Deploy prod`.
2. Dentro del stage, haya un `timeout(time: ..., unit: 'MINUTES')` envolviendo un `input`.
3. El `input` incluya:
   - `message:` con un texto humano ("¿Desplegar a producción?").
   - `ok:` con el label del botón ("Desplegar").
   - `submitter:` restringiendo a un grupo (p. ej. `release-managers`).
4. El stage tenga `when { branch 'main' }`.
5. Exista un `stage('Deploy prod')` **después** del gate, también con `when { branch 'main' }`, que ejecute el despliegue a prod (puedes reutilizar el patrón `kubectl` con otra credencial `kubeconfig-prod`).
6. El bloque `post { }` del pipeline incluya `aborted { ... }` para manejar el caso en que el gate expire o se cancele.

### 5.3 Entregables

```
/tmp/jk-03-02/
└── Jenkinsfile
```

Un único archivo. El validador no exige nada más.

## 6. Resultado esperado

El validador imprime `OK` para cada chequeo y termina con `0 issue(s)`.

```bash
bash tests/validate.sh /tmp/jk-03-02
```

## 7. Criterios de aceptación

- **Estructural**: validador en verde (`0 issue(s)`).
- **Semántico** (autoevaluación): el gate aparece sólo en `main`, exige aprobación de un grupo nombrado, no cuelga builds indefinidamente, y el `aborted` se maneja. Comparar con `solution/REFERENCE.md`.
- **Mantenibilidad**: `timeout` razonable (10–30 min, no 7 días), `message` claro, `submitter` apuntando a un grupo real (no a un usuario individual).

## 8. Validación

```bash
bash tests/validate.sh /tmp/jk-03-02
```

El validador es estructural: busca con `grep` las construcciones exigidas (`input`, `timeout`, `submitter`, `when`, `post { aborted }`). **No** ejecuta el pipeline.

## 9. Preguntas de reflexión

1. ¿Qué pasa si olvidas el `timeout` y el gate queda esperando una semana? ¿Qué recurso del controller se consume?
2. ¿Por qué `submitter: 'release-managers'` es más seguro que `submitter: 'alice'`?
3. Si el `input` expira, ¿el `post { success }` se ejecuta? ¿Y `post { failure }`? ¿Y `post { aborted }`?
4. Un desarrollador propone usar `input` sin `when`, para que el gate aparezca también en PRs. ¿Qué problema tiene eso?
5. ¿Cómo auditarías *quién* aprobó un deploy a prod seis meses después?

## 10. Extensiones

- Añade un `parameters { choice(name: 'DEPLOY_STRATEGY', ...) }` que se consulte en el `input` (pista: el `input` puede llevar `parameters: [...]` propios y devolver un `Map`).
- Captura el aprobador con `script { def who = input(...) ; echo "Aprobado por ${who}" }` y escríbelo en un artefacto de auditoría con `archiveArtifacts`.
- Añade un *post-deploy health check* automático tras `Deploy prod` que, si falla, lance un rollback.

## 11. Limpieza

```bash
rm -rf /tmp/jk-03-02
```

No hay infraestructura que detener.
