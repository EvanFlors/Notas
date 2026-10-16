# Actividad 01 — ADR del contrato GitOps de plataforma

## 1. Identificación

- **ID:** `argo-12-01-platform-contract-adr`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `argo-12-platform-patterns-promotion-previews-observability`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto

Tras levantar Argo CD, hardening (`argo-11`), secretos (`argo-09`) y ApplicationSets (`argo-07`), toca escribir el **contrato operativo** de la plataforma. Es el documento que define cómo los equipos interactúan con GitOps: cómo promueven, cómo nacen previews, qué pasa con drift, quién recibe alertas, cómo nace un servicio nuevo. Sin este documento, cada equipo inventa lo suyo y la plataforma se fragmenta.

Trabajas con un escenario ficticio pero realista (ver `starter/scenario.md`). Produces un ADR único, defendible, que cubra las 5 áreas.

## 3. Objetivos

Al terminar deberías:

- Elegir una **estrategia de promoción** (branch / folder-overlay / image updater o mezcla) y defenderla contra alternativas.
- Definir el **contrato de PR previews**: nombrado de namespace, TTL, `ResourceQuota`, limpieza automática, cuenta/credenciales.
- Fijar la **política de drift**: `selfHeal` por ambiente, uso de `ignoreDifferences`, `syncWindows` en prod.
- Especificar la **observabilidad**: qué métricas se exponen, qué alertas despiertan a quién, dashboards oficiales elegidos.
- Documentar la **integración con IDP** (Backstage o alternativa): qué pasa cuando se crea un servicio nuevo.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` del módulo.
- Haber reproducido los 4 ejemplos (`examples/01..04`).
- Haber hecho `argo-07-01-env-per-folder-appset`, `argo-09-02-tradeoffs-adr`, `argo-11-01-harden-argocd-install`.
- Markdown editor.

**Costos**: ninguno (solo documento).

## 5. Instrucciones

### 5.1 Leer el escenario

```bash
cat starter/scenario.md
```

Es una org ficticia (nombre, número de equipos, servicios, ambientes, compliance). Trabaja sobre ese escenario — no te inventes variantes.

### 5.2 Copiar la plantilla ADR

```bash
mkdir -p /tmp/argo-12-adr && cp starter/ADR-template.md /tmp/argo-12-adr/ADR-001-gitops-contract.md
```

### 5.3 Completar las 5 secciones (orden obligatorio)

1. **Estrategia de promoción**: tabla ambiente × estrategia con justificación.
2. **PR previews**: contrato con 7 puntos (ver plantilla).
3. **Drift**: política por ambiente + `ignoreDifferences` templates comunes + `syncWindows`.
4. **Observabilidad**: lista mínima de métricas, 3+ alertas con PromQL concreto, 2 dashboards elegidos.
5. **IDP flow**: diagrama Mermaid o pseudocódigo del "crear servicio nuevo".

### 5.4 Cada decisión debe tener

- **Opción elegida**.
- **Alternativas consideradas** (al menos 2).
- **Trade-off aceptado** (nunca "no hay trade-off" — siempre lo hay).
- **Métrica de éxito** (cómo sabrás en 6 meses si fue correcta).

### 5.5 Validar

```bash
bash tests/validate.sh /tmp/argo-12-adr/ADR-001-gitops-contract.md
```

El validador comprueba estructura mínima (secciones, headers, longitud). El fondo de la decisión lo evalúa un revisor humano.

## 6. Resultado esperado

- Archivo `/tmp/argo-12-adr/ADR-001-gitops-contract.md` con las 5 secciones completas.
- Longitud razonable (≥ 200 líneas; indicador, no métrica dura).
- Al menos un diagrama Mermaid (promoción o IDP flow).
- Métricas con PromQL concreto (no "monitorear la latencia").

## 7. Criterios de aceptación

- Las 5 áreas presentes y defendidas.
- Cada decisión con alternativas y trade-off.
- Nombrado de namespaces previews determinista (`pr-{number}` o similar) y limpieza automática especificada.
- Al menos 3 alertas con `expr` PromQL válido.
- Flow de IDP cubre: creación de repo de código, PR al repo de infra, descubrimiento por ApplicationSet.

## 8. Validación

```bash
bash tests/validate.sh /tmp/argo-12-adr/ADR-001-gitops-contract.md
```

Checks automáticos:

- Existen las 5 headers de nivel 2 esperadas.
- Hay al menos 3 bloques ```promql``` o `expr:` literal.
- Hay al menos un bloque Mermaid.
- Hay una tabla con los ambientes (`dev`, `stg`, `prod`).
- Hay una sección "Alternativas" o "Trade-offs" nombrada.

## 9. Preguntas de reflexión

- Si la org adquiere otro equipo con 20 servicios nuevos, ¿qué sección del ADR es la primera que renegociarías?
- Image updater escribe a prod → ¿qué controles compensan la pérdida de "humano en el loop"?
- `selfHeal` en prod revirtió un parche de emergencia. ¿Cambias la política o cambias el runbook?
- La métrica `argocd_app_reconcile_bucket` p99 pasa de 10s a 90s. ¿Qué métricas correlacionadas pedirías antes de abrir ticket al equipo de infra?
- Backstage genera 100 servicios en 6 meses. ¿Qué parte del contrato se rompe primero y por qué?

## 10. Extensiones

- Añadir sección de **DR** (disaster recovery): cómo recuperar Argo CD mismo (relacionar con `argo-11-02-recover-argocd-from-backup`).
- Añadir **matriz de secretos** por ambiente (relacionar con `argo-09`).
- Añadir **SLOs internos de la plataforma** con error budgets.
- Añadir diagrama de "quién puede mergear qué" con `CODEOWNERS` concreto.

## 11. Limpieza

```bash
# Nada corriendo; es un documento.
# Opcional:
rm -rf /tmp/argo-12-adr
```
