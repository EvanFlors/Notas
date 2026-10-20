# Ejemplo 02 — Freestyle "hello world" (y su `config.xml`)

> Lectura y referencia. Reproduce un Freestyle minimo para **ver con tus ojos** donde queda su configuracion y por que no es versionable.

## 1. Precondiciones

- Jenkins local funcionando (ver `../01-jenkins-docker-up/`).
- Sesion iniciada como admin.

## 2. Crear el Freestyle job por UI

1. Dashboard → **New Item**.
2. Nombre: `freestyle-hello`.
3. Tipo: **Freestyle project** → **OK**.
4. En la configuracion del job:
   - **Description**: `Hello world freestyle (ejemplo didactico)`.
   - **Build Steps** → **Add build step** → **Execute shell** → pegar:

     ```bash
     echo "hello"
     uname -a
     ```
5. **Save**.

En la pagina del job, pulsar **Build Now**. En **Build History** aparece `#1`. Al abrirlo, en **Console Output** se ve:

```
Started by user admin
...
+ echo hello
hello
+ uname -a
Linux ... Linux
Finished: SUCCESS
```

## 3. Donde quedo guardada esa configuracion

```bash
# Ruta canonica dentro del controller
docker exec jenkins ls /var/jenkins_home/jobs/freestyle-hello/

# El unico archivo que define el job
docker exec jenkins cat /var/jenkins_home/jobs/freestyle-hello/config.xml
```

Veras algo asi:

```xml
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <actions/>
  <description>Hello world freestyle (ejemplo didactico)</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class="hudson.scm.NullSCM"/>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers/>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell>
      <command>echo &quot;hello&quot;
uname -a</command>
      <configuredLocalRules/>
    </hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
```

Observaciones:

- La **unica** fuente de verdad del job es este XML dentro del controller.
- No esta en Git. Un cambio en la UI reescribe el XML sin audit trail util.
- Para "versionar" tendrias que exportar manualmente el XML a un repo, con todas las limitaciones (no portatil entre versiones de plugins, no diffeable razonablemente).

## 4. Inspeccion del historial de builds

```bash
docker exec jenkins ls /var/jenkins_home/jobs/freestyle-hello/builds/
# 1  lastFailedBuild -> ...  lastStableBuild -> 1  lastSuccessfulBuild -> 1  legacyIds  permalinks

docker exec jenkins cat /var/jenkins_home/jobs/freestyle-hello/builds/1/log
# log de consola del build #1

docker exec jenkins ls /var/jenkins_home/workspace/freestyle-hello/
# workspace del job (vacio en este caso, no hay checkout)
```

## 5. Por que esto es anti-patron

| Problema | Consecuencia practica |
|----------|------------------------|
| `config.xml` fuera de Git | nadie puede hacer code review de un cambio del job |
| XML con defaults implicitos | diff entre dos jobs es inutilmente ruidoso |
| Dependencia de plugins instalados | mover el job a otro Jenkins rompe si falta un plugin |
| Sin lint | solo descubres errores al ejecutar |
| Sin reutilizacion | para N jobs similares, N configuraciones duplicadas |

El ejemplo siguiente (`03-pipeline-hello-world`) hace **el mismo "hello world"** pero con un `Jenkinsfile` versionado.

## 6. Limpieza

Puedes borrar el job desde la UI (**Delete Project**) o:

```bash
docker exec jenkins rm -rf /var/jenkins_home/jobs/freestyle-hello
```

y recargar la configuracion desde `Manage Jenkins > Reload Configuration from Disk`.
