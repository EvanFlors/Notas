# Actividad 01 — ADR: contrato de arquitectura de plataforma

## 1. Identificación

- **ID:** `k8s-18-01-platform-contract-adr`
- **Tecnología:** `kubernetes`
- **Módulo:** `k8s-18-platform-patterns-bridges-helm-gitops-mesh`
- **Dificultad:** advanced
- **Duración estimada:** 60–90 min
- **Tipo:** architecture (entregable escrito, independiente)

## 2. Contexto

Vas a cerrar el módulo con un ADR real: el **contrato de la plataforma mínima viable** para un escenario dado. El validador **no juzga qué elecciones hiciste** (hay varias respuestas razonables): verifica que estén **tomadas, justificadas contra alternativas y con triggers de revisión**.

## 3. Objetivos

- Traducir un escenario a restricciones de plataforma.
- Decidir, con criterio: **Helm vs Kustomize**, **Argo CD vs Flux**, **service mesh sí/no**, **cost management on/off**.
- Documentar el contrato plataforma ↔ producto (qué ofrece, qué espera).
- Nombrar alternativas descartadas, consecuencias, riesgos y triggers de revisión.

## 4. Prerrequisitos

- Lección (`theory/lesson.md`) leída, en particular §2, §3, §5, §6 y §9.
- Ejemplos 01–03 recorridos (al menos conceptualmente).
- Haber hecho los módulos `k8s-14`, `k8s-16`, `k8s-17`.

## 5. Instrucciones

### 5.1 Escenario asignado

> **Organización:** fintech regulada (PCI-DSS). ~ 60 ingenieros de producto en 7 equipos; 2 clusters EKS (stage, prod) + 1 kind local por dev.
> **Workloads:** ~ 40 microservicios, mayoría HTTP/gRPC; 3 Postgres gestionados fuera del cluster (RDS); 1 Kafka managed (MSK).
> **Entrega hoy:** cada equipo tiene su `make deploy` que corre `kubectl apply` desde CI con un rol `cluster-admin` compartido. Drift frecuente. No hay cost visibility.
> **Lo que ya hay:** `kube-prometheus-stack`, `cert-manager`, `ingress-nginx`, `Velero`, Pod Security Admission `baseline` (aspiran a `restricted`). Sin policy framework. Sin GitOps. Sin mesh.
> **Equipo de plataforma:** 3 personas FTE.
> **Dolor principal:** lead time alto, drift, auditoría frágil (PCI-DSS pregunta "¿qué está corriendo exactamente?" y nadie contesta rápido). Factura cloud creciendo sin explicación.
> **Restricciones:** 6 meses para la primera versión del contrato, con capacidad de iterar.

**Tu misión:** proponer la **plataforma mínima viable** para resolver el dolor y entrar en zona auditable, en formato ADR.

### 5.2 Entregable

Edita el archivo:

```
starter/ADR-001-platform-contract.md
```

Reemplaza los `TODO:` por contenido real. **No borres las cabeceras de sección** — el validador las espera literalmente.

### 5.3 Estructura mínima (secciones obligatorias)

Las siguientes cabeceras deben aparecer textualmente:

- `# ADR-001: Platform Contract`
- `## Status`
- `## Context`
- `## Decisions`
- `## Platform Contract`
- `## Alternatives Considered`
- `## Consequences`
- `## Risks and Mitigations`
- `## Review Triggers`

Y además:

- **4 bloques de decisión explícitos** en `## Decisions`, uno por cada eje. Cada uno debe empezar por `We will adopt` seguido de la opción, cubriendo:
  - **packaging**: `Helm`, `Kustomize`, o `Helm and Kustomize`.
  - **GitOps**: `Argo CD` o `Flux`.
  - **service mesh**: `no service mesh`, `Istio`, `Linkerd`, `Cilium Service Mesh` (se **espera** `no service mesh` para este escenario; cualquier otra elección debe justificarse en `## Consequences` y `## Risks`).
  - **cost management**: `OpenCost`, `Kubecost`, o `no cost management`.
- **Al menos 3 alternativas descartadas** en `## Alternatives Considered` (cada una con razón ≥ 1 frase).
- **Al menos 4 consecuencias** (positivas y/o negativas) en `## Consequences`.
- **Al menos 3 riesgos con mitigación** en `## Risks and Mitigations` (la palabra `Mitigation` debe aparecer al menos 3 veces).
- **Al menos 2 criterios** de revisión en `## Review Triggers` (p. ej. "si aparece el segundo cluster prod", "si el lead time p50 no baja en 3 meses").
- En `## Platform Contract`: dos listados que describan **qué ofrece** la plataforma y **qué espera** del producto.

Longitud razonable: 600–1200 palabras.

### 5.4 Validar

```bash
bash tests/validate.sh starter/ADR-001-platform-contract.md
```

Debe terminar en `OK`. Si falla, el output dice qué falta.

### 5.5 (Opcional) comparar con la referencia

Tras intentarlo, lee `solution/ADR-reference.md`. Es **una** respuesta razonada, no la única.

## 6. Resultado esperado

- `starter/ADR-001-platform-contract.md` con todas las secciones, decisiones y contratos.
- Validador en `OK`.
- Puedes defender *por qué* esa plataforma mínima resuelve el dolor y por qué el mesh queda fuera.

## 7. Criterios de aceptación

- [ ] ADR con las 9 secciones obligatorias.
- [ ] 4 decisiones explícitas (packaging, GitOps, mesh, cost).
- [ ] Contrato plataforma ↔ producto escrito.
- [ ] 3+ alternativas descartadas.
- [ ] 4+ consecuencias.
- [ ] 3+ riesgos con mitigación.
- [ ] 2+ review triggers.
- [ ] `tests/validate.sh` pasa.
- [ ] Longitud ≥ 600 palabras.

## 8. Validación

```bash
bash tests/validate.sh starter/ADR-001-platform-contract.md
```

El validador comprueba **estructura y presencia**, no corrección semántica.

## 9. Preguntas de reflexión

1. ¿Qué datos del escenario pesaron más en elegir Argo CD vs Flux?
2. ¿Qué condiciones habría que cumplir para que, en 12 meses, **sí** introduzcas un service mesh?
3. ¿Cómo cambiaría tu ADR si fueran 6 clusters en 3 regiones?
4. ¿Qué métricas pondrías en el dashboard de plataforma a 90 días?
5. ¿Qué deprecations publicarías ya hoy (sabiendo que vas a cambiar `kubectl apply` por GitOps)?

## 10. Extensiones

- **E1** — Añade un diagrama ASCII de la plataforma en el ADR, mostrando dónde encaja cada pieza y el flujo del PR → prod.
- **E2** — Añade un rollout plan de 6 meses (M1–M6) con hitos y comunicaciones.
- **E3** — Escribe un ADR complementario (`ADR-002`) justificando `restricted` Pod Security Admission + Kyverno con 3 policies obligatorias.

## 11. Limpieza

```bash
# Si quieres volver al starter inicial
git checkout -- starter/ADR-001-platform-contract.md
```
