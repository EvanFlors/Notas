# Ejemplo 03 — Pipeline "hello world" (`Jenkinsfile` declarative)

> Lectura y referencia. Mismo "hello world" del ejemplo 02, pero expresado como `Jenkinsfile` declarative. Mismo output, modelo opuesto: la logica vive en Git, no en `config.xml`.

## 1. Precondiciones

- Jenkins local funcionando (ver `../01-jenkins-docker-up/`).
- Sesion iniciada como admin.

## 2. Variante A — Pipeline script inline (prototipado)

Util para probar sintaxis sin crear un repo. **No es la forma recomendada en prod**: la logica queda otra vez en `config.xml`.

1. Dashboard → **New Item**.
2. Nombre: `pipeline-hello-inline`.
3. Tipo: **Pipeline** → **OK**.
4. En la configuracion:
   - **Pipeline** → **Definition**: `Pipeline script`.
   - **Script**: pegar el siguiente `Jenkinsfile`:

```groovy
pipeline {
    agent any

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {
        stage('Hello') {
            steps {
                echo 'hello'
                sh 'uname -a'
            }
        }
    }

    post {
        always {
            echo "Finished with status: ${currentBuild.currentResult}"
        }
    }
}
```

5. **Save** → **Build Now**.

En **Console Output** veras los mismos `hello` y `uname -a` del ejemplo 02. En la vista **Pipeline Overview** (o Blue Ocean si lo instalaste) veras el `stage('Hello')` como un rectangulo verde.

## 3. Variante B — Pipeline script from SCM (recomendada)

La **unica** variante que vale en produccion: Jenkins clona un repo Git y lee el `Jenkinsfile` desde ahi.

Pasos (requiere un repo Git accesible por Jenkins, puede ser GitHub, GitLab, Bitbucket o un repo local servido por `git daemon`):

1. Guarda el `Jenkinsfile` anterior en la raiz de un repo Git.
2. Commit + push a una rama (p. ej. `main`).
3. En Jenkins, **New Item** → `pipeline-hello-scm` → **Pipeline** → **OK**.
4. En la configuracion:
   - **Pipeline** → **Definition**: `Pipeline script from SCM`.
   - **SCM**: `Git`.
   - **Repository URL**: la URL del repo.
   - **Credentials**: ninguna si es publico; sino una credencial creada en `Manage Jenkins > Credentials`.
   - **Branches to build**: `*/main`.
   - **Script Path**: `Jenkinsfile` (por default).
5. **Save** → **Build Now**.

Jenkins hace el `git clone` en el workspace, lee el `Jenkinsfile` y lo ejecuta. A partir de aqui, **cada cambio del pipeline es un PR** en el repo del codigo.

## 4. Anatomia del `Jenkinsfile` minimo

```groovy
pipeline {                       // (1) Declarative wrapper obligatorio
    agent any                    // (2) Agent: cualquier executor libre

    options {                    // (3) Opciones del pipeline
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {                     // (4) Lista de stages visibles en la UI
        stage('Hello') {         // (5) Un stage por caja en el pipeline graph
            steps {              // (6) Los pasos reales
                echo 'hello'
                sh 'uname -a'
            }
        }
    }

    post {                       // (7) Acciones por resultado final
        always {
            echo "Finished with status: ${currentBuild.currentResult}"
        }
    }
}
```

1. **`pipeline`**: wrapper obligatorio de Declarative. Si falta, Jenkins lo trata como Scripted (ver `jk-04`).
2. **`agent`**: `any` = cualquier executor libre. En `jk-03` veremos `agent { docker ... }` y `agent none`.
3. **`options`**: `timestamps` prefija cada linea del log con un timestamp; `buildDiscarder` configura la retention por job (sin esto, `JENKINS_HOME` crece sin limite).
4. **`stages`**: la lista. Vacio no vale.
5. **`stage`**: nombre humano (lo que ve el usuario en la UI).
6. **`steps`**: los pasos reales. `echo` imprime; `sh` ejecuta un shell en Linux/macOS (`bat` en Windows).
7. **`post`**: `always` corre siempre; otras condiciones (`success`, `failure`, `unstable`, `changed`, `fixed`) en `jk-03`.

## 5. Verificar el pipeline sin ejecutarlo (lint opcional)

Si tienes la **CLI de Jenkins** y el **declarative-linter** disponibles, puedes validar sintaxis sin ejecutar:

```bash
# Descargar jenkins-cli.jar
curl -sO http://localhost:8080/jnlpJars/jenkins-cli.jar

# Validar el Jenkinsfile
java -jar jenkins-cli.jar \
  -s http://localhost:8080/ \
  -auth admin:<API_TOKEN> \
  declarative-linter < Jenkinsfile
# Output esperado: "Jenkinsfile successfully validated."
```

`<API_TOKEN>` se genera en `People > admin > Configure > API Token`.

Este linter es **opcional** en este modulo (se profundiza en `jk-03`). Las actividades no requieren tenerlo activo — validan estructuralmente el texto del `Jenkinsfile`.

## 6. Donde queda guardado el pipeline

- Variante A (inline): otra vez en `JENKINS_HOME/jobs/pipeline-hello-inline/config.xml`, dentro del elemento `<definition class="...CpsFlowDefinition"><script>...</script>`. **Mismo problema que Freestyle**.
- Variante B (SCM): el `config.xml` solo apunta al repo. **La logica real vive en Git**. Si pierdes el Jenkins, el pipeline existe igual.

> **Idea clave:** "Pipeline" no es automaticamente mejor que "Freestyle"; **"Pipeline script from SCM" es mejor que ambos**. La variante inline es un paso intermedio didactico.

## 7. Limpieza

Desde la UI (**Delete Pipeline**) o:

```bash
docker exec jenkins rm -rf /var/jenkins_home/jobs/pipeline-hello-inline
docker exec jenkins rm -rf /var/jenkins_home/jobs/pipeline-hello-scm
```

y `Manage Jenkins > Reload Configuration from Disk`.
