# Ejemplo 02 — Árbol de decisión: brownfield vs greenfield

> Lectura y análisis. Sin ejecución. Objetivo: internalizar un **árbol de decisión** reproducible para "¿sigo con Jenkins, migro, o arranco greenfield en otra herramienta?".

## 1. Punto de partida

Ninguna decisión de tooling de CI/CD se toma por reflejo. Siempre hay **tres fuerzas**:

- **Legacy existente** (lo que ya corre y nadie quiere romper).
- **Costo recurrente** (lo que mantener cuesta cada año en personas, licencias, infra).
- **Costo de cambio** (lo que migrar o adoptar algo nuevo cuesta de una sola vez — y el riesgo asociado).

El árbol siguiente ordena esas fuerzas.

## 2. Árbol de decisión

```
                             ¿Hay Jenkins corriendo hoy?
                                       │
                     ┌─────────────────┴─────────────────┐
                     │                                   │
                    NO                                  SÍ
                     │                                   │
          GREENFIELD rama                     BROWNFIELD rama
                     │                                   │
   ┌─────────────────┴────────────────┐    ┌─────────────┴──────────────┐
   │                                  │    │                            │
¿Hay compliance                 ¿Repos en          ¿El Jenkins actual es
on-prem/air-gapped?             GitHub o            moderno (K8s plugin,
   │                            GitLab?             JCasC, Shared Libs,
   │                              │                 agents efímeros)?
   SÍ                             │                        │
   │                        ┌─────┴─────┐          ┌──────┴──────┐
   ▼                        │           │          │             │
Evaluar Jenkins          GitHub      GitLab        SÍ            NO
on-prem                     │           │          │             │
+ GHES/GitLab               ▼           ▼          │             ▼
self-managed              GHA        GitLab      Mantener     "Snowflake":
como alternativa          por        CI por      + evaluar    deuda crítica.
                          default    default     migración    Opciones:
                            │           │        en 12-24 m   (a) modernizar
                   ¿Workloads K8s        │                     primero,
                   puros (ML/data)?      │                    (b) migrar
                      │                  │                    por olas,
                 ┌────┴────┐             │                    (c) congelar
                SÍ         NO            │                     + build nuevo
                 │          │            │                     en paralelo
                 ▼          ▼            │                        │
          + Argo         Solo          +--+---+                   ▼
          Workflows      GHA         ¿Hay dolor      Decisión forzada:
          complementario              operativo       no mantener
                                      recurrente?    como está.
                                           │
                                      ┌────┴────┐
                                     SÍ         NO
                                      │          │
                                      ▼          ▼
                                  Plan de    Mantener,
                                  migración  revisar
                                  por olas   anualmente
```

## 3. Preguntas que ordenan el árbol

### 3.1 "¿Hay Jenkins corriendo hoy?"

- **NO** → arrancas limpio. Decisión por **SCM + workload** (ver 3.2).
- **SÍ** → la pregunta siguiente es cuánta deuda hay y qué tan moderno está.

### 3.2 "¿Dónde están los repos?"

- **GitHub** → GHA por default. Es gratis para empezar y la integración es nativa.
- **GitLab** → GitLab CI por default. Pipelines viven en el mismo producto que los MRs.
- **Bitbucket / otro** → caso particular; no cubierto aquí.

### 3.3 "¿Hay workloads K8s puros (ML, data, batch)?"

- **SÍ** → complementar con **Argo Workflows** o **Tekton**. CI/CD de apps "normales" puede seguir en GHA/GitLab. No forzar todo a Argo.
- **NO** → GHA/GitLab solo bastan.

### 3.4 "¿Hay compliance on-prem / air-gapped?"

- **SÍ** → opciones son **Jenkins self-hosted**, **GHES**, **GitLab self-managed**. Nunca SaaS externo.
- **NO** → SaaS por default (menor operación).

### 3.5 "¿El Jenkins actual es moderno?"

Checklist mínimo:

- Agents **efímeros** (K8s plugin o Docker), no VMs permanentes.
- **JCasC** aplicado: la config vive en `jenkins.yaml` versionado.
- **Shared Libraries** versionadas, con tests y CODEOWNERS.
- **Backup** del `JENKINS_HOME` verificado.
- **Plugins pinneados** y auditados; CVE lifecycle activo.
- Zero **freestyle** nuevo en últimos 24 meses.

Si tildas la mayoría → es un Jenkins defendible. Mantener + plan opcional.

Si fallas la mayoría → es un **snowflake**: no se reproduce, no se audita, no se parchea. Deuda crítica.

### 3.6 "¿Hay dolor operativo recurrente?"

Síntomas típicos:

- Builds que fallan por el controller sobrecargado.
- Plugins incompatibles bloqueando upgrades.
- Pipelines que "sólo funcionan en el agent Carlos-01".
- Tiempos de build que no bajan.
- Tickets de seguridad por CVEs de plugins varias veces al año.
- Equipo con rotación alta y nadie que entienda el Jenkins "entero".

Si varios → **plan de migración por olas**. Si ninguno → **mantener y revisar anualmente**.

## 4. Casos concretos

### Caso 1 — "Fundé mi startup la semana pasada"

- **No hay Jenkins** → rama greenfield.
- Repos en GitHub → **GHA** por default.
- Sin compliance on-prem.
- Sin workloads K8s puros.
- **Decisión**: GHA. Fin.

### Caso 2 — "Soy el nuevo DevOps lead del banco X"

- **Hay Jenkins** con 1200 jobs (brownfield).
- Mezcla declarative + freestyle + scripted; sin JCasC; 180 plugins; backup "esperemos que sí".
- Dolor operativo: builds de release fallan 1 de cada 5 ejecuciones.
- **Decisión**: no migrar inmediatamente. Primero, **modernizar** el Jenkins (JCasC + eliminar plugins no usados + migrar freestyle a pipeline + backup verificado). En paralelo, **inventario + clasificación**. A 18 meses: **plan de migración por olas** a GitLab CI (porque el SCM corporativo es GitLab self-managed).

### Caso 3 — "Equipo de ML plataforma, nuevo cluster K8s"

- No hay Jenkins.
- Repos en GitHub.
- Workloads K8s puros (training de modelos).
- **Decisión**: **Argo Workflows** para orquestar training; **GHA** para CI de las apps y de los Dockerfiles que corren encima.

### Caso 4 — "Tenemos un Jenkins moderno y funciona"

- Hay Jenkins con K8s plugin, JCasC, Shared Libraries, backup verificado.
- 300 jobs, todos pipeline, agents efímeros.
- Sin dolor operativo recurrente.
- **Decisión**: **mantener**. Revisar anualmente contra alternativas. **No migrar por moda**.

## 5. Qué llevarte

- El árbol **ordena preguntas**, no da respuestas. La respuesta la pones tú con los datos de tu empresa.
- **Nunca "sí/no"**. Siempre es "sí porque X, con plan Y, revisado en Z meses".
- La peor decisión no es "quedarse con Jenkins" ni "migrar"; es **no decidir** (seguir con la deuda sin plan).
- La actividad `01` te pide **aplicar este árbol** a un escenario y escribir el ADR.
