# Ejemplo 01 — Levantar Jenkins local con Docker

> Lectura y referencia reproducible. Comandos para arrancar Jenkins con la imagen oficial `jenkins/jenkins:lts`, obtener el admin password y hacer el tour minimo de UI.

## 1. Precondiciones

- Docker Engine instalado y en ejecucion (`docker version` responde).
- Puerto `8080` libre en el host (o cambialo en el `-p` del `docker run`).
- 2 GB de RAM libres como minimo para el controller.

## 2. Levantar el controller

```bash
# Volumen persistente para JENKINS_HOME
docker volume create jenkins_home

# Arranque del controller
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts

# Esperar a que arranque (unos 20-60 segundos)
docker logs -f jenkins
# Ctrl+C cuando veas "Jenkins is fully up and running"
```

- `-p 8080`: UI web y API REST.
- `-p 50000`: inbound agent protocol (JNLP); no necesario para este modulo pero se expone por completitud.
- `-v jenkins_home:/var/jenkins_home`: el **estado completo** de Jenkins vive aqui.

## 3. Obtener el admin password

El wizard de primera arranque pide una contrasena generada automaticamente:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Copia esa cadena. Es de **un solo uso** — tras completar el wizard deja de ser valida.

## 4. Setup wizard

Abre `http://localhost:8080` en el navegador y sigue:

1. **Unlock Jenkins**: pegar el `initialAdminPassword`.
2. **Customize Jenkins**: elegir **Install suggested plugins** (en prod se elegirian solo los necesarios; para este modulo didactico vale la suite).
3. **Create First Admin User**: usuario, password, email (p. ej. `admin / admin / admin@example.com`). Guarda esas credenciales.
4. **Instance Configuration**: dejar el URL por default (`http://localhost:8080/`).

Jenkins te deja en la **Dashboard** vacia.

## 5. Tour minimo de UI

Visita estas rutas para familiarizarte:

- **Dashboard** → `http://localhost:8080/`
- **New Item** → `http://localhost:8080/view/all/newJob` (crear jobs)
- **Manage Jenkins** → `http://localhost:8080/manage`
  - **System**: `http://localhost:8080/manage/configure`
  - **Plugins**: `http://localhost:8080/manage/pluginManager/`
  - **Nodes**: `http://localhost:8080/manage/computer/`
  - **Credentials**: `http://localhost:8080/manage/credentials/`
  - **Security**: `http://localhost:8080/manage/configureSecurity/`
- **People** → `http://localhost:8080/asynchPeople/`
- **Build Queue** y **Build Executor Status** → barra lateral izquierda de la Dashboard.

## 6. Verificaciones rapidas desde el host

```bash
# Container en ejecucion
docker ps --filter name=jenkins --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# Version de Jenkins instalada (via header HTTP)
curl -sI http://localhost:8080 | grep -i '^x-jenkins'

# Layout minimo de JENKINS_HOME
docker exec jenkins ls /var/jenkins_home | head -20
```

Deberias ver subdirectorios como `jobs/`, `workspace/`, `plugins/`, `users/`, `secrets/`, `nodes/`, `logs/`, y archivos como `config.xml`, `jenkins.model.JenkinsLocationConfiguration.xml`, `credentials.xml`.

## 7. Apagar y limpiar (opcional)

```bash
# Parar
docker stop jenkins

# Eliminar el contenedor (el volumen y el estado se conservan)
docker rm jenkins

# Borrar tambien el estado (DESTRUCTIVO)
docker volume rm jenkins_home
```

> **Idea clave:** mientras el volumen `jenkins_home` exista, puedes recrear el contenedor cuando quieras (incluso con una version LTS mas nueva) y recuperas tu Jenkins exacto. Si borras el volumen, pierdes jobs, credenciales y plugins.
