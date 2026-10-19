# Ejemplo 01 — Patrones de HA para Jenkins

> Lectura y análisis. Sin ejecución. Objetivo: ver las tres estrategias de HA realistas y entender por qué ninguna es "HA real sin pagar".

## 1. Punto de partida: el controller es SPOF

```
          ┌──────────────────────────────┐
          │  Jenkins controller          │
          │  (config + jobs + credentials│
          │   + queue + sessions)        │
          │  JENKINS_HOME en disco local │
          └───────┬──────────────────────┘
                  │ TCP/HTTP
       ┌──────────┼──────────┬──────────┐
       ▼          ▼          ▼          ▼
    agent-1    agent-2    agent-3    agent-N
```

Si el controller cae, el servicio cae. Los agents siguen con su build actual pero no reciben trabajo nuevo. La UI muere. Los webhooks de Git se pierden sin retry externo.

Las tres estrategias de HA que importan:

---

## 2. Patrón A — Activo-pasivo manual (OSS, barato, MTTR en minutos)

```
┌───────────────┐          ┌───────────────┐
│  Jenkins A    │ activo   │  Jenkins B    │ pasivo (apagado o drenado)
│  JENKINS_HOME │          │               │
└───────┬───────┘          └───────┬───────┘
        │                          │
        └────► backup diario ─────►│  restore script listo
                   S3/Velero
```

- **Un** controller sirve tráfico; el otro está apagado o drenado.
- Backup periódico del `JENKINS_HOME` del activo a storage central.
- Si el activo cae: operador restaura el backup en el pasivo, cambia DNS, levanta.
- **MTTR típico**: 10–30 min si el procedimiento está probado y automatizado.
- **MTTR real sin ensayos**: 2–6 h (nadie recuerda cómo descifrar credentials, se pierde la `master.key`, etc.).

Pros: cero coste adicional de licencia; fácil de entender. Contras: downtime garantizado durante el restore; requiere disciplina operativa seria.

**Cuándo elegir**: equipos pequeños/medianos sin presupuesto para CloudBees y con SLA realista (99.5% ≈ 3.5 h de caída/mes aceptable).

---

## 3. Patrón B — CloudBees CI (comercial)

```
┌────────────────────────────────────────────────────┐
│  CloudBees Operations Center                       │
│  (gestiona varios controllers y HA entre pares)    │
└─────────┬──────────────────────┬───────────────────┘
          ▼                      ▼
    ┌─────────┐            ┌─────────┐
    │ Team A  │  active─active     │ Team B  │
    │ ctrllr  │  via shared        │ ctrllr  │
    │   pair  │  storage           │   pair  │
    └─────────┘                    └─────────┘
```

- Fork comercial de Jenkins con HA real (pares activo-activo o activo-pasivo gestionado por el producto).
- *Operations Center* permite consolidar varios equipos bajo una gobernanza común.
- Alta disponibilidad gestionada por el producto; no es trabajo del operador.

Pros: HA real, soporte comercial, roadmap enterprise (RBAC avanzado, pipelines curados). Contras: licencia por controller/agent — en orgs medianas, miles de USD/mes rápido.

**Cuándo elegir**: SLA 99.9% real sobre un parque Jenkins grande donde el coste de licencia es menor que el de un equipo dedicado 24×7.

---

## 4. Patrón C — Jenkins Operator en Kubernetes

```
┌────────────────────────────────────────────┐
│   Jenkins Operator (controller K8s)        │
│   - watches CRD "Jenkins"                  │
│   - reconcilia según jenkins.yaml (JCasC)  │
└────────────────┬───────────────────────────┘
                 │ create/update
                 ▼
       ┌─────────────────────┐
       │  Jenkins Pod        │   (si cae, K8s lo re-provisiona)
       │  PVC: JENKINS_HOME  │
       └─────────────────────┘
```

- Operator define el controller como un recurso Kubernetes.
- Reconciliation loop: si el Pod muere, K8s lo recrea en segundos. Si el `jenkins.yaml` cambia (vía Git), se re-aplica.
- **No** es HA en el sentido estricto (sigue siendo single controller), pero el MTTR cae a **1–3 min**: el restart es la propia reconciliación.
- Backup del `PVC` con **Velero** (snapshot + replicación cross-region).

Pros: barato, declarativo, encaja en workflows GitOps. Contras: no cubre un fallo del PVC (si el disco se corrompe, dependes del Velero restore).

**Cuándo elegir**: ya corres en K8s, aceptas MTTR de minutos y quieres JCasC + reproducibilidad.

---

## 5. Comparativa resumida

| Dimensión | Activo-pasivo manual | CloudBees CI | Jenkins Operator |
|-----------|----------------------|--------------|------------------|
| MTTR típico | 10–30 min (si entrenado) | < 1 min (automático) | 1–3 min |
| Coste adicional | ~0 | Alto (licencia) | ~0 (OSS, requiere K8s) |
| Complejidad operativa | Media | Baja | Media-alta |
| HA real activo-activo | No | Sí | No |
| Encaja con GitOps | Manual | Parcial | Nativo |
| SLA realista | 99.5% | 99.9% | 99.5–99.8% |

---

## 6. Preguntas de autocomprobación

1. En el patrón activo-pasivo manual, ¿qué archivo del `JENKINS_HOME` **no puedes olvidar** en el backup o el restore no desciframiento de credentials? (Pista: `secrets/`).
2. Si CloudBees CI ofrece activo-activo, ¿por qué los agents no se duplican? ¿A qué se refiere "activo-activo"?
3. En el patrón Operator, ¿qué pasa si el PVC se corrompe y Velero tiene un snapshot de ayer? ¿Qué pierdes?
4. Dado un equipo de 15 personas con un Jenkins LTS en VM, 80 pipelines, sin presupuesto para licencias, ¿qué patrón recomendarías y por qué?
5. ¿Puedes anunciar SLA 99.9% con el patrón A? ¿Qué sería lo máximo honesto?

Las respuestas se trabajan en la actividad `01-operate-at-scale-adr`.
