# Starter — jk-05-01-run-pipeline-on-k8s-agent

Esta actividad es **guiada**: hay plantillas de referencia en `../README.md` secciones 5.2 y 5.3. Debes producir dos archivos: `podTemplate.yaml` y `Jenkinsfile`.

## Pasos

1. Lee `../README.md` completo y recorre los ejemplos `01-k8s-plugin-podtemplate` y `02-multi-container-agent` del módulo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/jk-05-k8s-agent
   cd /tmp/jk-05-k8s-agent
   ```
3. Crea `podTemplate.yaml` con:
   - `apiVersion: v1`, `kind: Pod`, `spec.restartPolicy: Never`.
   - Contenedor `jnlp` con imagen `jenkins/inbound-agent:*`.
   - Al menos un contenedor de build con `sleep infinity` y `resources` completos.
4. Crea `Jenkinsfile` con:
   - `pipeline { agent { kubernetes { yaml ... | yamlFile 'podTemplate.yaml' } } }`.
   - Al menos una `stage` dentro de `stages`.
   - Al menos un `container('nombre-build') { sh '...' }`.
5. Valida:
   ```bash
   bash <ruta-repo>/courses/jenkins/05-agents-distributed-builds-kubernetes-plugin/activities/01-run-pipeline-on-k8s-agent/tests/validate.sh /tmp/jk-05-k8s-agent
   ```
6. Compara con `../solution/` para autoevaluarte.

> **Opcional (kind)**: si tienes `kind` + `kubectl`, puedes probar el pipeline en un cluster local. El validador detecta su ausencia y emite `SKIP` sin fallar.
