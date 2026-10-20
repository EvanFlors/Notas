# Actividad 02 — Análisis: "When NOT to introduce a service mesh"

## 1. Identificación

- **ID:** `k8s-18-02-when-not-mesh`
- **Tecnología:** `kubernetes`
- **Módulo:** `k8s-18-platform-patterns-bridges-helm-gitops-mesh`
- **Dificultad:** advanced
- **Duración estimada:** 45–60 min
- **Tipo:** independent (análisis escrito)

## 2. Contexto

Esta actividad **no te pide instalar un mesh**. Te pide escribir el **criterio** que una organización debería cumplir **antes** de introducirlo, y cómo responder a cada criterio con **evidencia** (métrica, documento, decisión). El objetivo pedagógico es que, por default, respondas `no mesh` y sepas defenderlo.

El validador comprueba estructura y presencia (criterios, evidencia, red flags, decisión final).

## 3. Objetivos

- Enumerar los **síntomas** que justifican evaluar un mesh.
- Enumerar los **criterios previos** (observabilidad, policy, FTE, budget, rollback) y para cada uno, **cómo se mide**.
- Enumerar **red flags** que indican que un mesh **va a doler** sin aportar.
- Nombrar **alternativas sin mesh** para cada síntoma.
- Emitir una **decisión final** `We will NOT adopt a service mesh at this time` (o `We will adopt ...` si justificas lo contrario).

## 4. Prerrequisitos

- Lección (`theory/lesson.md`), especialmente §5 y §6.
- Haber hecho `k8s-07` (networking) y `k8s-15` (observability).

## 5. Instrucciones

### 5.1 Escenario

Elige **uno** de los siguientes escenarios (o invéntate uno coherente y explícito):

- **A — Startup Series A, 15 ingenieros, 1 cluster EKS, 12 microservicios HTTP, Postgres managed.**
- **B — Empresa 300 ingenieros, 4 clusters en 2 regiones, 150 microservicios mixtos (HTTP, gRPC, Kafka consumers), 2 bases de datos operadas en cluster + varias managed.**
- **C — Fintech regulada (PCI-DSS), 60 ingenieros, 2 clusters, 40 microservicios, Postgres y Kafka managed, 3 FTE de plataforma.** (Mismo escenario que la actividad 01.)
- **D — Tu propio escenario (describe equipos, clusters, workloads, FTE de plataforma, regulación, dolor).**

### 5.2 Entregable

Edita el archivo:

```
starter/MESH-DECISION.md
```

Reemplaza los `TODO:` por tu análisis real. **No borres las cabeceras de sección** — el validador las espera literalmente.

### 5.3 Estructura mínima (secciones obligatorias)

- `# Analysis: When NOT to introduce a service mesh`
- `## Scenario`
- `## Symptoms that would justify a mesh`
- `## Preconditions before introducing a mesh`
- `## Red flags against introducing a mesh`
- `## Alternatives without a mesh`
- `## Decision`
- `## Revisit Conditions`

Y además:

- En `## Symptoms that would justify a mesh`: al menos **4** síntomas (bullets).
- En `## Preconditions before introducing a mesh`: al menos **5** precondiciones, cada una **con evidencia** (debe aparecer la palabra `Evidence` al menos 5 veces en la sección).
- En `## Red flags against introducing a mesh`: al menos **3** bullets.
- En `## Alternatives without a mesh`: al menos **3** alternativas (bullets), cada una vinculada a un síntoma.
- En `## Decision`: una línea que empiece por `We will NOT adopt a service mesh at this time` **o** por `We will adopt` con una opción válida (`Istio`, `Linkerd`, `Cilium Service Mesh`).
- En `## Revisit Conditions`: al menos **3** condiciones (bullets) que dispararían reabrir la decisión.

Longitud razonable: 500–900 palabras.

### 5.4 Validar

```bash
bash tests/validate.sh starter/MESH-DECISION.md
```

Debe terminar en `OK`.

### 5.5 (Opcional) comparar con la referencia

Lee `solution/MESH-DECISION-reference.md` solo después de intentarlo.

## 6. Resultado esperado

- `starter/MESH-DECISION.md` completo.
- Validador en `OK`.
- Puedes defender tu decisión (y, probablemente, la decisión sea `NOT`).

## 7. Criterios de aceptación

- [ ] 8 secciones presentes.
- [ ] 4+ síntomas.
- [ ] 5+ precondiciones con evidencia explícita.
- [ ] 3+ red flags.
- [ ] 3+ alternativas sin mesh.
- [ ] Decisión final explícita.
- [ ] 3+ revisit conditions.
- [ ] `tests/validate.sh` pasa.

## 8. Validación

```bash
bash tests/validate.sh starter/MESH-DECISION.md
```

## 9. Preguntas de reflexión

1. ¿Cuántos de los síntomas justificantes aplicarían hoy a tu organización real?
2. ¿Qué parte del "mesh" podrías obtener sin instalar uno (cert-manager + SPIFFE para mTLS, OTel para L7 obs, Argo Rollouts para canary)?
3. ¿Cómo influye el **tamaño del equipo de plataforma** (FTE) en la decisión?
4. ¿Qué métrica concreta publicarías para hacer esta decisión *revisable* trimestralmente?
5. ¿En qué escenario defenderías lo contrario (introducir mesh ya mismo)?

## 10. Extensiones

- **E1** — Añade una tabla comparativa Istio vs Linkerd vs Cilium Service Mesh con 5 criterios (madurez, overhead, modelo sidecar vs ambient, operabilidad, ecosistema).
- **E2** — Añade un **plan de evaluación de 90 días** si la decisión fuera "evaluar con PoC en un namespace no crítico".
- **E3** — Redacta un segundo análisis para el escenario **opuesto** (B o C según el que no elegiste).

## 11. Limpieza

```bash
git checkout -- starter/MESH-DECISION.md
```
