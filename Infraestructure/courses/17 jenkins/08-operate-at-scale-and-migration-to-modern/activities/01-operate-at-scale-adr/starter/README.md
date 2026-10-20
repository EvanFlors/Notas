# Starter — jk-08-01-operate-at-scale-adr

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un ADR Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo y recorre `../../examples/01-jenkins-ha-pattern/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/jk-08-01
   cd /tmp/jk-08-01
   ```
3. Crea `ADR-OPERATE-AT-SCALE.md` con las 6 secciones requeridas:
   - Estado, Contexto, Decisión, Consecuencias, Alternativas (y el encabezado ADR).
4. Incluye en la Decisión al menos:
   - Diagrama ASCII del patrón HA (dentro de un code fence).
   - Patrón elegido (`activo-pasivo` / `CloudBees` / `Operator`) y justificación.
   - Estrategia de backup (`JENKINS_HOME`, `secrets/master.key`, destino Velero/S3, frecuencia).
   - Cadencia LTS y plugins.
   - Capacity: controller vs agents, nº ejecutores, ≥ 3 métricas de alerta.
   - JCasC como vehículo de reproducibilidad.
   - SLA objetivo y compliance de retención 7 años.
5. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/jenkins/08-operate-at-scale-and-migration-to-modern/activities/01-operate-at-scale-adr/tests/validate.sh /tmp/jk-08-01
   ```
6. Compara tu ADR con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador comprueba estructura, no semántica. La corrección conceptual la revisas tú contra la referencia.

## Plantilla sugerida (opcional)

```markdown
# ADR 001 — Operación a escala del Jenkins corporativo

## Estado
Propuesto

## Contexto
<4 años en VM, 120 pipelines, 15 agents, SLA 99.5%, retención 7 años,
sin presupuesto CloudBees, EKS corporativo disponible...>

## Decisión

### 1. Patrón HA
<Jenkins Operator en EKS + activo-pasivo manual con hot-standby apagado...>

```text
<diagrama>
```

### 2. Backup del JENKINS_HOME
- Qué: config, jobs, credentials, secrets/master.key, users, plugins.
- Dónde: Velero → S3 object-locked, retención 7 años.
- Frecuencia: diaria + horaria incremental.
- Prueba restore: mensual.

### 3. Upgrade cadence
- Patch LTS: 1 semana.
- Minor LTS: 1 mes.
- Max atrás: 2 LTS.

### 4. Capacity
- Controller 4 vCPU / 8 GB, executors=0.
- Agents en K8s plugin, podTemplate por lenguaje.
- Ejecutores objetivo: ...

### 5. Observabilidad
- Métricas: jenkins_queue_depth, executor_in_use_count, heap_used_ratio.
- Alertas: ...

## Consecuencias
### Positivas
...
### Negativas
...

## Alternativas descartadas
### Alt A: seguir en VM sin K8s
...
### Alt B: CloudBees CI
...
```
