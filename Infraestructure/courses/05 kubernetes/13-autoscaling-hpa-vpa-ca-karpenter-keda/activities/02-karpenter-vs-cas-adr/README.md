# k8s-13-02 — ADR: Karpenter vs Cluster Autoscaler para EKS

## 1. Identificación

- **ID:** `k8s-13-02-karpenter-vs-cas-adr`
- **Tecnología:** `kubernetes`
- **Módulo:** `13-autoscaling-hpa-vpa-ca-karpenter-keda`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** architecture

## 2. Contexto

Tu equipo opera un cluster **EKS** en `us-east-1` con el siguiente perfil:

- **Workload mix:**
  - 30 microservicios web (ligeros, 100m–500m CPU por réplica).
  - 2 pipelines batch nocturnos pesados (jobs de 4–16 CPU, hasta 32 GiB).
  - 4 colas KEDA de workers I/O-bound.
  - 1 pool de inferencia GPU (`g5.xlarge`, 8 Pods/día).
- **Patrón de tráfico:** diurno Mon–Fri 08:00–20:00 Europe/Madrid con picos predecibles al abrir mercado (09:00) y cierre (17:30).
- **Carga spot aceptable:** sí para web y batch; **no** para inferencia GPU.
- **Topología:** 3 AZ activas; multi-AZ obligatorio.
- **Hoy:** Cluster Autoscaler con 3 ASGs (`web-amd64`, `batch-amd64`, `gpu`). Costo ~$8 500/mes. Scale-up medido ~90 s.
- **Problema reportado:** nodos infrautilizados, scale-down lento, no se aprovecha Graviton, imposible ajustar instance types sin redeployar los ASGs.

El equipo pide un ADR que **decida** entre:

- **Opción A:** mantener Cluster Autoscaler, modernizándolo (mixed instances policy, overprovisioning con priority classes, scale-down tuning).
- **Opción B:** migrar a **Karpenter v1**, consolidando ASGs en `NodePool`s.

La decisión debe quedar escrita como **Architecture Decision Record** siguiendo el formato Michael Nygard, con trade-offs numerados, impacto operacional y plan de rollback.

Esta actividad es **independiente**: no se te da la respuesta. El validador comprueba la *forma* y *presencia de secciones críticas* del ADR, no la decisión concreta.

## 3. Objetivos

- Producir un ADR estructurado en `docs/adr/0001-autoscaler-choice.md`.
- Comparar al menos **6 dimensiones** cuantificables (scale-up latency, bin packing, soporte spot, soporte GPU, consolidación, operabilidad, costo, dependencias cloud, madurez).
- Defender una decisión concreta (`Accepted: Karpenter` o `Accepted: Cluster Autoscaler modernized`).
- Describir impacto en Terraform/IaC, en IAM, en el proceso de upgrade de nodos.
- Documentar plan de rollback explícito.
- Incluir al menos **3 referencias** citables (docs oficiales, comparativas con fecha).

## 4. Prerrequisitos

- Conocimientos: `k8s-11` (control plane), `k8s-12` (RBAC), `k8s-09` (scheduling), lección de este módulo.
- Software: cualquier editor de texto. No se despliega infra.
- Dependencias: ninguna.
- Variables de entorno: ninguna.
- Permisos / cuentas: ninguna; el escenario es hipotético.
- Infraestructura: cero.
- **Costos potenciales:** cero.

## 5. Instrucciones

### 5.1 Preparar el workspace

```bash
export BASE_DIR=/tmp/k8s-13-02
mkdir -p "$BASE_DIR"
cp -r starter/* "$BASE_DIR"/
cd "$BASE_DIR"
```

El `starter/` incluye:

- `docs/adr/0000-template.md` — plantilla Nygard adaptada.
- `context/workload-inventory.md` — el inventario de workloads de §2 en forma de tabla.
- `context/sla-and-cost-targets.md` — SLOs y objetivos financieros a defender.

### 5.2 Investigar

Lee (como mínimo):

- Documentación oficial de **Karpenter v1**: concepts, disruption, consolidationPolicy.
- Documentación oficial de **Cluster Autoscaler** en EKS: `--balance-similar-node-groups`, `--expander`, mixed instances.
- Al menos un **post-mortem o case study** público donde alguien migró de CA a Karpenter (hay varios en el blog de AWS, Pinterest, Grafana Labs, Anthropic, etc.) con fecha visible.

Toma notas en `context/notes.md`. No se evalúa, pero te servirá para el ADR.

### 5.3 Escribir el ADR

Produce `docs/adr/0001-autoscaler-choice.md` siguiendo la plantilla. **Debes** incluir las secciones:

- `# ADR 0001:` (título)
- `## Status` (`Accepted` | `Proposed` | `Rejected` | `Superseded`)
- `## Context`
- `## Decision`
- `## Consequences`
- `## Alternatives` (al menos una alternativa comparada)
- `## Rollback Plan`
- `## References`

Y una tabla comparativa con **al menos 6 dimensiones**. Puedes usar la tabla del §7 de `theory/lesson.md` como punto de partida pero debes ampliarla con contexto propio.

### 5.4 Validar

```bash
cd "$BASE_DIR"
bash tests/validate.sh
```

El validador verifica que el ADR existe, tiene las secciones requeridas, decide (`Accepted` con un sujeto claro), compara ≥ 6 dimensiones, cita ≥ 3 fuentes y describe rollback.

## 6. Resultado esperado

- `docs/adr/0001-autoscaler-choice.md` con todas las secciones.
- Decisión defendida con números (no "parece mejor"; cuánto mejor, en qué dimensión).
- Validador en verde.

## 7. Criterios de aceptación

- **Estructura:** las 8 secciones requeridas presentes.
- **Comparación:** tabla con ≥ 6 filas de dimensiones, cada una con valor para A y B.
- **Decisión:** `## Status` dice `Accepted` seguido del nombre de la opción elegida.
- **Rollback:** plan concreto (no "revertir el commit"). Qué se hace si Karpenter dispara nodos infinitos; qué pasa con los Pods en vuelo.
- **Referencias:** ≥ 3 URLs o DOIs con fecha.
- **Reproducibilidad:** cualquier reviewer debería poder seguir la lógica sin preguntar al autor.

## 8. Validación

```bash
bash tests/validate.sh
```

Chequeos automáticos:

1. Existe `docs/adr/0001-autoscaler-choice.md`.
2. Secciones obligatorias presentes.
3. `## Status` empieza por `Accepted:`.
4. Tabla comparativa con ≥ 6 filas (`| ... | ... | ... |`).
5. ≥ 3 enlaces (`http://` o `https://`).
6. Sección `## Rollback Plan` con ≥ 100 caracteres de texto.

## 9. Preguntas de reflexión

1. Si tu organización decidiera multi-cloud (EKS + GKE) en 12 meses, ¿cambiaría tu decisión? ¿Cómo?
2. ¿Qué métrica operacional usarías para medir el éxito de la migración en los primeros 30 días?
3. ¿Qué le pedirías a Finanzas para calcular el ROI de la migración? ¿Cómo responderías si dicen "no vale el esfuerzo"?
4. Karpenter puede terminar un nodo spot a los 2 min de interrupt notice. ¿Qué protecciones (PDB, graceful shutdown, replicas mínimas) incorporas al workload antes de aceptar la migración?

## 10. Extensiones

1. Escribe un segundo ADR (`0002-nodepool-topology.md`) con el diseño concreto de `NodePool`s (nombres, requirements, consolidationPolicy, weights) si eligiste Karpenter.
2. Diseña dashboard Grafana con 4 paneles clave para monitorizar el autoscaler elegido.
3. Define un runbook de 1 página para "Karpenter crea nodos que no quedan `Ready`" o equivalente para CA.

## 11. Limpieza

```bash
rm -rf /tmp/k8s-13-02
```

El ADR escrito queda bajo `/tmp/k8s-13-02/docs/adr/`. Si quieres guardarlo:

```bash
mkdir -p ~/adrs/k8s-13
cp /tmp/k8s-13-02/docs/adr/0001-autoscaler-choice.md ~/adrs/k8s-13/
```
