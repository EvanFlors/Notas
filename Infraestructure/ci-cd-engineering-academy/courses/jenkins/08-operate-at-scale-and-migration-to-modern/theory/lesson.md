# jk-08 — Lección: operar a escala y migrar a herramientas modernas

> 10 secciones. Mayoritariamente conceptual. Prerrequisitos: `jk-04`, `jk-06`, `jk-07`.

---

## 1. El controller es un single-point-of-failure por diseño

Jenkins nació en 2004 como una herramienta de un equipo pequeño; su arquitectura refleja esa época:

- **Un único controller** mantiene el estado: configuración, jobs, builds queue, credentials, locks, user sessions.
- **N agents** se conectan al controller y ejecutan el trabajo real.

El controller es un **monolito con estado en disco** (`$JENKINS_HOME`). Si cae, cae **todo**:

- La UI no responde.
- Los agents siguen ejecutando lo que ya tenían asignado, pero al terminar no saben qué hacer y la queue se congela.
- Nuevos webhooks de Git se pierden si no hay reintentos externos.
- Los *locks* globales (`lock('resource')`) desaparecen; si el controller vuelve y los pipelines reintentan, pueden pisarse.

Esto no es un bug — es el modelo. Hay tres maneras de convivir con ello:

1. **Aceptar la ventana de caída** (minutos a horas) y optimizar **MTTR**: backup rápido + restore automatizado.
2. **Pagar CloudBees CI** (fork comercial): ofrece HA real a nivel de controller (activo-pasivo gestionado por el producto) y *multi-controller operations* (varios controllers por equipo bajo un *operations center*).
3. **Usar Jenkins Operator en Kubernetes** (CRD + reconciliation loop): no te da HA del controller, pero sí re-provisión automática desde `jenkins.yaml` (JCasC) tras una caída — recortas MTTR a minutos.

> **Trampa habitual**: anunciar "99.9% uptime" sin ninguna de las tres estrategias arriba. El modelo single-controller **impide** 99.9% real; lo máximo que da un activo-pasivo manual bien hecho es ~99.5%.

---

## 2. Backup del `JENKINS_HOME`: lo único que importa restaurar

Todo el estado de Jenkins vive en `$JENKINS_HOME`. Un backup correcto implica:

- **Qué incluir**:
  - `config.xml` del controller.
  - `jobs/<name>/config.xml` (freestyle) y `jobs/<name>/builds/*` (historial de ejecuciones + logs si quieres retención).
  - `credentials.xml` (cifrado con la master key del controller).
  - `secrets/` (incluye `master.key` y `hudson.util.Secret` — **sin estas dos, los credentials no se descifran en el restore**).
  - `users/`, `nodes/`, `plugins/*.jpi`.
  - `jenkins.yaml` (JCasC) si lo usas.
- **Qué excluir**:
  - `workspace/` (datos efímeros de builds — se recrea).
  - `caches/`, `war/` (regenerables).
  - Logs antiguos si tienes retención gestionada aparte.
- **Dónde guardarlo**: fuera del mismo nodo. Buckets S3 con *versioning* + *object lock* (compliance). Si corres en K8s, **Velero** respalda `PersistentVolumes` y recursos Kubernetes a la vez.
- **Frecuencia**: diaria mínimo; incremental cada 1 h si el equipo depende de que los builds de ayer existan en el restore.
- **Prueba de restore**: una vez al mes, levantar un controller nuevo con el backup y comprobar que se puede entrar a la UI, que los credentials descifran y que un pipeline arranca. **Backup no probado = sin backup.**

Error típico: olvidar `secrets/master.key`. Al restaurar, los `credentials.xml` existen pero no se pueden leer. Resultado: todos los secrets hay que recrearlos a mano.

---

## 3. Upgrade cadence: LTS cada ~12 semanas, no "cuando acordemos"

Jenkins publica:

- **Weekly releases** (`jenkins/jenkins:latest`): no las uses en producción.
- **LTS releases** (`jenkins/jenkins:lts`): nueva LTS cada ~12 semanas (3 meses), con parches menores en medio (`2.479.1`, `2.479.2`, …).

**Regla operativa recomendada**:

- **Patch LTS** (p. ej. `2.479.1 → 2.479.2`): aplicar en **1 semana** desde la publicación. Son parches de seguridad y bugfixes.
- **Minor LTS** (p. ej. `2.479.x → 2.492.x`): aplicar en **1 mes** desde la publicación. Da tiempo para que plugins populares se actualicen a la nueva línea.
- **No** quedarse más de **2 LTS atrás**. A partir de ahí, upgrade sin saltos intermedios es doloroso y las notas de breaking changes se acumulan.

Lo mismo para **plugins**: pin versions en `plugins.txt`, PR semanal con `bumps`, revisión de changelog para los de riesgo (Credentials, Pipeline, Kubernetes). Un plugin con CVE sin parchear vive en el controller con permisos de **todo** — es el vector 1 de incidentes Jenkins reales.

**Pre-upgrade checklist** (mínimo):

1. Backup verificado del `JENKINS_HOME`.
2. Lectura del **changelog** de la versión destino (saltar breaking changes es el error más caro).
3. Upgrade primero en **staging controller** (un controller aparte, pequeño, con una copia reducida de la config).
4. **Ventana** anunciada: el controller se reinicia durante el upgrade; cualquier build en curso se corta (los agents pueden continuar según `durable task plugin`, pero no cuentes con ello).

---

## 4. Capacity planning: controller coordina, agents cargan

Dos cosas distintas:

- **Controller**: coordina. Su carga viene de UI/HTTP, webhooks, polling SCM, serialización de pipelines, scheduling. Dimensionado **sin ejecutores propios** (`executors = 0` en el controller — el controller **no** ejecuta builds; delega todo a agents).
  - CPU: 2–4 vCPU en orgs pequeñas; 8+ en grandes.
  - RAM: 4–8 GB con heap `-Xmx4g` como punto de partida; subir si ves GC pauses frecuentes.
  - Disco: SSD, ≥ 50 GB para `JENKINS_HOME`.
- **Agents**: ejecutan builds. Carga variable según workloads.
  - **Efímeros** (K8s plugin, Docker plugin): se crean por build y mueren. Imposible contaminar builds entre sí. **Preferido en 2026.**
  - **Permanentes** (SSH, JNLP inbound): persistentes. Útiles para builds que necesitan cache local (p. ej. gradle cache enorme).
  - **Cloud agents** (EC2/GCE/Azure): spawn automático según demanda.

**Fórmula aproximada de ejecutores**:

```
ejecutores_necesarios = (builds_por_hora * duracion_media_minutos / 60) * factor_pico
```

Con `factor_pico = 2` para absorber bursts (merge trenes de lunes por la mañana). Si pasas de ese número, los jobs esperan en queue (visible en `jenkins_queue_depth`).

**Síntomas de infra-dimensionado**:

- Queue depth > 10 sostenido durante > 15 min.
- `Executor idle %` del controller < 20% (controller saturado).
- Response time del `/api/json` > 2 s.
- Heap uso > 85% y GC old gen > 1/min.

---

## 5. Observabilidad: tres métricas que deben alertar

Jenkins expone métricas con el **Metrics plugin** (JVM, request latency, build durations) y, mejor, con el **Prometheus plugin** (scrape por un Prometheus corporativo).

**Alertas mínimas** (si te quedas con tres):

1. `jenkins_queue_depth > 10 for 15m` — hay más trabajo del que agents absorben.
2. `jenkins_executor_in_use_count / jenkins_executor_count > 0.9 for 10m` — saturación de ejecutores; builds esperarán.
3. `jvm_memory_heap_used_bytes / jvm_memory_heap_max_bytes > 0.85 for 10m` — controller a punto de OOM.

Alertas adicionales útiles pero no críticas: tiempo medio de build por job (detectar regresiones), `up{job="jenkins"} == 0` (controller caído — fuerza paging), ratio de build failures por hora (detectar entorno roto).

Dashboards obligatorios: queue depth histórica, builds/hora, tiempo p95 de build por pipeline crítico, uso de agents.

---

## 6. Decidir migración: no es un switch, es un proceso de meses

Migrar fuera de Jenkins no se decide un lunes. La pregunta correcta es:

> **"¿Qué pasa si Jenkins cae un viernes y necesitamos reconstruirlo? ¿Y si ese Jenkins tiene 400 pipelines freestyle sin versionado?"**

Si la respuesta genera miedo, estás ante **deuda operativa**, y la migración es la forma de amortizarla. Pero migrar mal es peor que no migrar.

**Framework de decisión**:

| Criterio | Peso |
|----------|------|
| ¿La mayoría de repos ya vive en una plataforma con CI integrado (GitHub, GitLab)? | Alto — favorece migrar al CI nativo. |
| ¿Hay > 100 pipelines freestyle sin versionado? | Alto — favorece migrar: freestyle es insostenible. |
| ¿Hay Shared Libraries con `src/*.groovy` + tests? | Medio contra — tienes activos reutilizables; evaluar portabilidad. |
| ¿El equipo tiene experiencia en el target (GHA/GitLab/Argo)? | Alto — si no, hay curva de aprendizaje; planificar formación. |
| ¿Los pipelines dependen de plugins Jenkins muy específicos (p. ej. integraciones legacy)? | Medio contra — cada plugin es un bloqueador potencial. |
| ¿Compliance exige retener logs históricos N años? | Alto — plan de archivado obligatorio antes de apagar. |

**No migres si**:

- El Jenkins está sano, es reciente (<1 año desde la última LTS), tiene JCasC y los pipelines están en libraries versionadas. Migrar por moda es malgastar meses del equipo.
- No tienes un target claro. "Migrar a *lo que sea*" es garantía de desastre.

**Migra si**:

- El Jenkins es snowflake (no reproducible), freestyle, con plugins sin pinnear y con un equipo que lo vive como carga.
- Hay un target natural (GHA porque todos los repos están en GitHub, por ejemplo) con el equipo ya expuesto a él.
- Las ventajas (OIDC federation al cloud, reusable workflows, UI moderna, auditoría integrada) resuelven dolores reales.

---

## 7. Inventario y clasificación: migrar / consolidar / retirar

Primera fase operativa de la migración. Antes de tocar nada:

1. **Inventario completo** de pipelines:
   - Freestyle y pipeline.
   - Shared libraries y sus consumers.
   - Credentials usados (cuáles son secrets reales, cuáles son placeholders).
   - Agents / podTemplates referenciados.
   - Webhooks externos que apuntan al controller.
   - Artefactos publicados (dónde van: Artifactory, Nexus, S3).

2. **Clasificación por fila**:

| Clase | Criterio | Acción |
|-------|----------|--------|
| **Retirar** | Job sin runs en 90 días; o duplicado de otro; o apunta a un repo archivado. | Borrar o archivar su `config.xml` fuera del controller. **No migrar.** |
| **Consolidar** | 5 jobs hacen lo mismo con parámetros ligeramente distintos. | Unificar en 1 pipeline parametrizado antes de migrar. |
| **Migrar** | Job activo, con uso real, sin duplicados. | Target definido; estimar esfuerzo. |

> Regla de dedo: **el 20–40% de los jobs en un Jenkins con años encima son candidatos a retirar.** No migres el peso muerto; es trabajo tirado.

3. **Priorización** por **impacto × facilidad**:
   - Primero: pipelines simples y críticos (prueban que el target funciona en producción).
   - Después: pipelines complejos pero no críticos (absorben la curva de aprendizaje sin riesgo).
   - Último: pipelines complejos y críticos (requieren dual-run largo y gates manuales).

---

## 8. Dual-run: la red de seguridad

**Dual-run** = ejecutar el **mismo pipeline** en Jenkins **y** en el target en paralelo durante N semanas. Comparar salidas. Solo cuando el target es verde consistente, declarar ganador y apagar el Jenkins para ese pipeline.

Mecánica:

```
Push a Git
   │
   ├──► Webhook a Jenkins   ──► Jenkinsfile          ──► artefacto Jenkins
   │
   └──► Workflow GHA/GitLab ──► .github/workflows/*  ──► artefacto nuevo
                                                           │
                                                           └──► comparar
```

**Qué comparar**:

- **Resultado**: ambos verde / ambos rojo. Divergencia = investigar.
- **Artefacto**: hash del binario / imagen / zip. Debe ser **bit-a-bit** idéntico en builds reproducibles (es señal de que no hay drift). En builds no reproducibles (p. ej. timestamp inside), comparar **contenido lógico** (lista de archivos + hash de cada uno excluyendo metadatos).
- **Duración**: no debe degradarse más de 2× respecto a Jenkins (si pasa, el target no está dimensionado).
- **Logs**: errores comunes que aparecen solo en uno (p. ej. "secret not available" porque OIDC no se configuró bien).

**Duración mínima**: 2–4 semanas de dual-run para pipelines no críticos; 4–8 para críticos. **No negociable para producción.**

**Cuándo declarar ganador**:

- 100% de runs del target en verde consistente con Jenkins.
- Comparación de artefactos pasa.
- El equipo que mantiene el pipeline dice "ya no quiero tocar el Jenkinsfile".
- Hay un `rollback button` documentado (reactivar el webhook a Jenkins si el target falla).

---

## 9. OIDC federation: adiós a `withCredentials` de larga duración

Un cambio técnico que **justifica por sí solo** migrar a GHA/GitLab modernos: el reemplazo de **AWS access keys (o GCP service account keys, o Azure SP secrets) de larga duración** por **OIDC federation**.

En Jenkins clásico:

```groovy
withCredentials([usernamePassword(credentialsId: 'aws-prod-deployer',
                                   usernameVariable: 'AWS_ACCESS_KEY_ID',
                                   passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
  sh 'aws s3 cp build.zip s3://prod-releases/'
}
```

Problemas:

- Key de larga duración, rotación manual, filtra en logs si el pipeline la imprime por error.
- Compromiso del controller = compromiso de la key.

En GHA con OIDC:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions-deployer
          aws-region: eu-west-1
      - run: aws s3 cp build.zip s3://prod-releases/
```

AWS confía en el OIDC provider de GitHub, el workflow genera un JWT firmado por GitHub, AWS lo valida, devuelve credenciales temporales STS. **No hay secreto almacenado.** Rotación automática (el JWT dura segundos). Scope controlable por `sub` claim (repo, branch, environment).

Lo mismo con GitLab (`CI_JOB_JWT_V2`) y con Argo Workflows (via `IRSA` en EKS, `Workload Identity` en GKE).

**Durante la migración**, aprovecha: no portes credentials — rediséñalos a OIDC desde el día uno en el target.

---

## 10. Cuándo apagar Jenkins: criterios de corte y archivado

El error común: dejar el Jenkins encendido "por si acaso" durante años después de migrar. Resultado: costo residual, superficie de ataque, un día alguien lo descubre con CVEs sin parchear y se enciende la alarma.

**Criterios para apagar un controller**:

1. **Todos los pipelines** declarados `migrados` llevan ≥ 4 semanas sin ejecutarse en Jenkins (solo en el target).
2. **Historial archivado**: logs y artefactos de builds relevantes exportados a storage de largo plazo (S3 Glacier con policy de retención, o similar). Compliance firma.
3. **Shared libraries archivadas**: los repos de las libraries se marcan read-only; el reusable workflow / Component equivalente queda como su reemplazo documentado.
4. **Webhooks externos** reconfigurados: ya ninguno apunta al Jenkins.
5. **Credentials de larga duración rotados y revocados** (los que no se migraron a OIDC se desactivan en el cloud antes de apagar).
6. **DNS**: el nombre `jenkins.<empresa>` se mantiene redirigido 30 días a una página "Jenkins fue migrado — ir a <target>" antes de borrarse.

**Procedimiento de apagado**:

1. Último backup verificado del `JENKINS_HOME`.
2. Deshabilitar nuevos builds (`Prepare for Shutdown` en la UI).
3. Esperar a que la queue drene.
4. Snapshot del volumen → storage de largo plazo.
5. Apagar el controller.
6. 30 días en standby (sin servir tráfico, pero recuperable).
7. Borrar la infra.

**Qué conservar para siempre**: el **ADR de migración** (este módulo lo produce). Es el registro histórico de qué se migró, cuándo, por qué y bajo qué criterios de éxito. Dentro de 3 años, cuando aparezca un auditor preguntando "¿por qué dejaste de usar Jenkins y cómo garantizas que no se perdieron logs?", el ADR responde.

---

## Qué llevarse en una frase

> Jenkins es **inercia operativa**, no un sistema inmortal. Operarlo bien es aceptar el controller como SPOF y mitigarlo con backup + MTTR corto. Migrar bien es **inventariar, clasificar, dual-run y apagar con criterios de corte explícitos y un ADR que sobreviva al propio Jenkins**.

## Qué sigue

Este es el último módulo del curso Jenkins. Para profundizar en el target:

- `github-actions` — reusable workflows, OIDC a AWS/GCP/Azure, environments, matrix strategies.
- `gitlab-cicd` — CI/CD Components, dynamic child pipelines, OIDC federation.
- `argocd-gitops` — Argo Workflows / Rollouts, GitOps real.
